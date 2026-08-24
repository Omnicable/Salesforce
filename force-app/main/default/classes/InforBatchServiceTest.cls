@isTest
private class InforBatchServiceTest {
    private static String makeAccountNumber7() {
        Integer raw = Math.abs(Crypto.getRandomInteger());
        String digits = String.valueOf(Math.mod(raw, 1000000)).leftPad(6, '0');
        return 'T' + digits;
    }

    private class TestService extends InforBaseAPIService {
        TestService(SObject record, String actionCode) {
            this(record, actionCode, 'TEST');
        }

        TestService(SObject record, String actionCode, String flowTrigger) {
            super(record, actionCode, false, flowTrigger);
        }

        protected override String getEndpointPath() {
            return '/test/batch';
        }

        protected override String getHttpMethod() {
            return 'GET';
        }

        public override String getClassName() {
            return 'InforBatchServiceTestService';
        }
    }

    private class StaticResponseMock implements HttpCalloutMock {
        private final Integer code;
        private final String body;

        StaticResponseMock(Integer code, String body) {
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

    private static Contact getTestContact() {
        return [
            SELECT Id, FirstName, LastName, Email, Phone, Buyer__c, Ext_Id__c, Contact_Title__c,
                   Active__c, Account_Number__c, GenderIdentity
            FROM Contact
            LIMIT 1
        ];
    }

    private static void runBatch(List<InforBaseAPIService> services) {
        Test.startTest();
        Database.executeBatch(new InforBatchService(services), services.size());
        Test.stopTest();
    }

    @testSetup
    static void setup() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new ERPSettings__c();
        }
        settings.baseURL__c = 'https://test.example.com';
        settings.accessToken__c = 'token';
        settings.tokenExpiration__c = Datetime.now().addHours(1);
        upsert settings;

        Account a = new Account(
            Name = 'Omni Cable Corporation',
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        insert a;

        Id rtId = Schema.SObjectType.Contact.getRecordTypeInfosByName()
            .get('Potential Distributor Contact')
            .getRecordTypeId();

        Contact c = new Contact(
            FirstName = 'Batch',
            LastName = 'Tester',
            Email = 'batch.tester@example.com',
            Phone = '555-1212',
            AccountId = a.Id,
            RecordTypeId = rtId,
            Sequence__c = 1,
            Active__c = 'A',
            Buyer__c = 'Y',
            Contact_Title__c = 'Purchasing Agent',
            Ext_Id__c = a.Account_Number__c + ':1'
        );
        insert c;

        Account oldAcct = new Account(
            Name = 'Old Account',
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        Account newAcct = new Account(
            Name = 'New Account',
            Type = 'Customer - Direct',
            Account_Number__c = makeAccountNumber7(),
            Active__c = 'A'
        );
        insert new List<Account>{ oldAcct, newAcct };

        insert new Cases_Requests__c(
            Contact__c = c.Id,
            Account_Name2__c = oldAcct.Id,
            Move_to_Account__c = newAcct.Id
        );
    }

    @isTest
    static void testBatch_Success_InsertsLogsAndReport() {
        Contact c = getTestContact();

        List<InforBaseAPIService> services = new List<InforBaseAPIService>{
            new TestService(c, 'Any'),
            new InforContactService(c, 'Add', false, 'ADD_CONTACT'),
            new InforUserDefinedFieldsService(c, 'AddValue', false, 'ADD_CONTACT'),
            new InforUserDefinedFieldServiceOBCUA8(c, 'AddValue', false, 'ADD_CONTACT'),
            new InforContactConnectService(c, 'AddConnection', false, 'ADD_CONTACT')
        };

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(
            200,
            '{"nrOfSuccessfullTransactions":1,"nrOfFailedTransactions":0}'
        ));

        runBatch(services);

        System.assertEquals(
            0,
            [SELECT count() FROM PlatformEventLog__c WHERE Has_Error__c = true],
            'Successful callouts should not create error logs'
        );
        System.assertEquals(
            services.size(),
            [SELECT count() FROM PlatformEventLog__c WHERE Has_Error__c = false],
            'Each service should produce one success log'
        );

        OmniSync_Contact_Report__c report = [
            SELECT Id, Name, Error__c, Flow__c
            FROM OmniSync_Contact_Report__c
            LIMIT 1
        ];
        System.assertEquals('Batch Tester', report.Name, 'Report name should reflect the contact');
        System.assertEquals(false, report.Error__c, 'Report should not be flagged on success');
        System.assertEquals(
            services.size(),
            [SELECT count() FROM PlatformEventLog__c WHERE OmniSync_Contact_Report__c = :report.Id],
            'All logs should link to the contact report'
        );
    }

    @isTest
    static void testBatch_Failure_RecordsErrorForNonAddUpd() {
        Contact c = getTestContact();
        List<InforBaseAPIService> services = new List<InforBaseAPIService>{
            new TestService(c, 'Upd', 'DELETE_CONTACT')
        };

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(
            200,
            '{"nrOfSuccessfullTransactions":0,"nrOfFailedTransactions":1}'
        ));

