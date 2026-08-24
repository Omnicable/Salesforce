/**
 * @description Batchable entry that reloads {@link QuotesOrdersCredits_Header__c} rows changed since the last
 *              checkpoint and runs the header sync chain per chunk: {@link OpportunitySync}, then {@link QuoteSync},
 *              then {@link OrderSync}. Incremental scope is driven by {@link LastModifiedDate} using
 *              {@link Opportunity_Sync__c#LastModifiedDate__c}; when that watermark is null, all headers are
 *              processed. After each successful chunk, {@link #saveSettings} upserts the highest
 *              {@link LastModifiedDate} seen so far into org defaults.
 *              <p>
 *              Typically invoked from {@link OpportunitySyncScheduler} for scheduled incremental sync.
 *              Standard price book resolution is delegated to {@link SyncBase} before the header sync chain
 *              runs in {@link #execute}.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see OpportunitySync
 * @see QuoteSync
 * @see OrderSync
 * @see OpportunitySyncScheduler
 * @see OpportunityDetailSyncBatch
 */
public  class OpportunityHeaderSyncBatch extends SyncBase implements Database.Batchable<SObject> {
    
    /**
     * @description Highest {@link QuotesOrdersCredits_Header__c#LastModifiedDate} processed in this batch run.
     */
    private Datetime latestProcessedLastModifiedDate;
    
    /**
     * @description Default constructor for incremental sync from {@link Opportunity_Sync__c}.
     */
    public OpportunityHeaderSyncBatch() {
        System.debug('OpportunityHeaderSyncBatch: constructor');
    }
    
    /**
     * @description Returns a query locator for header rows modified after the org sync watermark via
     *              {@link #buildQuery}.
     * @param bc Batch context supplied by the platform.
     * @return Query locator for {@link QuotesOrdersCredits_Header__c} rows in scope.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('OpportunityHeaderSyncBatch: start');
        Datetime lastModifiedDate = getLastModifiedDate();
        // Bind variable must be in this method's scope for Database.getQueryLocator(String).
        List<String> additionalHeaders = getHeaderErrors();
        return Database.getQueryLocator(buildQuery(lastModifiedDate));
    }
    
    /**
     * @description Runs opportunity, quote, and order header sync for one batch chunk. Resolves the standard
     *              price book, then invokes the header sync chain in order. On success, persists the chunk
     *              watermark via {@link #saveSettings}. On failure, logs debug output and inserts an
     *              {@link Opportunity_Sync_Report__c} row.
     * @param bc    Batch context supplied by the platform.
     * @param scope Chunk of {@link QuotesOrdersCredits_Header__c} rows from {@link #start}.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<QuotesOrdersCredits_Header__c> headers = (List<QuotesOrdersCredits_Header__c>) scope;
        
        try{
            Id standardPricebookId = getStandardPricebookId();
            new OpportunitySync(headers, standardPricebookId).runSync();
            new QuoteSync(headers, standardPricebookId).runSync();
            new OrderSync(headers, standardPricebookId).runSync();
            latestProcessedLastModifiedDate = headers[headers.size() - 1].LastModifiedDate;
            saveSettings(latestProcessedLastModifiedDate);
            
        }catch(Exception e) {
            System.debug('OpportunityHeaderSyncBatch: exception: ' + e.getMessage());
            Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
                Name = 'Opportunity Header Sync Batch',
            Record_Type__c = e.getMessage(),
            Is_Successful__c = false,
            Total_Count__c = headers.size());
            insert report;
        }
        
    }
    
    /**
     * @description Batch completion hook. Header-sync watermark persistence occurs in {@link #execute} via
     *              {@link #saveSettings}; this method is intentionally empty.
     * @param bc Batch context supplied by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('OpportunityHeaderSyncBatch: finish');
    }
    
    
    /**
     * @description Builds dynamic SOQL for header rows modified after the watermark, ordered oldest first.
     * @param lastModifiedDate Sync watermark from {@link Opportunity_Sync__c}; null processes all headers.
     * @return SOQL selecting accessible non-BASE64 fields on {@link QuotesOrdersCredits_Header__c}.
     */
    public static String buildQuery(Datetime lastModifiedDate) {
        String csv = getHeaderFieldCsv();
        if (lastModifiedDate == null) {
            return 'SELECT ' + csv + ' FROM QuotesOrdersCredits_Header__c ORDER BY LastModifiedDate ASC';
        }
        // :additionalHeaders is bound from start().
        return 'SELECT '
            + csv
            + ' FROM QuotesOrdersCredits_Header__c WHERE LastModifiedDate > :lastModifiedDate OR Order_Number__c IN :additionalHeaders ORDER BY LastModifiedDate ASC';
    }
    
