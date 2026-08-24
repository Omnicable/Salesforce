public with sharing class InforContactConnectService extends InforBaseAPIService {

    // public InforContactConnectService(SObject record, String actionCode) {
    //     super(record, actionCode);
    // }
    
    public InforContactConnectService(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        super(record, actionCode, multilocationChanged, flowTrigger);
    }
    
    /**
     * @description Get the endpoint path for Contact operations
     */
    protected override String getEndpointPath() {
        return '/M3/m3api-rest/v2/execute/CMS055MI/' + actionCode;
    }
    
    /**
     * @description Get the HTTP method for Contact operations
     */
    protected override String getHttpMethod() {
        return 'GET';
    }
    
    /**
     * @description Get the class name for Contact operations
     */
    public override virtual String getClassName() {
        return 'InforContactConnectService';
    }
    
    protected override Map<String, Object> getUrlParameters() {
        Map<String, Object> body = new Map<String, Object>();
        Contact contact = (Contact) this.record;
        System.debug('contact: ' + JSON.serialize(contact));
        body.put('CNPE', contact.Id);
        body.put('CUNO', contact.Account_Number__c);
        body.put('RFTP', contact.Buyer__c == 'Y' ? 'BUYER' : 'GENERIC');
        body.put('CONO', cono);
        body.put('DIVI', divi);
        System.debug('request_body: ' + JSON.serialize(body));
        return body;
    }
    
    
    

    
}