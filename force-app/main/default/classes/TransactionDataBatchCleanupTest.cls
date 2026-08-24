/**
 * @author Chris Williams <chrisw@launchdm.com>
 * @group Yearly Cleanup
 * @since 2026-07-16
 * @description
 * Test class for {@link TransactionDataBatchCleanup}.
 *
 * Verifies that records older than the two-year retention window are deleted
 * and that recent records are retained. Retention matches the batch
 * ({@code LAST_N_YEARS:2}) using each object's business date field or
 * {@code LastModifiedDate}:
 * <ul>
 *   <li>{@link Pending_Issue__c}.{@code Disposition_Date__c}</li>
 *   <li>{@link RMA__c}.{@code RMA_Date__c}</li>
 *   <li>{@link SalesHistory__c}.{@code Invoice_Date__c}</li>
 *   <li>{@link QuotesOrdersCredits_Header__c}.{@code Date__c}</li>
 * </ul>
 *
 * Also covers master-detail cascade deletes and full step chaining via
 * {@link TransactionDataBatchCleanup#executeBatch}.
 *
 * @see TransactionDataBatchCleanup
 */
@IsTest
private class TransactionDataBatchCleanupTest {

    /**
     * @description Builds a unique suffix for test record names.
     * @return Unique string suitable for Name / identifier fields.
     */
    private static String uniqueSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    /**
     * @description Returns a date older than the two-year retention window ({@code LAST_N_YEARS:2}).
     * @return Date three years before today (before the Jan 1 cutoff of {@code LAST_N_YEARS:2}).
     */
    private static Date olderThanRetention() {
        return Date.today().addYears(-3);
    }

    /**
     * @description Returns a date within the two-year retention window.
     * @return Date thirty days before today.
     */
    private static Date withinRetention() {
        return Date.today().addDays(-30);
    }

    /**
     * @description Inserts and returns a unique Account for test data parents.
     * @return Inserted {@link Account}.
     */
    private static Account newAccount() {
        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;
        return acct;
    }

    /**
     * @description Resolves the Quotes record type Id for {@link QuotesOrdersCredits_Header__c}.
     * @return Record type Id for developer name {@code Quotes}.
     */
    private static Id quotesHeaderRecordTypeId() {
        return Schema.SObjectType.QuotesOrdersCredits_Header__c.getRecordTypeInfosByDeveloperName()
            .get('Quotes')
            .getRecordTypeId();
    }

    /**
     * @description Resolves the Standard record type Id for {@link QuoteOrderCredit_Details__c}.
     * @return Record type Id for developer name {@code Standard}.
     */
    private static Id quoteDetailStandardRecordTypeId() {
        return Schema.SObjectType.QuoteOrderCredit_Details__c.getRecordTypeInfosByDeveloperName()
            .get('Standard')
            .getRecordTypeId();
    }

    /**
     * @description Builds an unsaved {@link Pending_Issue__c} with Account parent and disposition date.
     * @param acct Parent {@link Account} for the master-detail relationship.
     * @param dispositionDate Value for {@code Disposition_Date__c} used by retention filtering.
     * @return Unsaved {@link Pending_Issue__c}.
     */
    private static Pending_Issue__c newPendingIssue(Account acct, Date dispositionDate) {
        Pending_Issue__c issue = new Pending_Issue__c();
        String accountField = findMasterDetailFieldApiName(Pending_Issue__c.SObjectType, Account.SObjectType);
        if (accountField != null) {
            issue.put(accountField, acct.Id);
        }
        issue.Disposition_Date__c = dispositionDate;
        return issue;
    }

    /**
     * @description Finds the master-detail field API name from {@code childType} to {@code parentType}.
     * @param childType Child sObject type.
     * @param parentType Parent sObject type referenced by the master-detail field.
     * @return Field API name, or {@code null} if none is found.
     */
    private static String findMasterDetailFieldApiName(Schema.SObjectType childType, Schema.SObjectType parentType) {
        for (Schema.SObjectField fieldToken : childType.getDescribe().fields.getMap().values()) {
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (fieldDescribe.getType() != Schema.DisplayType.REFERENCE) {
                continue;
            }
            if (!fieldDescribe.isCascadeDelete()) {
                continue;
            }
            for (Schema.SObjectType refType : fieldDescribe.getReferenceTo()) {
                if (refType == parentType) {
                    return fieldDescribe.getName();
                }
            }
        }
        return null;
    }

    /**
     * @description
     * Verifies {@link TransactionDataBatchCleanup.CleanupStep#PENDING_ISSUE} deletes only
     * {@link Pending_Issue__c} rows with {@code Disposition_Date__c} older than retention.
     */
    @IsTest
    static void executeBatch_deletesOldPendingIssues() {
        Account acct = newAccount();
        Pending_Issue__c oldIssue = newPendingIssue(acct, olderThanRetention());
        Pending_Issue__c recentIssue = newPendingIssue(acct, withinRetention());
        insert new List<Pending_Issue__c>{ oldIssue, recentIssue };

        Test.startTest();
        Id jobId = Database.executeBatch(
            new TransactionDataBatchCleanup(TransactionDataBatchCleanup.CleanupStep.PENDING_ISSUE),
            50
        );
        Test.stopTest();

        assertJobCompleted(jobId);
        System.assertEquals(0, [SELECT COUNT() FROM Pending_Issue__c WHERE Id = :oldIssue.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Pending_Issue__c WHERE Id = :recentIssue.Id]);
    }

