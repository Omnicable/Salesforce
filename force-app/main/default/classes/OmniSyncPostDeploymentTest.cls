/**
 * @description Tests for {@link OmniSyncPostDeployment} batch job and {@code renameDuplicatePartNumbers}.
 */
@IsTest
private class OmniSyncPostDeploymentTest {
    private static String uniqueSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static Id quotesHeaderRecordTypeId() {
        return Schema.SObjectType.QuotesOrdersCredits_Header__c.getRecordTypeInfosByDeveloperName()
            .get('Quotes')
            .getRecordTypeId();
    }

    private static Id quoteDetailStandardRecordTypeId() {
        return Schema.SObjectType.QuoteOrderCredit_Details__c.getRecordTypeInfosByDeveloperName()
            .get('Standard')
            .getRecordTypeId();
    }

    private static Spec_Sheet__c newSpecSheet() {
        return new Spec_Sheet__c(Name = 'Spec-' + uniqueSuffix());
    }

    private static QuotesOrdersCredits_Header__c newQuoteHeader(Id customerId) {
        String u = uniqueSuffix();
        return new QuotesOrdersCredits_Header__c(
            Name = 'Hdr-' + u,
            Customer__c = customerId,
            Order_Number__c = 'ORD-' + u,
            RecordTypeId = quotesHeaderRecordTypeId()
        );
    }

    private static Part_Numbers__c newPart(Id specSheetId, String nameStem, String extId, String opus) {
        return new Part_Numbers__c(
            Name = nameStem,
            Spec_Sheet__c = specSheetId,
            ExtID__c = extId,
            Item_Number_OPUS__c = opus
        );
    }

    // --- Database.Batchable<SObject> (stale part rename) ---

