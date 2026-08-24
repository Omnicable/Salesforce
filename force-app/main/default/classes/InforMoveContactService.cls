/**
 * @description
 * Service that builds requests used in the "move contact" flow.
 *
 * This service targets CMS055MI connection actions for moving a contact from one
 * account to another based on a {@link Cases_Requests__c} record.
 */
public with sharing class InforMoveContactService  extends InforBaseAPIService{
    /**
     * @description Creates a move-contact service.
     * @param record The {@link Cases_Requests__c} record (as SObject).
     * @param actionCode Infor action code (e.g., AddConnection, DeleteConnect).
     */
    // public InforMoveContactService(SObject record, String actionCode) {
    //     super(record, actionCode);
    // }
    
    /**
     * @description Creates a move-contact service with multilocation context.
     * @param record The {@link Cases_Requests__c} record (as SObject).
     * @param actionCode Infor action code (e.g., AddConnection, DeleteConnect).
     * @param multilocationChanged Whether multilocation logic applies.
     */
    public InforMoveContactService(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        super(record, actionCode, multilocationChanged, flowTrigger);
    }
    
    /**
     * @description Gets the endpoint path for CMS055MI with action appended.
     * @return Endpoint path.
     */
    protected override String getEndpointPath() {
        return '/M3/m3api-rest/v2/execute/CMS055MI/' + actionCode;
    }
    
    /**
     * @description Gets the HTTP method for this service.
     * @return HTTP method (GET).
     */
    protected override String getHttpMethod() {
        return 'GET';
    }
    
    /**
     * @description Gets a friendly service name for logging.
     * @return Service name.
     */
    public override virtual String getClassName() {
            return 'InforMoveContactService';
        }
    
    /**
     * @description
     * Builds Infor query parameters for moving a contact by inspecting related records.
     *
     * @return Map of Infor parameter keys/values for the configured action.
     */
    protected override Map<String, Object> getUrlParameters() {
        Map<String, Object> body = new Map<String, Object>();
        Cases_Requests__c caseRequest = (Cases_Requests__c) this.record;
        
        Contact contact = [SELECT Id, Buyer__c, Account.Account_Number__c FROM Contact WHERE Id = :caseRequest.Contact__c LIMIT 1];
        Account oldAccount = [SELECT Id, Account_Number__c FROM Account WHERE Id = :caseRequest.Account_Name2__c LIMIT 1];
        Account newAccount = [SELECT Id, Account_Number__c FROM Account WHERE Id = :caseRequest.Move_to_Account__c LIMIT 1];

        System.debug('caseRequest: ' + JSON.serialize(caseRequest));
        System.debug('contact: ' + JSON.serialize(contact));
        System.debug('actionCode: ' + actionCode);
        
        if(actionCode == 'addConnection'){
            body.put('CNPE', caseRequest.Contact__c);
            body.put('CUNO', newAccount.Account_Number__c);
            body.put('RFTP', contact.Buyer__c == 'Y' ? 'BUYER' : 'GENERIC');
            body.put('CONO', cono);
            body.put('DIVI', divi);
            System.debug('request_body_add: ' + JSON.serialize(body));
            return body;
            
        }else{
            body.put('CNPE', caseRequest.Contact__c);
            body.put('CUNO', oldAccount.Account_Number__c);
            body.put('CONO', cono);
            body.put('DIVI', divi);
            body.put('RFTP', contact.Buyer__c == 'Y' ? 'BUYER' : 'GENERIC');
            System.debug('request_body_delete: ' + JSON.serialize(body));
            return body;
            
        }
    
    }
    
}