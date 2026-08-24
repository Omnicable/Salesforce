/**
 * @description Batch remediation job for unresolved {@link Opportunity_Sync_Item__c} rows produced by QOC sync
 *              ({@link OpportunitySync}, line sync, and related classes). Scans items where {@link Opportunity_Sync_Item__c#Fixed__c}
 *              is false, extracts affected order numbers or detail ext ids from error payloads, and re-touches the
 *              corresponding {@link QuotesOrdersCredits_Header__c} or {@link QuoteOrderCredit_Details__c} source rows so
 *              downstream sync can retry. Supported error patterns:
 *              <ul>
 *              <li>{@code INVALID_FIELD} messages referencing {@code Order_Number__c} (external id parsed from
 *                  {@link Opportunity_Sync_Item__c#Error_Message__c})</li>
 *              <li>{@code OP_WITH_INVALID_USER_TYPE_EXCEPTION} or {@code UNABLE_TO_LOCK_ROW} failures with
 *                  {@link Opportunity_Sync_Item__c#Record__c} JSON containing {@code Order_Number__c} and/or
 *                  {@code Ext_Id__c}</li>
 *              </ul>
 *              Processed items are marked {@link Opportunity_Sync_Item__c#Fixed__c} = true.
 *              <p>
 *              Schedule or invoke manually after sync batches report persistent DML errors. Does not modify
 *              {@link Opportunity_Sync_Report__c} parent rows in the current implementation.
 *              </p>
 * @group QOC Sync
 * @see Opportunity_Sync_Item__c
 * @see Opportunity_Sync_Report__c
 * @see OpportunitySync
 * @see OpportunityHeaderSyncBatch
 * @see OpportunityDetailSyncBatch
 */
