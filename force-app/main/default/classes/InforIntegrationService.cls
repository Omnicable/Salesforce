/**
 * @description
 * Invocable entry point for launching Infor M3 integrations from Salesforce Flow.
 *
 * For each input payload, this service:
 * - Ensures a valid OAuth token is available via {@link InforAuthService#getAccessToken()}
 * - Builds the ordered list of {@link InforBaseAPIService} request builders through
 *   {@link InforBaseAPIService#createServices(SObject, String, Boolean)}
 * - Starts {@link InforBatchService} with batch size {@code 1} to execute callouts
 * - Returns the resulting AsyncApexJob Id to the Flow caller
 *
 * During unit tests, batch execution is skipped and {@code null} is returned for each input
 * so that callout and batch behavior can be covered in dedicated test classes.
 *
 * @see InforAuthService
 * @see InforBaseAPIService
 * @see InforBatchService
 */
public with sharing class InforIntegrationService {

    @TestVisible
    private static Boolean throwExceptionForTest = false;
    
    /**
     * @description
     * Invocable method used by Flow to start Infor processing for one or more records.
     *
     * Each input starts a separate {@link InforBatchService} job containing the services
     * returned by {@link InforBaseAPIService#createServices(SObject, String, Boolean)}.
     *
     * @param inputs List of Flow input payloads containing the source record, action code,
     *               and multilocation flag.
     * @return List of AsyncApexJob Ids, one per input. In test context each entry is {@code null}.
     */
    @InvocableMethod(label='Infor Callout BOD' description='Calls the Infor BOD API')
    public static List<ID> imsCallout(List<InforIMSmsg> inputs) {
        
        List<ID> results = new List<Id>();
        OmniSync_Contact_Report__c contactReport = new OmniSync_Contact_Report__c( Name = 'InforIntegrationService', Error__c = true);
        InforIMSmsg currentInput;
        
        try{
            
            // Ensure a valid access token exists before starting batch work.
            InforAuthService authService = new InforAuthService();
            String accessToken = InforAuthService.getAccessToken();
            List<PlatformEventLog__c> logRecords = new List<PlatformEventLog__c>();
            for (InforIMSmsg input : inputs) {
                currentInput = input;
                if (Test.isRunningTest() && throwExceptionForTest) {
                    throw new CalloutException('Forced test exception');
                }
                List<InforBaseAPIService> services = InforBaseAPIService.createServices(input.record, input.actionCode, input.multilocationChanged);
                System.debug('services: ' + JSON.serialize(services));
                if (Test.isRunningTest()) {
                    // Avoid Database.executeBatch() limitations during unit tests.
                    // Batch execution is covered separately in InforBatchServiceTest.
                    results.add(null);
                } else {
                    Id jobID = Database.executeBatch(new InforBatchService(services), 1);
                    results.add(jobID);
                }
                
            }
            
        }catch(Exception e){
            System.debug('Error: ' + e.getMessage());
                
            if(currentInput != null  && currentInput.record != null && currentInput.record instanceof Contact){
                Contact contact = (Contact) currentInput.record;
                contactReport.Name = contact.FirstName + ' ' + contact.LastName;
                contactReport.Flow__c = currentInput.actionCode;
                contactReport.Contact__c = contact.Id;
            }

            insert contactReport;

            PlatformEventLog__c log = new PlatformEventLog__c( Name = 'InforIntegrationService', Has_Error__c = true, JSONData__c = e.getMessage() + ' ' + e.getStackTraceString());
            log.OmniSync_Contact_Report__c = contactReport.Id;
            insert log;
        }
        
        
        return results;
        
    }
    
    /**
     * @description Input payload for {@link #imsCallout(List)} invocable Flow actions.
     */
    public class InforIMSmsg {
        
        /** @description Salesforce record that triggered the Infor integration. */
        @InvocableVariable
        public SObject record;
        
        /** @description High-level action code passed to {@link InforBaseAPIService#createServices(SObject, String, Boolean)}. */
        @InvocableVariable
        public String actionCode;
        
        /** @description Whether the triggering change is related to multilocation logic. */
        @InvocableVariable
        public Boolean multilocationChanged;
    }
    
}