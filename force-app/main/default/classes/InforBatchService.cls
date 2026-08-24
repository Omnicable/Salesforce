/**
 * @description
 * Batch runner that executes a list of {@link InforBaseAPIService} request builders as HTTP callouts.
 *
 * For each service in the batch scope, this class:
 * - Builds an {@link HttpRequest} via {@link InforBaseAPIService#buildRequest()}
 * - Sends the callout to Infor M3
 * - Parses the response for {@code nrOfSuccessfullTransactions} and {@code nrOfFailedTransactions}
 * - Creates a {@link PlatformEventLog__c} record for each callout (success or failure)
 * - Inserts accumulated log records at the end of {@link #execute(Database.BatchableContext, List)}
 *
 * A response is treated as an error when the HTTP status is not {@code 200} or when
 * {@code nrOfFailedTransactions} is greater than zero.
 *
 * @see InforBaseAPIService
 * @see InforIntegrationService
 * @see PlatformEventLog__c
 */
public with sharing class InforBatchService implements Database.Batchable<InforBaseAPIService>, Database.AllowsCallouts, Database.Stateful {
    
    /** @description Infor services to execute, supplied at construction time. */
    private List<InforBaseAPIService> services = new List<InforBaseAPIService>();
    /** @description Log records accumulated during {@link #execute(Database.BatchableContext, List)}. */
    private List<PlatformEventLog__c> logs = new List<PlatformEventLog__c>();
    
    /** @description Contact report record to be inserted at the end of the batch. */
    private OmniSync_Contact_Report__c contactReport = new OmniSync_Contact_Report__c( Name = 'Infor Batch Service', Error__c = false);
    
    /**
     * @description Creates a batch job for the given list of Infor services.
     * @param services Ordered list of {@link InforBaseAPIService} instances to execute.
     */
    public InforBatchService(List<InforBaseAPIService> services) {
        this.services = services;
    }
    
    /**
     * @description Returns the services to process in this batch job.
     * @param bc Batch context provided by the platform.
     * @return Iterable of {@link InforBaseAPIService} items passed to {@link #execute(Database.BatchableContext, List)}.
     */
    public Iterable<InforBaseAPIService> start(Database.BatchableContext bc) {
        return services;
    }
    
    /**
     * @description
     * Executes Infor callouts for each service in the current batch scope.
     *
     * For each service:
     * - Sends the HTTP request built by the service
     * - Deserializes the JSON response body
     * - Sets {@link PlatformEventLog__c#Has_Error__c} based on HTTP status and failed transaction count
     * - Stores the source record JSON in {@link PlatformEventLog__c#Record__c}
     * - Stores the raw response body in {@link PlatformEventLog__c#JSONData__c}
     *
     * Inserts all accumulated log records when at least one log exists in the scope.
     *
     * @param bc Batch context provided by the platform.
     * @param scope Current chunk of {@link InforBaseAPIService} instances to process.
     */
    public void execute(Database.BatchableContext bc, List<InforBaseAPIService> scope) {
        
        try{
            
            for (InforBaseAPIService service : scope) {
                
                Contact contact = (Contact) service.record;
                contactReport.Name = contact.FirstName + ' ' + contact.LastName;
                System.debug('contact: ' + contact);
                contactReport.Flow__c = service.flowTrigger;
                contactReport.Contact__c = contact.Id;
                
                HttpRequest req = service.buildRequest();
                Http http = new Http();
                HttpResponse res = http.send(req);
                System.debug('res: ' + res.getStatusCode());
                System.debug('res body: ' + res.getBody());
                
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Integer nrOfSuccessfullTransactions = (Integer)responseBody.get('nrOfSuccessfullTransactions');
                Integer nrOfFailedTransactions = (Integer)responseBody.get('nrOfFailedTransactions');
                
                PlatformEventLog__c log = new PlatformEventLog__c();
                log.Name = service.getClassName();
                log.Action_Code__c = service.actionCode;
                sObject obj = service.record;
                log.Record__c = JSON.serialize(obj);
                log.JSONData__c = res.getBody();
                log.Flow__c = service.flowTrigger;
                
                if((res.getStatusCode() == null || res.getStatusCode() != 200 || nrOfFailedTransactions > 0) && (service.flowTrigger != 'UPDATE_CONTACT' && service.actionCode != 'Add')) {
                    log.Has_Error__c = true;
                    contactReport.Error__c  = true;
                } else{
                    log.Has_Error__c = false;
                    
                }
                logs.add(log);
            }
            
        }catch(Exception e){
            System.debug('error: ' + e.getMessage());
            System.debug('error stack: ' + e.getStackTraceString());
            
            PlatformEventLog__c log = new PlatformEventLog__c();
            log.Name = 'InforBatchService';
            log.Has_Error__c = true;
            log.JSONData__c = JSON.serialize(e.getMessage());
            log.Flow__c = 'InforBatchService';
            logs.add(log);
        }
        
    }
    
    /**
     * @description Batch completion hook. Log persistence is handled in {@link #execute(Database.BatchableContext, List)}.
     * @param bc Batch context provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        insert contactReport;
        if(logs.size() > 0) {
            for(PlatformEventLog__c log : logs) {
                log.OmniSync_Contact_Report__c = contactReport.Id;
            }
            insert logs;
        }
    }
}