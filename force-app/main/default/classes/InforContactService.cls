/**
 * @description
 * Service that builds Infor M3 contact requests via CRS618MI.
 *
 * Maps {@link Contact} fields into CRS618MI query parameters and delegates request
 * assembly to {@link InforBaseAPIService#buildRequest()}. Typical action codes are
 * {@code Add} for new contacts and {@code Upd} for updates.
 *
 * This service is created by {@link InforBaseAPIService#createServices(SObject, String, Boolean)}
 * and executed by {@link InforBatchService}.
 *
 * @see InforBaseAPIService
 * @see InforBatchService
 */
public with sharing class InforContactService extends InforBaseAPIService {

    /**
     * @description Creates a contact service for the given record and action.
     * @param record The {@link Contact} record (as SObject).
     * @param actionCode Infor CRS618MI action code (for example, {@code Add} or {@code Upd}).
     * @param multilocationChanged Whether the change is related to multilocation logic.
     */
    public InforContactService(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        super(record, actionCode, multilocationChanged, flowTrigger);
    }

    /**
     * @description Returns the CRS618MI endpoint path with the configured action appended.
     * @return Endpoint path in the form {@code /M3/m3api-rest/v2/execute/CRS618MI/{actionCode}}.
     */
    protected override String getEndpointPath() {
        return '/M3/m3api-rest/v2/execute/CRS618MI/' + actionCode;
    }

    /**
     * @description Returns the HTTP method used for CRS618MI contact requests.
     * @return HTTP method ({@code GET}).
     */
    public override String getHttpMethod() {
        return 'GET';
    }

    /**
     * @description Returns the service name used for logging and {@link PlatformEventLog__c} records.
     * @return Service class name ({@code InforContactService}).
     */
    public override virtual String getClassName() {
        return 'InforContactService';
    }

    /**
     * @description
     * Maps {@link Contact} fields into Infor CRS618MI query parameters.
     *
     * Parameter mapping:
     * - {@code CNPE} — Contact Id
     * - {@code CUNO} — {@code Contact.Account_Number__c}
     * - {@code CONO} — company number ({@code 200})
     * - {@code DIVI} — division ({@code 001})
     * - {@code TX50} — first and last name
     * - {@code TX40} — {@code Contact.Contact_Title__c}
     * - {@code STAT} — {@code 20} when {@code Active__c = 'A'}, otherwise {@code 90}
     * - {@code NAMF} — {@code Contact.FirstName}
     * - {@code NAMS} — {@code Contact.LastName}
     * - {@code EMAL} — {@code Contact.Email}
     * - {@code PHNO} — {@code Contact.Phone}
     * - {@code RFTP} — {@code BUYER} when {@code Buyer__c = 'Y'}, otherwise {@code GENERIC}
     * - {@code GEND} — {@code 1} (Male), {@code 2} (Female), or {@code 3} (other/unset)
     * - {@code LHCD} — language code ({@code GB})
     * - {@code JTIT} — {@code Contact.Ext_Id__c}
     *
     * @return Map of Infor parameter keys and values for CRS618MI.
     */
    public override Map<String, Object> getUrlParameters() {
        Map<String, Object> body = new Map<String, Object>();
        Contact contact = (Contact) this.record;
        body.put('CNPE', contact.Id);
        body.put('CUNO', contact.Account_Number__c);
        body.put('CONO', cono);
        body.put('DIVI', divi);
        body.put('TX50', contact.FirstName + ' ' + contact.LastName);
        body.put('TX40', contact.Contact_Title__c);
        body.put('STAT', contact.Active__c == 'A' ? 20 : 90);
        body.put('NAMF', contact.FirstName);
        body.put('NAMS', contact.LastName);
        body.put('EMAL', contact.Email);
        body.put('PHNO', contact.Phone);
        body.put('RFTP', contact.Buyer__c == 'Y' ? 'BUYER' : 'GENERIC');
        body.put('GEND', contact.GenderIdentity == 'Male' ? 1 : contact.GenderIdentity == 'Female' ? 2 : 3);
        body.put('LHCD', 'GB');
        body.put('JTIT', contact.Ext_Id__c);
        System.debug('request_body: ' + JSON.serialize(body));
        return body;
    }
}