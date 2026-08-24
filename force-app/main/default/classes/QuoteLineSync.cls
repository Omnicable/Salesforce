/**
 * @description Synchronous detail sync that maps {@link QuoteOrderCredit_Details__c} rows to {@link QuoteLineItem}
 *              via DataWeave ({@code qocDetailToQuoteLine}). Credit-type details are excluded in DataWeave. Links
 *              parent {@link Quote} by header Id or order number, matches existing lines by detail link and ext id,
 *              and persists an {@link Opportunity_Sync_Report__c} with {@link Opportunity_Sync_Item__c} rows on DML failure.
 *              <p>
 *              Typically invoked from {@link OpportunityDetailSyncBatch#execute} after {@link OpportunityLineItemSync}.
 *              {@link #standardPricebookId}, {@link #product2IdByPartRef}, and {@link #pricebookEntryByProduct2Id} are
 *              supplied by the batch (shared with {@link OrderLineSync}). Line DML uses {@link SyncBase#saveRecords}.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see OpportunityLineItemSync
 * @see OpportunityDetailSyncBatch
 * @see OrderLineSync
 */
public without sharing class QuoteLineSync extends SyncBase {
    /**
     * @description QOC detail rows in the current sync scope.
     */
    private List<QuoteOrderCredit_Details__c> details = new List<QuoteOrderCredit_Details__c>();

    /**
     * @description Run summary; inserted by {@link SyncBase#saveRecords} with nested sync items on failure.
     */
    private Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
        Is_Successful__c = true,
        Record_Type__c = 'Quote Line',
        Update_Count__c = 0,
        Insert_Count__c = 0,
        Total_Count__c = 0,
        Error_Count__c = 0,
        Existing_Record_Count__c = 0
    );

    /**
     * @description Standard price book used for {@link PricebookEntry} resolution; shared with order line sync.
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
     * @description Existing quote lines by {@link QuoteLineItem#Quote_Order_Credit_Detail__c} (detail Id).
     */
    private Map<Id, Id> detailIdToExistingLineId = new Map<Id, Id>();

    /**
     * @description Existing quote lines by {@link QuoteLineItem#Ext_Id__c} (fallback for legacy rows).
     */
    private Map<String, Id> extIdToExistingLineId = new Map<String, Id>();

    /**
     * @description Maps detail {@link QuoteOrderCredit_Details__c#Ext_Id__c} to {@link QuoteOrderCredit_Details__c#Order_Header__c}.
     */
    private Map<String, Id> extIdToHeaderId = new Map<String, Id>();

    /**
     * @description Parent quotes by {@link Quote#Quote_Order_Credit__c} (header Id).
     */
    private Map<Id, Id> headerIdToQuoteIdMap = new Map<Id, Id>();

    /**
     * @description Parent quotes by {@link Quote#Order_Number__c}.
     */
    private Map<String, Id> orderNumberToQuoteIdMap = new Map<String, Id>();

    /**
     * @description Captures detail scope and product/PBE context from {@link OpportunityDetailSyncBatch}.
     * @param details                    QOC detail rows driving the sync.
     * @param standardPricebookId        Integration price book Id from upstream sync.
     * @param product2IdByPartRef        Part number to {@link Product2} Id map from upstream sync.
     * @param pricebookEntryByProduct2Id Product Id to standard {@link PricebookEntry} map from upstream sync.
     */
    public QuoteLineSync(
        List<QuoteOrderCredit_Details__c> details,
        Id standardPricebookId,
        Map<String, Id> product2IdByPartRef,
        Map<Id, PricebookEntry> pricebookEntryByProduct2Id
    ) {
        this.details = details == null ? new List<QuoteOrderCredit_Details__c>() : details;
        this.standardPricebookId = standardPricebookId;
        this.product2IdByPartRef = product2IdByPartRef == null ? new Map<String, Id>() : product2IdByPartRef;
        this.pricebookEntryByProduct2Id = pricebookEntryByProduct2Id == null
            ? new Map<Id, PricebookEntry>()
            : pricebookEntryByProduct2Id;
        this.report.Total_Count__c = this.details.size();
    }

    /**
     * @description Runs quote line sync for the current detail scope: index keys, load parent quotes and existing lines,
     *              transform via DataWeave, route insert vs update, and persist via {@link SyncBase#saveRecords}.
     */
    public void runSync() {
        if (details.isEmpty()) {
            return;
        }

        initializeScope();

        List<QuoteLineItem> quoteLineItems = (List<QuoteLineItem>) JSON.deserialize(
            syncDataWeaveToJson('qocDetailToQuoteLine', details),
            List<QuoteLineItem>.class
        );
        if (quoteLineItems == null) {
            quoteLineItems = new List<QuoteLineItem>();
        }

        this.report.Total_Count__c = quoteLineItems.size();
        Map<Id, QuoteLineItem> linesToUpdateById = new Map<Id, QuoteLineItem>();
        List<QuoteLineItem> toInsert = new List<QuoteLineItem>();

        for (QuoteLineItem qli : quoteLineItems) {
            if (qli == null) {
                continue;
            }
            Id existingLineId = resolveExistingQuoteLineId(qli);
            if (existingLineId != null) {
                qli.Product2Id = null;
                qli.PricebookEntryId = null;
                qli.Quote = null;
                qli.Id = existingLineId;
                linesToUpdateById.put(existingLineId, qli);
            } else {
                Id product2Id = resolveProduct2Id(qli.Item_Number__c);
                Id pricebookEntryId = resolvePricebookEntryId(
                    product2Id,
                    standardPricebookId,
                    pricebookEntryByProduct2Id
                );
                if (pricebookEntryId == null) {
                    continue;
                }
                qli.PricebookEntryId = pricebookEntryId;
                String orderNumber = qli.OrderNumber__c;
                Id quoteId = resolveQuoteId(qli.Ext_Id__c, orderNumber);
                if (quoteId != null) {
                    qli.QuoteId = quoteId;
                } else if (orderNumber != null) {
                    qli.Quote = new Quote(Order_Number__c = orderNumber);
                }
                toInsert.add(qli);
            }
        }

        saveRecords(toInsert, new List<QuoteLineItem>(linesToUpdateById.values()), report);
    }

    /**
     * @description Indexes detail scope, loads parent quotes and existing quote lines.
     */
    private void initializeScope() {
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

        loadParentQuotes(headerIds, orderNumberKeys);
        getExistingRecords(detailIdList, extIds);
    }

    /**
     * @description Matches a transformed line to an existing Id by detail link, then ext id.
     * @param candidate Quote line from DataWeave before insert/update routing.
     * @return Existing {@link QuoteLineItem} Id, or null when the line should insert.
     */
    private Id resolveExistingQuoteLineId(QuoteLineItem candidate) {
        if (candidate == null) {
            return null;
        }
        if (candidate.Quote_Order_Credit_Detail__c != null
                && detailIdToExistingLineId.containsKey(candidate.Quote_Order_Credit_Detail__c)) {
            return detailIdToExistingLineId.get(candidate.Quote_Order_Credit_Detail__c);
        }
        if (candidate.Ext_Id__c != null && extIdToExistingLineId.containsKey(candidate.Ext_Id__c)) {
            return extIdToExistingLineId.get(candidate.Ext_Id__c);
        }
        return null;
    }

    /**
     * @description Loads existing quote lines by detail Id and ext id; sets {@link Opportunity_Sync_Report__c#Existing_Record_Count__c}.
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
        for (QuoteLineItem existing : [
            SELECT Id, Ext_Id__c, Quote_Order_Credit_Detail__c
            FROM QuoteLineItem
            WHERE Quote_Order_Credit_Detail__c IN :detailIdBind
                OR Ext_Id__c IN :extIdBind
        ]) {
            if (existing.Quote_Order_Credit_Detail__c != null) {
                detailIdToExistingLineId.put(existing.Quote_Order_Credit_Detail__c, existing.Id);
            }
            if (existing.Ext_Id__c != null) {
                extIdToExistingLineId.put(existing.Ext_Id__c, existing.Id);
            }
            existingIds.add(existing.Id);
        }

        report.Existing_Record_Count__c = existingIds.size();
    }

    /**
     * @description Queries parent {@link Quote} rows by header Id and order number for line linking.
     * @param headerIds       Header Ids from detail {@link QuoteOrderCredit_Details__c#Order_Header__c}.
     * @param orderNumberKeys Order numbers from detail scope.
     */
    private void loadParentQuotes(Set<Id> headerIds, Set<String> orderNumberKeys) {
        if (headerIds != null && !headerIds.isEmpty() || orderNumberKeys != null && !orderNumberKeys.isEmpty()) {
            for (Quote parentQuote : [
                SELECT Id, Order_Number__c, Quote_Order_Credit__c
                FROM Quote
                WHERE Quote_Order_Credit__c IN :headerIds OR Order_Number__c IN :orderNumberKeys
            ]) {
                if (parentQuote.Quote_Order_Credit__c != null) {
                    headerIdToQuoteIdMap.put(parentQuote.Quote_Order_Credit__c, parentQuote.Id);
                }
                if (parentQuote.Order_Number__c != null) {
                    orderNumberToQuoteIdMap.put(parentQuote.Order_Number__c, parentQuote.Id);
                }
            }
        }
    }

    /**
     * @description Resolves parent {@link Quote} Id by header Id (via ext id) or order number.
     * @param extId       Line ext id used to look up header Id.
     * @param orderNumber Fallback order number from the transformed line.
     * @return {@link Quote} Id when found; otherwise null.
     */
    private Id resolveProduct2Id(String itemNumber) {
        if (String.isBlank(itemNumber)) {
            return product2IdByPartRef.get('Non-Stock');
        }
        return product2IdByPartRef.get(itemNumber);
    }

    private Id resolveQuoteId(String extId, String orderNumber) {
        Id headerId = extId == null ? null : extIdToHeaderId.get(extId);
        if (headerId != null && headerIdToQuoteIdMap.containsKey(headerId)) {
            return headerIdToQuoteIdMap.get(headerId);
        }
        if (orderNumber != null && orderNumberToQuoteIdMap.containsKey(orderNumber)) {
            return orderNumberToQuoteIdMap.get(orderNumber);
        }
        return null;
    }
}