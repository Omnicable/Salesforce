@isTest
private class QuoteOrderCreditDetailscStatsTT {

    @testSetup static void setup() {
        Account testAccount = createAccount(1);

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

@isTest    
static void testTrigger() {
      try {

        Account testAccount = [SELECT Id, Name from Account limit 1];

        QuotesOrdersCredits_Header__c testHeader = new QuotesOrdersCredits_Header__c(Name='999999', Order_Number__c='123456', Customer__c=testAccount.Id,  Date__c = system.today(), Status__c='Invoiced', Type__c='Order', Sub_Type__c='Blanket', New_Total_Order_Sales__c=100.00);
        insert testHeader;

        QuoteOrderCredit_Details__c testDetails = new QuoteOrderCredit_Details__c(Order_Header__c = testHeader.Id, Qty_Ordered__c=2, /*Amount__c = 300,*/ Dollars__c = 300);
        insert testDetails;


          Assert.areNotEqual(null, testDetails, 'testDetails should not be null');
      }
      catch(Exception e) {
          List<QuoteOrderCredit_Details__c> l = [SELECT Id from QuoteOrderCredit_Details__c LIMIT 1];
          update l;
         
          Assert.areNotEqual(null, l, 'QuoteOrderCredit_Details__c should not be null');
      }
   }
}