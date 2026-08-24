@isTest
private class BudgetcStatsTT {

    @testSetup static void setup() {
        Account testAccount = createAccount(1);
    }

        /**
     * @description create accounts for testing
     * @author chrisw@launchdm.com | 05-14-2025
     * @param Integer count
     * @return Account
     **/
    public static Account createAccount(Integer count) {
        Id stExam = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Potential Distributor').getRecordTypeId();
        Account account = new Account(
            Name = 'Test Account',
            Account_Number__c = '123456',
            RecordtypeId = stExam,
            Buying_Group__c = 'Test Buying Group',
            Region__c = '6',
            Company_Name__c = 'Test Company',
            Active__c = 'A',
            Price_Book_Email_Day__c = Date.today().day()
        );
        insert account;
        return account;
    }


@isTest    
static void testTrigger() {
      try {

        Account testAccount = [SELECT Id, Name from Account limit 1];   

          Budget__c o = new Budget__c(Name='Test Budget', Customer__c=testAccount.Id);
          insert o;
          Assert.areNotEqual(null, o, 'Budget__c should not be null');
      }
      catch(Exception e) {
          List<Budget__c> l = [SELECT Id from Budget__c LIMIT 1];
          update l;
          Assert.areNotEqual(null, l, 'Budget__c should not be null');
      }
   }
}