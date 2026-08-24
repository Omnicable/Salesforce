/**
 * @description
 * Service that builds requests for updating Infor user-defined fields via CMS083MI (OBCUA7).
 *
 * This service maps a Contact's full name into the required CMS083MI parameters.
 */
public with sharing class InforUserDefinedFieldsService extends InforBaseAPIService {

    /**
     * @description Creates a UDF service for the given record/action with multilocation context.
     * @param record The {@link Contact} record (as SObject).
     * @param actionCode Infor action code (e.g., AddValue, DltValue).
     * @param multilocationChanged Whether multilocation logic applies.
     */
    public InforUserDefinedFieldsService(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        super(record, actionCode, multilocationChanged, flowTrigger);
    }
    
    /**
     * @description Gets the endpoint path for CMS083MI with action appended.
     * @return Endpoint path.
     */
    protected override String getEndpointPath() {
        return '/M3/m3api-rest/v2/execute/CMS083MI/' + actionCode;
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
        return 'InforUserDefinedFieldsService';
    }
    
    /**
     * @description Maps Contact fields into Infor query parameters for OBCUA7.
     * @return Map of Infor parameter keys/values.
     */
    protected override Map<String, Object> getUrlParameters() {
        Map<String, Object> body = new Map<String, Object>();
        Contact contact = (Contact) this.record;
        String fullName = contact.FirstName.toUpperCase() + ' ' + contact.LastName.toUpperCase();
        String extId = contact.Ext_Id__c;
        // List<Contact> foundContacts = [Select Id, FirstName, LastName, Ext_Id__c from Contact where Id = :contact.Id];
        // if(foundContacts.size() > 0) {
        //     extId = foundContacts[0].Ext_Id__c;
        // }

        body.put('FILE', 'OOHEAD');
        body.put('FLDI', 'OAUCA7');
        body.put('AL20', extId.length() > 20 ? extId.substring(0, 20) : extId);
        body.put('TX40', fullName.length() > 40 ? fullName.substring(0, 40) : fullName);
        body.put('CONO', cono);
        body.put('DIVI', divi);
        System.debug('request_body: ' + JSON.serialize(body));
        return body;
    }

    
}