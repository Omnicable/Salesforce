/**
 * @description Test class for {@link InforIntegrationService}.
 */
@isTest
private class InforIntegrationServiceTest {
    @testSetup
    static void setup() {
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
    }

    private static InforIntegrationService.InforIMSmsg newMessage(
        SObject record,
        String actionCode,
        Boolean multilocationChanged
    ) {
        InforIntegrationService.InforIMSmsg msg = new InforIntegrationService.InforIMSmsg();
        msg.record = record;
        msg.actionCode = actionCode;
        msg.multilocationChanged = multilocationChanged;
        return msg;
    }

    private static Contact newUnsavedContact(String firstName, String lastName) {
        return new Contact(FirstName = firstName, LastName = lastName);
    }

    private static void resetForcedException() {
        InforIntegrationService.throwExceptionForTest = false;
    }

    @isTest
    static void testImsCallout_EmptyInputs_ReturnsEmptyList() {
        Test.startTest();
        List<Id> jobIds = InforIntegrationService.imsCallout(new List<InforIntegrationService.InforIMSmsg>());
        Test.stopTest();

        System.assertEquals(0, jobIds.size(), 'Empty input list should return empty results');
    }

    @isTest
    static void testImsCallout_Success_AddAction_NoErrorLogs() {
        InforIntegrationService.InforIMSmsg msg = newMessage(newUnsavedContact('Test', 'Contact'), 'Add', false);

        Test.startTest();
        List<Id> jobIds = InforIntegrationService.imsCallout(new List<InforIntegrationService.InforIMSmsg>{ msg });
        Test.stopTest();

        System.assertEquals(1, jobIds.size(), 'Should return one result per input');
        System.assertEquals(null, jobIds[0], 'In tests, batch execution is skipped');
        System.assertEquals(
            0,
            [SELECT count() FROM OmniSync_Contact_Report__c WHERE Error__c = true],
            'Success path should not create error reports'
        );
        System.assertEquals(
            0,
            [SELECT count() FROM PlatformEventLog__c WHERE Name = 'InforIntegrationService' AND Has_Error__c = true],
            'Success path should not create error logs'
        );
    }

    @isTest
    static void testImsCallout_MultipleInputs_ReturnsOneResultPerInput() {
        List<InforIntegrationService.InforIMSmsg> inputs = new List<InforIntegrationService.InforIMSmsg>{
            newMessage(newUnsavedContact('First', 'Input'), 'Add', false),
            newMessage(newUnsavedContact('Second', 'Input'), 'Upd', true)
        };

        Test.startTest();
        List<Id> jobIds = InforIntegrationService.imsCallout(inputs);
        Test.stopTest();

        System.assertEquals(2, jobIds.size(), 'Should return one result per input');
        System.assertEquals(null, jobIds[0], 'In tests, batch execution is skipped');
        System.assertEquals(null, jobIds[1], 'In tests, batch execution is skipped');
    }

    @isTest
    static void testImsCallout_UpdAction_BuildsServicesWithoutError() {
        InforIntegrationService.InforIMSmsg msg = newMessage(newUnsavedContact('Update', 'Contact'), 'Upd', false);

        Test.startTest();
        List<Id> jobIds = InforIntegrationService.imsCallout(new List<InforIntegrationService.InforIMSmsg>{ msg });
        Test.stopTest();

        System.assertEquals(1, jobIds.size());
        System.assertEquals(null, jobIds[0]);
    }

    @isTest
    static void testImsCallout_Exception_NullRecord_CreatesErrorReportAndLog() {
        InforIntegrationService.InforIMSmsg msg = newMessage(null, 'Upd', false);

        Test.startTest();
        List<Id> jobIds = InforIntegrationService.imsCallout(new List<InforIntegrationService.InforIMSmsg>{ msg });
        Test.stopTest();

        System.assertEquals(0, jobIds.size(), 'Exception should return without adding results');

        OmniSync_Contact_Report__c report = [
            SELECT Name, Error__c, Flow__c, Contact__c
            FROM OmniSync_Contact_Report__c
            WHERE Error__c = true
            LIMIT 1
        ];
        System.assertEquals('InforIntegrationService', report.Name);
        System.assertEquals(true, report.Error__c);
        System.assertEquals(null, report.Flow__c);
        System.assertEquals(null, report.Contact__c);

        PlatformEventLog__c log = [
            SELECT Has_Error__c, OmniSync_Contact_Report__c, JSONData__c
            FROM PlatformEventLog__c
            WHERE Name = 'InforIntegrationService'
            LIMIT 1
        ];
        System.assertEquals(true, log.Has_Error__c);
        System.assertEquals(report.Id, log.OmniSync_Contact_Report__c);
        System.assert(log.JSONData__c != null && log.JSONData__c.contains('Attempt to de-reference a null object'));
    }

    @isTest
    static void testImsCallout_Exception_WithContact_PopulatesContactReport() {
        Contact c = newUnsavedContact('Error', 'Path');
        InforIntegrationService.InforIMSmsg msg = newMessage(c, 'Upd', false);

        InforIntegrationService.throwExceptionForTest = true;
        try {
            Test.startTest();
            List<Id> jobIds = InforIntegrationService.imsCallout(new List<InforIntegrationService.InforIMSmsg>{ msg });
            Test.stopTest();

            System.assertEquals(0, jobIds.size(), 'Exception should return without adding results');

            OmniSync_Contact_Report__c report = [
                SELECT Name, Flow__c, Contact__c, Error__c
                FROM OmniSync_Contact_Report__c
                WHERE Error__c = true
                LIMIT 1
            ];
            System.assertEquals('Error Path', report.Name);
            System.assertEquals('Upd', report.Flow__c);
            System.assertEquals(true, report.Error__c);
            System.assertEquals(null, report.Contact__c);

            PlatformEventLog__c log = [
                SELECT Has_Error__c, OmniSync_Contact_Report__c
                FROM PlatformEventLog__c
                WHERE Name = 'InforIntegrationService'
                LIMIT 1
            ];
            System.assertEquals(true, log.Has_Error__c);
            System.assertEquals(report.Id, log.OmniSync_Contact_Report__c);
        } finally {
            resetForcedException();
        }
    }

    @isTest
    static void testImsCallout_Exception_NullInputEntry_CreatesErrorReport() {
        InforIntegrationService.InforIMSmsg validMsg = newMessage(newUnsavedContact('Before', 'Failure'), 'Add', false);

        Test.startTest();
        List<Id> jobIds = InforIntegrationService.imsCallout(
            new List<InforIntegrationService.InforIMSmsg>{ validMsg, null }
        );
        Test.stopTest();

        System.assertEquals(1, jobIds.size(), 'First input should complete before the null input throws');
        System.assertEquals(
            1,
            [SELECT count() FROM OmniSync_Contact_Report__c WHERE Error__c = true],
            'Null input should create an error report'
        );
        System.assertEquals(
            1,
            [SELECT count() FROM PlatformEventLog__c WHERE Name = 'InforIntegrationService' AND Has_Error__c = true],
            'Null input should create an error log'
        );
    }

    @isTest
    static void testImsCallout_Exception_NullInputsList_CreatesErrorReport() {
        Test.startTest();
        List<Id> jobIds = InforIntegrationService.imsCallout(null);
        Test.stopTest();

        System.assertEquals(0, jobIds.size());
        System.assertEquals(
            1,
            [SELECT count() FROM OmniSync_Contact_Report__c WHERE Error__c = true],
            'Null inputs list should create an error report'
        );
    }
}