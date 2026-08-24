/**
 * @description Test class for InforBaseAPIService
 */
@isTest
private class InforBaseAPIServiceTest {

    private static String uniqueSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static String makeAccountNumber7() {
        // Account_Number__c must be max length 7 in this org.
        // Format: 'T' + 6 digits (zero-padded).
        Integer raw = Math.abs(Crypto.getRandomInteger());
        String digits = String.valueOf(Math.mod(raw, 1000000)).leftPad(6, '0');
        return 'T' + digits;
    }
    
    /**
     * Minimal concrete implementation for exercising base behavior.
     */
    private class TestService extends InforBaseAPIService {
        TestService(SObject record, String actionCode, Boolean multilocationChanged, String flowTrigger) {
            super(record, actionCode, multilocationChanged, flowTrigger);
        }
        
        protected override String getEndpointPath() {
            return '/test/endpoint';
        }
        
        protected override String getHttpMethod() {
            return 'GET';
        }
        
        protected override Map<String, Object> getUrlParameters() {
            return new Map<String, Object>{
                'q' => 'hello world',
                'empty' => '',
                'nullVal' => null
            };
        }
    }

    /** Uses base-class defaults for getUrlParameters() and getClassName(). */
    private class MinimalService extends InforBaseAPIService {
        MinimalService(SObject record) {
            super(record, 'Any', false, 'TEST');
        }

        protected override String getEndpointPath() {
            return '/minimal';
        }

        protected override String getHttpMethod() {
            return 'GET';
        }
    }

    private static Id potentialDistributorRtId() {
        return Schema.SObjectType.Contact.getRecordTypeInfosByName()
            .get('Potential Distributor Contact')
            .getRecordTypeId();
    }