public without sharing class OppSyncCleanErrorHandler extends SyncBase implements Database.Batchable<SObject> {
    
    /**
     * @description Returns a query locator for unfixed sync error items, oldest first.
     * @param bc Batch context supplied by the platform.
     * @return Query locator for {@link Opportunity_Sync_Item__c} rows with {@code Fixed__c = false}.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('start bcc: ' + bc);
        return Database.getQueryLocator(
            [SELECT
            Id,
            Error_Message__c,
            Status_Code__c,
            Error__c,
            Record_Id__c,
            Record__c,
            Record_Type__c,
            Fixed__c
        FROM Opportunity_Sync_Item__c WHERE Fixed__c = false ORDER BY Opportunity_Sync_Report__c ASC]
            );
    }
    
    /**
     * @description Processes one batch chunk of sync error items. For each recognized failure, collects order numbers
     *              or detail ext ids, updates the related QOC header/detail rows (no-op DML to release locks / re-fire
     *              integration), and marks the sync item fixed.
     * @param bc    Batch context supplied by the platform.
     * @param scope Chunk of {@link Opportunity_Sync_Item__c} rows from {@link #start}.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        System.debug('scope: ' + scope);
        List<Opportunity_Sync_Item__c> items = (List<Opportunity_Sync_Item__c>) scope;
        
        try{
            
            List<String> missingOrderNumbers = new List<String>();
            List<String> missingExtIds = new List<String>();
            List<Opportunity_Sync_Item__c> itemsToUpdate = new List<Opportunity_Sync_Item__c>();
            
            for (Opportunity_Sync_Item__c item : items) {
                
                if (item.Status_Code__c == 'INVALID_FIELD' && item.Error_Message__c != null && item.Error_Message__c.contains('Order_Number__c')) {
                    String orderNumber = parseOrderNumberFromError(item.Error_Message__c);
                    System.debug('orderNumber: ' + orderNumber);
                    if (orderNumber != null) {
                        missingOrderNumbers.add(orderNumber);
                        item.Fixed__c = true;
                        itemsToUpdate.add(item);
                    }
                    
                } else if ((item.Status_Code__c == 'OP_WITH_INVALID_USER_TYPE_EXCEPTION' || item.Status_Code__c == 'UNABLE_TO_LOCK_ROW') && String.isNotBlank(item.Record__c)) {
                    System.debug('UNABLE_TO_LOCK_ROW: ');
                    Map<String, Object> recordByField = (Map<String, Object>) JSON.deserializeUntyped(item.Record__c);
                    System.debug('record: ' + recordByField);
                    String orderNumber = recordByField == null ? null : (String) recordByField.get('Order_Number__c');
                    String extId = recordByField == null ? null : (String) recordByField.get('Ext_Id__c');
                    if (orderNumber != null) {
                        missingOrderNumbers.add(String.valueOf(orderNumber));
                        item.Fixed__c = true;
                        itemsToUpdate.add(item);
                    }
                    if (extId != null) {
                        missingExtIds.add(extId);
                        item.Fixed__c = true;
                        itemsToUpdate.add(item);
                    }
                    
                }else if (item.Status_Code__c == 'DUPLICATE_VALUE' && String.isNotBlank(item.Record__c)) {
                    Map<String, Object> recordByField = (Map<String, Object>) JSON.deserializeUntyped(item.Record__c);
                    System.debug('record: ' + recordByField);
                    String orderNumber = recordByField == null ? null : (String) recordByField.get('Order_Number__c');
                    String extId = recordByField == null ? null : (String) recordByField.get('Ext_Id__c');
                    if (orderNumber != null) {
                        missingOrderNumbers.add(String.valueOf(orderNumber));
                        item.Fixed__c = true;
                        itemsToUpdate.add(item);
                    }
                    if (extId != null) {
                        missingExtIds.add(extId);
                        item.Fixed__c = true;
                        itemsToUpdate.add(item);
                    }
                }
            }
            
            List<String> emptyOpportunities = getEmptyOpportunities();
            if (emptyOpportunities.size() > 0) {
                missingOrderNumbers.addAll(emptyOpportunities);
            }
            
            processheaders(missingOrderNumbers);
            processdetails(missingExtIds, missingOrderNumbers);
            
            if (itemsToUpdate.size() > 0) {
                update itemsToUpdate;
            }
            
        }catch(Exception e) {
            System.debug('Error: ' + e.getMessage());
            System.debug('Error: ' + e.getStackTraceString());
        }
        
    }
    
    private void processheaders(List<String> missingOrderNumbers) {
        try{
            if (missingOrderNumbers.size() == 0) {
                return;
            }
            Id standardPricebookId = getStandardPricebookId();
            String allFields = getHeaderFieldCsv();
            String query = 'SELECT ' + allFields + ' FROM QuotesOrdersCredits_Header__c WHERE Order_Number__c IN :missingOrderNumbers';
            // String query = 'SELECT Id FROM QuotesOrdersCredits_Header__c WHERE Order_Number__c IN :missingOrderNumbers';
            List<QuotesOrdersCredits_Header__c> headers = Database.query(query);
            // update headers;
            new OpportunitySync(headers, standardPricebookId).runSync();
            new QuoteSync(headers, standardPricebookId).runSync();
            new OrderSync(headers, standardPricebookId).runSync();
        }catch(Exception e) {
            System.debug('Error: ' + e.getMessage());
            System.debug('Error: ' + e.getStackTraceString());
        }
    }
    
    private void processdetails(List<String> missingExtIds, List<String> missingOrderNumbers) {
        try{
            if (missingExtIds.size() == 0 && missingOrderNumbers.size() == 0) {
                return;
            }
            String allFields = getDetailFieldCsv();
            String query =
                'SELECT '
                + allFields
                + ' FROM QuoteOrderCredit_Details__c WHERE Ext_Id__c IN :missingExtIds'
                + ' OR Order_Header__r.Order_Number__c IN :missingOrderNumbers';
            // String query =
            //     'SELECT '
            //     + ' Id'
            //     + ' FROM QuoteOrderCredit_Details__c WHERE Ext_Id__c IN :missingExtIds'
            //     + ' OR Order_Header__r.Order_Number__c IN :missingOrderNumbers';
            List<QuoteOrderCredit_Details__c> details = Database.query(query);
            // update details;

            List<String> partNumbers = new List<String>();
            for (QuoteOrderCredit_Details__c detail : details) {
                if (detail.Item_Number__c != null) {
                    partNumbers.add(detail.Item_Number__c);
                }
            }

            Id standardPricebookId = getStandardPricebookId();
            Map<String, Id> product2IdByPartRef = getProducts(partNumbers);
            product2IdByPartRef.put(SyncBase.NON_STOCK_ITEM_KEY, getNonStockProduct(standardPricebookId).Id);
            Map<Id, PricebookEntry> pricebookEntryByProduct2Id = addMissingPricebookEntries(
                product2IdByPartRef.values(),
                standardPricebookId
            );
            
            new OpportunityLineItemSync(details, standardPricebookId, product2IdByPartRef, pricebookEntryByProduct2Id).runSync();
            new QuoteLineSync(details, standardPricebookId, product2IdByPartRef, pricebookEntryByProduct2Id).runSync();
            new OrderLineSync(details, standardPricebookId, product2IdByPartRef, pricebookEntryByProduct2Id).runSync();
        }catch(Exception e) {
            System.debug('Error: ' + e.getMessage());
            System.debug('Error: ' + e.getStackTraceString());
        }
    }
    /**
     * @description Batch completion hook; no cross-chunk aggregation is performed.
     * @param bc Batch context supplied by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('OppSyncCleanErrorHandler finished');
        try{
            List<Opportunity_Sync_Report__c> reports = [SELECT Id FROM Opportunity_Sync_Report__c WHERE Errors__c = 0 ORDER BY LastModifiedDate ASC LIMIT 500];
            delete reports;
        }catch(Exception e) {
            System.debug('Error deleting reports: ' + e.getMessage());
            System.debug('Error deleting reports: ' + e.getStackTraceString());
        }
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
    
    private List<String> getEmptyOpportunities(){
        List<String> emptyOpportunities = new List<String>();
        for (Opportunity o : [SELECT Id, Order_Number__c FROM Opportunity WHERE Amount = null LIMIT 1000]) {
            emptyOpportunities.add(o.Order_Number__c);
        }
        return emptyOpportunities;
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
}