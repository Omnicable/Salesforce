/**
 * @description Synchronous header sync that maps {@link QuotesOrdersCredits_Header__c} rows (Order and Credit types)
 *              to {@link Order} records via DataWeave ({@code qocToOrder}). Matches existing rows by
 *              {@link Order#Order_Number__c}, applies insert/update routing with partial-success DML through
 *              {@link SyncBase}, and links new Orders to parent Opportunity and Quote stubs by order number.
 *              After Orders are persisted, {@link OrderContentDocumentLinkHandler#copyFromQocHeaders} copies
 *              header {@link ContentDocumentLink} rows onto related Orders (matched by
 *              {@link Order#Quote_Order_Credit__c}). Later header file insert, update, or delete is synced to
 *              those Orders by {@link OrderContentDocumentLinkHandler#syncFromQocHeaderLinks} from
 *              {@link ContentDocumentLinkTrigger}.
 *              <p>
 *              Typically invoked from {@link OpportunityHeaderSyncBatch#execute} after {@link QuoteSync}.
 *              Only Order and Credit header types are in scope. {@link #standardPricebookId} is usually supplied
 *              by {@link OpportunitySync#standardPricebookId} in the same batch chunk.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see OpportunitySync
 * @see QuoteSync
 * @see OpportunityHeaderSyncBatch
 * @see OrderContentDocumentLinkHandler
 */
public  class OrderSync extends SyncBase {
    /**
     * @description QOC header rows in the current sync scope (Order and Credit types only).
     */
    private List<QuotesOrdersCredits_Header__c> headers;
    
