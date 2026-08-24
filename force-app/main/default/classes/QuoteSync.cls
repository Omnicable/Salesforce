/**
 * @description Synchronous header sync that maps {@link QuotesOrdersCredits_Header__c} rows to {@link Quote}
 *              records via DataWeave ({@code qocToQuote}). Matches existing rows by {@link Quote#Order_Number__c},
 *              applies insert/update routing with partial-success DML through {@link SyncBase}, and links new
 *              Quotes to parent Opportunities by order number stub.
 *              <p>
 *              Typically invoked from {@link OpportunityHeaderSyncBatch#execute} after {@link OpportunitySync}.
 *              Credit-type headers are excluded from quote sync. {@link #standardPricebookId} is usually supplied
 *              by {@link OpportunitySync#standardPricebookId} in the same batch chunk.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see OpportunitySync
 * @see OpportunityHeaderSyncBatch
 * @see OrderSync
 */
public  class QuoteSync extends SyncBase {
    /**
     * @description QOC header rows in the current sync scope (non-Credit types only).
     */
    private List<QuotesOrdersCredits_Header__c> headers;

    /**
     * @description Run summary; inserted by {@link SyncBase#saveRecords} with nested sync items on failure.
     */
    private Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
        Is_Successful__c = true,
        Record_Type__c = 'Quote',
        Update_Count__c = 0,
        Insert_Count__c = 0,
        Total_Count__c = 0,
        Error_Count__c = 0,
        Existing_Record_Count__c = 0
    );

    /**
     * @description Standard price book applied to each Quote; typically set from {@link OpportunitySync}.
     */
    public Id standardPricebookId;

    /**
     * @description Existing Quotes keyed by {@link Quote#Order_Number__c} for insert vs update routing.
     */
    private Map<String, Quote> orderNumberToQuoteMap = new Map<String, Quote>();

    /**
     * @description Quotes queued for insert during {@link #runSync}; cleared at the start of each run.
     */
    List<Quote> toInsert = new List<Quote>();

    /**
     * @description Quotes queued for update during {@link #runSync}; cleared at the start of each run.
     */
    List<Quote> toUpdate = new List<Quote>();

    /**
     * @description Captures non-Credit header scope and resolves the org standard (or fallback) price book.
     * @param headers QOC header rows driving the sync; null yields an empty scope and {@link #runSync} no-ops.
     */
    public QuoteSync(List<QuotesOrdersCredits_Header__c> headers) {
        this.headers = filterNonCreditHeaders(headers);
        this.report.Total_Count__c = this.headers.size();
        this.standardPricebookId = this.getStandardPricebookId();
    }

    /**
     * @description Same as {@link #QuoteSync(List)} but uses a price book Id from upstream sync (e.g. {@link OpportunitySync}).
     * @param headers               QOC header rows driving the sync; null yields an empty scope.
     * @param standardPricebookId   Price book Id applied to each synced Quote before DML; null keeps the resolved default.
     */
    public QuoteSync(List<QuotesOrdersCredits_Header__c> headers, Id standardPricebookId) {
        this(headers);
        if (standardPricebookId != null) {
            this.standardPricebookId = standardPricebookId;
        }
    }

    /**
     * @description Runs the full Quote sync for the current header scope: collect keys, load existing rows,
     *              transform via DataWeave, route to insert/update lists, and persist Quotes.
     */
    public void runSync() {
        if (headers == null || headers.isEmpty()) {
            return;
        }

        toInsert.clear();
        toUpdate.clear();
        orderNumberToQuoteMap.clear();

        Set<String> orderNumbers = new Set<String>();
        collectOrderNumberKeys(headers, orderNumbers);

        getExistingRecords(orderNumbers);

        List<Quote> quotes = (List<Quote>) JSON.deserialize(
            syncDataWeaveToJson('qocToQuote', headers),
            List<Quote>.class
        );

        assignRecordsToUpdateAndInsert(quotes);
        saveRecords(toInsert, toUpdate, report);
    }

    /**
     * @description Applies price book, matches {@link #orderNumberToQuoteMap}, and fills {@link #toInsert}
     *              or {@link #toUpdate}. Updates clear the Opportunity stub; inserts use an Opportunity stub by order number.
     * @param quotes Quote rows produced by DataWeave.
     */
    private void assignRecordsToUpdateAndInsert(List<Quote> quotes) {
        for (Quote q : quotes) {
            
            if (q.Order_Number__c != null && orderNumberToQuoteMap.containsKey(q.Order_Number__c)) {
                Quote existingQuote = orderNumberToQuoteMap.get(q.Order_Number__c);
                q.Id = existingQuote.Id;
                q.Opportunity = null;
                toUpdate.add(q);
            } else {
                q.Pricebook2Id = standardPricebookId;
                q.Opportunity = new Opportunity(Order_Number__c = q.Order_Number__c);
                toInsert.add(q);
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
     * @description Queries existing Quotes with {@code FOR UPDATE} and populates {@link #orderNumberToQuoteMap}.
     *              Sets {@link Opportunity_Sync_Report__c#Existing_Record_Count__c} from the map size.
     * @param orderNumbers Distinct order number keys from {@link #collectOrderNumberKeys}; empty skips the query.
     */
    private void getExistingRecords(Set<String> orderNumbers) {
        if (orderNumbers == null || orderNumbers.isEmpty()) {
            report.Existing_Record_Count__c = 0;
            return;
        }
        for (Quote q : [
            SELECT Id, Order_Number__c
            FROM Quote
            WHERE Order_Number__c IN :orderNumbers
        ]) {
            if (q.Order_Number__c != null) {
                orderNumberToQuoteMap.put(q.Order_Number__c, q);
            }
        }
        report.Existing_Record_Count__c = orderNumberToQuoteMap.size();
    }

    /**
     * @description Returns non-Credit headers for quote sync, deduped by header Id.
     * @param input Raw header list from the batch or caller; null yields an empty list.
     * @return Filtered header rows with {@link QuotesOrdersCredits_Header__c#Type__c} not equal to Credit.
     */
    private static List<QuotesOrdersCredits_Header__c> filterNonCreditHeaders(
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
            if (h.Type__c != 'Credit') {
                filtered.add(h);
                seenHeaderIds.add(h.Id);
            }
        }
        return filtered;
    }
}