        runBatch(services);

        PlatformEventLog__c log = [
            SELECT Has_Error__c, OmniSync_Contact_Report__c
            FROM PlatformEventLog__c
            WHERE Name = 'InforBatchServiceTestService'
            LIMIT 1
        ];
        System.assertEquals(true, log.Has_Error__c, 'Failed transactions should mark the log as an error');
        System.assertNotEquals(null, log.OmniSync_Contact_Report__c, 'Finish should link logs to the contact report');

        OmniSync_Contact_Report__c report = [
            SELECT Error__c
            FROM OmniSync_Contact_Report__c
            LIMIT 1
        ];
        System.assertEquals(true, report.Error__c, 'Report should be flagged when a callout fails');
    }

    @isTest
    static void testBatch_Failure_HttpStatusRecordsError() {
        Contact c = getTestContact();
        List<InforBaseAPIService> services = new List<InforBaseAPIService>{
            new TestService(c, 'Upd', 'DELETE_CONTACT')
        };

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(
            500,
            '{"nrOfSuccessfullTransactions":0,"nrOfFailedTransactions":0}'
        ));

        runBatch(services);

        PlatformEventLog__c log = [
            SELECT Has_Error__c
            FROM PlatformEventLog__c
            WHERE Name = 'InforBatchServiceTestService'
            LIMIT 1
        ];
        System.assertEquals(true, log.Has_Error__c, 'Non-200 HTTP status should mark the log as an error');
    }

    @isTest
    static void testBatch_Failure_UpdateContactFlowSuppressesError() {
        Contact c = getTestContact();
        List<InforBaseAPIService> services = new List<InforBaseAPIService>{
            new InforContactService(c, 'Upd', false, 'UPDATE_CONTACT')
        };

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(
            200,
            '{"nrOfSuccessfullTransactions":0,"nrOfFailedTransactions":1}'
        ));

        runBatch(services);

        PlatformEventLog__c log = [
            SELECT Has_Error__c
            FROM PlatformEventLog__c
            WHERE Name = 'InforContactService'
            LIMIT 1
        ];
        System.assertEquals(
            false,
            log.Has_Error__c,
            'UPDATE_CONTACT flow should not flag failed transactions as errors'
        );

        OmniSync_Contact_Report__c report = [
            SELECT Error__c
            FROM OmniSync_Contact_Report__c
            LIMIT 1
        ];
        System.assertEquals(false, report.Error__c, 'Report should stay clear for UPDATE_CONTACT failures');
    }

    @isTest
    static void testBatch_Failure_AddActionSuppressesError() {
        Contact c = getTestContact();
        List<InforBaseAPIService> services = new List<InforBaseAPIService>{
            new InforContactService(c, 'Add', false, 'ADD_CONTACT')
        };

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(
            200,
            '{"nrOfSuccessfullTransactions":0,"nrOfFailedTransactions":1}'
        ));

        runBatch(services);

        PlatformEventLog__c log = [
            SELECT Has_Error__c
            FROM PlatformEventLog__c
            WHERE Name = 'InforContactService'
            LIMIT 1
        ];
        System.assertEquals(
            false,
            log.Has_Error__c,
            'Add action should not flag failed transactions as errors'
        );
    }

    @isTest
    static void testBatch_Exception_InsertsBatchErrorLog() {
        Contact c = getTestContact();
        List<InforBaseAPIService> services = new List<InforBaseAPIService>{
            new TestService(c, 'Any')
        };

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(200, 'not-valid-json'));

        runBatch(services);

        PlatformEventLog__c log = [
            SELECT Name, Has_Error__c, JSONData__c, Flow__c
            FROM PlatformEventLog__c
            WHERE Name = 'InforBatchService'
            LIMIT 1
        ];
        System.assertEquals(true, log.Has_Error__c, 'Exception path should create an error log');
        System.assertEquals('InforBatchService', log.Flow__c, 'Exception log should use the batch flow name');
        System.assertNotEquals(null, log.JSONData__c, 'Exception message should be serialized');
    }

    @isTest
    static void testBatch_NonContactRecord_InsertsBatchErrorLog() {
        Cases_Requests__c moveReq = [
            SELECT Id, Contact__c, Account_Name2__c, Move_to_Account__c
            FROM Cases_Requests__c
            LIMIT 1
        ];
        List<InforBaseAPIService> services = new List<InforBaseAPIService>{
            new InforMoveContactService(moveReq, 'AddConnection', false, 'MOVE_CONTACT')
        };

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(
            200,
            '{"nrOfSuccessfullTransactions":1,"nrOfFailedTransactions":0}'
        ));

        runBatch(services);

        System.assertEquals(
            1,
            [SELECT count() FROM PlatformEventLog__c WHERE Name = 'InforBatchService' AND Has_Error__c = true],
            'Non-Contact records should hit the exception handler'
        );
    }
}