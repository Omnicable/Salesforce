public with sharing class OmniSyncPostDeployment implements Database.Batchable<SObject> {
    private static final Integer DEFAULT_BATCH_SIZE = 200;

    /**
     * When non-empty during {@code Test.isRunningTest()}, {@link #start} scopes to these Ids (same
     * quote-line exclusion as production). Real rows cannot satisfy {@code LastModifiedDate <= LAST_N_YEARS:3}
     * in the current calendar year, so tests use this hook instead of date literals.
     */
    @TestVisible
    private static Set<Id> testOnlyPartIdsForBatchStart;

    /**
     * Queues the batch job that renames stale part numbers (per start() query).
     * @return The AsyncApexJob Id from Database.executeBatch.
     */
    public static Id executeBatch() {
        return Database.executeBatch(new OmniSyncPostDeployment(), DEFAULT_BATCH_SIZE);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (Test.isRunningTest() && testOnlyPartIdsForBatchStart != null && !testOnlyPartIdsForBatchStart.isEmpty()) {
            return Database.getQueryLocator(
                [
                    SELECT Id, Name, ExtID__c, Item_Number_OPUS__c
                    FROM Part_Numbers__c
                    WHERE
                        Id IN :testOnlyPartIdsForBatchStart
                        AND Id NOT IN (
                            SELECT Item_Number__c
                            FROM QuoteOrderCredit_Details__c
                            WHERE Item_Number__c != NULL
                        )
                ]
            );
        }
        return Database.getQueryLocator(
            [
                SELECT Id, Name, ExtID__c, Item_Number_OPUS__c
                FROM Part_Numbers__c
                WHERE
                    CreatedDate <= LAST_N_YEARS:8
                    AND LastModifiedDate <= LAST_N_YEARS:3
                    AND Id NOT IN (
                        SELECT Item_Number__c
                        FROM QuoteOrderCredit_Details__c
                        WHERE Item_Number__c != NULL
                    )
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Part_Numbers__c> parts = new List<Part_Numbers__c>();
        for (SObject row : scope) {
            parts.add((Part_Numbers__c) row);
        }
        for (Part_Numbers__c part : parts) {
            part.Name = part.Name + '_old';
            part.ExtID__c = part.ExtID__c + '_old';
            part.Item_Number_OPUS__c = part.Item_Number_OPUS__c + '_old';
        }
        System.debug('parts: ' + parts);
        update parts;
    }

    public void finish(Database.BatchableContext bc) {
    }

    public void renameDuplicatePartNumbers() {
        // Anonymous Apex: delete newest record for duplicate ExtID__c
        Set<String> dupExtIds = new Set<String>();
        for (AggregateResult ar : [
            SELECT ExtID__c extId, COUNT(Id) cnt
            FROM Part_Numbers__c
            WHERE ExtID__c != NULL
            GROUP BY ExtID__c
            HAVING COUNT(Id) > 1
        ]) {
            dupExtIds.add((String) ar.get('extId'));
        }

        List<Part_Numbers__c> updateOld = new List<Part_Numbers__c>();
        if (!dupExtIds.isEmpty()) {
            List<Part_Numbers__c> dupes = [
                SELECT Id, Name, ExtID__c, Item_Number_OPUS__c, CreatedDate
                FROM Part_Numbers__c
                WHERE ExtID__c IN :dupExtIds
                ORDER BY ExtID__c, CreatedDate ASC
            ];

            Map<String, Part_Numbers__c> oldestByExtId = new Map<String, Part_Numbers__c>();
            Set<Id> dupIds = new Set<Id>();
            for (Part_Numbers__c rec : dupes) {
                dupIds.add(rec.Id);
                if (!oldestByExtId.containsKey(rec.ExtID__c)) {
                    oldestByExtId.put(rec.ExtID__c, rec); // oldest due to ASC sort
                }
            }

            Set<Id> referencedIds = new Set<Id>();
            for (QuoteOrderCredit_Details__c detail : [
                SELECT Item_Number__c
                FROM QuoteOrderCredit_Details__c
                WHERE Item_Number__c IN :dupIds
            ]) {
                referencedIds.add(detail.Item_Number__c);
            }

            for (Part_Numbers__c rec : oldestByExtId.values()) {
                if (!referencedIds.contains(rec.Id)) {
                    rec.Name = rec.Name + '_old';
                    rec.ExtID__c = rec.ExtID__c + '_old';
                    rec.Item_Number_OPUS__c = rec.Item_Number_OPUS__c + '_old';
                    updateOld.add(rec);
                }
            }
        }

        update updateOld;
    }
}