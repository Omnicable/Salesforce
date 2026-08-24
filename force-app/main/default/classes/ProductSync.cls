/**
 * @description Synchronous sync of {@link Part_Numbers__c} rows to {@link Product2} via DataWeave ({@code partToProduct}).
 *              Matches existing products by {@link Product2#Item_Number__c}, routes to insert/update lists, and persists
 *              through {@link SyncBase#saveRecords}. Delete removes products linked by
 *              {@link Product2#Part_Number_Ref__c} with partial-success DML and sync items on failure.
 *              <p>
 *              Invoked from {@link PartNumberEventTrigger} (and optionally {@link PartNumberTrigger}) via
 *              {@link Queueable}. {@link #runSync} is the primary entry point.
 *              </p>
 * @group QOC Sync
 * @see SyncBase
 * @see PartNumberEventTrigger
 */
public  class ProductSync extends SyncBase{
    private static final String OP_UPSERT = 'Upsert';
    private static final String OP_DELETE = 'Delete';

    /**
     * @description Part number rows in the current sync scope.
     */
    private List<Part_Numbers__c> parts = new List<Part_Numbers__c>();

    /**
     * @description Trigger operation: {@value OP_UPSERT} or {@value OP_DELETE}.
     */
    private String operation;

    /**
     * @description Run summary; inserted by {@link SyncBase#saveRecords} or {@link #persistReport} on failure.
     */
    private Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
        Is_Successful__c = true,
        Record_Type__c = 'Product',
        Update_Count__c = 0,
        Insert_Count__c = 0,
        Total_Count__c = 0,
        Error_Count__c = 0,
        Existing_Record_Count__c = 0
    );

    /**
     * @description Existing products keyed by {@link Product2#Item_Number__c} for insert vs update routing.
     */
    private Map<String, Product2> itemNumberToProductMap = new Map<String, Product2>();

    /**
     * @description Products queued for insert during {@link #runUpsert}; cleared at the start of each upsert run.
     */
    private List<Product2> toInsert = new List<Product2>();

    /**
     * @description Products queued for update during {@link #runUpsert}; cleared at the start of each upsert run.
     */
    private List<Product2> toUpdate = new List<Product2>();

    /**
     * @description Captures part scope, operation, and initializes {@link Opportunity_Sync_Report__c#Total_Count__c}.
     * @param parts     Source part rows; null is treated as empty.
     * @param operation {@code Upsert} or {@code Delete}.
     */
    public ProductSync(List<Part_Numbers__c> parts, String operation) {
        this.parts = parts == null ? new List<Part_Numbers__c>() : parts;
        this.operation = operation;
        this.report.Total_Count__c = this.parts.size();
    }

    /**
     * @description Runs product sync for the current scope: upsert via DataWeave insert/update routing, or delete by part ref.
     */
    public void runSync() {
        if (parts.isEmpty()) {
            return;
        }

        if (operation == OP_DELETE) {
            runDelete();
        } else {
            runUpsert();
        }
    }

    /**
     * @description Transforms parts via DataWeave, matches by item number, and persists with {@link SyncBase#saveRecords}.
     */
    private void runUpsert() {
        List<Product2> products = (List<Product2>) JSON.deserialize(
            syncDataWeaveToJson('partToProduct', parts),
            List<Product2>.class
        );
        if (products.isEmpty()) {
            insert report;
            return;
        }

        toInsert.clear();
        toUpdate.clear();
        itemNumberToProductMap.clear();

        Set<String> itemNumbers = new Set<String>();
        for (Product2 product : products) {
            if (product.Item_Number__c != null) {
                itemNumbers.add(product.Item_Number__c);
            }
        }

        getExistingRecords(itemNumbers);
        assignRecordsToUpdateAndInsert(products);
        saveRecords(toInsert, toUpdate, report);
    }

    /**
     * @description Deletes products linked to scope parts with partial-success DML and sync reporting.
     */
    private void runDelete() {
        List<Product2> products = [
            SELECT Id, Part_Number_Ref__c, Item_Number__c
            FROM Product2
            WHERE Part_Number_Ref__c IN :parts
        ];
        if (products.isEmpty()) {
            insert report;
            return;
        }

        persistReport(errorsFromDelete(Database.delete(products, false), products));
    }

    /**
     * @description Maps {@link Database.DeleteResult} failures to sync items (aligned with {@link SyncBase#errorsFromDml}).
     * @param results Delete results in list order.
     * @param rows    Products submitted in the same order as {@code results}.
     * @return Sync error items for failed deletes.
     */
    private List<Opportunity_Sync_Item__c> errorsFromDelete(Database.DeleteResult[] results, List<Product2> rows) {
        List<Opportunity_Sync_Item__c> errors = new List<Opportunity_Sync_Item__c>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                report.Is_Successful__c = false;
                errors.add(
                    new Opportunity_Sync_Item__c(
                        Error__c = JSON.serialize(results[i].getErrors()),
                        Record__c = JSON.serialize(rows[i]),
                        Record_Type__c = report.Record_Type__c
                    )
                );
            } else {
                report.Update_Count__c++;
            }
        }
        return errors;
    }

    /**
     * @description Inserts {@link #report} and links any DML error items (used for delete when {@link SyncBase#saveRecords} does not apply).
     * @param errors Sync items from failed DML; empty when all succeed.
     */
    private void persistReport(List<Opportunity_Sync_Item__c> errors) {
        insert report;
        if (!errors.isEmpty()) {
            for (Opportunity_Sync_Item__c item : errors) {
                item.Opportunity_Sync_Report__c = report.Id;
            }
            insert errors;
        }
    }

    /**
     * @description Runs DataWeave script {@code partToProduct} on {@link #parts}.
     * @return Deserialized {@link Product2} rows (not yet committed).
     */
    public List<Product2> syncProducts() {
        return (List<Product2>) JSON.deserialize(
            syncDataWeaveToJson('partToProduct', parts),
            List<Product2>.class
        );
    }

    /**
     * @description Queries existing products by item number and populates {@link #itemNumberToProductMap}.
     * @param itemNumbers Distinct {@link Product2#Item_Number__c} values from the transformed scope.
     */
    private void getExistingRecords(Set<String> itemNumbers) {
        if (itemNumbers == null || itemNumbers.isEmpty()) {
            report.Existing_Record_Count__c = 0;
            return;
        }

        for (Product2 existing : [
            SELECT Id, Item_Number__c
            FROM Product2
            WHERE Item_Number__c IN :itemNumbers
        ]) {
            if (existing.Item_Number__c != null) {
                itemNumberToProductMap.put(existing.Item_Number__c, existing);
            }
        }

        report.Existing_Record_Count__c = itemNumberToProductMap.size();
    }

    /**
     * @description Routes DataWeave products to {@link #toInsert} or {@link #toUpdate} using {@link #itemNumberToProductMap}.
     * @param products Product rows from {@code partToProduct}.
     */
    private void assignRecordsToUpdateAndInsert(List<Product2> products) {
        for (Product2 product : products) {
            if (product.Item_Number__c != null && itemNumberToProductMap.containsKey(product.Item_Number__c)) {
                product.Id = itemNumberToProductMap.get(product.Item_Number__c).Id;
                toUpdate.add(product);
            } else {
                toInsert.add(product);
            }
        }
    }
}