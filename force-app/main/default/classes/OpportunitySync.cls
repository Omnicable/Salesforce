/**
 * @description Synchronous header sync that maps {@link QuotesOrdersCredits_Header__c} rows to {@link Opportunity}
 *              records via DataWeave ({@code qocToOpportunity}). Matches existing rows by {@link Opportunity#Order_Number__c},
 *              applies insert/update routing with partial-success DML through {@link SyncBase}, then creates primary
 *              {@link OpportunityContactRole} rows when {@link Opportunity#Contact__c} is set on insert or changes on update.
 *              <p>
 *              Typically invoked from {@link OpportunityHeaderSyncBatch#execute} as the first step in the
 *              Opportunity, Quote, and Order sync chain. {@link #standardPricebookId} is passed to {@link QuoteSync}
 *              and {@link OrderSync} in the same batch chunk.
 *              </p>
 *              <p>
 *              Opportunity team membership is handled by the Add Opportunity Team flow, not this class.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see OpportunityHeaderSyncBatch
 * @see QuoteSync
 * @see OrderSync
 */
public class OpportunitySync extends SyncBase {
    /**
     * @description {@link OpportunityContactRole#Role} applied to the header buyer primary contact role.
     */
    private static final String OPPORTUNITY_CONTACT_ROLE = 'Technical Buyer';

    /**
     * @description {@link Opportunity_Sync_Item__c#Record_Type__c} value for contact-role DML failures.
     */
    private static final String CONTACT_ROLE_SYNC_ITEM_TYPE = 'Opportunity Contact Role';

    /**
     * @description {@link UserLicense} names allowed to own {@link Opportunity} records in this org.
     */
    private static final Set<String> OPPORTUNITY_OWNER_LICENSES = new Set<String>{ 'Salesforce', 'Salesforce Platform' };

    /**
     * @description QOC header rows in the current sync scope.
     */
    private List<QuotesOrdersCredits_Header__c> headers;

