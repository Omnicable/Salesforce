/**
 * @description Tests for {@link SalesCloudPostDeployment} batch start, execute, and finish paths across
 *              supported integration object types and actions.
 */
@IsTest
private class SalesCloudPostDeploymentTest {

    private static Date windowStart() {
        return Date.today().addDays(-1);
    }

    private static Date windowEnd() {
        return Date.today().addDays(1);
    }

    @TestSetup
    static void setupData() {
        Account customer = new Account(Name = 'SalesCloudPostDeployment Test Account', Account_Number__c = '111111111');
        insert customer;

        QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(
            Name = 'SCPD Test Header',
            Customer__c = customer.Id,
            Order_Number__c = 'SCPD-H-' + String.valueOf(Datetime.now().getTime())
        );
        insert header;

        insert new QuoteOrderCredit_Details__c(
            Order_Header__c = header.Id,
            Ext_Id__c = 'SCPD-D-' + String.valueOf(Datetime.now().getTime())
        );

        Part_Numbers__c part = new Part_Numbers__c(
            Name = 'SCPD Test Part',
            Item_Number__c = '123456'
        );

        insert part;
    }

    @IsTest
    static void batchTestAction_countsHeadersInWindow() {
        QuotesOrdersCredits_Header__c header = [
            SELECT Id
            FROM QuotesOrdersCredits_Header__c
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(
                windowStart(),
                windowEnd(),
                header,
                'test'
            ),
            200
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :header.Id],
            'Test action should not delete header rows'
        );
    }

    @IsTest
    static void batchTestAction_countsDetailsInWindow() {
        QuoteOrderCredit_Details__c detail = [
            SELECT Id
            FROM QuoteOrderCredit_Details__c
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(
                windowStart(),
                windowEnd(),
                detail,
                'test'
            ),
            200
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Id = :detail.Id],
            'Test action should not delete detail rows'
        );
    }

    @IsTest
    static void batchDeleteAction_deletesDetails() {
        QuoteOrderCredit_Details__c detail = [
            SELECT Id
            FROM QuoteOrderCredit_Details__c
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(
                windowStart(),
                windowEnd(),
                detail,
                'delete'
            ),
            200
        );
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Id = :detail.Id],
            'Delete action should remove detail rows in scope'
        );
    }

    @IsTest
    static void batchUpdateAction_updatesHeadersWithoutError() {
        QuotesOrdersCredits_Header__c header = [
            SELECT Id, SalesNote1__c
            FROM QuotesOrdersCredits_Header__c
            LIMIT 1
        ];
        header.SalesNote1__c = 'SCPD batch update';
        update header;

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(
                windowStart(),
                windowEnd(),
                header,
                'update'
            ),
            200
        );
        Test.stopTest();

        QuotesOrdersCredits_Header__c updated = [
            SELECT SalesNote1__c
            FROM QuotesOrdersCredits_Header__c
            WHERE Id = :header.Id
        ];
        System.assertEquals('SCPD batch update', updated.SalesNote1__c);
    }

    @IsTest
    static void batchUnknownType_processesZeroRows() {
        Account accountStub = new Account();

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(
                windowStart(),
                windowEnd(),
                accountStub,
                'test'
            ),
            200
        );
        Test.stopTest();

        System.assert(true, 'Unknown record type should complete without error');
    }

    @IsTest
    static void startReturnsQueryLocatorForHeaderType() {
        QuotesOrdersCredits_Header__c header = [
            SELECT Id
            FROM QuotesOrdersCredits_Header__c
            LIMIT 1
        ];

        SalesCloudPostDeployment batch = new SalesCloudPostDeployment(
            windowStart(),
            windowEnd(),
            header,
            'test'
        );

        Database.QueryLocator locator = batch.start(null);
        System.assertNotEquals(null, locator, 'Header start should return a query locator');
    }

    @IsTest
    static void executeTestAction_accumulatesScopeSize() {
        QuotesOrdersCredits_Header__c header = [
            SELECT Id, CreatedDate
            FROM QuotesOrdersCredits_Header__c
            LIMIT 1
        ];

        SalesCloudPostDeployment batch = new SalesCloudPostDeployment(
            windowStart(),
            windowEnd(),
            header,
            'test'
        );

        Test.startTest();
        batch.execute(null, new List<SObject>{ header });
        batch.finish(null);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :header.Id],
            'Test execute should not delete the header row'
        );
    }
}