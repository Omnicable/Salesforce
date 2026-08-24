/**
 * @description Synchronous detail sync that maps {@link QuoteOrderCredit_Details__c} rows to {@link OrderItem}
 *              via DataWeave ({@code qocDetailToOrderLine}). Only Order and Credit detail types are included in
 *              DataWeave. Links parent {@link Order} by header Id or order number, matches existing lines by detail
 *              link and ext id, and persists an {@link Opportunity_Sync_Report__c} with
 *              {@link Opportunity_Sync_Item__c} rows on DML failure.
 *              <p>
 *              Typically invoked from {@link OpportunityDetailSyncBatch#execute} after {@link QuoteLineSync} as the
 *              final step in the line sync chain. {@link #standardPricebookId}, {@link #product2IdByPartRef}, and
 *              {@link #pricebookEntryByProduct2Id} are supplied by the batch. Line DML uses {@link SyncBase#saveRecords}.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see OpportunityLineItemSync
 * @see QuoteLineSync
 * @see OpportunityDetailSyncBatch
 */
public without sharing class OrderLineSync extends SyncBase {
    /**
     * @description QOC detail rows in the current sync scope.
     */
    private List<QuoteOrderCredit_Details__c> details = new List<QuoteOrderCredit_Details__c>();

    /**
     * @description Run summary; inserted by {@link SyncBase#saveRecords} with nested sync items on failure.
     */
    private Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
        Is_Successful__c = true,
        Record_Type__c = 'Order Line',
        Update_Count__c = 0,
        Insert_Count__c = 0,
        Total_Count__c = 0,
        Error_Count__c = 0,
        Existing_Record_Count__c = 0
    );

    /**
     * @description Standard price book used for {@link PricebookEntry} resolution.
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
     * @description Existing order items by {@link OrderItem#Quote_Order_Credit_Detail__c} (detail Id).
     */
    private Map<Id, Id> detailIdToExistingLineId = new Map<Id, Id>();

    /**
     * @description Existing order items by {@link OrderItem#Ext_Id__c} (fallback for legacy rows).
     */
    private Map<String, Id> extIdToExistingLineId = new Map<String, Id>();

    /**
     * @description Maps detail {@link QuoteOrderCredit_Details__c#Ext_Id__c} to {@link QuoteOrderCredit_Details__c#Order_Header__c}.
     */
    private Map<String, Id> extIdToHeaderId = new Map<String, Id>();

    /**
     * @description Parent orders by {@link Order#Quote_Order_Credit__c} (header Id).
     */
    private Map<Id, Id> headerIdToOrderIdMap = new Map<Id, Id>();

    /**
     * @description Parent orders by {@link Order#Order_Number__c}.
     */
    private Map<String, Id> orderNumberToOrderIdMap = new Map<String, Id>();

    /**
     * @description Captures detail scope and product/PBE context from {@link OpportunityDetailSyncBatch}.
     * @param details                    QOC detail rows driving the sync.
     * @param standardPricebookId        Integration price book Id from upstream sync.
     * @param product2IdByPartRef        Part number to {@link Product2} Id map from upstream sync.
     * @param pricebookEntryByProduct2Id Product Id to standard {@link PricebookEntry} map from upstream sync.
     */
    public OrderLineSync(
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
     * @description Runs order line sync for the current detail scope: index keys, load parent orders and existing lines,
     *              transform via DataWeave, route insert vs update, and persist via {@link SyncBase#saveRecords}.
     */
    public void runSync() {
        if (details.isEmpty()) {
            return;
        }

        initializeScope();

        List<OrderItem> orderLineItems = (List<OrderItem>) JSON.deserialize(
            syncDataWeaveToJson('qocDetailToOrderLine', details),
            List<OrderItem>.class
        );
        if (orderLineItems == null) {
            orderLineItems = new List<OrderItem>();
        }

        Map<Id, OrderItem> linesToUpdateById = new Map<Id, OrderItem>();
        List<OrderItem> toInsert = new List<OrderItem>();

        for (OrderItem oi : orderLineItems) {
            if (oi == null) {
                continue;
            }
            Id existingLineId = resolveExistingOrderLineId(oi);
            if (existingLineId != null) {
                oi.Product2Id = null;
                oi.PricebookEntryId = null;
                oi.Order = null;
                oi.Id = existingLineId;
                linesToUpdateById.put(existingLineId, oi);
            } else {
                Id product2Id = resolveProduct2Id(oi.Item_Number__c);
                Id pricebookEntryId = resolvePricebookEntryId(
                    product2Id,
                    standardPricebookId,
                    pricebookEntryByProduct2Id
                );
                if (pricebookEntryId == null) {
                    continue;
                }
                oi.PricebookEntryId = pricebookEntryId;
                String orderNumber = oi.OrderNumber__c;
                Id orderId = resolveOrderId(oi.Ext_Id__c, orderNumber);
                if (orderId != null) {
                    oi.OrderId = orderId;
                } else if (orderNumber != null) {
                    oi.Order = new Order(Order_Number__c = orderNumber);
                }
                toInsert.add(oi);
            }
        }

        saveRecords(toInsert, new List<OrderItem>(linesToUpdateById.values()), report);
    }

    /**
     * @description Indexes detail scope, loads parent orders and existing order items.
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

        report.Total_Count__c = orderNumberKeys.size();
        loadParentOrders(headerIds, orderNumberKeys);
        getExistingRecords(detailIdList, extIds);
    }

    /**
     * @description Matches a transformed line to an existing Id by detail link, then ext id.
     * @param candidate Order item from DataWeave before insert/update routing.
     * @return Existing {@link OrderItem} Id, or null when the line should insert.
     */
    private Id resolveExistingOrderLineId(OrderItem candidate) {
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
     * @description Loads existing order items by detail Id and ext id; sets {@link Opportunity_Sync_Report__c#Existing_Record_Count__c}.
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
        for (OrderItem existing : [
            SELECT Id, Ext_Id__c, Quote_Order_Credit_Detail__c
            FROM OrderItem
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
     * @description Queries parent {@link Order} rows by header Id and order number for line linking.
     * @param headerIds       Header Ids from detail {@link QuoteOrderCredit_Details__c#Order_Header__c}.
     * @param orderNumberKeys Order numbers from detail scope.
     */
    private void loadParentOrders(Set<Id> headerIds, Set<String> orderNumberKeys) {
        if (headerIds != null && !headerIds.isEmpty() || orderNumberKeys != null && !orderNumberKeys.isEmpty()) {
            for (Order parentOrder : [
                SELECT Id, Order_Number__c, Quote_Order_Credit__c
                FROM Order
                WHERE Quote_Order_Credit__c IN :headerIds OR Order_Number__c IN :orderNumberKeys
            ]) {
                if (parentOrder.Quote_Order_Credit__c != null) {
                    headerIdToOrderIdMap.put(parentOrder.Quote_Order_Credit__c, parentOrder.Id);
                }
                if (parentOrder.Order_Number__c != null) {
                    orderNumberToOrderIdMap.put(parentOrder.Order_Number__c, parentOrder.Id);
                }
            }
        }
    }

    /**
     * @description Resolves parent {@link Order} Id by header Id (via ext id) or order number.
     * @param extId       Line ext id used to look up header Id.
     * @param orderNumber Fallback order number from the transformed line.
     * @return {@link Order} Id when found; otherwise null.
     */
    private Id resolveProduct2Id(String itemNumber) {
        if (String.isBlank(itemNumber)) {
            return product2IdByPartRef.get('Non-Stock');
        }
        return product2IdByPartRef.get(itemNumber);
    }

    private Id resolveOrderId(String extId, String orderNumber) {
        Id headerId = extId == null ? null : extIdToHeaderId.get(extId);
        if (headerId != null && headerIdToOrderIdMap.containsKey(headerId)) {
            return headerIdToOrderIdMap.get(headerId);
        }
        if (orderNumber != null && orderNumberToOrderIdMap.containsKey(orderNumber)) {
            return orderNumberToOrderIdMap.get(orderNumber);
        }
        return null;
    }
}