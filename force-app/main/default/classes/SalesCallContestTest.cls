//NOTE: Since the trigger SalesCallContest do not have a unit test class on production  
// this class was created to allow the deployment to production of a non related functionallity
// TODO: Imporove code coverage of SalesCallContest Trigger
@isTest
public class SalesCallContestTest {
   

    @testSetup static void setup() {

        Id recType = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Potential Distributor').getRecordTypeId();

        Account testAccount = new Account(Name = 'Test Account', RecordtypeId = recType, Account_Number__c = '123456');
        insert testAccount;

        String sequence = '1';
        String newId = testAccount.Account_Number__c + ':' + sequence;

        // Create test data
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Ext_Id__c = newId,
            SalesCallContest__c = true,
            Contact_Title__c = 'Account',
            Email = 'test@omnicable.com',
            AccountId = testAccount.Id, 
            Sequence__c = Decimal.valueOf(sequence));

        insert testContact;

    }

    @IsTest
    private static void testSalesCallContest() {

       Contact testContact = [SELECT Id, SalesCallContest__c FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];

        Task testTask = new Task(WhoId = testContact.Id, Subject = 'Call Test');
		Test.startTest();
			insert testTask;

        Task retreivedTask = [SELECT Id, SalesCallContest__c FROM Task WHERE Id = :testTask.Id LIMIT 1];
        Assert.areEqual(retreivedTask.SalesCallContest__c, testContact.SalesCallContest__c, 'SalesCallContest__c should be the same for the task and the contact');
		Test.stopTest();        
    }
}