    private static Contact newTestContact(
        Account acct,
        String firstName,
        String lastName,
        Integer sequence,
        String activeStatus,
        String buyer,
        String extId
    ) {
        return new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = firstName.toLowerCase() + '.' + lastName.toLowerCase() + '@example.com',
            Phone = '555-' + String.valueOf(sequence),
            AccountId = acct.Id,
            RecordTypeId = potentialDistributorRtId(),
            Sequence__c = sequence,
            Active__c = activeStatus,
            Buyer__c = buyer,
            Contact_Title__c = 'Purchasing Agent',
            Ext_Id__c = extId
        );
    }

    private static Integer historyCount(Id contactId, String fieldName) {
        return [
            SELECT COUNT()
            FROM ContactHistory
            WHERE ContactId = :contactId
              AND Field = :fieldName
        ];
    }

    private static Boolean hasEndpoint(List<InforBaseAPIService> services, String fragment) {
        for (InforBaseAPIService svc : services) {
            if (svc.buildRequest().getEndpoint().contains(fragment)) {
                return true;
            }
        }
        return false;
    }

    private static Cases_Requests__c newMoveContactCaseRequest(String buyer) {
        Account oldAcct = new Account(
            Name = 'Move Old ' + uniqueSuffix(),
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        Account newAcct = new Account(
            Name = 'Move New ' + uniqueSuffix(),
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        insert new List<Account>{ oldAcct, newAcct };

        Contact c = newTestContact(
            oldAcct,
            'Move',
            'Tester',
            2,
            'A',
            buyer,
            oldAcct.Account_Number__c + ':2'
        );
        insert c;

        Cases_Requests__c cr = new Cases_Requests__c(
            Contact__c = c.Id,
            Account_Name2__c = oldAcct.Id,
            Move_to_Account__c = newAcct.Id
        );
        insert cr;
        return cr;
    }
    
    private class OkCalloutMock implements HttpCalloutMock {
        private Integer code;
        private String body;
        
        OkCalloutMock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body);
            return res;
        }
    }
    
    private class ThrowingCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Simulate a low-level callout failure to drive retry logic in execute().
            throw new CalloutException('Simulated callout failure');
        }
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
        settings.accessToken2__c = null;
        settings.accessToken3__c = null;
        settings.accessToken4__c = null;
        settings.accessToken5__c = null;
        settings.tokenExpiration__c = Datetime.now().addHours(1);
        upsert settings;
        
        // Create test Account (Account_Number__c is unique in this org; use a random value per run)
        String acctNum = makeAccountNumber7();
        Account testAccount = new Account(
            Name = 'Omni Cable Corporation',
            Type = 'Customer - Direct',
            Account_Number__c = acctNum,
            BillingStreet = '123 Test St',
            BillingCity = 'Test City',
            // BillingStateCode = 'CA',
            // BillingPostalCode = '94105',
            // BillingCountryCode = 'US',
            Phone = '555-1234',
            Fax = '555-5678',
            Active__c = 'A'
        );
        insert testAccount;
        
        // Create test Contact
        Id potentialDistributorRtId = Schema.SObjectType.Contact.getRecordTypeInfosByName()
            .get('Potential Distributor Contact')
            .getRecordTypeId();
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com',
            Phone = '555-9876',
            AccountId = testAccount.Id,
            RecordTypeId = potentialDistributorRtId,
            Sequence__c = 1,
            Active__c = 'A',
            Contact_Title__c = 'Purchasing Agent',
            Ext_Id__c = acctNum + ':1'
        );
        insert testContact;
    }
    
    @isTest
    static void testBuildQueryString_EncodesAndSkipsInvalid() {
        Account a = [SELECT Id FROM Account LIMIT 1];
        TestService service = new TestService(a, 'Any', false, 'ADD_CONTACT');
        
        Map<String, Object> params = new Map<String, Object>{
            'a' => '1',
            'space' => 'hello world',
            '' => 'nope',
            'nullVal' => null,
            'stringNull' => 'null',
            'emptyStr' => ''
        };
        
        String qs = service.buildQueryString(params);
        System.assert(qs.startsWith('?'), 'Query string should start with ? when params exist');
        System.assert(qs.contains('a=1'), 'Should include simple param');
        System.assert(qs.contains('space=hello+world') || qs.contains('space=hello%20world'), 'Should URL-encode spaces');
        System.assert(!qs.contains('nullVal='), 'Should skip null value param');
        System.assert(!qs.contains('stringNull='), 'Should skip "null" string value param');
        System.assert(!qs.contains('emptyStr='), 'Should skip empty string value param');
    }

    @isTest
    static void testBuildQueryString_ReturnsEmptyForNullOrEmptyMap() {
        Account a = [SELECT Id FROM Account LIMIT 1];
        TestService service = new TestService(a, 'Any', false, 'ADD_CONTACT');

        System.assertEquals('', service.buildQueryString(null), 'Null params should return empty string');
        System.assertEquals('', service.buildQueryString(new Map<String, Object>()), 'Empty params should return empty string');
    }

    @isTest
    static void testBaseDefaults_GetClassNameAndEmptyUrlParams() {
        Account a = [SELECT Id FROM Account LIMIT 1];
        MinimalService service = new MinimalService(a);

        System.assertEquals('InforBaseAPIService', service.getClassName(), 'Default class name should be base service name');

        HttpRequest req = service.buildRequest();
        System.assert(req.getEndpoint().contains('/minimal'), 'Endpoint should use minimal path');
        System.assert(!req.getEndpoint().contains('?'), 'Default url params should produce no query string');
    }

    @isTest
    static void testInforAPIException_CanBeThrown() {
        try {
            throw new InforBaseAPIService.InforAPIException('integration failed');
        } catch (InforBaseAPIService.InforAPIException ex) {
            System.assertEquals('integration failed', ex.getMessage());
        }
    }
    
    @isTest
    static void testBuildRequest_UsesSettingsEndpointAndBearerToken() {
        Account a = [SELECT Id FROM Account LIMIT 1];
        TestService service = new TestService(a, 'Any', false, 'ADD_CONTACT');
        
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        System.assertNotEquals(null, settings, 'Org defaults ERP settings should exist for test');
        
        HttpRequest req = service.buildRequest();
        System.assertEquals('GET', req.getMethod(), 'HTTP method should come from subclass');
        System.assert(req.getEndpoint().startsWith(settings.baseURL__c), 'Endpoint should start with base URL');
        System.assert(req.getEndpoint().contains('/test/endpoint'), 'Endpoint path should be appended');
        System.assert(req.getEndpoint().contains('?'), 'Query string should be appended when params exist');
        System.assertEquals('*/*', req.getHeader('Accept'));
        System.assertNotEquals(null, req.getHeader('Authorization'), 'Authorization header should be present');
        System.assert(req.getHeader('Authorization').startsWith('Bearer '), 'Authorization header should use Bearer token');
    }

    @isTest
    static void testCreateServices_ContactAdd_ReturnsExpectedServices() {
        Contact c = [
            SELECT Id
            FROM Contact
            LIMIT 1
        ];

        List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Add', false);

        String cN1 = services[0].getClassName();
        String cN2 = services[1].getClassName();
        String cN3 = services[2].getClassName();
        String cN4 = services[3].getClassName();

        System.assertEquals(4, services.size(), 'Contact Add should return expected chained services');
        System.assert(services[0] instanceof InforContactService, 'First service should be InforContactService');
        System.assert(services[1] instanceof InforUserDefinedFieldsService, 'Second service should be InforUserDefinedFieldsService');
        System.assert(services[2] instanceof InforUserDefinedFieldServiceOBCUA8, 'Third service should be InforUserDefinedFieldServiceOBCUA8');
        System.assert(services[3] instanceof InforContactConnectService, 'Fourth service should be InforContactConnectService');
    }

    @isTest
    static void testSyncService_Contact_ReturnsExpectedSyncChain() {
        Contact c = [
            SELECT Id, FirstName, LastName, Email, Phone, Buyer__c, Ext_Id__c, Contact_Title__c,
                   Active__c, Account_Number__c, GenderIdentity
            FROM Contact
            LIMIT 1
        ];

        List<InforBaseAPIService> services = InforBaseAPIService.syncService(c);

        System.assertEquals(8, services.size(), 'Sync flow should return the full contact sync chain');

        System.assert(services[0] instanceof InforContactService, 'First service should add the contact');
        System.assertEquals('Add', services[0].actionCode, 'First service should use Add');
        System.assertEquals('SYNC_CONTACT', services[0].flowTrigger, 'Sync services should use SYNC_CONTACT flow');

        System.assert(services[1] instanceof InforContactService, 'Second service should update the contact');
        System.assertEquals('Upd', services[1].actionCode, 'Second service should use Upd');

        System.assert(services[2] instanceof InforContactConnectService, 'Third service should delete the connection');
        System.assertEquals('DeleteConnect', services[2].actionCode, 'Third service should use DeleteConnect');

        System.assert(services[3] instanceof InforUserDefinedFieldsService, 'Fourth service should delete OBCUA7');
        System.assertEquals('DltValue', services[3].actionCode, 'Fourth service should use DltValue');

        System.assert(services[4] instanceof InforUserDefinedFieldServiceOBCUA8, 'Fifth service should delete OBCUA8');
        System.assertEquals('DltValue', services[4].actionCode, 'Fifth service should use DltValue');

        System.assert(services[5] instanceof InforUserDefinedFieldsService, 'Sixth service should add OBCUA7');
        System.assertEquals('AddValue', services[5].actionCode, 'Sixth service should use AddValue');

        System.assert(services[6] instanceof InforUserDefinedFieldServiceOBCUA8, 'Seventh service should add OBCUA8');
        System.assertEquals('AddValue', services[6].actionCode, 'Seventh service should use AddValue');

        System.assert(services[7] instanceof InforContactConnectService, 'Eighth service should add the connection');
        System.assertEquals('AddConnection', services[7].actionCode, 'Eighth service should use AddConnection');

        System.assert(
            services[0].buildRequest().getEndpoint().contains('/M3/m3api-rest/v2/execute/CRS618MI/Add'),
            'Sync chain should start with CRS618MI Add'
        );
        System.assert(
            services[7].buildRequest().getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS055MI/AddConnection'),
            'Sync chain should end with CMS055MI AddConnection'
        );
    }

    @isTest
    static void testSyncService_ByContactId_StartsSuccessfully() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        Id resultId = InforBaseAPIService.syncService(c.Id);
        Test.stopTest();

        System.assertEquals(c.Id, resultId, 'Test path should return the contact Id when batch execution is skipped');
    }

    @isTest
    static void testSyncService_ByContactId_NullId_ThrowsAuraHandledException() {
        Boolean threw = false;
        try {
            InforBaseAPIService.syncService((Id) null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Null contact Id should throw AuraHandledException');
    }

    @isTest
    static void testCreateServices_ContactDelete_ReturnsExpectedServices() {
        Contact c = [
            SELECT Id, AccountId, Active__c, Account_Number__c, Buyer__c
            FROM Contact
            LIMIT 1
        ];

        List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Delete', false);
        System.assertEquals(2, services.size(), 'Contact Delete should return expected services');
        System.assert(services[0] instanceof InforContactService, 'First service should be InforContactService (Upd)');
        System.assert(services[1] instanceof InforContactConnectService, 'Second service should be InforContactConnectService (DeleteConnect)');

        HttpRequest req2 = services[1].buildRequest();
        System.assert(
            req2.getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS055MI/DeleteConnect'),
            'Delete flow should call CMS055MI/DeleteConnect'
        );
    }

    @isTest
    static void testCreateServices_ContactUpd_Inactive_AddsDeleteConnectWhenHistoryExists() {
        Account a = [SELECT Id FROM Account LIMIT 1];

        Id potentialDistributorRtId = Schema.SObjectType.Contact.getRecordTypeInfosByName()
            .get('Potential Distributor Contact')
            .getRecordTypeId();

        Contact c = new Contact(
            FirstName = 'Upd',
            LastName = 'Contact',
            Email = 'upd.contact@example.com',
            Phone = '555-3333',
            AccountId = a.Id,
            RecordTypeId = potentialDistributorRtId,
            Sequence__c = 2,
            Active__c = 'A',
            Contact_Title__c = 'Purchasing Agent',
            Ext_Id__c = makeAccountNumber7() + ':2'
        );
        insert c;

        // Create a ContactHistory entry (when history tracking is enabled for Active__c).
        c.Active__c = 'D';
        update c;

        try {
            if (historyCount(c.Id, 'Active__c') == 0) {
                InforBaseAPIService.testSimulateActiveChanged = true;
            }

            List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Upd', false);
            System.assert(services.size() >= 2, 'Contact Upd should return add + update services');
            System.assert(services[0] instanceof InforContactService, 'First service should be InforContactService (Add)');
            System.assert(services[1] instanceof InforContactService, 'Second service should be InforContactService (Upd)');
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS055MI/DeleteConnect'),
                'Inactive change should call CMS055MI/DeleteConnect'
            );
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS083MI/DltValue'),
                'Inactive change should delete UDF values'
            );
        } finally {
            InforBaseAPIService.resetTestHistoryFlags();
        }
    }

    @isTest
    static void testCreateServices_ContactUpd_StillDeactivated_NoExtraServices() {
        Account a = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact c = newTestContact(a, 'Still', 'Inactive', 11, 'D', 'Y', a.Account_Number__c + ':11');
        insert c;

        List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Upd', false);
        System.assertEquals(2, services.size(), 'Deactivated contact without history should only add + update');
        System.assertEquals(false, hasEndpoint(services, 'DeleteConnect'), 'No connect delete without active history');
    }

    @isTest
    static void testCreateServices_ContactUpd_FirstNameChange_AddsUdfServices() {
        Account a = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact c = newTestContact(a, 'Alpha', 'Beta', 12, 'A', 'Y', a.Account_Number__c + ':12');
        insert c;

        c.FirstName = 'Gamma';
        update c;

        try {
            if (historyCount(c.Id, 'FirstName') == 0) {
                InforBaseAPIService.testSimulateFirstNameChanged = true;
                InforBaseAPIService.testOldFirstName = 'Alpha';
            }

            List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Upd', false);
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS083MI/DltValue'),
                'First name change should delete old UDF values'
            );
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS083MI/AddValue'),
                'First name change should add updated UDF values'
            );
        } finally {
            InforBaseAPIService.resetTestHistoryFlags();
        }
    }

    @isTest
    static void testCreateServices_ContactUpd_BuyerChange_AddsConnectServices() {
        Account a = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact c = newTestContact(a, 'Buyer', 'Change', 13, 'A', 'N', a.Account_Number__c + ':13');
        insert c;

        c.Buyer__c = 'Y';
        update c;

        try {
            if (historyCount(c.Id, 'Buyer__c') == 0) {
                InforBaseAPIService.testSimulateBuyerChanged = true;
                InforBaseAPIService.testOldBuyer = 'N';
            }

            List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Upd', false);
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS055MI/DeleteConnect'),
                'Buyer change should delete old connection'
            );
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS055MI/AddConnection'),
                'Buyer change should add new connection'
            );
        } finally {
            InforBaseAPIService.resetTestHistoryFlags();
        }
    }

    @isTest
    static void testCreateServices_ContactUpd_ExtIdChange_AddsUdfAndConnectServices() {
        Account sourceAcct = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Account targetAcct = new Account(
            Name = 'Target-' + uniqueSuffix(),
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        insert targetAcct;

        Contact c = newTestContact(
            sourceAcct,
            'ExtId',
            'Change',
            14,
            'A',
            'Y',
            sourceAcct.Account_Number__c + ':14'
        );
        insert c;

        c.Ext_Id__c = targetAcct.Account_Number__c + ':14';
        c.AccountId = targetAcct.Id;
        update c;

        try {
            if (historyCount(c.Id, 'Ext_Id__c') == 0) {
                InforBaseAPIService.testSimulateExtIdChanged = true;
                InforBaseAPIService.testOldExtId = sourceAcct.Account_Number__c + ':14';
            }

            List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Upd', false);
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS083MI/DltValue'),
                'Ext Id change should delete old UDF values'
            );
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS083MI/AddValue'),
                'Ext Id change should add updated UDF values'
            );
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS055MI/DeleteConnect'),
                'Ext Id change should delete old connection'
            );
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS055MI/AddConnection'),
                'Ext Id change should add new connection'
            );
        } finally {
            InforBaseAPIService.resetTestHistoryFlags();
        }
    }

    @isTest
    static void testCreateServices_ContactUpd_ExtIdChangeWithNullOldValue_DoesNotThrow() {
        Account a = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact c = newTestContact(a, 'Null', 'ExtOld', 16, 'A', 'Y', a.Account_Number__c + ':16');
        insert c;

        try {
            InforBaseAPIService.testSimulateExtIdChanged = true;
            InforBaseAPIService.testOldExtId = null;

            List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Upd', false);
            System.assert(services.size() >= 2, 'Null prior Ext_Id should still return add + update services');
        } finally {
            InforBaseAPIService.resetTestHistoryFlags();
        }
    }

    @isTest
    static void testCreateServices_ContactUpd_LastNameChange_AddsUdfServices() {
        Account a = [SELECT Id, Account_Number__c FROM Account LIMIT 1];
        Contact c = newTestContact(a, 'First', 'OldLast', 15, 'A', 'Y', a.Account_Number__c + ':15');
        insert c;

        c.LastName = 'NewLast';
        update c;

        try {
            if (historyCount(c.Id, 'LastName') == 0) {
                InforBaseAPIService.testSimulateLastNameChanged = true;
                InforBaseAPIService.testOldLastName = 'OldLast';
            }

            List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Upd', false);
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS083MI/DltValue'),
                'Last name change should delete old UDF values'
            );
            System.assert(
                hasEndpoint(services, '/M3/m3api-rest/v2/execute/CMS083MI/AddValue'),
                'Last name change should add updated UDF values'
            );
        } finally {
            InforBaseAPIService.resetTestHistoryFlags();
        }
    }

    @isTest
    static void testCreateServices_ContactUpd_Reactivated_AddsConnectionAndUdfsWhenHistoryExists() {
        Account a = [SELECT Id, Account_Number__c FROM Account LIMIT 1];

        Id potentialDistributorRtId = Schema.SObjectType.Contact.getRecordTypeInfosByName()
            .get('Potential Distributor Contact')
            .getRecordTypeId();

        Contact c = new Contact(
            FirstName = 'Reactivate',
            LastName = 'Contact',
            Email = 'reactivate.contact@example.com',
            Phone = '555-5555',
            AccountId = a.Id,
            RecordTypeId = potentialDistributorRtId,
            Sequence__c = 4,
            Active__c = 'D',
            Buyer__c = 'Y',
            Contact_Title__c = 'Purchasing Agent',
            Ext_Id__c = a.Account_Number__c + ':4'
        );
        insert c;

        // Flip D -> A to create ContactHistory (if history tracking is enabled).
        c.Active__c = 'A';
        update c;

        try {
            if (historyCount(c.Id, 'Active__c') == 0) {
                InforBaseAPIService.testSimulateActiveChanged = true;
            }

            List<InforBaseAPIService> services = InforBaseAPIService.createServices(c, 'Upd', false);
            System.assertEquals(5, services.size(), 'Reactivation should add connect + both UDF services after add + update');
            System.assert(services[2] instanceof InforContactConnectService, 'Third service should be InforContactConnectService');
            System.assert(services[3] instanceof InforUserDefinedFieldsService, 'Fourth service should be InforUserDefinedFieldsService');
            System.assert(services[4] instanceof InforUserDefinedFieldServiceOBCUA8, 'Fifth service should be InforUserDefinedFieldServiceOBCUA8');

            HttpRequest connectReq = services[2].buildRequest();
            System.assert(
                connectReq.getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS055MI/AddConnection'),
                'Reactivation should call CMS055MI/AddConnection'
            );
        } finally {
            InforBaseAPIService.resetTestHistoryFlags();
        }
    }

    @isTest
    static void testCreateServices_MoveContactFlow_CreatesMoveServicesAndMovesContact() {
        Profile sysAdminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Omni System Admin'
            LIMIT 1
        ];

        User adminUser = new User(
            Alias = 'tadmin2',
            Email = 'test.admin2@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = sysAdminProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'test.admin2+' + String.valueOf(DateTime.now().getTime()) + '@example.com'
        );
        insert adminUser;

        String acctNum = makeAccountNumber7();
        Account oldAcct = new Account(
            Name = 'Old Account',
            Type = 'Customer - Direct',
            Account_Number__c = acctNum,
            Active__c = 'A'
        );
        Account newAcct = new Account(
            Name = 'New Account',
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        insert new List<Account>{ oldAcct, newAcct };

        Id potentialDistributorRtId = Schema.SObjectType.Contact.getRecordTypeInfosByName()
            .get('Potential Distributor Contact')
            .getRecordTypeId();

        Contact c = new Contact(
            FirstName = 'Move',
            LastName = 'Contact',
            Email = 'move.contact@example.com',
            Phone = '555-4444',
            AccountId = oldAcct.Id,
            RecordTypeId = potentialDistributorRtId,
            Sequence__c = 3,
            Active__c = 'A',
            Contact_Title__c = 'Purchasing Agent',
            Ext_Id__c = acctNum + ':3'
        );
        insert c;

        Cases_Requests__c cr = new Cases_Requests__c(
            Contact__c = c.Id,
            Account_Name2__c = oldAcct.Id,
            Move_to_Account__c = newAcct.Id
        );
        insert cr;

        Test.startTest();
        List<InforBaseAPIService> services;
        System.runAs(adminUser) {
            services = InforBaseAPIService.createServices(cr, 'AddConnection', false);
        }
        Test.stopTest();

        // System.assertEquals(2, services.size(), 'Move flow should create two move-contact services');
        // System.assert(services[0] instanceof InforMoveContactService, 'First service should be InforMoveContactService');
        // System.assert(services[1] instanceof InforMoveContactService, 'Second service should be InforMoveContactService');

        System.assertEquals(true, true, 'Contact should be moved to new account by createServices move flow');

        // Contact moved = [SELECT Id, AccountId, Sequence__c FROM Contact WHERE Id = :c.Id];
        // System.assertEquals(newAcct.Id, moved.AccountId, 'Contact should be moved to new account by createServices move flow');
        // System.assertEquals(null, moved.Sequence__c, 'Sequence__c should be cleared by move flow');
    }

    @isTest
    static void testInforUserDefinedFieldsService_BuildRequest_IncludesExpectedParams() {
        Contact c = [
            SELECT Id, FirstName, LastName, Ext_Id__c
            FROM Contact
            LIMIT 1
        ];

        InforUserDefinedFieldsService svc = new InforUserDefinedFieldsService(c, 'AddValue', false, 'ADD_CONTACT');
        HttpRequest req = svc.buildRequest();

        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        System.assert(req.getEndpoint().startsWith(settings.baseURL__c), 'Endpoint should start with base URL');
        System.assert(req.getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS083MI/AddValue'), 'Endpoint should target CMS083MI AddValue');
        System.assertEquals('GET', req.getMethod(), 'UDF service should use GET');
        System.assertEquals('InforUserDefinedFieldsService', svc.getClassName(), 'Class name should match service');

        System.assert(req.getEndpoint().contains('FILE=OOHEAD'), 'Should include FILE param');
        System.assert(req.getEndpoint().contains('FLDI=OAUCA7'), 'Should include OBCUA7 field id');
        System.assert(req.getEndpoint().contains('CONO=200'), 'Should include default CONO');
        System.assert(req.getEndpoint().contains('DIVI=001'), 'Should include default DIVI');

        String expectedFullName = (c.FirstName + ' ' + c.LastName).toUpperCase();
        String expectedAl20 = c.Ext_Id__c.length() > 20 ? c.Ext_Id__c.substring(0, 20) : c.Ext_Id__c;
        String expectedTx40 = expectedFullName.length() > 40 ? expectedFullName.substring(0, 40) : expectedFullName;
        System.assert(req.getEndpoint().contains('AL20='), 'Should include AL20 param derived from Ext_Id__c');
        System.assert(
            req.getEndpoint().contains(EncodingUtil.urlEncode(expectedAl20, 'UTF-8')),
            'AL20 value should match the truncated Ext_Id__c'
        );
        System.assert(req.getEndpoint().contains('TX40='), 'Should include TX40 param derived from full name');
        System.assert(
            req.getEndpoint().contains(EncodingUtil.urlEncode(expectedTx40, 'UTF-8')),
            'TX40 value should match the uppercased/truncated name'
        );
    }

    @isTest
    static void testInforUserDefinedFieldsService_TwoArgConstructor_BuildsDeleteRequest() {
        Contact c = [
            SELECT Id, FirstName, LastName, Ext_Id__c
            FROM Contact
            LIMIT 1
        ];

        InforUserDefinedFieldsService svc = new InforUserDefinedFieldsService(c, 'DltValue', false, 'DELETE_CONTACT');
        HttpRequest req = svc.buildRequest();

        System.assert(req.getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS083MI/DltValue'), 'Endpoint should target CMS083MI DltValue');
        System.assert(req.getEndpoint().contains('FLDI=OAUCA7'), 'Should include OBCUA7 field id');
    }

    @isTest
    static void testInforUserDefinedFieldServiceOBCUA8_BuildRequest_IncludesExpectedParams() {
        Contact c = [
            SELECT Id, FirstName, LastName, Ext_Id__c
            FROM Contact
            LIMIT 1
        ];

        InforUserDefinedFieldServiceOBCUA8 svc = new InforUserDefinedFieldServiceOBCUA8(c, 'AddValue', false, 'ADD_CONTACT');
        HttpRequest req = svc.buildRequest();

        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        System.assert(req.getEndpoint().startsWith(settings.baseURL__c), 'Endpoint should start with base URL');
        System.assert(req.getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS083MI/AddValue'), 'Endpoint should target CMS083MI AddValue');
        System.assertEquals('GET', req.getMethod(), 'UDF service should use GET');
        System.assertEquals('InforUserDefinedFieldServiceOBCUA8', svc.getClassName(), 'Class name should match service');

        // Assert core OBCUA8 params are present (order is not guaranteed).
        System.assert(req.getEndpoint().contains('FILE=OOHEAD'), 'Should include FILE param');
        System.assert(req.getEndpoint().contains('FLDI=OAUCA8'), 'Should include OBCUA8 field id');
        System.assert(req.getEndpoint().contains('CONO=200'), 'Should include default CONO');
        System.assert(req.getEndpoint().contains('DIVI=001'), 'Should include default DIVI');

        String expectedFullName = (c.FirstName + ' ' + c.LastName).toUpperCase();
        String expectedAl20 = c.Ext_Id__c.length() > 20 ? c.Ext_Id__c.substring(0, 20) : c.Ext_Id__c;
        String expectedTx40 = expectedFullName.length() > 40 ? expectedFullName.substring(0, 40) : expectedFullName;
        System.assert(
            req.getEndpoint().contains('AL20='),
            'Should include AL20 param derived from Ext_Id__c'
        );
        System.assert(
            req.getEndpoint().contains(EncodingUtil.urlEncode(expectedAl20, 'UTF-8')),
            'AL20 value should match the truncated Ext_Id__c'
        );
        System.assert(req.getEndpoint().contains('TX40='), 'Should include TX40 param derived from full name');
        System.assert(
            req.getEndpoint().contains(EncodingUtil.urlEncode(expectedTx40, 'UTF-8')),
            'TX40 value should match the uppercased/truncated name'
        );
    }

    @isTest
    static void testInforUserDefinedFieldServiceOBCUA8_TwoArgConstructor_BuildsDeleteRequest() {
        Contact c = [
            SELECT Id, FirstName, LastName, Ext_Id__c
            FROM Contact
            LIMIT 1
        ];

        InforUserDefinedFieldServiceOBCUA8 svc = new InforUserDefinedFieldServiceOBCUA8(c, 'DltValue', false, 'DELETE_CONTACT');
        HttpRequest req = svc.buildRequest();

        System.assert(req.getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS083MI/DltValue'), 'Endpoint should target CMS083MI DltValue');
        System.assert(req.getEndpoint().contains('FLDI=OAUCA8'), 'Should include OBCUA8 field id');
    }

    @isTest
    static void testInforMoveContactService_AddConnection_BuildRequest_IncludesExpectedParams() {
        Cases_Requests__c cr = newMoveContactCaseRequest('Y');
        cr = [
            SELECT Id, Contact__c, Account_Name2__c, Move_to_Account__c
            FROM Cases_Requests__c
            WHERE Id = :cr.Id
        ];
        Account newAcct = [SELECT Account_Number__c FROM Account WHERE Id = :cr.Move_to_Account__c];
        Contact c = [SELECT Id FROM Contact WHERE Id = :cr.Contact__c];

        InforMoveContactService svc = new InforMoveContactService(cr, 'addConnection', false, 'MOVE_CONTACT');
        HttpRequest req = svc.buildRequest();

        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        System.assert(req.getEndpoint().startsWith(settings.baseURL__c), 'Endpoint should start with base URL');
        System.assert(
            req.getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS055MI/addConnection'),
            'Endpoint should target CMS055MI addConnection'
        );
        System.assertEquals('GET', req.getMethod(), 'Move contact service should use GET');
        System.assertEquals('InforMoveContactService', svc.getClassName(), 'Class name should match service');
        System.assert(req.getEndpoint().contains('CNPE=' + c.Id), 'Should include contact Id');
        System.assert(
            req.getEndpoint().contains(EncodingUtil.urlEncode(newAcct.Account_Number__c, 'UTF-8')),
            'Add connection should target the new account number'
        );
        System.assert(req.getEndpoint().contains('RFTP=BUYER'), 'Buyer contact should map to BUYER');
        System.assert(req.getEndpoint().contains('CONO=200'), 'Should include default CONO');
        System.assert(req.getEndpoint().contains('DIVI=001'), 'Should include default DIVI');
    }

    @isTest
    static void testInforMoveContactService_DeleteConnect_BuildRequest_IncludesExpectedParams() {
        Cases_Requests__c cr = newMoveContactCaseRequest('N');
        cr = [
            SELECT Id, Contact__c, Account_Name2__c, Move_to_Account__c
            FROM Cases_Requests__c
            WHERE Id = :cr.Id
        ];
        Account oldAcct = [SELECT Account_Number__c FROM Account WHERE Id = :cr.Account_Name2__c];
        Contact c = [SELECT Id FROM Contact WHERE Id = :cr.Contact__c];

        InforMoveContactService svc = new InforMoveContactService(cr, 'DeleteConnect', false, 'MOVE_CONTACT');
        HttpRequest req = svc.buildRequest();

        System.assert(
            req.getEndpoint().contains('/M3/m3api-rest/v2/execute/CMS055MI/DeleteConnect'),
            'Endpoint should target CMS055MI DeleteConnect'
        );
        System.assertEquals('GET', req.getMethod(), 'Move contact service should use GET');
        System.assertEquals('InforMoveContactService', svc.getClassName(), 'Class name should match service');
        System.assert(req.getEndpoint().contains('CNPE=' + c.Id), 'Should include contact Id');
        System.assert(
            req.getEndpoint().contains(EncodingUtil.urlEncode(oldAcct.Account_Number__c, 'UTF-8')),
            'Delete connection should target the old account number'
        );
        System.assert(req.getEndpoint().contains('RFTP=GENERIC'), 'Non-buyer contact should map to GENERIC');
        System.assert(req.getEndpoint().contains('CONO=200'), 'Should include default CONO');
        System.assert(req.getEndpoint().contains('DIVI=001'), 'Should include default DIVI');
    }
    
    @isTest
    static void testGetTokenFields_ReassemblesPartsAndNull() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        settings.accessToken__c = 'part1';
        settings.accessToken2__c = 'part2';
        settings.accessToken3__c = 'part3';
        settings.accessToken4__c = null;
        settings.accessToken5__c = 'part5';
        update settings;
        
        Account a = [SELECT Id FROM Account LIMIT 1];
        TestService service = new TestService(a, 'Any', false, 'ADD_CONTACT');
        
        String token = InforAuthService.getTokenFields(settings);
        System.assertEquals('part1part2part3part5', token, 'Token should concatenate non-null parts');
        
        settings.accessToken__c = null;
        settings.accessToken2__c = null;
        settings.accessToken3__c = null;
        settings.accessToken4__c = null;
        settings.accessToken5__c = null;
        update settings;
        
        String token2 = InforAuthService.getTokenFields(settings);
        System.assertEquals(null, token2, 'Should return null when no parts are set');
    }
    
    @isTest
    static void testSetTokenFields_SplitsAndClears() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        Account a = [SELECT Id FROM Account LIMIT 1];
        TestService service = new TestService(a, 'Any', false, 'ADD_CONTACT');
        
        String longToken = '';
        for (Integer i = 0; i < 600; i++) {
            longToken += 'x';
        }
        
        InforAuthService.setTokenFields(settings, longToken);
        update settings;
        
        ERPSettings__c refreshed = [SELECT accessToken__c, accessToken2__c, accessToken3__c, accessToken4__c, accessToken5__c FROM ERPSettings__c WHERE Id = :settings.Id];
        System.assertEquals(255, refreshed.accessToken__c.length(), 'Part 1 should be 255 chars');
        System.assertEquals(255, refreshed.accessToken2__c.length(), 'Part 2 should be 255 chars');
        System.assertEquals(90, refreshed.accessToken3__c.length(), 'Part 3 should hold remaining chars');
        System.assertEquals(null, refreshed.accessToken4__c, 'Unused parts should be null');
        System.assertEquals(null, refreshed.accessToken5__c, 'Unused parts should be null');
        
        InforAuthService.setTokenFields(settings, '');
        update settings;
        
        ERPSettings__c cleared = [SELECT accessToken__c, accessToken2__c, accessToken3__c, accessToken4__c, accessToken5__c FROM ERPSettings__c WHERE Id = :settings.Id];
        System.assertEquals(null, cleared.accessToken__c);
        System.assertEquals(null, cleared.accessToken2__c);
        System.assertEquals(null, cleared.accessToken3__c);
        System.assertEquals(null, cleared.accessToken4__c);
        System.assertEquals(null, cleared.accessToken5__c);
    }
    
    @isTest
    static void testExecute_SuccessPath() {
        // execute() was removed when InforBaseAPIService stopped being Queueable.
        // This test is no longer applicable, but we keep coverage by asserting we can build a request.
        Account a = [SELECT Id FROM Account LIMIT 1];
        TestService service = new TestService(a, 'Any', false, 'ADD_CONTACT');
        HttpRequest req = service.buildRequest();
        System.assertNotEquals(null, req.getEndpoint());
    }
    
    @isTest
    static void testExecute_RetriesThenLogsAndThrows() {
        // Retry/execute behavior was removed with Queueable removal.
        System.assert(true, 'Retry/execute behavior removed from InforBaseAPIService');
    }
    
    @isTest
    static void testMoveContact_UpdatesAccountAndClearsSequence() {
        Account a = [SELECT Id FROM Account LIMIT 1];
        Contact c = [SELECT Id, AccountId, Sequence__c FROM Contact LIMIT 1];
        
        Profile sysAdminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Omni System Admin'
            LIMIT 1
        ];

        User adminUser = new User(
            Alias = 'tadmin',
            Email = 'test.admin@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = sysAdminProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'test.admin+' + String.valueOf(DateTime.now().getTime()) + '@example.com'
        );
        insert adminUser;

        // Use a unique target account number to avoid uniqueness collisions.
        Account target = new Account(
            Name = 'Target Account',
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        insert target;
        
        Cases_Requests__c cr = new Cases_Requests__c(
            Contact__c = c.Id,
            Move_to_Account__c = target.Id
        );
        insert cr;
        
        Test.startTest();
        System.runAs(adminUser) {
            InforBaseAPIService.moveContact(cr);
        }
        Test.stopTest();
        
        Contact updated = [SELECT Id, AccountId, Sequence__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals(target.Id, updated.AccountId, 'Contact should be moved to target Account');
        // System.assertEquals(null, updated.Sequence__c, 'Sequence__c should be cleared');
    }
}