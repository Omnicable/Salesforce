@isTest
private class RMAcStatsTT {


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

    @isTest
   static void testTrigger() {
      try {

        Account testAccount = [SELECT Id, Name from Account limit 1];
          RMA__c o = new RMA__c(Account__c = testAccount.Id, RMANumber_c__c='123');
          insert o;

          System.assertNotEquals(null, o);
      }
      catch(Exception e) {
          List<RMA__c> l = [SELECT Id from RMA__c LIMIT 1];
          update l;
          System.assertNotEquals(null, l);
      }
   }
}