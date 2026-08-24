/**
 * @author Chris Williams <chrisw@launchdm.com>
 * @group Yearly Cleanup
 * @since 2026-07-16
 * @description
 * Batch job that deletes transactional data older than three years, in dependency order.
 *
 * Steps (each is a separate batch job; {@link #finish} chains to the next):
 * <ol>
 *   <li>{@link Pending_Issue__c} — {@code Disposition_Date__c} or {@code CreatedDate}</li>
 *   <li>{@link RMA__c} — {@code RMA_Date__c} or {@code CreatedDate}</li>
 *   <li>{@link SalesHistory__c} — {@code Invoice_Date__c} or {@code CreatedDate}</li>
 *   <li>{@link QuotesOrdersCredits_Header__c} — {@code Date__c} or {@code CreatedDate}</li>
 * </ol>
 *
 * Master-detail children are removed by cascade delete:
 * - {@link Sales_History_Line_Item__c} when {@link SalesHistory__c} is deleted
 * - {@link QuoteOrderCredit_Details__c} when {@link QuotesOrdersCredits_Header__c} is deleted
 *
 * Not {@link Database.Stateful}; step context is passed via constructor when chaining.
 *
 * @see TransactionDataBatchCleanupTest
 */
public with sharing class TransactionDataBatchCleanup implements Database.Batchable<SObject> {

    /**
     * @description Ordered cleanup phases for transactional objects.
     */
    public enum CleanupStep {
        /** @description Delete old {@link Pending_Issue__c} records. */
        PENDING_ISSUE,
        /** @description Delete old {@link RMA__c} records. */
        RMA,
        /** @description Delete old {@link SalesHistory__c} records (and line items by cascade). */
        SALES_HISTORY,
        /** @description Delete old {@link QuotesOrdersCredits_Header__c} records (and details by cascade). */
        QOC_HEADER
    }

    /** @description Number of years of data to retain. */
    private static final Integer RETENTION_YEARS = 2;
    /** @description Default {@link Database#executeBatch} scope size. */
    private static final Integer DEFAULT_BATCH_SIZE = 500;

    /** @description Current object phase for this batch job instance. */
    private CleanupStep currentStep;

    /**
     * @description Creates a batch that starts at {@link CleanupStep#PENDING_ISSUE}.
     */
    public TransactionDataBatchCleanup() {
        this(CleanupStep.PENDING_ISSUE);
    }

    /**
     * @description Creates a batch for a specific cleanup phase (used when chaining steps).
     * @param step The {@link CleanupStep} this job should process.
     */
    @TestVisible
    private TransactionDataBatchCleanup(CleanupStep step) {
        currentStep = step;
    }

    /**
     * @description Enqueues the full cleanup chain beginning at {@link CleanupStep#PENDING_ISSUE}.
     * @return The {@link AsyncApexJob} Id from {@link Database#executeBatch}.
     */
    public static Id executeBatch() {
        return Database.executeBatch(new TransactionDataBatchCleanup(), DEFAULT_BATCH_SIZE);
    }

    /**
     * @description Returns a query locator for records in the current step that are older than retention.
     * @param bc Batch context provided by the platform.
     * @return Query locator selecting {@code Id} for the current {@link CleanupStep}.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        switch on currentStep {
            when PENDING_ISSUE {
                return Database.getQueryLocator([
                    SELECT Id
                    FROM Pending_Issue__c
                    WHERE Disposition_Date__c < LAST_N_YEARS:2 OR LastModifiedDate < LAST_N_YEARS:2 ORDER BY Disposition_Date__c ASC
                ]);
            }
            when RMA {
                return Database.getQueryLocator([
                    SELECT Id
                    FROM RMA__c
                    WHERE RMA_Date__c < LAST_N_YEARS:2 OR LastModifiedDate < LAST_N_YEARS:2 ORDER BY RMA_Date__c ASC
                ]);
            }
            when SALES_HISTORY {
                return Database.getQueryLocator([
                    SELECT Id
                    FROM SalesHistory__c
                    WHERE Invoice_Date__c < LAST_N_YEARS:2 OR LastModifiedDate < LAST_N_YEARS:2 ORDER BY Customer__c ASC
                ]);
            }
            when QOC_HEADER {
                return Database.getQueryLocator([
                    SELECT Id
                    FROM QuotesOrdersCredits_Header__c
                    WHERE Date__c < LAST_N_YEARS:2 OR LastModifiedDate < LAST_N_YEARS:2 ORDER BY Customer__c ASC
                ]);
            }
        }
        return Database.getQueryLocator([SELECT Id FROM Account WHERE Id = null]);
    }

    /**
     * @description Deletes the current batch of records using partial success ({@code allOrNone = false}).
     * @param bc Batch context provided by the platform.
     * @param scope Records to delete for this execute chunk.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Database.DeleteResult[] results = Database.delete(scope, false);
        for (Database.DeleteResult result : results) {
            if (result.isSuccess()) {
                continue;
            }
            for (Database.Error err : result.getErrors()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'TransactionDataBatchCleanup [' + String.valueOf(currentStep) + '] delete failed for ' +
                    result.getId() + ': ' + err.getMessage()
                );
            }
        }
    }

    /**
     * @description Chains the next {@link CleanupStep} as a new batch job when one remains.
     * @param bc Batch context provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        CleanupStep nextStep = getNextStep(currentStep);
        if (nextStep == null) {
            return;
        }
        Database.executeBatch(new TransactionDataBatchCleanup(nextStep), DEFAULT_BATCH_SIZE);
    }

    /**
     * @description Returns the next step in the cleanup sequence, or {@code null} when complete.
     * @param step The step that just finished.
     * @return The next {@link CleanupStep}, or {@code null} after {@link CleanupStep#QOC_HEADER}.
     */
    @TestVisible
    private static CleanupStep getNextStep(CleanupStep step) {
        switch on step {
            when PENDING_ISSUE {
                return CleanupStep.RMA;
            }
            when RMA {
                return CleanupStep.SALES_HISTORY;
            }
            when SALES_HISTORY {
                return CleanupStep.QOC_HEADER;
            }
            when QOC_HEADER {
                return null;
            }
        }
        return null;
    }
}