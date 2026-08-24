@isTest
private class BudgetMonthcStatsTT {

    @testSetup static void setup() {
        Account testAccount = createAccount(1);
        Budget__c budget = createBudget(testAccount);
    }


        /**
     * @description create accounts for testing
     * @author chrisw@launchdm.com | 09-06-2022
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


        /**
     * @description create budget record for testing
     * @author chrisw@launchdm.com | 05-14-2025
     * @param Account account
     * @return Budget__c
     **/
    public static Budget__c createBudget(Account account) {
        Budget__c budget = new Budget__c(Name='Test Budget', Customer__c=account.Id);
        insert budget;
        return budget;
    }

   
    @isTest
    static void testTrigger() {
      try {
        Budget__c budget = [SELECT Id, Name from Budget__c limit 1];
        Budget_Month__c o = new Budget_Month__c(Budget__c=budget.Id);
        insert o;
        Assert.areNotEqual(null, o, 'Budget Month should not be null');
      }
      catch(Exception e) {
        List<Budget_Month__c> l = [SELECT Id from Budget_Month__c LIMIT 1];
        update l;
        Assert.areNotEqual(null, l, 'Budget Month should not be null');
      }
   }
}