    /**
     * @description Upserts org default {@link Opportunity_Sync__c} with the header sync watermark.
     * @param lastModifiedDate Highest header {@link LastModifiedDate} processed so far.
     */
    private void saveSettings(Datetime lastModifiedDate) {
        Opportunity_Sync__c settings = Opportunity_Sync__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            settings = new Opportunity_Sync__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        if (settings.LastModifiedDate__c == null || lastModifiedDate > settings.LastModifiedDate__c) {
            settings.LastModifiedDate__c = lastModifiedDate;
            upsert settings;
        }
    }
    
    
    /**
     * @description Reads the header-sync watermark from org default {@link Opportunity_Sync__c}.
     * @return {@link Opportunity_Sync__c#LastModifiedDate__c}, or null when settings are absent.
     */
    private static Datetime getLastModifiedDate() {
        Opportunity_Sync__c settings = Opportunity_Sync__c.getOrgDefaults();
        return settings == null ? null : settings.LastModifiedDate__c;
    }
    
    /**
     * @description Comma-separated field API names for {@link QuotesOrdersCredits_Header__c} dynamic queries.
     * @return SELECT clause field list; {@code Id} only if no accessible fields qualify.
     */
    private static String getHeaderFieldCsv() {
        Map<String, Schema.SObjectField> fieldMap = QuotesOrdersCredits_Header__c.SObjectType.getDescribe().fields.getMap();
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
    
    private static List<String> getHeaderErrors(){
        List<String> additionalHeaders = new List<String>();
        List<Opportunity_Sync_Item__c> errors = [SELECT
            Id,
            Error_Message__c,
            Status_Code__c,
            Error__c,
            Record_Id__c,
            Record__c,
            Record_Type__c,
            Fixed__c
        FROM Opportunity_Sync_Item__c WHERE Fixed__c = false and (Opportunity_Sync_Report__r.Record_Type__c = 'Order' or Opportunity_Sync_Report__r.Record_Type__c = 'Opportunity' or Opportunity_Sync_Report__r.Record_Type__c = 'Quote') ORDER BY CreatedDate ASC LIMIT 500];

        List<Opportunity_Sync_Item__c> itemsToUpdate = new List<Opportunity_Sync_Item__c>();
        for (Opportunity_Sync_Item__c error : errors) {
            processInvalidFieldHeaders(error, itemsToUpdate, additionalHeaders);
            processUnLockedHeaders(error, itemsToUpdate, additionalHeaders);
        }
        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }
        System.debug('additionalHeaders: ' + additionalHeaders);
        return additionalHeaders;
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
    
    private static void processInvalidFieldHeaders(Opportunity_Sync_Item__c error, List<Opportunity_Sync_Item__c> itemsToUpdate, List<String> additionalHeaders) {
        if (error.Status_Code__c == 'INVALID_FIELD' && error.Error_Message__c != null && error.Error_Message__c.contains('Order_Number__c')) {
            String orderNumber = parseOrderNumberFromError(error.Error_Message__c);
            if (orderNumber != null) {
                error.Fixed__c = true;
                additionalHeaders.add(orderNumber);
                itemsToUpdate.add(error);
            }
        }
    }

    private static void processUnLockedHeaders(Opportunity_Sync_Item__c item, List<Opportunity_Sync_Item__c> itemsToUpdate, List<String> additionalHeaders) {
        if ((item.Status_Code__c == 'OP_WITH_INVALID_USER_TYPE_EXCEPTION' || item.Status_Code__c == 'UNABLE_TO_LOCK_ROW') && String.isNotBlank(item.Record__c)) {
            Map<String, Object> recordByField = (Map<String, Object>) JSON.deserializeUntyped(item.Record__c);
            String orderNumber = recordByField == null ? null : (String) recordByField.get('Order_Number__c');
            String extId = recordByField == null ? null : (String) recordByField.get('Ext_Id__c');
            if (orderNumber != null) {
                item.Fixed__c = true;
                itemsToUpdate.add(item);
                additionalHeaders.add(orderNumber);
            }
        }
    }
}