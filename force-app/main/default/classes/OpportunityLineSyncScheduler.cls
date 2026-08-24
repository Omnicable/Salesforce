/**
 * @description Schedulable entry that runs {@link OpportunityDetailSyncBatch} when no detail sync batch
 *              is already queued or running.
 */
public without sharing class OpportunityLineSyncScheduler implements Schedulable {
    private static final String DETAIL_BATCH_CLASS_NAME = 'OpportunityDetailSyncBatch';
    private static final Set<String> PENDING_JOB_STATUSES = new Set<String>{
        'Holding',
        'Queued',
        'Preparing',
        'Processing'
    };

    public void execute(SchedulableContext sc) {
        if (hasPendingDetailSyncBatch()) {
            System.debug(
                LoggingLevel.INFO,
                'OpportunityLineSyncScheduler: skip; ' + DETAIL_BATCH_CLASS_NAME + ' already pending or running'
            );
            return;
        }
        Database.executeBatch(new OpportunityDetailSyncBatch(), 500);
    }

    @TestVisible
    private static Boolean hasPendingDetailSyncBatch() {
        List<AsyncApexJob> jobs = [
            SELECT Id, CreatedDate
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
                AND ApexClass.Name = :DETAIL_BATCH_CLASS_NAME
                AND Status IN :PENDING_JOB_STATUSES
            LIMIT 1
        ];
        if (jobs.isEmpty()) {
            return false;
        }
        AsyncApexJob job = jobs[0];
        if (job.CreatedDate < Datetime.now().addHours(-1)) {
            System.abortJob(job.Id);
            return false;
        }
        return true;
    }
}