    /**
     * @description Run summary; inserted by {@link SyncBase#saveRecords} with nested sync items on failure.
     */
    private Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
        Is_Successful__c = true,
        Record_Type__c = 'Opportunity',
        Update_Count__c = 0,
        Insert_Count__c = 0,
        Total_Count__c = 0,
        Error_Count__c = 0,
        Existing_Record_Count__c = 0
    );

    /**
     * @description Standard price book applied to each Opportunity; shared with Quote and Order sync in the batch.
     */
    public Id standardPricebookId;

    /**
     * @description Existing Opportunities keyed by {@link Opportunity#Order_Number__c} for insert vs update routing.
     */
    private Map<String, Opportunity> orderNumberToOpportunityMap = new Map<String, Opportunity>();

    /**
     * @description Existing Opportunities keyed by {@link Opportunity#Quote_Order_Credit__c} for insert vs update routing.
     */
    private Map<Id, Opportunity> headerIdToOpportunityMap = new Map<Id, Opportunity>();

    /**
     * @description Opportunities queued for insert during {@link #runSync}; cleared at the start of each run.
     */
    List<Opportunity> toInsert = new List<Opportunity>();

    /**
     * @description Opportunities queued for update during {@link #runSync}; cleared at the start of each run.
     */
    List<Opportunity> toUpdate = new List<Opportunity>();


    /**
     * @description Captures header scope and resolves the org standard (or fallback) price book.
     * @param headers QOC header rows driving the sync; null is allowed but {@link #runSync} no-ops on empty scope.
     */
    public OpportunitySync(List<QuotesOrdersCredits_Header__c> headers, Id standardPricebookId) {
        this.headers = headers;
        this.report.Total_Count__c = headers.size();
        this.standardPricebookId = standardPricebookId;
    }
    
    /**
     * @description Runs the full Opportunity sync for the current header scope: collect keys, load existing rows,
     *              transform via DataWeave, route to insert/update lists, persist Opportunities, then sync contact roles
     *              when {@link Opportunity#Contact__c} is set or changes.
     */
    public void runSync() {
        if (headers == null || headers.isEmpty()) {
            return;
        }

        toInsert.clear();
        toUpdate.clear();
        orderNumberToOpportunityMap.clear();

        Set<String> orderNumbers = new Set<String>();
        Set<Id> headerIds = new Set<Id>();
        Set<Id> ownerIdsToCheck = new Set<Id>();
        collectHeaderScopeKeys(headers, orderNumbers, headerIds, ownerIdsToCheck);

        getExistingRecords(orderNumbers, headerIds);
        List<Opportunity> opportunities = (List<Opportunity>) JSON.deserialize(
            syncDataWeaveToJson('qocToOpportunity', headers),
            List<Opportunity>.class
        );
        Set<Id> activeOwnerIds = getActiveOwnerIds(ownerIdsToCheck);
        assignRecordsToUpdateAndInsert(opportunities, activeOwnerIds);
        saveRecords(toInsert, toUpdate, report);
        syncOpportunityContactRoles(mergedOpportunitiesForContactRoleSync());
    }

    /**
     * @description Returns Opportunities from {@link #toInsert} and {@link #toUpdate} after DML (Ids set on successful saves).
     * @return Opportunities eligible for contact-role sync.
     */
    private List<Opportunity> mergedOpportunitiesForContactRoleSync() {
        List<Opportunity> saved = new List<Opportunity>();
        saved.addAll(toInsert);
        saved.addAll(toUpdate);
        return saved;
    }

    /**
     * @description Resolves which owner Ids from the header scope refer to active Salesforce CRM users
     *              eligible to own {@link Opportunity} records (Standard user type with a Salesforce license).
     * @param ownerIdsToCheck Distinct {@link QuotesOrdersCredits_Header__c#Inside_AM_Name__c} values.
     * @return Eligible active owner user Ids from that set.
     */
    private Set<Id> getActiveOwnerIds(Set<Id> ownerIdsToCheck) {
        Set<Id> activeOwnerIds = new Set<Id>();
        if (ownerIdsToCheck == null || ownerIdsToCheck.isEmpty()) {
            return activeOwnerIds;
        }
        for (User u : [
            SELECT Id
            FROM User
            WHERE Id IN :ownerIdsToCheck
                AND IsActive = true
                AND UserType = 'Standard'
                AND Profile.UserLicense.Name IN :OPPORTUNITY_OWNER_LICENSES
        ]) {
            activeOwnerIds.add(u.Id);
        }
        return activeOwnerIds;
    }

    /**
     * @description Applies price book, matches {@link #orderNumberToOpportunityMap}, and fills {@link #toInsert}
     *              or {@link #toUpdate}. On update, preserves {@link Opportunity#StageName} for non-Order and non-Credit
     *              types so user-set stages are not overwritten. Reassigns {@link Opportunity#OwnerId} to the running
     *              user when the proposed owner is inactive or lacks an eligible Salesforce license.
     * @param opportunities  Opportunity rows produced by DataWeave.
     * @param activeOwnerIds User Ids eligible for opportunity ownership.
     */
    private void assignRecordsToUpdateAndInsert(List<Opportunity> opportunities, Set<Id> activeOwnerIds) {
        for (Opportunity o : opportunities) {
            
            if (orderNumberToOpportunityMap.containsKey(o.Order_Number__c) || headerIdToOpportunityMap.containsKey(o.Quote_Order_Credit__c)) {
                Opportunity existingOpp = orderNumberToOpportunityMap.get(o.Order_Number__c);
                if(existingOpp == null) {
                    existingOpp = headerIdToOpportunityMap.get(o.Quote_Order_Credit__c);
                }
                
                o.Id = existingOpp.Id;

                if (o.Type__c != 'Order' && o.Type__c != 'Credit') {
                    o.StageName = existingOpp.StageName;
                }

                if(o.CloseDate == null) {
                    o.CloseDate = existingOpp.CloseDate;
                }
                if(o.CloseDate == null) {
                    o.CloseDate = Date.today().addDays(2);
                }
                
                Id effectiveOwnerId = (o.OwnerId != null) ? o.OwnerId : existingOpp.OwnerId;
                if (effectiveOwnerId != null && !activeOwnerIds.contains(effectiveOwnerId)) {
                    o.OwnerId = UserInfo.getUserId();
                }
                toUpdate.add(o);
            } else {
                o.Pricebook2Id = standardPricebookId;
                o.CloseDate = Date.today().addDays(2);
                
                if (o.OwnerId != null && !activeOwnerIds.contains(o.OwnerId)) {
                    o.OwnerId = UserInfo.getUserId();
                }
                toInsert.add(o);
            }
        }

    }
    
    
    /**
     * @description Single pass over headers to collect lookup keys (null-safe).
     * @param headerRows      Header rows in sync scope; null is ignored.
     * @param orderNumberKeys Populated with non-null {@link QuotesOrdersCredits_Header__c#Order_Number__c}
     *                        and {@link QuotesOrdersCredits_Header__c#Name} values.
     * @param ownerIdsToCheck Populated with non-null {@link QuotesOrdersCredits_Header__c#Inside_AM_Name__c} values.
     */
    private static void collectHeaderScopeKeys(
        List<QuotesOrdersCredits_Header__c> headerRows,
        Set<String> orderNumberKeys,
        Set<Id> headerIds,
        Set<Id> ownerIdsToCheck
    ) {
        if (headerRows == null) {
            return;
        }
        for (QuotesOrdersCredits_Header__c h : headerRows) {
            if (h == null) {
                continue;
            }
            if (h.Order_Number__c != null) {
                orderNumberKeys.add(h.Order_Number__c);
            }
            if (h.Name != null) {
                orderNumberKeys.add(h.Name);
            }
            if (h.Inside_AM_Name__c != null) {
                ownerIdsToCheck.add(h.Inside_AM_Name__c);
            }
            if (h.Id != null) {
                headerIds.add(h.Id);
            }
        }
    }

    /**
     * @description Queries existing Opportunities with {@code FOR UPDATE} and populates {@link #orderNumberToOpportunityMap}.
     *              Sets {@link Opportunity_Sync_Report__c#Existing_Record_Count__c} from the map size.
     * @param orderNumbers Distinct order number keys from {@link #collectHeaderScopeKeys}; empty skips the query.
     */
    private void getExistingRecords(Set<String> orderNumbers, Set<Id> headerIds) {
        
        for (Opportunity o : [
            SELECT Id, Order_Number__c, StageName, OwnerId, Quote_Order_Credit__c, Contact__c, CloseDate
            FROM Opportunity
            WHERE Order_Number__c IN :orderNumbers OR Quote_Order_Credit__c IN :headerIds
        ]) {
            if (o.Order_Number__c != null) {
                orderNumberToOpportunityMap.put(o.Order_Number__c, o);
            }

            if(o.Quote_Order_Credit__c != null) {
                headerIdToOpportunityMap.put(o.Quote_Order_Credit__c, o);
            }
        }
        report.Existing_Record_Count__c = orderNumberToOpportunityMap.size();
    }


    /**
     * @description Stable composite key for an opportunity/contact pair in contact-role maps.
     * @param opportunityId Opportunity Id.
     * @param contactId     Contact Id.
     * @return String key of the form {@code "<opportunityId>#<contactId>"}.
     */
    private String opportunityContactRoleKey(Id opportunityId, Id contactId) {
        return String.valueOf(opportunityId) + '#' + String.valueOf(contactId);
    }
    
    
    /**
     * @description Ensures each saved Opportunity has a primary {@link OpportunityContactRole} when
     *              {@link Opportunity#Contact__c} is set on insert or changes on update. On contact change,
     *              deletes the previous contact role and inserts a new one; existing roles are not updated.
     *              Call only after Opportunity DML so rows have Ids.
     * @param opportunities Opportunities from {@link #toInsert} and {@link #toUpdate} after {@link #saveRecords}.
     */
    private void syncOpportunityContactRoles(List<Opportunity> opportunities) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }

        Set<Id> insertedOppIds = new Set<Id>();
        for (Opportunity inserted : toInsert) {
            if (inserted != null && inserted.Id != null) {
                insertedOppIds.add(inserted.Id);
            }
        }

        List<OpportunityContactRole> rolesToInsert = new List<OpportunityContactRole>();
        Map<Id, Id> previousContactIdByOppId = new Map<Id, Id>();

        for (Opportunity o : opportunities) {
            if (o == null || o.Id == null) {
                continue;
            }

            Id newContactId = o.Contact__c;
            if (insertedOppIds.contains(o.Id)) {
                if (newContactId != null) {
                    rolesToInsert.add(buildPrimaryContactRole(o.Id, newContactId));
                }
                continue;
            }

            Id previousContactId = getPreviousContactId(o.Id);
            if (newContactId == previousContactId) {
                continue;
            }

            if (previousContactId != null) {
                previousContactIdByOppId.put(o.Id, previousContactId);
            }
            if (newContactId != null) {
                rolesToInsert.add(buildPrimaryContactRole(o.Id, newContactId));
            }
        }

        List<OpportunityContactRole> rolesToDelete = loadContactRolesToDelete(previousContactIdByOppId);
        persistContactRoleChanges(
            filterContactRolesToInsert(rolesToInsert),
            rolesToDelete
        );
    }

    /**
     * @description Builds a primary {@link OpportunityContactRole} for the header buyer contact.
     * @param opportunityId Opportunity Id.
     * @param contactId     Buyer contact Id.
     * @return New contact role row pending insert.
     */
    private OpportunityContactRole buildPrimaryContactRole(Id opportunityId, Id contactId) {
        return new OpportunityContactRole(
            OpportunityId = opportunityId,
            ContactId = contactId,
            Role = OPPORTUNITY_CONTACT_ROLE,
            IsPrimary = true
        );
    }

    /**
     * @description Returns the buyer contact Id stored on the Opportunity before the current sync update.
     * @param opportunityId Opportunity Id from an update path in {@link #toUpdate}.
     * @return Previous {@link Opportunity#Contact__c}, or null when unknown or unset.
     */
    private Id getPreviousContactId(Id opportunityId) {
        for (Opportunity existing : orderNumberToOpportunityMap.values()) {
            if (existing.Id == opportunityId) {
                return existing.Contact__c;
            }
        }
        for (Opportunity existing : headerIdToOpportunityMap.values()) {
            if (existing.Id == opportunityId) {
                return existing.Contact__c;
            }
        }
        return null;
    }

    /**
     * @description Loads existing contact roles for Opportunities whose buyer contact changed.
     * @param previousContactIdByOppId Opportunity Id to prior {@link Opportunity#Contact__c}.
     * @return Contact roles to delete for the previous buyer contacts.
     */
    private List<OpportunityContactRole> loadContactRolesToDelete(Map<Id, Id> previousContactIdByOppId) {
        List<OpportunityContactRole> rolesToDelete = new List<OpportunityContactRole>();
        if (previousContactIdByOppId.isEmpty()) {
            return rolesToDelete;
        }
        for (OpportunityContactRole ocr : [
            SELECT Id, OpportunityId, ContactId
            FROM OpportunityContactRole
            WHERE OpportunityId IN :previousContactIdByOppId.keySet()
        ]) {
            Id previousContactId = previousContactIdByOppId.get(ocr.OpportunityId);
            if (previousContactId != null && ocr.ContactId == previousContactId) {
                rolesToDelete.add(ocr);
            }
        }
        return rolesToDelete;
    }

    /**
     * @description Removes insert candidates that already have a contact role on the Opportunity.
     * @param rolesToInsert Proposed contact roles pending insert.
     * @return Filtered list excluding opportunity/contact pairs that already exist.
     */
    private List<OpportunityContactRole> filterContactRolesToInsert(List<OpportunityContactRole> rolesToInsert) {
        if (rolesToInsert.isEmpty()) {
            return rolesToInsert;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (OpportunityContactRole role : rolesToInsert) {
            opportunityIds.add(role.OpportunityId);
        }

        Set<String> existingRoleKeys = new Set<String>();
        for (OpportunityContactRole existing : [
            SELECT OpportunityId, ContactId
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds
        ]) {
            existingRoleKeys.add(opportunityContactRoleKey(existing.OpportunityId, existing.ContactId));
        }

        List<OpportunityContactRole> filteredRoles = new List<OpportunityContactRole>();
        for (OpportunityContactRole role : rolesToInsert) {
            if (!existingRoleKeys.contains(opportunityContactRoleKey(role.OpportunityId, role.ContactId))) {
                filteredRoles.add(role);
            }
        }
        return filteredRoles;
    }

    /**
     * @description Deletes and inserts contact roles with partial success; failures become {@link Opportunity_Sync_Item__c}
     *              rows linked to {@link #report}.
     * @param rolesToInsert Contact roles to insert.
     * @param rolesToDelete Contact roles to delete.
     */
    private void persistContactRoleChanges(
        List<OpportunityContactRole> rolesToInsert,
        List<OpportunityContactRole> rolesToDelete
    ) {
        List<Opportunity_Sync_Item__c> errors = new List<Opportunity_Sync_Item__c>();
        if (!rolesToDelete.isEmpty()) {
            errors.addAll(
                contactRoleDeleteErrorsFromDml(Database.delete(rolesToDelete, false), rolesToDelete)
            );
        }
        if (!rolesToInsert.isEmpty()) {
            errors.addAll(
                contactRoleErrorsFromDml(Database.insert(rolesToInsert, false), rolesToInsert)
            );
        }
        if (errors.isEmpty()) {
            return;
        }
        report.Is_Successful__c = false;
        if (report.Id == null) {
            insert report;
        }
        for (Opportunity_Sync_Item__c item : errors) {
            item.Opportunity_Sync_Report__c = report.Id;
        }
        insert errors;
    }

    /**
     * @description Builds sync items for failed contact-role delete rows.
     * @param results Delete results in the same order as {@code rows}.
     * @param rows    Contact roles submitted for delete.
     * @return        {@link Opportunity_Sync_Item__c} rows for failed deletes; empty when all succeed.
     */
    private List<Opportunity_Sync_Item__c> contactRoleDeleteErrorsFromDml(
        Database.DeleteResult[] results,
        List<OpportunityContactRole> rows
    ) {
        List<Opportunity_Sync_Item__c> errors = new List<Opportunity_Sync_Item__c>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                errors.add(
                    new Opportunity_Sync_Item__c(
                        Error__c = JSON.serialize(results[i].getErrors()),
                        Record__c = JSON.serialize(rows[i]),
                        Record_Type__c = CONTACT_ROLE_SYNC_ITEM_TYPE,
                        Status_Code__c = String.valueOf(results[i].getErrors()[0].statusCode)
                    )
                );
            }
        }
        return errors;
    }

    /**
     * @description Builds sync items for failed contact-role DML rows.
     * @param results DML results in the same order as {@code rows}.
     * @param rows    Contact roles submitted for the DML operation.
     * @return        {@link Opportunity_Sync_Item__c} rows for failed saves; empty when all succeed.
     */
    private List<Opportunity_Sync_Item__c> contactRoleErrorsFromDml(
        Database.SaveResult[] results,
        List<OpportunityContactRole> rows
    ) {
        List<Opportunity_Sync_Item__c> errors = new List<Opportunity_Sync_Item__c>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                errors.add(
                    new Opportunity_Sync_Item__c(
                        Error__c = JSON.serialize(results[i].getErrors()),
                        Record__c = JSON.serialize(rows[i]),
                        Record_Type__c = CONTACT_ROLE_SYNC_ITEM_TYPE,
                        Status_Code__c = String.valueOf(results[i].getErrors()[0].statusCode)
                    )
                );
            }
        }
        return errors;
    }
}