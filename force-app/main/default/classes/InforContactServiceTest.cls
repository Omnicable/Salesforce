/**
 * @description Test class for InforContactService
 */
@isTest
private class InforContactServiceTest {

    private static String makeAccountNumber7() {
        // Account_Number__c must be max length 7 in this org.
        // Format: 'T' + 6 digits (zero-padded).
        Integer raw = Math.abs(Crypto.getRandomInteger());
        String digits = String.valueOf(Math.mod(raw, 1000000)).leftPad(6, '0');
        return 'T' + digits;
    }
    
    @testSetup
    static void setupTestData() {
        // Create ERP Settings
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new ERPSettings__c();
        }
        settings.clientID__c = 'test_client_id';
        settings.clientSecret__c = 'test_client_secret';
        settings.username__c = 'test_username';
        settings.password__c = 'test_password';
        settings.tokenURL__c = 'https://test.example.com/oauth/token';
        settings.baseURL__c = 'https://test.example.com';
        settings.accessToken__c = 'test_access_token';
        settings.tokenExpiration__c = Datetime.now().addHours(1);
        upsert settings;
        
        // Create test Account (Account_Number__c is unique in this org)
        Account testAccount = new Account(
            Name = 'Omni Cable Corporation',
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        insert testAccount;
    }

    private static Contact createValidContact(Account acct, Integer seq, String active, String title) {
        Id potentialDistributorRtId = Schema.SObjectType.Contact.getRecordTypeInfosByName()
            .get('Potential Distributor Contact')
            .getRecordTypeId();

        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com',
            Phone = '555-9876',
            AccountId = acct.Id,
            RecordTypeId = potentialDistributorRtId,
            Sequence__c = seq,
            Active__c = active,
            Contact_Title__c = title,
            Ext_Id__c = acct.Account_Number__c + ':' + String.valueOf(seq)
        );
        insert c;
        return c;
    }
    
    @isTest
    static void testGetEndpointPath() {
        Account testAccount = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact testContact = createValidContact(testAccount, 1, 'A', 'Purchasing Agent');
        InforContactService service = new InforContactService(testContact, 'Add', false, 'ADD_CONTACT');

        HttpRequest req = service.buildRequest();
        System.assert(req.getEndpoint().contains('/M3/m3api-rest/v2/execute/CRS618MI/Add'), 'Endpoint should include CRS618MI/Add');
    }
    
    @isTest
    static void testGetHttpMethod() {
        Account testAccount = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact testContact = createValidContact(testAccount, 2, 'A', 'Purchasing Agent');
        InforContactService service = new InforContactService(testContact, 'Add', false, 'ADD_CONTACT');
        HttpRequest req = service.buildRequest();
        System.assertEquals('GET', req.getMethod(), 'HTTP method should be GET');
    }
    
    @isTest
    static void testGetUrlParameters_CompleteContact() {
        Account testAccount = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact testContact = createValidContact(testAccount, 3, 'A', 'Purchasing Agent');
        InforContactService service = new InforContactService(testContact, 'Add', false, 'ADD_CONTACT');

        Map<String, Object> params = service.getUrlParameters();
        System.assertEquals(testContact.Id, params.get('CNPE'));
        System.assertEquals(testContact.Account_Number__c, params.get('CUNO'));
        System.assertEquals('GET', service.getHttpMethod());
    }
    
    @isTest
    static void testGetUrlParameters_ContactWithActiveStatusA() {
        Account testAccount = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact testContact = createValidContact(testAccount, 4, 'A', 'Purchasing Agent');
        InforContactService service = new InforContactService(testContact, 'Upd', false, 'UPDATE_CONTACT');

        Map<String, Object> params = service.getUrlParameters();
        System.assertEquals(20, params.get('STAT'), 'Active A should map to STAT=20');
    }
    
    @isTest
    static void testGetUrlParameters_ContactWithInactiveStatus() {
        Account testAccount = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact testContact = createValidContact(testAccount, 5, 'D', 'Purchasing Agent');
        InforContactService service = new InforContactService(testContact, 'Upd', false, 'UPDATE_CONTACT');

        Map<String, Object> params = service.getUrlParameters();
        System.assertEquals(90, params.get('STAT'), 'Inactive should map to STAT=90');
    }
    
    @isTest
    static void testConstructor() {
        Account testAccount = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact testContact = createValidContact(testAccount, 6, 'A', 'Purchasing Agent');
        Test.startTest();
        InforContactService service = new InforContactService(testContact, 'Add', false, 'ADD_CONTACT');
        Test.stopTest();
        
        System.assertNotEquals(null, service, 'Service should not be null');
    }
    
    @isTest
    static void testGetUrlParameters_ContactName() {
        Account testAccount = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact testContact = createValidContact(testAccount, 7, 'A', 'Purchasing Agent');
        InforContactService service = new InforContactService(testContact, 'Add', false, 'ADD_CONTACT');

        Map<String, Object> params = service.getUrlParameters();
        System.assertEquals(testContact.FirstName + ' ' + testContact.LastName, params.get('TX50'));
    }
}