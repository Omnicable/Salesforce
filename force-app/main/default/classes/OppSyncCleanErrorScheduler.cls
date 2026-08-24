/**
 * @description Schedulable entry that runs {@link OpportunityHeaderSyncBatch} when no header sync batch
 *              is already queued or running.
 */
public class OppSyncCleanErrorScheduler implements Schedulable {
    private static final String HEADER_BATCH_CLASS_NAME = 'OppSyncCleanErrorHandler';
    private static final Set<String> PENDING_JOB_STATUSES = new Set<String>{
        'Holding',
        'Queued',
        'Preparing',
        'Processing'
    };

    public OppSyncCleanErrorScheduler() {
    }

    public void execute(SchedulableContext sc) {
        if (hasPendingHeaderSyncBatch()) {
            System.debug(
                LoggingLevel.INFO,
                'OppSyncCleanErrorScheduler: skip; ' + HEADER_BATCH_CLASS_NAME + ' already pending or running'
            );
            return;
        }
        Database.executeBatch(new OppSyncCleanErrorHandler(), 100);
    }

    @TestVisible
    private static Boolean hasPendingHeaderSyncBatch() {
        List<AsyncApexJob> jobs = [
            SELECT Id, CreatedDate
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
                AND ApexClass.Name = :HEADER_BATCH_CLASS_NAME
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