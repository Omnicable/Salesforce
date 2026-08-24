/*
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest(SeeAllData=true)
private class OC_Trigger_test {
    static testMethod void Ownershipchange() {
        User u118 = [select Id,Sales_Number__c from User where isActive = True and Sales_Number__c <>'' LIMIT 1];
    //    User u707 = [select Id from User where isActive = True and Sales_Number__c <>''];
        List<User> users = [Select Id, Email from User where isActive = true and Sales_Number__c <> '' Limit 2];
        List<Account> accounts= [select id, name, OwnerID, ParentAccount__c, Account_Number__c from account where Active__c ='A' and Account_Number__c <>'' LIMIT 2];
            Account aRum = accounts.get(0);
            Account parentaRum = accounts.get(1); 
            aRum.Salesperson_Code__c = u118.Sales_Number__c;
            aRum.OwnerId = u118.Id ;
            aRum.ParentAccount__c = parentaRum.Account_Number__c;
        update aRum;
    }
    static testMethod void myUnitTest() {
        List<User> users = [select Id,Sales_Number__c from User where isActive = True and Sales_Number__c <>'' LIMIT 2];
            User u118 = users.get(0);
            User u707 = users.get(1);   
        Account a = new Account(Name='test account', Account_Number__c='888888',ParentAccount__c = '984434',
            Outside_Salesperson__c = u707.Id,
            Salesperson_Code__c = u118.Sales_Number__c,
            OwnerId = u118.Id 
        );
        insert a;
        Contact c = new Contact(AccountId=a.Id,Lastname='test',Email = 'john.dean@ggmail.com', Buyer__c ='Y', Contact_Title__c = 'Accounting', FirstName = 'John');
        insert c;
    }


    static testMethod void QOCTest() {
        QuotesOrdersCredits_Header__c qTest = null;
        for ( QuotesOrdersCredits_Header__c q : [Select Id,(Select Id From Tasks where Subject like 'Open Quote%' and Status<>'Completed') From QuotesOrdersCredits_Header__c where Type__c='Quote' and Status__c='Open' order by LastModifiedDate desc limit 100]) {
            qTest = q;
            if ( ! q.Tasks.isEmpty()) {
                break;
            }
        }
        QuotesOrdersCredits_Header__c nq = new QuotesOrdersCredits_Header__c( Id = qTest.Id, Status__c='Cancelled', Notes__c ='hi');
        update nq;
    }
    static testMethod void newAccountpage_Test()
{
        //Test converage for the myPage visualforce page
        PageReference pageRef = Page.newAccountPage;
        Test.setCurrentPageReference(pageRef);
        mycontroller2 controller = new mycontroller2();
        Account newAccount = new Account(Name='John Crabshack',Account_Number__c='888889',ParentAccount__c='984423');
        insert newAccount;
        //create first contact
        Contact myContact = new Contact (FirstName='Joe',
        LastName='Schmoed', Email='jschmoed@yahoo.com', Buyer__c ='Y', Contact_Title__c = 'Accounting',
        AccountId=newAccount.id);
        insert myContact;
        ApexPages.StandardController sc = new ApexPages.standardController(newAccount);
        // create an instance of the controller
        mycontroller2 myPageCon = new mycontroller2(sc);
        //try calling methods/properties of the controller in all possible scenarios
        //List <Contact> pContacts = myPageCon.getPcons();
        myPageCon.getPcons();
        myPageCon.AddRows();

}
//        static TestMethod void testBudgetOwner() {
        // Grab two Users
//        User[] users = [select Id from User where Isactive= True and Sales_Number__c <> ' ' limit 2];
//        User u1 = users[0];
//        User u2 = users[1];
        // Grab 1 account
 //       Account[] account = [Select Id, OwnerId, Account_Number__c from Account where Active__c ='A' and Type ='Distributor' limit 1];
 //       Account a1 = account[0];
        // Create an Budget
 //       System.debug('Creating Budget');
 //       Budget__c o1 = new Budget__c(Budget_Year__c = Date.newInstance(2013, 01, 01), Name = a1.Account_Number__c+':2013', 
 //                                       Customer__c = a1.Id, Budget_Owner__c = a1.OwnerId);
 //       insert o1;
 //       Budget_Month__c bm1 = new Budget_Month__c(Budget__c = o1.Id ,Name = a1.Account_Number__c+':2013-01-01', Budget_Owner__c = a1.OwnerId,
 //                                             Budget_Date__c = Date.newInstance(2013, 01, 01));
 //       insert bm1;
        // Test: Owner_Link should be set to user 1
  //      Budget__c o2 = [select id, Budget_Owner__c from Budget__c where Id = :o1.Id];
 //       System.assertEquals(a1.OwnerId, o2.Budget_Owner__c);
 //       Budget_Month__c bm2 = [select id, Budget_Owner__c from Budget_Month__c where Id = :bm1.Id];
 //       System.assertEquals(a1.OwnerId, bm2.Budget_Owner__c);
        // Modify Owner
  //      Account a2 = [select id, OwnerId, Account_Number__c from Account where Id = :a1.Id];
 //       a2.OwnerId = u2.Id;
 //       update a2;
        // Test: Owner_Link should be set to user 2
 //       Budget__c o3 = [select id, Budget_Owner__c from Budget__c where id = :o2.Id];
 //       Budget_Month__c bm3 = [select id, Budget_Owner__c from Budget_Month__c where id = :bm2.id];
 //       System.assertEquals(u2.Id, o3.Budget_Owner__c);
 //       System.assertEquals(u2.Id, bm3.Budget_Owner__c);
 //   }
    
    static TestMethod void testOwnerLink() {
        // Grab two Users
        User[] users = [select Id from User where Isactive= True and Sales_Number__c <> ' ' limit 2];
        User u1 = users[0];
        User u2 = users[1];
        // Create an Opportunity
        System.debug('Creating Opportunity');
        Budget__c o1 = new Budget__c(Budget_Year__c = Date.newInstance(2013, 01, 01), Name = '989800:2013', 
                                        Customer__c = '0016000000V44a5',Budget_Owner__c = u1.Id);
        insert o1;
        // Test: Owner_Link should be set to user 1
        Budget__c o2 = [select id, Budget_Owner__c from Budget__c where Id = :o1.Id];
        System.assertEquals(u1.Id, o2.Budget_Owner__c);
        // Modify Owner
        o2.Budget_Owner__c = u2.Id;
        update o2;
        // Test: Owner_Link should be set to user 2
        Budget__c o3 = [select id, Budget_Owner__c from Budget__c where Id = :o2.Id];
        System.assertEquals(u2.Id, o3.Budget_Owner__c);
    }
/*    static testMethod void mySalesCallTest() {

 pssst, lifted this from ...

    http://community.salesforce.com/sforce/board/message?board.id=apex&message.id=11984

 

        //First, prepare opportunity for the test data

        Contact Contacttrue = new Contact(firstname='test',lastname='contacta',email='x@y.com', SalesCallContest__c=True);

        insert Contacttrue;

          Contact Contactfalse = new Contact(firstname='test',lastname='contactb',email='x@z.com', SalesCallContest__c=True);

        insert Contactfalse;      

       // System.debug('Created Account with Id: ' + acct1.id);

        
        //acct.Health_Status__c = 'Customer';

        //update acct;
         

        Task TaskToCreate = new Task(WhoId=Contacttrue.Id,Subject='Call');

           insert TaskToCreate;
        

        
// Verify correct action

        Task TaskUpd = [select id, SalesCallContest__c from Task where id = :TaskToCreate.Id];

        System.debug('THE VALUE OF STATUS IS: ' + 'SalesCallContest__c');

//        System.assert(acctUpd.CustomField__C == TaskToCreate.Status;

 //       System.assert(Lead2.CustomField__c == null);

            }
   */

}