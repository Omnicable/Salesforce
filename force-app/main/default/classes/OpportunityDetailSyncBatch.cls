/**
 * @description Batchable entry that reloads {@link QuoteOrderCredit_Details__c} rows changed since the last
 *              checkpoint and runs the line sync chain per chunk: {@link OpportunityLineItemSync}, then
 *              {@link QuoteLineSync}, then {@link OrderLineSync}. Incremental scope is driven by
 *              {@link LastModifiedDate} using {@link Opportunity_Sync__c#Detail_Last_Modified__c}; when that
 *              watermark is null, all details are processed. After each successful chunk,
 *              {@link #saveSettings} upserts the highest {@link LastModifiedDate} seen so far into org defaults.
 *              <p>
 *              Typically invoked from {@link OpportunityLineSyncScheduler} for scheduled incremental sync, or
 *              constructed with explicit detail Ids for targeted sync (watermark ignored when {@link #detailIds}
 *              is non-empty). Resolves {@link Product2} and {@link PricebookEntry} rows per chunk before
 *              delegating to the line sync classes.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see OpportunityLineItemSync
 * @see QuoteLineSync
 * @see OrderLineSync
 * @see OpportunityLineSyncScheduler
 * @see OpportunityHeaderSyncBatch
 */
public  class OpportunityDetailSyncBatch extends SyncBase implements Database.Batchable<SObject>{
    /**
     * @description Detail record Ids for targeted sync; bound in {@link #buildQueryByIds}. When empty,
     *              {@link #start} uses the incremental watermark query from {@link #buildQuery}.
     */
    private Set<Id> detailIds = new Set<Id>();
    
    /**
     * @description Ext_Id values captured at enqueue time for trigger parity; not referenced in query building.
     */
    private Set<String> extIds = new Set<String>();
    
    /**
     * @description Highest {@link QuoteOrderCredit_Details__c#LastModifiedDate} processed in this batch run.
     */
    private Datetime latestProcessedDetailLastModifiedDate;
    
    /**
     * @description Default constructor for incremental sync from {@link Opportunity_Sync__c}.
     */
    public OpportunityDetailSyncBatch() { }
    
    /**
     * @description Captures explicit detail scope (and optional ext-id snapshot) for a targeted batch run.
     * @param detailIds Detail Ids to sync; null becomes an empty set and {@link #start} falls back to incremental
     *                  watermark query. Non-empty values bypass the watermark.
     * @param extIds    Ext_Id values from the caller; stored for trigger parity, not used in SOQL here.
     */
    public OpportunityDetailSyncBatch(Set<Id> detailIds, Set<String> extIds) {
        this.detailIds = detailIds == null ? new Set<Id>() : detailIds;
        this.extIds = extIds == null ? new Set<String>() : extIds;
    }
    