    /**
     * @description Run summary; inserted by {@link SyncBase#saveRecords} with nested sync items on failure.
     */
    private Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
        Is_Successful__c = true,
    Record_Type__c = 'Order',
    Update_Count__c = 0,
    Insert_Count__c = 0,
    Total_Count__c = 0,
    Error_Count__c = 0,
    Existing_Record_Count__c = 0
        );
    
    /**
     * @description Standard price book applied to each Order; typically set from {@link OpportunitySync}.
     */
    public Id standardPricebookId;
    
    /**
     * @description Existing Orders keyed by {@link Order#Order_Number__c} for insert vs update routing.
     */
    private Map<String, Order> orderNumberToOrderMap = new Map<String, Order>();
    
    /**
     * @description Orders queued for insert during {@link #runSync}; cleared at the start of each run.
     */
    List<Order> toInsert = new List<Order>();
    
    /**
     * @description Orders queued for update during {@link #runSync}; cleared at the start of each run.
     */
    List<Order> toUpdate = new List<Order>();
    
    /**
     * @description Same as {@link #OrderSync(List)} but uses a price book Id from upstream sync (e.g. {@link OpportunitySync}).
     * @param headers               QOC header rows driving the sync; null yields an empty scope.
     * @param standardPricebookId   Price book Id applied to each synced Order before DML; null keeps the resolved default.
     */
    public OrderSync(List<QuotesOrdersCredits_Header__c> headers, Id standardPricebookId) {
        this.headers = filterOrderAndCreditHeaders(headers);
        this.report.Total_Count__c = this.headers.size();
        this.standardPricebookId = standardPricebookId;
    }
    
    /**
     * @description Runs the full Order sync for the current header scope: collect keys, load existing rows,
     *              transform via DataWeave, route to insert/update lists, persist Orders, then copy QOC header
     *              files onto those Orders via {@link OrderContentDocumentLinkHandler#copyFromQocHeaders}.
     */
    public void runSync() {
        if (headers == null || headers.isEmpty()) {
            return;
        }
        
        toInsert.clear();
        toUpdate.clear();
        orderNumberToOrderMap.clear();
        
        Set<String> orderNumbers = new Set<String>();
        collectOrderNumberKeys(headers, orderNumbers);
        
        getExistingRecords(orderNumbers);
        
        List<Order> orders = (List<Order>) JSON.deserialize(
            syncDataWeaveToJson('qocToOrder', headers),
        List<Order>.class
            );
        
        assignRecordsToUpdateAndInsert(orders);
        saveRecords(toInsert, toUpdate, report);
        OrderContentDocumentLinkHandler.copyFromQocHeaders(orders);
    }
    
    /**
     * @description Applies price book and status, matches {@link #orderNumberToOrderMap}, and fills {@link #toInsert}
     *              or {@link #toUpdate}. Updates clear Opportunity and Quote stubs. Inserts set parent stubs by order
     *              number; Credit-type rows omit the Quote stub.
     * @param orders Order rows produced by DataWeave.
     */
    private void assignRecordsToUpdateAndInsert(List<Order> orders) {
        for (Order o : orders) {
            o.Pricebook2Id = standardPricebookId;
            
            if (o.Status__c == 'Invoiced') {
                o.Status = 'Invoiced';
            }
            
            if (o.Order_Number__c != null && orderNumberToOrderMap.containsKey(o.Order_Number__c)) {
                Order existingOrder = orderNumberToOrderMap.get(o.Order_Number__c);
                if(existingOrder.Pricebook2Id == null) {
                    o.Pricebook2Id = standardPricebookId;
                }else{
                    o.Pricebook2Id = existingOrder.Pricebook2Id;
                }
                
                o.Id = existingOrder.Id;
                o.Opportunity = null;
                o.Quote = null;
                toUpdate.add(o);
            } else {
                
                
                if (o.Type__c != 'Credit') {
                    o.Quote = new Quote(Order_Number__c = o.Order_Number__c);
                    o.Opportunity = new Opportunity(Order_Number__c = o.Order_Number__c);
                }
                toInsert.add(o);
            }
        }
    }
    
    /**
     * @description Single pass over headers to collect order-number lookup keys (null-safe).
     * @param headerRows      Header rows in sync scope; null is ignored.
     * @param orderNumberKeys Populated with non-null {@link QuotesOrdersCredits_Header__c#Order_Number__c}
     *                        and {@link QuotesOrdersCredits_Header__c#Name} values.
     */
    private static void collectOrderNumberKeys(
        List<QuotesOrdersCredits_Header__c> headerRows,
    Set<String> orderNumberKeys
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
        }
    }
    
    /**
     * @description Queries existing Orders with {@code FOR UPDATE} and populates {@link #orderNumberToOrderMap}.
     *              Sets {@link Opportunity_Sync_Report__c#Existing_Record_Count__c} from the map size.
     * @param orderNumbers Distinct order number keys from {@link #collectOrderNumberKeys}; empty skips the query.
     */
    private void getExistingRecords(Set<String> orderNumbers) {
        if (orderNumbers == null || orderNumbers.isEmpty()) {
            report.Existing_Record_Count__c = 0;
            return;
        }
        for (Order o : [
            SELECT Id, Order_Number__c, Pricebook2Id
            FROM Order
            WHERE Order_Number__c IN :orderNumbers
        ]) {
            if (o.Order_Number__c != null) {
                orderNumberToOrderMap.put(o.Order_Number__c, o);
            }
        }
        report.Existing_Record_Count__c = orderNumberToOrderMap.size();
    }
    
    /**
     * @description Returns Order and Credit headers for order sync, deduped by header Id.
     * @param input Raw header list from the batch or caller; null yields an empty list.
     * @return Filtered header rows with {@link QuotesOrdersCredits_Header__c#Type__c} equal to Order or Credit.
     */
    private static List<QuotesOrdersCredits_Header__c> filterOrderAndCreditHeaders(
        List<QuotesOrdersCredits_Header__c> input
    ) {
        List<QuotesOrdersCredits_Header__c> filtered = new List<QuotesOrdersCredits_Header__c>();
        Set<Id> seenHeaderIds = new Set<Id>();
        if (input == null) {
            return filtered;
        }
        for (QuotesOrdersCredits_Header__c h : input) {
            if (h == null || h.Id == null || seenHeaderIds.contains(h.Id)) {
                continue;
            }
            if (h.Type__c == 'Order' || h.Type__c == 'Credit') {
                filtered.add(h);
                seenHeaderIds.add(h.Id);
            }
        }
        return filtered;
    }
}