    /**
     * @description
     * Verifies {@link TransactionDataBatchCleanup.CleanupStep#RMA} deletes only
     * {@link RMA__c} rows with {@code RMA_Date__c} older than retention.
     */
    @IsTest
    static void executeBatch_deletesOldRmas() {
        Account acct = newAccount();
        RMA__c oldRma = new RMA__c(
            Name = 'RMA-Old-' + uniqueSuffix(),
            Account__c = acct.Id,
            RMA_Date__c = olderThanRetention()
        );
        RMA__c recentRma = new RMA__c(
            Name = 'RMA-Recent-' + uniqueSuffix(),
            Account__c = acct.Id,
            RMA_Date__c = withinRetention()
        );
        insert new List<RMA__c>{ oldRma, recentRma };

        Test.startTest();
        Id jobId = Database.executeBatch(
            new TransactionDataBatchCleanup(TransactionDataBatchCleanup.CleanupStep.RMA),
            50
        );
        Test.stopTest();

        assertJobCompleted(jobId);
        System.assertEquals(0, [SELECT COUNT() FROM RMA__c WHERE Id = :oldRma.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM RMA__c WHERE Id = :recentRma.Id]);
    }

    /**
     * @description
     * Verifies {@link TransactionDataBatchCleanup.CleanupStep#SALES_HISTORY} deletes old
     * {@link SalesHistory__c} parents and cascade-deletes related {@link Sales_History_Line_Item__c} children.
     */
    @IsTest
    static void executeBatch_deletesOldSalesHistoryAndLineItems() {
        Account acct = newAccount();
        SalesHistory__c oldHistory = new SalesHistory__c(
            Name = 'INV-Old-' + uniqueSuffix(),
            Customer__c = acct.Id,
            Invoice_Date__c = olderThanRetention()
        );
        SalesHistory__c recentHistory = new SalesHistory__c(
            Name = 'INV-Recent-' + uniqueSuffix(),
            Customer__c = acct.Id,
            Invoice_Date__c = withinRetention()
        );
        insert new List<SalesHistory__c>{ oldHistory, recentHistory };

        Sales_History_Line_Item__c oldLine = new Sales_History_Line_Item__c(
            Name = 'Line-Old',
            Sales_History__c = oldHistory.Id
        );
        Sales_History_Line_Item__c recentLine = new Sales_History_Line_Item__c(
            Name = 'Line-Recent',
            Sales_History__c = recentHistory.Id
        );
        insert new List<Sales_History_Line_Item__c>{ oldLine, recentLine };

        Test.startTest();
        Id jobId = Database.executeBatch(
            new TransactionDataBatchCleanup(TransactionDataBatchCleanup.CleanupStep.SALES_HISTORY),
            50
        );
        Test.stopTest();

        assertJobCompleted(jobId);
        System.assertEquals(0, [SELECT COUNT() FROM SalesHistory__c WHERE Id = :oldHistory.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM SalesHistory__c WHERE Id = :recentHistory.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM Sales_History_Line_Item__c WHERE Id = :oldLine.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Sales_History_Line_Item__c WHERE Id = :recentLine.Id]);
    }

    /**
     * @description
     * Verifies {@link TransactionDataBatchCleanup.CleanupStep#QOC_HEADER} deletes old
     * {@link QuotesOrdersCredits_Header__c} parents and cascade-deletes {@link QuoteOrderCredit_Details__c}.
     */
    @IsTest
    static void executeBatch_deletesOldQocHeadersAndDetails() {
        Account acct = newAccount();
        QuotesOrdersCredits_Header__c oldHeader = new QuotesOrdersCredits_Header__c(
            Name = 'QOC-Old-' + uniqueSuffix(),
            Customer__c = acct.Id,
            RecordTypeId = quotesHeaderRecordTypeId(),
            Date__c = olderThanRetention()
        );
        QuotesOrdersCredits_Header__c recentHeader = new QuotesOrdersCredits_Header__c(
            Name = 'QOC-Recent-' + uniqueSuffix(),
            Customer__c = acct.Id,
            RecordTypeId = quotesHeaderRecordTypeId(),
            Date__c = withinRetention()
        );
        insert new List<QuotesOrdersCredits_Header__c>{ oldHeader, recentHeader };

        QuoteOrderCredit_Details__c oldDetail = new QuoteOrderCredit_Details__c(
            Name = 'Det-Old-' + uniqueSuffix(),
            Order_Header__c = oldHeader.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId()
        );
        QuoteOrderCredit_Details__c recentDetail = new QuoteOrderCredit_Details__c(
            Name = 'Det-Recent-' + uniqueSuffix(),
            Order_Header__c = recentHeader.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId()
        );
        insert new List<QuoteOrderCredit_Details__c>{ oldDetail, recentDetail };

        Test.startTest();
        Id jobId = Database.executeBatch(
            new TransactionDataBatchCleanup(TransactionDataBatchCleanup.CleanupStep.QOC_HEADER),
            50
        );
        Test.stopTest();

        assertJobCompleted(jobId);
        System.assertEquals(0, [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :oldHeader.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :recentHeader.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Id = :oldDetail.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Id = :recentDetail.Id]);
    }