    /**
     * @description Returns a query locator for detail rows in scope. Uses {@link #buildQueryByIds} when
     *              {@link #detailIds} is non-empty; otherwise loads rows after the org detail-sync watermark via
     *              {@link #buildQuery}.
     * @param bc Batch context supplied by the platform.
     * @return Query locator for {@link QuoteOrderCredit_Details__c} rows in scope.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime detailLastModifiedDate = getDetailLastModifiedDate();
        // Bind variables must be in this method's scope for Database.getQueryLocator(String).
        Map<String, List<String>> detailErrors = getDetailErrors();
        List<String> additionalDetailIds = detailErrors.get('additionalDetailIds');
        List<String> additionalHeaderIds = detailErrors.get('additionalHeaderIds');
        if (additionalDetailIds == null) {
            additionalDetailIds = new List<String>();
        }
        if (additionalHeaderIds == null) {
            additionalHeaderIds = new List<String>();
        }
        return Database.getQueryLocator(buildQuery(detailLastModifiedDate));
    }
    
    /**
     * @description Runs opportunity line item, quote line, and order line sync for one batch chunk. Resolves
     *              products and price book entries, then invokes the line sync chain in order. On success,
     *              persists the chunk watermark via {@link #saveSettings}. On failure, logs debug output and
     *              inserts an {@link Opportunity_Sync_Report__c} row.
     * @param bc    Batch context supplied by the platform.
     * @param scope Chunk of {@link QuoteOrderCredit_Details__c} rows from {@link #start}.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<QuoteOrderCredit_Details__c> details = (List<QuoteOrderCredit_Details__c>) scope;
        if (details == null || details.isEmpty()) {
            return;
        }
        
        try{
            
            Id standardPricebookId = getStandardPricebookId();
            List<String> partNumbers = new List<String>();
            for (QuoteOrderCredit_Details__c detail : details) {
                if (detail.Item_Number__c != null) {
                    partNumbers.add(detail.Item_Number__c);
                }
            }
            
            Map<String, Id> product2IdByPartRef = getProducts(partNumbers);
            product2IdByPartRef.put(SyncBase.NON_STOCK_ITEM_KEY, getNonStockProduct(standardPricebookId).Id);
            Map<Id, PricebookEntry> pricebookEntryByProduct2Id = addMissingPricebookEntries(product2IdByPartRef.values(), standardPricebookId);
            new OpportunityLineItemSync(details, standardPricebookId, product2IdByPartRef, pricebookEntryByProduct2Id).runSync();
            new QuoteLineSync(details, standardPricebookId, product2IdByPartRef, pricebookEntryByProduct2Id).runSync();
            new OrderLineSync(details, standardPricebookId, product2IdByPartRef, pricebookEntryByProduct2Id).runSync();
            
            latestProcessedDetailLastModifiedDate = details[details.size() - 1].LastModifiedDate;
            if (latestProcessedDetailLastModifiedDate != null) {
                saveSettings(latestProcessedDetailLastModifiedDate);
            }
            
        }catch(Exception e) {
            System.debug('OpportunityDetailSyncBatch error: ' + e.getMessage());
            System.debug('OpportunityDetailSyncBatch error: ' + e.getStackTraceString());
            
            Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
                Name = 'Opportunity Batch Detail',
            Record_Type__c = e.getMessage(),
            Is_Successful__c = false,
            Total_Count__c = details.size());
            insert report;
        }
        
    }
    
    /**
     * @description Batch completion hook. Detail-sync watermark persistence occurs in {@link #execute} via
     *              {@link #saveSettings}; this method is intentionally empty.
     * @param bc Batch context supplied by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        List<Opportunity_Sync_Report__c> itemsToDelete = new List<Opportunity_Sync_Report__c>([SELECT Id FROM Opportunity_Sync_Report__c WHERE Errors__c = 0 LIMIT 300]);
        Database.delete(itemsToDelete, false);
    }
    
    /**
     * @description Upserts org default {@link Opportunity_Sync__c} with the detail sync watermark.
     * @param detailLastModifiedDate Highest detail {@link LastModifiedDate} processed so far.
     */
    private void saveSettings(Datetime detailLastModifiedDate) {
        Opportunity_Sync__c settings = Opportunity_Sync__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            settings = new Opportunity_Sync__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        settings.Detail_Last_Modified__c = detailLastModifiedDate;
        upsert settings;
    }
    
    
    
    /**
     * @description Builds dynamic SOQL for detail rows modified after the watermark, ordered oldest first.
     * @param detailLastModifiedDate Sync watermark from {@link Opportunity_Sync__c}; null processes all details.
     * @return SOQL selecting accessible non-BASE64 fields on {@link QuoteOrderCredit_Details__c}.
     */
    public static String buildQuery(Datetime detailLastModifiedDate) {
        String csv = getDetailFieldCsv();
        if (detailLastModifiedDate == null) {
            return 'SELECT ' + csv + ' FROM QuoteOrderCredit_Details__c ORDER BY LastModifiedDate ASC';
        }
        // :additionalDetailIds / :additionalHeaderIds are bound from start().
        return 'SELECT '
            + csv
            + ' FROM QuoteOrderCredit_Details__c WHERE LastModifiedDate > :detailLastModifiedDate'
            + ' OR Ext_Id__c IN :additionalDetailIds'
            + ' OR Order_Header__r.Order_Number__c IN :additionalHeaderIds'
            + ' ORDER BY LastModifiedDate ASC';
    }

    /**
     * @description Builds SOQL for a full sync (no watermark).
     * @return SOQL for all accessible detail rows.
     */
    public static String buildQuery() {
        return buildQuery(null);
    }
    
    /**
     * @description Reads the detail-sync watermark from org default {@link Opportunity_Sync__c}.
     * @return {@link Opportunity_Sync__c#Detail_Last_Modified__c}, or null when settings are absent.
     */
    private static Datetime getDetailLastModifiedDate() {
        Opportunity_Sync__c settings = Opportunity_Sync__c.getOrgDefaults();
        return settings == null ? null : settings.Detail_Last_Modified__c;
    }
    
    /**
     * @description Comma-separated field API names for {@link QuoteOrderCredit_Details__c} dynamic queries.
     * @return SELECT clause field list; {@code Id} only if no accessible fields qualify.
     */
    private static String getDetailFieldCsv() {
        Map<String, Schema.SObjectField> fieldMap = QuoteOrderCredit_Details__c.SObjectType.getDescribe().fields.getMap();
        List<String> names = new List<String>();
        for (Schema.SObjectField f : fieldMap.values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (!d.isAccessible()) {
                continue;
            }
            if (d.getType() == Schema.DisplayType.BASE64) {
                continue;
            }
            names.add(d.getName());
        }
        names.sort();
        return names.isEmpty() ? 'Id' : String.join(names, ',');
    }
    