    @IsTest
    static void executeBatch_returnsJobId() {
        Test.startTest();
        Id jobId = OmniSyncPostDeployment.executeBatch();
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'executeBatch should enqueue a job');
    }

    @IsTest
    static void start_returnsQueryLocator_forPartNumbersQuery() {
        OmniSyncPostDeployment batchJob = new OmniSyncPostDeployment();
        Database.QueryLocator locator = batchJob.start(null);
        System.assertNotEquals(null, locator, 'start should return a query locator');
    }

    @IsTest
    static void batch_leavesNewPartsUnchanged_whenOutsideStartQuery() {
        Spec_Sheet__c spec = newSpecSheet();
        insert spec;
        insert newPart(spec.Id, 'P-New', 'EXT-N-' + uniqueSuffix(), 'OP-N');

        Test.startTest();
        OmniSyncPostDeployment.executeBatch();
        Test.stopTest();

        Part_Numbers__c row = [SELECT Name FROM Part_Numbers__c WHERE Spec_Sheet__c = :spec.Id LIMIT 1];
        System.assertEquals('P-New', row.Name, 'Current part rows should not match the stale-part query');
    }

    @IsTest
    static void batch_execute_appendsOldSuffix_whenRowMatchesStartQuery() {
        Spec_Sheet__c spec = newSpecSheet();
        insert spec;
        String ext = 'E' + uniqueSuffix().left(8);
        Part_Numbers__c stale = newPart(spec.Id, 'Stale-Nm', ext, 'OP-ST');
        insert stale;

        OmniSyncPostDeployment.testOnlyPartIdsForBatchStart = new Set<Id>{ stale.Id };
        try {
            Test.startTest();
            OmniSyncPostDeployment.executeBatch();
            Test.stopTest();
        } finally {
            OmniSyncPostDeployment.testOnlyPartIdsForBatchStart = null;
        }

        stale = [SELECT Name, ExtID__c, Item_Number_OPUS__c FROM Part_Numbers__c WHERE Id = :stale.Id];
        System.assert(stale.Name.endsWith('_old'), 'execute should append _old to Name');
        System.assert(stale.ExtID__c.endsWith('_old'));
        System.assert(stale.Item_Number_OPUS__c.endsWith('_old'));
    }

    @IsTest
    static void execute_method_appendsOldSuffix_withoutBatchFramework() {
        Spec_Sheet__c spec = newSpecSheet();
        insert spec;
        Part_Numbers__c row = newPart(spec.Id, 'Direct-Ex', 'X' + uniqueSuffix().left(7), 'OP-X');
        insert row;
        row = [SELECT Id, Name, ExtID__c, Item_Number_OPUS__c FROM Part_Numbers__c WHERE Id = :row.Id];

        Test.startTest();
        new OmniSyncPostDeployment().execute(null, new List<SObject>{ row });
        Test.stopTest();

        row = [SELECT Name, ExtID__c, Item_Number_OPUS__c FROM Part_Numbers__c WHERE Id = :row.Id];
        System.assert(row.Name.endsWith('_old'));
        System.assert(row.ExtID__c.endsWith('_old'));
        System.assert(row.Item_Number_OPUS__c.endsWith('_old'));
    }

    @IsTest
    static void batch_excludesPartReferencedOnQuoteOrderDetail() {
        Account cust = new Account(Name = 'Acct-' + uniqueSuffix());
        insert cust;
        QuotesOrdersCredits_Header__c hdr = newQuoteHeader(cust.Id);
        insert hdr;
        Spec_Sheet__c spec = newSpecSheet();
        insert spec;
        String ext = 'R' + uniqueSuffix().left(8);
        Part_Numbers__c linked = newPart(spec.Id, 'Linked-P', ext, 'OP-LK');
        insert linked;

        insert new QuoteOrderCredit_Details__c(
            Name = 'Ln-' + uniqueSuffix(),
            Order_Header__c = hdr.Id,
            Item_Number__c = linked.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId()
        );

        OmniSyncPostDeployment.testOnlyPartIdsForBatchStart = new Set<Id>{ linked.Id };
        try {
            Test.startTest();
            OmniSyncPostDeployment.executeBatch();
            Test.stopTest();
        } finally {
            OmniSyncPostDeployment.testOnlyPartIdsForBatchStart = null;
        }

        linked = [SELECT Name, ExtID__c FROM Part_Numbers__c WHERE Id = :linked.Id];
        System.assertEquals('Linked-P', linked.Name, 'Referenced parts must be excluded from the batch scope');
        System.assertEquals(ext, linked.ExtID__c);
    }

    // --- renameDuplicatePartNumbers ---

    @IsTest
    static void renameDuplicatePartNumbers_renamesOldestWhenNotReferenced() {
        Spec_Sheet__c spec = newSpecSheet();
        insert spec;

        String sharedExt = 'DUP-' + uniqueSuffix();
        Part_Numbers__c older = newPart(spec.Id, 'Part-A', sharedExt, 'OP-A');
        Part_Numbers__c newer = newPart(spec.Id, 'Part-B', sharedExt, 'OP-B');
        insert new List<Part_Numbers__c>{ older, newer };

        Test.setCreatedDate(older.Id, Datetime.now().addDays(-2));
        Test.setCreatedDate(newer.Id, Datetime.now().addDays(-1));

        Test.startTest();
        new OmniSyncPostDeployment().renameDuplicatePartNumbers();
        Test.stopTest();

        Map<Id, Part_Numbers__c> refreshed = new Map<Id, Part_Numbers__c>(
            [SELECT Name, ExtID__c, Item_Number_OPUS__c FROM Part_Numbers__c WHERE Id IN :new Set<Id>{ older.Id, newer.Id }]
        );

        Part_Numbers__c o = refreshed.get(older.Id);
        Part_Numbers__c n = refreshed.get(newer.Id);
        System.assert(o.Name.endsWith('_old'), 'Oldest duplicate should be renamed');
        System.assert(o.ExtID__c.endsWith('_old'));
        System.assert(o.Item_Number_OPUS__c.endsWith('_old'));
        System.assert(!n.Name.endsWith('_old'), 'Newer duplicate keeps original name');
        System.assertEquals(sharedExt, n.ExtID__c);
        System.assertEquals('OP-B', n.Item_Number_OPUS__c);
    }

    @IsTest
    static void renameDuplicatePartNumbers_skipsOldestWhenReferencedOnDetail() {
        Account cust = new Account(Name = 'Acct-' + uniqueSuffix());
        insert cust;
        QuotesOrdersCredits_Header__c hdr = newQuoteHeader(cust.Id);
        insert hdr;
        Spec_Sheet__c spec = newSpecSheet();
        insert spec;

        String sharedExt = 'REF-' + uniqueSuffix();
        Part_Numbers__c older = newPart(spec.Id, 'Part-C', sharedExt, 'OP-C');
        Part_Numbers__c newer = newPart(spec.Id, 'Part-D', sharedExt, 'OP-D');
        insert new List<Part_Numbers__c>{ older, newer };

        Test.setCreatedDate(older.Id, Datetime.now().addDays(-2));
        Test.setCreatedDate(newer.Id, Datetime.now().addDays(-1));

        insert new QuoteOrderCredit_Details__c(
            Name = 'Ln-' + uniqueSuffix(),
            Order_Header__c = hdr.Id,
            Item_Number__c = older.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId()
        );

        Test.startTest();
        new OmniSyncPostDeployment().renameDuplicatePartNumbers();
        Test.stopTest();

        Part_Numbers__c o = [
            SELECT Name, ExtID__c, Item_Number_OPUS__c
            FROM Part_Numbers__c
            WHERE Id = :older.Id
        ];
        System.assert(!o.Name.endsWith('_old'), 'Referenced oldest duplicate should not be renamed');
        System.assertEquals(sharedExt, o.ExtID__c);
    }

    @IsTest
    static void renameDuplicatePartNumbers_noOpWhenNoDuplicates() {
        Spec_Sheet__c spec = newSpecSheet();
        insert spec;
        Part_Numbers__c only = newPart(spec.Id, 'Solo', 'SOLO-' + uniqueSuffix(), 'OP-S');
        insert only;

        Test.startTest();
        new OmniSyncPostDeployment().renameDuplicatePartNumbers();
        Test.stopTest();

        Part_Numbers__c row = [SELECT Name FROM Part_Numbers__c WHERE Id = :only.Id];
        System.assertEquals('Solo', row.Name);
    }
}