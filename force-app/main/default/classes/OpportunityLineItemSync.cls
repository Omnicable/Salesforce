/**
 * @description Synchronous detail sync that maps {@link QuoteOrderCredit_Details__c} rows to
 *              {@link OpportunityLineItem} via DataWeave ({@code qocDetailToOpportunityLine}). Resolves
 *              {@link Product2} by part number (or a {@code Non-Stock} placeholder when
 *              {@link QuoteOrderCredit_Details__c#Item_Number__c} is null), links parent {@link Opportunity} by
 *              header Id or order number, matches existing lines by detail link and ext id, and persists an
 *              {@link Opportunity_Sync_Report__c} with {@link Opportunity_Sync_Item__c} rows on DML failure.
 *              <p>
 *              Typically invoked from {@link OpportunityDetailSyncBatch#execute} as the first step in the
 *              line sync chain. {@link #standardPricebookId}, {@link #product2IdByPartRef}, and
 *              {@link #pricebookEntryByProduct2Id} are passed to {@link QuoteLineSync} and {@link OrderLineSync}
 *              in the same batch chunk. Line DML uses partial-success persistence through {@link SyncBase#saveRecords}.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see OpportunityDetailSyncBatch
 * @see QuoteLineSync
 * @see OrderLineSync
 */
public without sharing class OpportunityLineItemSync extends SyncBase {
    /**
     * @description QOC detail rows in the current sync scope.
     */
    private List<QuoteOrderCredit_Details__c> details = new List<QuoteOrderCredit_Details__c>();
    
    /**
     * @description Run summary; inserted by {@link SyncBase#saveRecords} with nested sync items on failure.
     */
    private Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
        Is_Successful__c = true,
    Record_Type__c = 'Opportunity Line Item',
    Update_Count__c = 0,
    Insert_Count__c = 0,
    Total_Count__c = 0,
    Error_Count__c = 0,
    Existing_Record_Count__c = 0
    
        );
    
    /**
     * @description Standard price book used for {@link PricebookEntry} resolution; shared with quote and order line sync.
     */
    public Id standardPricebookId;
    
    /**
     * @description Part number ref ({@link Product2#Part_Number_Ref__c}) to {@link Product2} Id for the current scope.
     */
    public Map<String, Id> product2IdByPartRef = new Map<String, Id>();
    
    /**
     * @description {@link Product2} Id to standard {@link PricebookEntry} on {@link #standardPricebookId}.
     */
    public Map<Id, PricebookEntry> pricebookEntryByProduct2Id = new Map<Id, PricebookEntry>();
    
    /**
     * @description Existing opportunity lines by {@link OpportunityLineItem#Quote_Order_Credit_Detail__c} (detail Id).
     */
    private Map<Id, Id> detailIdToExistingOliId = new Map<Id, Id>();
    
    /**
     * @description Existing opportunity lines by {@link OpportunityLineItem#Ext_Id__c} (fallback for legacy rows).
     */
    private Map<String, Id> extIdToExistingOliId = new Map<String, Id>();

    
    /**
     * @description Maps detail {@link QuoteOrderCredit_Details__c#Ext_Id__c} to {@link QuoteOrderCredit_Details__c#Order_Header__c}.
     */
    private Map<String, Id> extIdToHeaderId = new Map<String, Id>();
    
    /**
     * @description Parent opportunities by {@link Opportunity#Quote_Order_Credit__c} (header Id).
     */
    private Map<Id, Id> headerIdToOpportunityIdMap = new Map<Id, Id>();
    
    /**
     * @description Parent opportunities by {@link Opportunity#Order_Number__c}.
     */
    private Map<String, Id> orderNumberToOpportunityIdMap = new Map<String, Id>();


    /**
     * @description Loads detail scope by Id (dynamic SOQL) before {@link #runSync()}.
     * @param detailIds Detail record Ids to sync; null or empty leaves scope empty.
     */
    public OpportunityLineItemSync(List<QuoteOrderCredit_Details__c> details, Id standardPricebookId, Map<String, Id> product2IdByPartRef, Map<Id, PricebookEntry> pricebookEntryByProduct2Id) {
        this.details = details == null ? new List<QuoteOrderCredit_Details__c>() : details;
        this.standardPricebookId = standardPricebookId;
        this.product2IdByPartRef = product2IdByPartRef == null ? new Map<String, Id>() : product2IdByPartRef;
        this.pricebookEntryByProduct2Id = pricebookEntryByProduct2Id == null
            ? new Map<Id, PricebookEntry>()
            : pricebookEntryByProduct2Id;
        this.report.Total_Count__c = this.details.size();
    }
    
    /**
     * @description Runs the full opportunity line sync for the current detail scope: initialize scope, refresh
     *              parent opportunities, resolve products and price book entries, transform via DataWeave, route
     *              to insert vs update (clearing non-updateable fields on update), and persist via {@link SyncBase#saveRecords}.
     */
    public void runSync() {
        
        if (details.isEmpty()) {
            return;
        }
        
        initializeScope();
        
        List<OpportunityLineItem> opportunityLineItems = (List<OpportunityLineItem>) JSON.deserialize(
            syncDataWeaveToJson('qocDetailToOpportunityLine', details),
            List<OpportunityLineItem>.class
        );
        if (opportunityLineItems == null) {
            opportunityLineItems = new List<OpportunityLineItem>();
        }

        Map<Id, OpportunityLineItem> linesToUpdateById = new Map<Id, OpportunityLineItem>();
        List<OpportunityLineItem> toInsert = new List<OpportunityLineItem>();

        for (OpportunityLineItem oli : opportunityLineItems) {
            if (oli == null) {
                continue;
            }
            Id existingOliId = resolveExistingOpportunityLineItemId(oli);
            if (existingOliId != null) {
                oli.Product2Id = null;
                oli.PricebookEntryId = null;
                oli.Opportunity = null;
                oli.Id = existingOliId;
                linesToUpdateById.put(existingOliId, oli);
            } else {
                Id product2Id = resolveProduct2Id(oli.Item_Number__c);
                Id pricebookEntryId = resolvePricebookEntryId(
                    product2Id,
                    standardPricebookId,
                    pricebookEntryByProduct2Id
                );
                if (pricebookEntryId == null) {
                    System.debug(
                        LoggingLevel.WARN,
                        'OpportunityLineItemSync: skip insert; no PricebookEntry for Item_Number__c='
                            + oli.Item_Number__c
                            + ' product2Id='
                            + product2Id
                    );
                    continue;
                }
                oli.PricebookEntryId = pricebookEntryId;
                String orderNumber = oli.OrderNumber__c;
                Id opportunityId = resolveOpportunityId(oli.Ext_Id__c, orderNumber);
                if (opportunityId != null) {
                    oli.OpportunityId = opportunityId;
                } else if (orderNumber != null) {
                    oli.Opportunity = new Opportunity(Order_Number__c = orderNumber);
                }
                toInsert.add(oli);
            }
        }
        
        saveRecords(toInsert, new List<OpportunityLineItem>(linesToUpdateById.values()), report);
    }
    
    /**
     * @description Re-queries details by Id, resolves price book and Non-Stock product, indexes scope keys,
     *              loads parent opportunities and existing opportunity lines.
     */
    private void initializeScope() {

        report.Total_Count__c = details.size();
        extIdToHeaderId.clear();
        Set<String> extIds = new Set<String>();
        List<Id> detailIdList = new List<Id>();
        Set<String> orderNumberKeys = new Set<String>();
        Set<Id> headerIds = new Set<Id>();
        
        for (QuoteOrderCredit_Details__c detail : details) {
            if (detail.Id != null) {
                detailIdList.add(detail.Id);
            }
            if (detail.Ext_Id__c != null) {
                extIds.add(detail.Ext_Id__c);
                
                if (detail.Order_Header__c != null) {
                    extIdToHeaderId.put(detail.Ext_Id__c, detail.Order_Header__c);
                    headerIds.add(detail.Order_Header__c);
                }
            }
            if (detail.OrderNumber__c != null) {
                orderNumberKeys.add(detail.OrderNumber__c);
            }

        }
        
        loadParentOpportunities(headerIds, orderNumberKeys);
        getExistingRecords(detailIdList, extIds);
    }
    
    
    /**
     * @description Matches a transformed line to an existing Id by detail link, then ext id.
     * @param candidate Opportunity line from DataWeave before insert/update routing.
     * @return Existing {@link OpportunityLineItem} Id, or null when the line should insert.
     */
    private Id resolveExistingOpportunityLineItemId(OpportunityLineItem candidate) {
        if (candidate == null) {
            return null;
        }
        if (candidate.Quote_Order_Credit_Detail__c != null
        && detailIdToExistingOliId.containsKey(candidate.Quote_Order_Credit_Detail__c)) {
            return detailIdToExistingOliId.get(candidate.Quote_Order_Credit_Detail__c);
        }
        if (candidate.Ext_Id__c != null && extIdToExistingOliId.containsKey(candidate.Ext_Id__c)) {
            return extIdToExistingOliId.get(candidate.Ext_Id__c);
        }
        return null;
    }
    
    /**
     * @description Loads existing opportunity lines by detail Id and ext id; sets {@link Opportunity_Sync_Report__c#Existing_Record_Count__c}.
     * @param detailIds Detail Ids in scope.
     * @param extIds    Ext_Id values in scope.
     */
    private void getExistingRecords(List<Id> detailIds, Set<String> extIds) {
        List<Id> detailIdBind = detailIds == null ? new List<Id>() : detailIds;
        Set<String> extIdBind = extIds == null ? new Set<String>() : extIds;

        if (detailIdBind.isEmpty() && extIdBind.isEmpty()) {
            report.Existing_Record_Count__c = 0;
            return;
        }

        Set<Id> existingIds = new Set<Id>();
        for (OpportunityLineItem oli : [
            SELECT Id, Ext_Id__c, Quote_Order_Credit_Detail__c
            FROM OpportunityLineItem
            WHERE Quote_Order_Credit_Detail__c IN :detailIdBind
                OR Ext_Id__c IN :extIdBind
        ]) {
            if (oli.Quote_Order_Credit_Detail__c != null) {
                detailIdToExistingOliId.put(oli.Quote_Order_Credit_Detail__c, oli.Id);
            }
            if (oli.Ext_Id__c != null) {
                extIdToExistingOliId.put(oli.Ext_Id__c, oli.Id);
            }
            existingIds.add(oli.Id);
        }

        report.Existing_Record_Count__c = existingIds.size();
    }
    
    /**
     * @description Queries parent {@link Opportunity} rows by header Id and order number for line linking.
     * @param headerIds       {@link QuotesOrdersCredits_Header__c} Ids from detail {@link QuoteOrderCredit_Details__c#Order_Header__c}.
     * @param orderNumberKeys Order numbers from detail scope.
     */
    private void loadParentOpportunities(Set<Id> headerIds, Set<String> orderNumberKeys) {
        if (headerIds != null && !headerIds.isEmpty() || orderNumberKeys != null && !orderNumberKeys.isEmpty()) {
            for (Opportunity opp : [
                SELECT Id, Order_Number__c, Quote_Order_Credit__c
                FROM Opportunity
                WHERE Quote_Order_Credit__c IN :headerIds OR Order_Number__c IN :orderNumberKeys
            ]) {
                if (opp.Quote_Order_Credit__c != null) {
                    headerIdToOpportunityIdMap.put(opp.Quote_Order_Credit__c, opp.Id);
                }
                if (opp.Order_Number__c != null) {
                    orderNumberToOpportunityIdMap.put(opp.Order_Number__c, opp.Id);
                }
            }
        }

    }

    
    /**
     * @description Resolves parent opportunity Id by header Id (via ext id) or order number.
     * @param extId       Line ext id used to look up header Id.
     * @param orderNumber Fallback order number from detail scope.
     * @return {@link Opportunity} Id when found; otherwise null.
     */
    private Id resolveProduct2Id(String itemNumber) {
        if (String.isBlank(itemNumber)) {
            return product2IdByPartRef.get('Non-Stock');
        }
        return product2IdByPartRef.get(itemNumber);
    }

    private Id resolveOpportunityId(String extId, String orderNumber) {
        Id headerId = extId == null ? null : extIdToHeaderId.get(extId);
        if (headerId != null && headerIdToOpportunityIdMap.containsKey(headerId)) {
            return headerIdToOpportunityIdMap.get(headerId);
        }
        if (orderNumber != null && orderNumberToOpportunityIdMap.containsKey(orderNumber)) {
            return orderNumberToOpportunityIdMap.get(orderNumber);
        }
        return null;
    }
    
}