    private static Map<String, List<String>> getDetailErrors(){
        List<String> additionalDetailIds = new List<String>();
        List<String> additionalHeaderIds = new List<String>();
        List<Opportunity_Sync_Item__c> errors = [SELECT
            Id,
            Error_Message__c,
            Status_Code__c,
            Error__c,
            Record_Id__c,
            Record__c,
            Record_Type__c,
            Fixed__c
        FROM Opportunity_Sync_Item__c WHERE Fixed__c = false and (Opportunity_Sync_Report__r.Record_Type__c = 'Order Line' or Opportunity_Sync_Report__r.Record_Type__c = 'Opportunity Line Item' or Opportunity_Sync_Report__r.Record_Type__c = 'Quote Line') ORDER BY CreatedDate ASC LIMIT 500];
        
        List<Opportunity_Sync_Item__c> itemsToUpdate = new List<Opportunity_Sync_Item__c>();
        for (Opportunity_Sync_Item__c error : errors) {
            processInvalidFieldDetails(error, itemsToUpdate, additionalHeaderIds);
            processUnLockedDetails(error, itemsToUpdate, additionalDetailIds);
            processRequiredFieldsMissing(error, itemsToUpdate, additionalDetailIds);
        }
        if(itemsToUpdate.size() > 0){
            update itemsToUpdate;
        }
        Map<String, List<String>> detailErrors = new Map<String, List<String>>();
        detailErrors.put('additionalDetailIds', additionalDetailIds);
        detailErrors.put('additionalHeaderIds', additionalHeaderIds);
        System.debug('additionalDetailIds: ' + additionalDetailIds);
        System.debug('additionalHeaderIds: ' + additionalHeaderIds);
        return detailErrors;
        
    }
    
    /**
     * @description Extracts the external id value from a Salesforce {@code INVALID_FIELD} error message for
     *              {@code Order_Number__c} (pattern {@code external ID: <value>}).
     * @param errorMessage Raw {@link Opportunity_Sync_Item__c#Error_Message__c} text.
     * @return Parsed order number / external id, or null when not found.
     */
    private static String parseOrderNumberFromError(String errorMessage) {
        if (String.isBlank(errorMessage)) {
            return null;
        }
        Matcher externalIdMatcher = Pattern.compile('external ID:\\s*(\\S+)').matcher(errorMessage);
        if (externalIdMatcher.find()) {
            return externalIdMatcher.group(1);
        }
        return null;
    }
    
    private static void processInvalidFieldDetails(Opportunity_Sync_Item__c error, List<Opportunity_Sync_Item__c> itemsToUpdate, List<String> additionalDetailIds) {
        if (error.Status_Code__c == 'INVALID_FIELD' && error.Error_Message__c != null && error.Error_Message__c.contains('Order_Number__c')) {
            String orderNumber = parseOrderNumberFromError(error.Error_Message__c);
            if (orderNumber != null) {
                System.debug('orderNumber Fixed: ' + orderNumber);
                error.Fixed__c = true;
                additionalDetailIds.add(orderNumber);
                itemsToUpdate.add(error);
            }
        }
    }
    
    private static void processUnLockedDetails(Opportunity_Sync_Item__c item, List<Opportunity_Sync_Item__c> itemsToUpdate, List<String> additionalDetailIds) {
        if ((item.Status_Code__c == 'OP_WITH_INVALID_USER_TYPE_EXCEPTION' || item.Status_Code__c == 'UNABLE_TO_LOCK_ROW') && String.isNotBlank(item.Record__c)) {
            Map<String, Object> recordByField = (Map<String, Object>) JSON.deserializeUntyped(item.Record__c);
            String extId = recordByField == null ? null : (String) recordByField.get('Ext_Id__c');
            if (extId != null) {
                item.Fixed__c = true;
                itemsToUpdate.add(item);
                additionalDetailIds.add(extId);
            }
        }
    }

    private static void processRequiredFieldsMissing(Opportunity_Sync_Item__c item, List<Opportunity_Sync_Item__c> itemsToUpdate, List<String> additionalDetailIds) {
        if ((item.Status_Code__c == 'REQUIRED_FIELD_MISSING' || item.Status_Code__c == 'FIELD_INTEGRITY_EXCEPTION') && String.isNotBlank(item.Record__c)) {
            Map<String, Object> recordByField = (Map<String, Object>) JSON.deserializeUntyped(item.Record__c);
            String extId = recordByField == null ? null : (String) recordByField.get('Ext_Id__c');
            if (extId != null) {
                item.Fixed__c = true;
                itemsToUpdate.add(item);
                additionalDetailIds.add(extId);
            }
        }
    }
    
}