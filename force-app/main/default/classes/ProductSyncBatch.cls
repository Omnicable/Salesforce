/**
 * @description Batchable entry that reloads {@link Part_Numbers__c} rows by Id and runs {@link ProductSync} per chunk.
 *              Each chunk transforms parts via DataWeave ({@code partToProduct}) and persists {@link Product2} records
 *              with partial-success DML through {@link SyncBase#saveRecords}.
 *              <p>
 *              Typically invoked from {@link PartNumberEventTrigger} after {@link PartNumber__e} platform events.
 *              Part Ids come from {@link PartNumber__e#Id__c}; {@link PartNumber__e#Item_Number__c} is published for
 *              integration parity but matching is performed from loaded part rows in {@link ProductSync}.
 *              </p>
 * @group QOC Sync
 * @see ProductSync
 * @see SyncBase
 * @see PartNumberEventTrigger
 * @see PartNumberTrigger
 * @see OpportunityDetailSyncBatch
 */
public  class ProductSyncBatch implements Database.Batchable<SObject> {

    /**
     * @description Part number record Ids to query and sync; bound in {@link #buildQuery}.
     */
    private Set<Id> partNumberIds = new Set<Id>();

    /**
     * @description Captures the part number Ids for the batch run.
     * @param partNumberIds Part Ids from {@link PartNumber__e}; null yields an empty set and an empty batch query.
     */
    public ProductSyncBatch(Set<Id> partNumberIds) {
        this.partNumberIds = partNumberIds == null ? new Set<Id>() : partNumberIds;
    }

    /**
     * @description Returns a query locator for all accessible fields on parts in {@link #partNumberIds}.
     * @param bc Batch context supplied by the platform.
     * @return Query locator for {@link Part_Numbers__c} rows in scope.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(buildQuery());
    }

    /**
     * @description Runs {@link ProductSync} upsert for one batch chunk of {@link Part_Numbers__c} rows.
     * @param bc    Batch context supplied by the platform.
     * @param scope Chunk of {@link Part_Numbers__c} rows from {@link #start}.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Part_Numbers__c> parts = (List<Part_Numbers__c>) scope;

        ProductSync productSync = new ProductSync(parts, 'Upsert');
        productSync.runSync();
    }

    /**
     * @description Batch completion hook; no cross-chunk aggregation is performed today.
     * @param bc Batch context supplied by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('ProductSyncBatch finished');
    }

    /**
     * @description Builds dynamic SOQL for part rows in the batch constructor scope.
     * @return SOQL selecting all accessible non-BASE64 fields where Id is in {@code partNumberIds}.
     */
    public static String buildQuery() {
        String csv = getPartNumberFieldCsv();
        return 'SELECT ' + csv + ' FROM Part_Numbers__c WHERE Id IN :partNumberIds';
    }

    /**
     * @description Comma-separated field API names for {@link Part_Numbers__c} dynamic queries.
     * @return SELECT clause field list; {@code Id} only if no accessible fields qualify.
     */
    private static String getPartNumberFieldCsv() {
        Map<String, Schema.SObjectField> fieldMap = Part_Numbers__c.SObjectType.getDescribe().fields.getMap();
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