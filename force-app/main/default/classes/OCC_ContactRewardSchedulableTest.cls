@isTest
private class OCC_ContactRewardSchedulableTest {
    
    @testSetup static void setup() {
        User user = [SELECT Id, Name FROM User WHERE Profile.Name = 'Omni System Admin' AND IsActive = true LIMIT 1];
        System.runAs(user) {
            Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
            insert account;
            
            String newId = account.Account_Number__c + ':1';
            Contact contact = new Contact(LastName='My Contact', Contact_Title__c='Accounting', Email='test@omnicable.com', OCC_ViewAll__c =false, OCC_RewardsValue__c=1 ,AccountId=account.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 1, OCC_RewardStep__c = 1, FirstName='Test', Ext_Id__c = newId, OCC_RewardsTotal__c=0);
            insert contact;
            
            List<QuotesOrdersCredits_Header__c> allHeaders = new List<QuotesOrdersCredits_Header__c>();
            QuotesOrdersCredits_Header__c invoicedOrderOveride = new QuotesOrdersCredits_Header__c(Name='999999', RewardOverride__c=10, Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Status__c='Invoiced', Type__c='Order', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00);
            allHeaders.add(invoicedOrderOveride);
            QuotesOrdersCredits_Header__c invoicedOrder = new QuotesOrdersCredits_Header__c(Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Status__c='Invoiced', Type__c='Order', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00);
            allHeaders.add(invoicedOrder);
            QuotesOrdersCredits_Header__c returnedCreditOveride = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Status__c='Invoiced', Type__c='Credit', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00, SalesNote3__c ='RMA');
            allHeaders.add(returnedCreditOveride);
            QuotesOrdersCredits_Header__c returnedCredit = new QuotesOrdersCredits_Header__c(Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Status__c='Invoiced', Type__c='Credit', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00, SalesNote3__c ='RMA');
            allHeaders.add(returnedCredit);
            QuotesOrdersCredits_Header__c myQuote = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Type__c='RFQ', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00);
            allHeaders.add(myQuote);
            upsert allHeaders;
            
            
            List<QuoteOrderCredit_Details__c> allDetails = new List<QuoteOrderCredit_Details__c>();
            QuoteOrderCredit_Details__c invoicedOrderDetailsOveride = new QuoteOrderCredit_Details__c(Order_Header__c = invoicedOrderOveride.Id, Qty_Ordered__c=2, /*Amount__c = 300,*/ Dollars__c = 300);
            allDetails.add(invoicedOrderDetailsOveride);
            QuoteOrderCredit_Details__c invoicedOrderDetails = new QuoteOrderCredit_Details__c(Order_Header__c = invoicedOrder.Id, Qty_Ordered__c=2, /*Amount__c = 300,*/ Dollars__c = 300);
            allDetails.add(invoicedOrderDetails);
            QuoteOrderCredit_Details__c returnedCreditDetailsOveride = new QuoteOrderCredit_Details__c(Order_Header__c = returnedCreditOveride.Id, Qty_Ordered__c=2, /*Amount__c = 300,*/ Dollars__c = 300);
            allDetails.add(returnedCreditDetailsOveride);
            QuoteOrderCredit_Details__c returnedCreditDetails = new QuoteOrderCredit_Details__c(Order_Header__c = returnedCredit.Id, Qty_Ordered__c=2, /*Amount__c = 300,*/ Dollars__c = 300);
            allDetails.add(returnedCreditDetails);
            upsert allDetails;
        }
    }
    
    @isTest static void testContactRewardSchedulable() {
        
        List<Contact> contacts = [SELECT id, OCC_RewardsValue__c, OCC_RewardsTotal__c FROM Contact];
        Map<Id, Contact> contactsMap = new Map<Id, Contact>(contacts);
        List<Id> contIds = new List<Id>(contactsMap.keySet());
        System.debug('contIds: ' + contIds);
        
        System.debug('contacts: ' + contacts);
        Decimal previousTotal = contacts.get(0).OCC_RewardsTotal__c;
        contacts.get(0).OCC_RewardsValue__c = 0;
        update contacts;
        
        Test.startTest();
        Datetime dt = Datetime.now().addMinutes(1);
        OCC_ContactRewardSchedulable batch = new OCC_ContactRewardSchedulable();
        Final String cron_exp = '0 '+ dt.minute() + ' * ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
        String jobId = System.schedule('Test OCC_ContactRewardSchedulable', cron_exp, batch);
        
        List<Task> lt = [SELECT Id FROM Task WHERE WhatId IN : contIds];
        System.assertEquals(0, lt.size(), 'Tasks exist before job has run');
        
        Test.stopTest();
        
        // Check schedulable is in the job list
        List<AsyncApexJob> jobsScheduled = [select Id, ApexClassID, ApexClass.Name, Status, JobType from AsyncApexJob where JobType = 'ScheduledApex'];
        System.assertEquals(1, jobsScheduled.size(), 'expecting one scheduled job');
        System.assertEquals('OCC_ContactRewardSchedulable', jobsScheduled[0].ApexClass.Name, 'expecting specific scheduled job');
        
        // check apex batch is in the job list
        List<AsyncApexJob> jobsApexBatch = [select Id, ApexClassID, ApexClass.Name, Status, JobType from AsyncApexJob where JobType = 'BatchApex'];
        System.assertEquals(1, jobsApexBatch.size(), 'expecting one apex batch job');
        System.assertEquals('ContactRewardTotalBatch', jobsApexBatch[0].ApexClass.Name, 'expecting specific batch job');
        
    }
}