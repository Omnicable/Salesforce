/**
 * @description
 * Abstract base class for building Infor M3 API requests.
 *
 * Subclasses supply the endpoint path, HTTP method, and URL/query parameters for a
 * specific Infor program (for example, CRS618MI or CMS055MI). This class provides
 * shared orchestration and request-building utilities:
 * - Factory method {@link #createServices(SObject, String, Boolean)} for contact integration flows
 * - {@link #buildRequest()} to assemble a fully qualified {@link HttpRequest}
 * - Query-string encoding via {@link #buildQueryString(Map)}
 *
 * Callouts are not sent from this class directly. {@link InforBatchService} calls
 * {@link #buildRequest()} on each service and executes the HTTP request.
 *
 * @see InforBatchService
 * @see InforAuthService
 * @see InforContactService
 * @see InforContactConnectService
 * @see InforUserDefinedFieldsService
 * @see InforUserDefinedFieldServiceOBCUA8
 * @see InforMoveContactService
 */
public abstract without sharing class InforBaseAPIService {

    /** @description Source record being integrated to Infor. */
    public SObject record;
    /** @description Infor action code for this request (for example, {@code Add} or {@code Upd}). */
    public String actionCode;
    /** @description Whether the triggering change is related to multilocation logic. */
    protected Boolean multilocationChanged;
    /** @description Default Infor company number ({@code CONO}) applied to request parameters. */
    protected Integer cono = 200;
    /** @description Default Infor division ({@code DIVI}) applied to request parameters. */
    protected String divi = '001';

    public String flowTrigger;

    @TestVisible private static Boolean testSimulateActiveChanged = false;
    @TestVisible private static Boolean testSimulateBuyerChanged = false;
    @TestVisible private static Boolean testSimulateFirstNameChanged = false;
    @TestVisible private static Boolean testSimulateLastNameChanged = false;
    @TestVisible private static Boolean testSimulateExtIdChanged = false;
    @TestVisible private static String testOldBuyer;
    @TestVisible private static String testOldExtId;
    @TestVisible private static String testOldFirstName;
    @TestVisible private static String testOldLastName;
    /** @description When false (default), {@link #syncService(Id)} skips {@link Database#executeBatch} in tests. */
    @TestVisible private static Boolean executeBatchInTest = false;

    @TestVisible
    private static void resetTestHistoryFlags() {
        testSimulateActiveChanged = false;
        testSimulateBuyerChanged = false;
        testSimulateFirstNameChanged = false;
        testSimulateLastNameChanged = false;
        testSimulateExtIdChanged = false;
        testOldBuyer = null;
        testOldExtId = null;
        testOldFirstName = null;
        testOldLastName = null;
    }

    /**
     * @description Creates a service for the given record and action with multilocation context.
     * @param record The SObject the service is operating on.
     * @param actionCode The Infor action code (for example, {@code Add}, {@code Upd}, {@code DeleteConnect}).
     * @param multilocationChanged Whether the change is related to multilocation logic.
     */
    public InforBaseAPIService(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        this.actionCode = actionCode;
        this.record = record;
        this.multilocationChanged = multilocationChanged;
        this.flowTrigger = flowTrigger;
    }

    /**
     * @description
     * Factory that creates the ordered list of Infor services to run for a record and action.
     *
     * Evaluates contact and move-request flows:
     * - {@code Add} on {@link Contact} — contact create, UDF values, and connection services
     * - {@code Delete} on {@link Contact} — contact update and connection delete services
     * - {@code Upd} on {@link Contact} — contact update plus conditional UDF/connection services
     * - {@code AddConnection} on {@link Cases_Requests__c} — move-contact flow (future development)
     *
     * @param record The record to integrate.
     * @param actionCode The high-level action code driving orchestration.
     * @param multilocationChanged Whether the change is related to multilocation logic.
     * @return Ordered list of {@link InforBaseAPIService} instances to execute.
     */
    public static List<InforBaseAPIService> createServices(SObject record, String actionCode, Boolean multilocationChanged) {
        List<InforBaseAPIService> services = new List<InforBaseAPIService>();
        services.addAll(newContactFlow(record, actionCode, multilocationChanged, 'ADD_CONTACT'));
        services.addAll(deletedContactFlow(record, actionCode, multilocationChanged, 'DELETE_CONTACT'));
        services.addAll(updatedContactFlow(record, actionCode, multilocationChanged, 'UPDATE_CONTACT'));
        //services.addAll(moveContactFlow(record, actionCode, multilocationChanged, 'MOVE_CONTACT'));
        return services;
    }

    /**
     * @description
     * Builds the ordered Infor sync chain used for a full contact re-sync (add, update,
     * reconnect, and UDF reset/re-add).
     *
     * @param record Contact record to sync.
     * @return Ordered list of {@link InforBaseAPIService} instances for {@link InforBatchService}.
     */
    public static List<InforBaseAPIService> syncService(SObject record) {
        List<InforBaseAPIService> services = new List<InforBaseAPIService>();

        InforBaseAPIService addService = new InforContactService(record, 'Add', false, 'SYNC_CONTACT');
        services.add(addService);

        InforBaseAPIService updateService = new InforContactService(record, 'Upd', false, 'SYNC_CONTACT');
        services.add(updateService);

        InforContactConnectService deleteConnectService = new InforContactConnectService(record, 'DeleteConnect', false, 'SYNC_CONTACT');
        services.add(deleteConnectService);

        InforUserDefinedFieldsService deleteOBCUA7 = new InforUserDefinedFieldsService(record, 'DltValue', false, 'SYNC_CONTACT');
        services.add(deleteOBCUA7);

        InforUserDefinedFieldServiceOBCUA8 deleteOBCUA8 = new InforUserDefinedFieldServiceOBCUA8(record, 'DltValue', false, 'SYNC_CONTACT');
        services.add(deleteOBCUA8);

        InforUserDefinedFieldsService addOBCUA7 = new InforUserDefinedFieldsService(record, 'AddValue', false, 'SYNC_CONTACT');
        services.add(addOBCUA7);

        InforUserDefinedFieldServiceOBCUA8 addOBCUA8 = new InforUserDefinedFieldServiceOBCUA8(record, 'AddValue', false, 'SYNC_CONTACT');
        services.add(addOBCUA8);

        InforContactConnectService addConnectService = new InforContactConnectService(record, 'AddConnection', false, 'SYNC_CONTACT');
        services.add(addConnectService);

        return services;
    }

    /**
     * @description
     * Lightning entry point that loads a Contact, builds the {@link #syncService(SObject)} chain,
     * ensures an Infor access token, and starts {@link InforBatchService}.
     *
     * @param contactId Id of the Contact to sync to Infor.
     * @return Async Apex job Id for the started batch.
     */
    @AuraEnabled
    public static Id syncService(Id contactId) {
        try {
            if (contactId == null) {
                throw new AuraHandledException('Contact Id is required.');
            }

            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, Email, Phone, Buyer__c, Ext_Id__c,
                       Contact_Title__c, Active__c, Account_Number__c, GenderIdentity,
                       AccountId, Sequence__c, ParentSequence__c
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            if (contacts.isEmpty()) {
                throw new AuraHandledException('Contact was not found.');
            }

            InforAuthService.getAccessToken();
            List<InforBaseAPIService> services = syncService(contacts[0]);
            if (services.isEmpty()) {
                throw new AuraHandledException('No Infor sync services were generated for this contact.');
            }

            if (Test.isRunningTest() && !executeBatchInTest) {
                // Avoid callout batch execution during unit tests; covered by InforBatchServiceTest.
                return contacts[0].Id;
            }

            return Database.executeBatch(new InforBatchService(services), 1);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Builds services for the contact-created integration flow.
     * @param record Source record.
     * @param actionCode High-level action code.
     * @param multilocationChanged Multilocation context flag.
     * @return Services to run when a contact is added.
     */
    private static List<InforBaseAPIService> newContactFlow(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        List<InforBaseAPIService> services = new List<InforBaseAPIService>();

        if(record.getSObjectType() == Schema.Contact.SObjectType && actionCode == 'Add') {
            InforBaseAPIService service = new InforContactService(record, actionCode, multilocationChanged, flowTrigger);
            services.add(service);

            InforUserDefinedFieldsService userDefinedFieldsService = new InforUserDefinedFieldsService(record, 'AddValue', multilocationChanged, flowTrigger);
            services.add(userDefinedFieldsService);

            InforUserDefinedFieldServiceOBCUA8 userDefinedFieldsService2 = new InforUserDefinedFieldServiceOBCUA8(record, 'AddValue', multilocationChanged, flowTrigger);
            services.add(userDefinedFieldsService2);

            InforContactConnectService connectService = new InforContactConnectService(record, 'AddConnection', multilocationChanged, flowTrigger);
            services.add(connectService);
        }

        return services;
    }

    /**
     * @description Builds services for the contact-deleted integration flow.
     * @param record Source record.
     * @param actionCode High-level action code.
     * @param multilocationChanged Multilocation context flag.
     * @return Services to run when a contact is deleted.
     */
    private static List<InforBaseAPIService> deletedContactFlow(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        List<InforBaseAPIService> services = new List<InforBaseAPIService>();
        if(record.getSObjectType() == Schema.Contact.SObjectType && actionCode == 'Delete'){
            Contact contact = (Contact) record;
            contact.Active__c = 'D';

            InforBaseAPIService updateContactService = new InforContactService(record, 'Upd', multilocationChanged, flowTrigger);
            services.add(updateContactService);

            InforContactConnectService deleteConnectService = new InforContactConnectService(record, 'DeleteConnect', multilocationChanged, flowTrigger);
            services.add(deleteConnectService);

        }

        return services;
    }

    /**
     * @description
     * Builds services for the contact-updated integration flow.
     *
     * Uses recent {@link ContactHistory} entries to determine whether name, active status,
     * buyer, or account changes require additional UDF or connection services.
     *
     * @param record Source record.
     * @param actionCode High-level action code.
     * @param multilocationChanged Multilocation context flag.
     * @return Services to run when a contact is updated.
     */
    private static List<InforBaseAPIService> updatedContactFlow(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        List<InforBaseAPIService> services = new List<InforBaseAPIService>();
        if (record.getSObjectType() == Schema.Contact.SObjectType && actionCode == 'Upd') {
            System.debug('Infor Contact Updated Flow');
            Contact contact = (Contact) record;
            Contact oldContact = contact.clone(true, true, true, true);

            DateTime timeDiff = System.now().addSeconds(-20);
            Boolean firstNameChanged = false;
            Boolean lastNameChanged = false;
            Boolean activeChanged = false;
            Boolean buyerChanged = false;
            Boolean accountNumberChanged = false;


            for(ContactHistory change : [
                SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name
                FROM ContactHistory
                WHERE ContactId = :contact.Id
                    AND (Field = 'Active__c' OR Field = 'Buyer__c' OR Field = 'FirstName' OR Field = 'LastName' OR Field = 'Ext_Id__c')
                    AND CreatedDate >= :timeDiff
                ORDER BY CreatedDate DESC
            ]) {
                if(change.Field == 'Active__c' && activeChanged == false) {
                    activeChanged = true;
                    // contact.Active__c = (String)change.OldValue;
                }
                if(change.Field == 'Buyer__c' && buyerChanged == false) {
                    buyerChanged = true;
                    oldContact.Buyer__c = (String)change.OldValue;
                }
                if(change.Field == 'Ext_Id__c' && accountNumberChanged == false) {
                    accountNumberChanged = true;
                    String extId = String.valueOf(change?.OldValue ?? null); // "null" string if null — then treat "null"/blank
                    if (extId == null || extId == 'null' || String.isBlank(extId)) {
                        extId = null;
                    }


                    String accountNumber = extId != null ? extId.split(':')[0] : null;
                    Map<String, Object> oldContactMap = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(oldContact));
                    
                    if (accountNumber != null && extId != null) {
                        oldContactMap.put('Account_Number__c', accountNumber);
                        oldContactMap.put('Ext_Id__c', extId);
                    }
                    
                    oldContact = (Contact)JSON.deserialize(JSON.serialize(oldContactMap), Contact.class);
                }

                if(change.Field == 'FirstName' &&  firstNameChanged == false) {
                    firstNameChanged = true;
                    oldContact.FirstName = (String)change.OldValue;
                }
                if(change.Field == 'LastName' &&  lastNameChanged == false) {
                    lastNameChanged = true;
                    oldContact.LastName = (String)change.OldValue;
                }
            }

            if (Test.isRunningTest()) {
                if (testSimulateActiveChanged) {
                    activeChanged = true;
                }
                if (testSimulateBuyerChanged) {
                    buyerChanged = true;
                    oldContact.Buyer__c = testOldBuyer;
                }
                if (testSimulateExtIdChanged) {
                    accountNumberChanged = true;
                    String extId = testOldExtId;
                    String accountNumber = extId != null ? extId.split(':')[0] : null;
                    Map<String, Object> oldContactMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(oldContact));
                    oldContactMap.put('Account_Number__c', accountNumber);
                    oldContactMap.put('Ext_Id__c', extId);
                    oldContact = (Contact) JSON.deserialize(JSON.serialize(oldContactMap), Contact.class);
                }
                if (testSimulateFirstNameChanged) {
                    firstNameChanged = true;
                    oldContact.FirstName = testOldFirstName;
                }
                if (testSimulateLastNameChanged) {
                    lastNameChanged = true;
                    oldContact.LastName = testOldLastName;
                }
            }

            System.debug('firstNameChanged: ' + firstNameChanged);
            System.debug('lastNameChanged: ' + lastNameChanged);
            System.debug('activeChanged: ' + activeChanged);
            System.debug('buyerChanged: ' + buyerChanged);
            System.debug('accountNumberChanged: ' + accountNumberChanged);


            /** Add Contact prely as a redundant step to ensure that the contact is added to Infor */
            InforBaseAPIService addContact = new InforContactService(record, 'Add', multilocationChanged, flowTrigger);
            services.add(addContact);

            /** Update Contact to ensure that the contact is updated in Infor */
            InforBaseAPIService updateContactService = new InforContactService(record, actionCode, multilocationChanged, flowTrigger);
            services.add(updateContactService);


            if(!activeChanged && (String)record.get('Active__c') == 'D') {
                /** Do nothing because contact is still deactivated */
                System.debug('Infor Contact Deactivated Flow');
            }else if(activeChanged && (String)record.get('Active__c') == 'D') {
                /** Deactivate contact */
                System.debug('Infor Contact Deleted Flow');
                InforContactConnectService connectService = new InforContactConnectService(oldContact, 'DeleteConnect', multilocationChanged, flowTrigger);
                services.add(connectService);

                InforUserDefinedFieldsService deleteOBCUA7 = new InforUserDefinedFieldsService(oldContact, 'DltValue', multilocationChanged, flowTrigger);
                services.add(deleteOBCUA7);

                InforUserDefinedFieldServiceOBCUA8 deleteOBCUA8 = new InforUserDefinedFieldServiceOBCUA8(oldContact, 'DltValue', multilocationChanged, flowTrigger);
                services.add(deleteOBCUA8);

                
            }else if(activeChanged && (String)record.get('Active__c') == 'A') {
                /** Reactivate contact */
                System.debug('Infor Contac tActive__c change');

                InforContactConnectService connectService = new InforContactConnectService(record, 'AddConnection', multilocationChanged, flowTrigger);
                services.add(connectService);

                InforUserDefinedFieldsService addOBCUA7 = new InforUserDefinedFieldsService(record, 'AddValue', multilocationChanged, flowTrigger);
                services.add(addOBCUA7);

                InforUserDefinedFieldServiceOBCUA8 addOBCUA8 = new InforUserDefinedFieldServiceOBCUA8(record, 'AddValue', multilocationChanged, flowTrigger);
                services.add(addOBCUA8);

            } else{

                if(firstNameChanged || lastNameChanged || accountNumberChanged) {

                    InforUserDefinedFieldsService deleteOBCUA7 = new InforUserDefinedFieldsService(oldContact, 'DltValue', multilocationChanged, flowTrigger);
                    services.add(deleteOBCUA7);
    
                    InforUserDefinedFieldServiceOBCUA8 deleteOBCUA8 = new InforUserDefinedFieldServiceOBCUA8(oldContact, 'DltValue', multilocationChanged, flowTrigger);
                    services.add(deleteOBCUA8);
    
                    InforUserDefinedFieldsService updateOBCUA7 = new InforUserDefinedFieldsService(record, 'AddValue', multilocationChanged, flowTrigger);
                    services.add(updateOBCUA7);
    
                    InforUserDefinedFieldServiceOBCUA8 updateOBCUA8 = new InforUserDefinedFieldServiceOBCUA8(record, 'AddValue', multilocationChanged, flowTrigger);
                    services.add(updateOBCUA8);
                }

                if(buyerChanged || accountNumberChanged) {

                    if(oldContact.Ext_Id__c != null) {
                        InforContactConnectService deleteService = new InforContactConnectService(oldContact, 'DeleteConnect', multilocationChanged, flowTrigger);
                        services.add(deleteService);
                    }
               
                    InforContactConnectService addService = new InforContactConnectService(record, 'AddConnection', multilocationChanged, flowTrigger);
                    services.add(addService);
                }

            }

        }

        return services;
    }

    /**
     * @description
     * Builds services for the move-contact integration flow.
     *
     * Reserved for future development when {@link Cases_Requests__c} move requests
     * trigger {@link InforMoveContactService} callouts.
     *
     * @param record Source record.
     * @param actionCode High-level action code.
     * @param multilocationChanged Multilocation context flag.
     * @return Services to run for move-contact requests.
     */
    private static List<InforBaseAPIService> moveContactFlow(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
        List<InforBaseAPIService> services = new List<InforBaseAPIService>();
        if (record.getSObjectType() == Schema.Cases_Requests__c.SObjectType && actionCode == 'AddConnection') {
            System.debug('Infor Move Contact Flow');
            // System.debug('Infor Move Contact Flow');
            // InforBaseAPIService service = new InforMoveContactService(record, actionCode, multilocationChanged, flowTrigger);
            // services.add(service);

            // InforBaseAPIService nextServicce = new InforMoveContactService(record, 'DeleteConnect', multilocationChanged, flowTrigger);
            // services.add(nextServicce);

            // System.debug('InforMoveContactService Finished with out next action and moving contact to new account');
            // moveContact((Cases_Requests__c)record);

        }
        return services;
    }

    /**
     * @description
     * Builds an {@link HttpRequest} for this service using org-default {@link ERPSettings__c}.
     *
     * Request composition:
     * - Endpoint: {@code baseURL__c} + {@link #getEndpointPath()} + encoded query string
     * - Method: {@link #getHttpMethod()}
     * - Authorization: Bearer token from {@link InforAuthService#getTokenFields(ERPSettings__c)}
     * - Headers: {@code Accept}, {@code Accept-Encoding}, {@code Connection}
     *
     * @return Configured {@link HttpRequest} ready to be sent by {@link InforBatchService}.
     */
    public virtual HttpRequest buildRequest() {

        System.debug('record_data: ' + JSON.serialize(record));

        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        String accessToken = InforAuthService.getTokenFields(settings);

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        // Build endpoint with URL parameters
        String endpointPath = getEndpointPath();
        Map<String, Object> urlParams = getUrlParameters();
        String queryString = buildQueryString(urlParams);
        String fullEndpoint = settings.baseURL__c + endpointPath + queryString;

        req.setEndpoint(fullEndpoint);
        req.setMethod(getHttpMethod());

        // Set default headers
        req.setHeader('Accept',  '*/*');
        req.setHeader('Accept-Encoding',  'gzip, deflate, br');
        req.setHeader('Connection',  'keep-alive');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        return req;
    }

    /**
     * @description Returns the Infor endpoint path appended to {@link ERPSettings__c#baseURL__c}.
     * @return Endpoint path beginning with {@code /}.
     */
    protected abstract String getEndpointPath();

    /**
     * @description Returns the HTTP method for the Infor request.
     * @return HTTP method string (for example, {@code GET} or {@code POST}).
     */
    protected abstract String getHttpMethod();

    /**
     * @description Returns a human-readable service name for logging and {@link PlatformEventLog__c} records.
     * @return Service class name.
     */
    public virtual String getClassName() {
        return 'InforBaseAPIService';
    }

    /**
     * @description
     * Returns URL/query parameters to encode onto the endpoint.
     *
     * Subclasses override this method to map Salesforce field values into Infor parameter keys.
     * Null and blank values are omitted during encoding by {@link #buildQueryString(Map)}.
     *
     * @return Map of parameter name/value pairs.
     */
    protected virtual Map<String, Object> getUrlParameters() {
        return new Map<String, Object>();
    }

    /**
     * @description
     * Builds a URL-encoded query string from a parameter map.
     *
     * @param params Map of parameter name/value pairs.
     * @return Query string prefixed with {@code ?}, or an empty string when no usable params exist.
     */
    public String buildQueryString(Map<String, Object> params) {
        if (params == null || params.isEmpty()) {
            return '';
        }

        List<String> paramPairs = new List<String>();

        for (String key : params.keySet()) {
            String encodedParam = encodeParameter(key, params.get(key));
            if (String.isNotBlank(encodedParam)) {
                paramPairs.add(encodedParam);
            }
        }

        return paramPairs.isEmpty() ? '' : '?' + String.join(paramPairs, '&');
    }

    /**
     * @description URL-encodes a single query-string parameter.
     * @param key Parameter name.
     * @param valueObj Parameter value.
     * @return Encoded {@code key=value} pair, or an empty string when the key or value is not usable.
     */
    private String encodeParameter(String key, Object valueObj) {
        if (String.isBlank(key) || valueObj == null) {
            return '';
        }

        String value = String.valueOf(valueObj);
        if (String.isBlank(value) || value == 'null') {
            return '';
        }

        return EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(value, 'UTF-8');
    }

    /**
     * @description
     * Moves the {@link Contact} referenced by a move request to the target account.
     *
     * Updates:
     * - {@code Contact.AccountId} to {@code caseRequest.Move_to_Account__c}
     * - Clears {@code Contact.Sequence__c}
     * - Clears {@code Contact.Ext_Id__c}
     *
     * @param caseRequest Move request containing {@code Contact__c} and {@code Move_to_Account__c}.
     */
    public static void moveContact(Cases_Requests__c caseRequest) {
        System.debug('Moving contact to new account: caseRequest: ' + JSON.serialize(caseRequest));
        Contact contact = new Contact(Id = caseRequest.Contact__c);
        contact.AccountId = caseRequest.Move_to_Account__c;
        contact.Sequence__c = null;
        contact.Ext_Id__c = null;
        system.debug('contact: ' + JSON.serialize(contact));
        update contact;
    }

    /**
     * @description Exception thrown when Infor API request construction or execution fails.
     */
    public class InforAPIException extends Exception {}

}