    /**
     * @description
     * Verifies {@link TransactionDataBatchCleanup#executeBatch} runs the full chain
     * (Pending Issue → RMA → Sales History → QOC Header) and deletes only old transactional data.
     */
    @IsTest
    static void executeBatch_fullChainDeletesOldTransactionalData() {
        Account acct = newAccount();

        Pending_Issue__c oldIssue = newPendingIssue(acct, olderThanRetention());
        Pending_Issue__c recentIssue = newPendingIssue(acct, withinRetention());
        insert new List<Pending_Issue__c>{ oldIssue, recentIssue };

        RMA__c oldRma = new RMA__c(
            Name = 'RMA-Old-' + uniqueSuffix(),
            Account__c = acct.Id,
            RMA_Date__c = olderThanRetention()
        );
        RMA__c recentRma = new RMA__c(
            Name = 'RMA-Recent-' + uniqueSuffix(),
            Account__c = acct.Id,
            RMA_Date__c = withinRetention()
        );
        insert new List<RMA__c>{ oldRma, recentRma };

        SalesHistory__c oldHistory = new SalesHistory__c(
            Name = 'INV-Old-' + uniqueSuffix(),
            Customer__c = acct.Id,
            Invoice_Date__c = olderThanRetention()
        );
        SalesHistory__c recentHistory = new SalesHistory__c(
            Name = 'INV-Recent-' + uniqueSuffix(),
            Customer__c = acct.Id,
            Invoice_Date__c = withinRetention()
        );
        insert new List<SalesHistory__c>{ oldHistory, recentHistory };

        Sales_History_Line_Item__c oldLine = new Sales_History_Line_Item__c(
            Name = 'Line-Old',
            Sales_History__c = oldHistory.Id
        );
        insert oldLine;

        QuotesOrdersCredits_Header__c oldHeader = new QuotesOrdersCredits_Header__c(
            Name = 'QOC-Old-' + uniqueSuffix(),
            Customer__c = acct.Id,
            RecordTypeId = quotesHeaderRecordTypeId(),
            Date__c = olderThanRetention()
        );
        QuotesOrdersCredits_Header__c recentHeader = new QuotesOrdersCredits_Header__c(
            Name = 'QOC-Recent-' + uniqueSuffix(),
            Customer__c = acct.Id,
            RecordTypeId = quotesHeaderRecordTypeId(),
            Date__c = withinRetention()
        );
        insert new List<QuotesOrdersCredits_Header__c>{ oldHeader, recentHeader };

        QuoteOrderCredit_Details__c oldDetail = new QuoteOrderCredit_Details__c(
            Name = 'Det-Old-' + uniqueSuffix(),
            Order_Header__c = oldHeader.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId()
        );
        insert oldDetail;

        Test.startTest();
        Id jobId = TransactionDataBatchCleanup.executeBatch();
        Test.stopTest();

        assertJobCompleted(jobId);
        System.assertEquals(0, [SELECT COUNT() FROM Pending_Issue__c WHERE Id = :oldIssue.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Pending_Issue__c WHERE Id = :recentIssue.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM RMA__c WHERE Id = :oldRma.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM RMA__c WHERE Id = :recentRma.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM SalesHistory__c WHERE Id = :oldHistory.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM SalesHistory__c WHERE Id = :recentHistory.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM Sales_History_Line_Item__c WHERE Id = :oldLine.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :oldHeader.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :recentHeader.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Id = :oldDetail.Id]);
    }

    /**
     * @description Verifies {@link TransactionDataBatchCleanup#getNextStep} returns the expected sequence.
     */
    @IsTest
    static void getNextStep_returnsExpectedSequence() {
        System.assertEquals(
            TransactionDataBatchCleanup.CleanupStep.RMA,
            TransactionDataBatchCleanup.getNextStep(TransactionDataBatchCleanup.CleanupStep.PENDING_ISSUE)
        );
        System.assertEquals(
            TransactionDataBatchCleanup.CleanupStep.SALES_HISTORY,
            TransactionDataBatchCleanup.getNextStep(TransactionDataBatchCleanup.CleanupStep.RMA)
        );
        System.assertEquals(
            TransactionDataBatchCleanup.CleanupStep.QOC_HEADER,
            TransactionDataBatchCleanup.getNextStep(TransactionDataBatchCleanup.CleanupStep.SALES_HISTORY)
        );
        System.assertEquals(
            null,
            TransactionDataBatchCleanup.getNextStep(TransactionDataBatchCleanup.CleanupStep.QOC_HEADER)
        );
    }

    /**
     * @description Asserts the given {@link AsyncApexJob} completed with no errors.
     * @param jobId Id of the batch job to verify.
     */
    private static void assertJobCompleted(Id jobId) {
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }
}