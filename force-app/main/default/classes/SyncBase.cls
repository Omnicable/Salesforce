public without sharing abstract class SyncBase {

    public static final String NON_STOCK_ITEM_KEY = 'Non-Stock';

    /**
     * @description Max length for {@link Opportunity_Sync_Item__c#Error_Message__c} and report error text fields.
     */
    private static final Integer SYNC_ERROR_MESSAGE_MAX_LENGTH = 255;
    
    /**
     * @description Normalizes a DataWeave script result to JSON text for deserialization.
     * @param r DataWeave execution result; may be null.
     * @return JSON array string, or {@code "[]"} when the value is null.
     */
    protected String dwResultToJson(DataWeave.Result r) {
        Object v = r == null ? null : r.getValue();
        if (v == null) {
            return '[]';
        }
        return (v instanceof String) ? (String) v : JSON.serialize(v);
    }
    
    /**
     * @description Executes a named DataWeave script with the header list bound as {@code payload}.
     * @param scriptName   Metadata name of the DataWeave resource (e.g. {@code qocToOpportunity}).
     * @param inputHeaders Rows passed into the script; null becomes an empty list.
     * @return Raw DataWeave result from {@link DataWeave.Script#execute}.
     */
    protected DataWeave.Result runDw(String scriptName, List<SObject> inputHeaders) {
        DataWeave.Script s = DataWeave.Script.createScript(scriptName);
        List<SObject> rows = inputHeaders == null
            ? new List<SObject>()
            : inputHeaders;
        return s.execute(new Map<String, Object>{ 'payload' => rows });
    }
    
    /**
     * @description Runs {@code qocToOpportunity} against {@link #headers} and deserializes the output.
     * @return Opportunity sObjects produced by DataWeave (not yet committed).
     */
    protected String syncDataWeaveToJson(String scriptName, List<SObject> input) {
        DataWeave.Result dwresult = runDw(scriptName, input);
        return dwResultToJson(dwresult);
    }
    
    /**
     * @description Truncates a message to fit {@link Opportunity_Sync_Item__c#Error_Message__c} (255 chars).
     * @param message Raw error or exception text.
     * @return Truncated message, or null when input is null.
     */
    private static String truncateSyncErrorMessage(String message) {
        if (message == null) {
            return null;
        }
        return message.length() <= SYNC_ERROR_MESSAGE_MAX_LENGTH
            ? message
            : message.substring(0, SYNC_ERROR_MESSAGE_MAX_LENGTH);
    }

    /**
     * @description Maps {@link Database.SaveResult} failures to sync error records (aligned with result index).
     * @param results DML results in list order.
     * @param rows    Rows submitted in the same order as {@code results}.
     * @return {@link Omni_Sync_Error__c} rows for failed saves.
     */
    protected  List<Opportunity_Sync_Item__c> errorsFromDml(Database.SaveResult[] results, List<SObject> rows, Opportunity_Sync_Report__c report) {
        List<Opportunity_Sync_Item__c> errors = new List<Opportunity_Sync_Item__c>();
        Integer i = 0;
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                report.Is_Successful__c = false;
                report.Error_Count__c++;
                errors.add(
                    new Opportunity_Sync_Item__c(
                    Error_Message__c = truncateSyncErrorMessage(result.getErrors()[0].getMessage()),
                Status_Code__c = String.valueOf(result.getErrors()[0].statusCode),
                Error__c = JSON.serialize(result.getErrors()),
                // Record_Id__c = (String)rows[i].get('Order_Number__c'),
                Record__c = JSON.serialize(rows[i])
                    // Record_Type__c = report.Record_Type__c )
                ) );
            }else{
                report.Update_Count__c++;
            }
            i++;
        }
        return errors;
    }
    
    protected void saveRecords(List<SObject> toInsert, List<SObject> toUpdate, Opportunity_Sync_Report__c report) {
        report.Total_Count__c = toInsert.size() + toUpdate.size();
        List<Opportunity_Sync_Item__c> errors = new List<Opportunity_Sync_Item__c>();
        errors.addAll(updateRecords(toUpdate, report));
        errors.addAll(insertRecords(toInsert, report));
        insert report;
        
        if (!errors.isEmpty()) {
            for (Opportunity_Sync_Item__c item : errors) {
                item.Opportunity_Sync_Report__c = report.Id;
            }
            insert errors;
        }
        
    }
    
    /**
     * @description Partial-success update; failures become {@link Omni_Sync_Error__c} rows.
     * @param records Rows to update.
     * @param report The sync report to link the errors to.
     * @return Error records; empty when all succeed.
     */
    private List<Opportunity_Sync_Item__c> insertRecords(List<SObject> records, Opportunity_Sync_Report__c report) {
        if (records.isEmpty()) {
            return new List<Opportunity_Sync_Item__c>();
        }
        return errorsFromDml(Database.insert(records, false), records, report);
    }
    
    
    /**
     * @description Partial-success update; failures become {@link Omni_Sync_Error__c} rows.
     * @param records Rows to update.
     * @param report The sync report to link the errors to.
     * @return Error records; empty when all succeed.
     */
    private List<Opportunity_Sync_Item__c> updateRecords(List<SObject> records, Opportunity_Sync_Report__c report) {
        if (records.isEmpty()) {
            return new List<Opportunity_Sync_Item__c>();
        }
        return errorsFromDml(Database.update(records, false), records, report);
    }
    
    /**
     * @description Resolves the org standard price book. In unit tests, SOQL on {@code IsStandard} often returns
     *              no rows; {@link Test#getStandardPricebookId()} is used first. If the running user cannot see
     *              the standard book via SOQL, falls back to any active price book.
     * @return Standard {@link Pricebook2} Id when found, else first active book, else null.
     */
    protected Id getStandardPricebookId() {
        if (Test.isRunningTest()) {
            try {
                return Test.getStandardPricebookId();
            } catch (Exception e) {
                // Test org without standard PB wiring; try SOQL below
                System.debug('Error getting standard pricebook id: ' + e);
            }
        }
        List<Pricebook2> standardBooks = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];
        if (!standardBooks.isEmpty()) {
            return standardBooks[0].Id;
        }
        List<Pricebook2> activeBooks = [
            SELECT Id
            FROM Pricebook2
            WHERE IsActive = true
            ORDER BY IsStandard DESC, CreatedDate ASC
            LIMIT 1
        ];
        return activeBooks.isEmpty() ? null : activeBooks[0].Id;
    }
    
    /**
     * @description Resolves {@link PricebookEntry} Id for a product on the standard price book, using the
     *              supplied map first and querying on cache miss. Updates {@code pricebookEntryByProduct2Id}
     *              when a row is found via SOQL so downstream sync steps share the cache.
     * @param product2Id                 {@link Product2} Id for the line.
     * @param standardPricebookId        Standard price book to resolve against.
     * @param pricebookEntryByProduct2Id Product Id to {@link PricebookEntry} cache; may be updated in place.
     * @return Price book entry Id, or null when not found or required inputs are unset.
     */
    protected Id resolvePricebookEntryId(
        Id product2Id,
    Id standardPricebookId,
    Map<Id, PricebookEntry> pricebookEntryByProduct2Id
    ) {
        if (product2Id == null || standardPricebookId == null || pricebookEntryByProduct2Id == null) {
            return null;
        }
        if (pricebookEntryByProduct2Id.containsKey(product2Id)) {
            PricebookEntry cachedEntry = pricebookEntryByProduct2Id.get(product2Id);
            return cachedEntry == null ? null : cachedEntry.Id;
        }
        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Pricebook2Id, IsActive
            FROM PricebookEntry
            WHERE Product2Id = :product2Id AND Pricebook2Id = :standardPricebookId
            LIMIT 1
        ];
        if (!entries.isEmpty()) {
            pricebookEntryByProduct2Id.put(product2Id, entries[0]);
            return entries[0].Id;
        }
        return null;
    }
    
    /**
     * @description Resolves {@link Product2} records by {@link Product2#Part_Number_Ref__c} for the given part numbers.
     * @param partNumbers Distinct item numbers from the detail scope.
     * @return Part number ref to {@link Product2} Id.
     */
    protected Map<String, Id> getProducts(List<String> partNumbers) {
        Map<String, Id> product2IdByPartRef = new Map<String, Id>();
        if (partNumbers.isEmpty()) {
            return product2IdByPartRef;
        }
        for (Product2 product : [
            SELECT Id, Part_Number_Ref__c
            FROM Product2
            WHERE Part_Number_Ref__c IN :partNumbers
        ]) {
            product2IdByPartRef.put(product.Part_Number_Ref__c, product.Id);
        }
        return product2IdByPartRef;
    }
    
    /**
     * @description Finds or creates the {@code Non-Stock} {@link Product2} and ensures a standard {@link PricebookEntry}.
     * @return Active Non-Stock product for lines without an item number.
     */
    protected Product2 getNonStockProduct(Id standardPricebookId) {
        List<Product2> products = [
            SELECT Id, Name, Part_Number_Ref__c
            FROM Product2
            WHERE Name = 'Non-Stock'
            LIMIT 1
        ];
        if (!products.isEmpty()) {
            return products[0];
        }
        
        Product2 product = new Product2(Name = 'Non-Stock', IsActive = true, Category__c = 'Other');
        insert product;
        
        if (standardPricebookId != null) {
            List<PricebookEntry> existingEntries = [
                SELECT Id
                FROM PricebookEntry
                WHERE Product2Id = :product.Id AND Pricebook2Id = :standardPricebookId
                LIMIT 1
            ];
            if (existingEntries.isEmpty()) {
                insert new PricebookEntry(
                    Product2Id = product.Id,
                Pricebook2Id = standardPricebookId,
                IsActive = true,
                UnitPrice = 0
                    );
            }
        }
        
        return product;
    }
    
    /**
     * @description Loads or creates standard {@link PricebookEntry} rows for scoped products and Non-Stock.
     * @param product2Ids Product Ids from {@link #getProducts}; may be empty.
     * @return Product Id to price book entry map for {@link #standardPricebookId}.
     */
    protected Map<Id, PricebookEntry> addMissingPricebookEntries(List<Id> product2Ids, Id standardPricebookId) {
        Map<Id, PricebookEntry> pricebookEntryByProduct2IdLocal = new Map<Id, PricebookEntry>();
        List<PricebookEntry> toInsert = new List<PricebookEntry>();
        
        List<PricebookEntry> pricebookEntries = [
            SELECT Id, Pricebook2Id, Product2Id, IsActive
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId
                AND (Product2Id IN :product2Ids OR name = 'Non-Stock')
        ];
        
        for (PricebookEntry pbe : pricebookEntries) {
            pricebookEntryByProduct2IdLocal.put(pbe.Product2Id, pbe);
        }
        
        for (Id product2Id : product2Ids) {
            if (product2Id != null && !pricebookEntryByProduct2IdLocal.containsKey(product2Id)) {
                toInsert.add(
                    new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                Product2Id = product2Id,
                UnitPrice = 0,
                IsActive = true
                    )
                    );
            }
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (PricebookEntry pbe : toInsert) {
                pricebookEntryByProduct2IdLocal.put(pbe.Product2Id, pbe);
            }
        }
        
        return pricebookEntryByProduct2IdLocal;
    }
}