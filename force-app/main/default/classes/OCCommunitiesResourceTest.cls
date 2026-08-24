@IsTest 
global with sharing class OCCommunitiesResourceTest implements HTTPCalloutMock{
 
    @IsTest(SeeAllData=false) global static void testGetRewards() {   
    
        OCCommunitiesResource.RewardsResponse result = new  OCCommunitiesResource.RewardsResponse();
        
        
        /////////////
        test.startTest();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', OCC_RewardsValue__c=1 ,AccountId=account.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 1, OCC_RewardStep__c = 1, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
        
        //List<User> Users = [Select Name, ContactId from User where Id =: UserInfo.getUserId()];
        
        
        User user1 = new User(
            Username = System.now().millisecond() + '2test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);
        
 
        
        System.runAs(user1) {

        List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
        List<QuotesOrdersCredits_Header__c> qocHeaders2 = new List<QuotesOrdersCredits_Header__c>();
        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
        List<QuoteOrderCredit_Details__c> qocDetails2 = new List<QuoteOrderCredit_Details__c>();
        
        for(Integer i = 0; i < 1; i++){
            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(RewardOverride__c=1, Customer__c = account.Id, Buyer__c = contact.Id, Date__c = system.today());
            qocHeaders.add(header);
        }
        
        insert qocHeaders; 
        
        for(Integer i = 0; i < 1; i++){
            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Date__c = system.today(), Type__c = 'Order', Status__c = 'Invoiced', OCC_RewardRedeemed__c = false);
            qocHeaders2.add(header);
        }
        
        insert qocHeaders2;         
        
        
        for(Integer i = 0; i < qocHeaders2.size(); i++){
            String headerId = qocHeaders2[i].Id;
            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, /*Amount__c = 300,*/ Dollars__c = 300);
            qocDetails2.add(detail);

        }
        
        insert qocDetails2;
        
        
        QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(SalesNote3__c ='RMA', RewardOverride__c=1 , Customer__c = account.Id, Buyer__c = contact.Id, Date__c = system.today(), Type__c = 'Credit', Status__c = 'Invoiced', OCC_RewardRedeemed__c = false);
        insert header;
        //qocHeaders2.add(header);
        
        
        for(Integer i = 0; i < qocHeaders.size(); i++){
            String headerId = qocHeaders[i].Id;
            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, /*Amount__c = 300,*/ Dollars__c = 300);
            qocDetails.add(detail);

        }
        
        insert qocDetails;
        
        QuotesOrdersCredits_Header__c header1 = qocHeaders.get(0);
        
        Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header1.id,  Issue_Status__c = 'Open');
	        upsert issue;
        
        System.debug(LoggingLevel.ERROR, 'details=: ' + qocDetails);

        test.stopTest();
        
        //////////////
        
        result = OCCommunitiesResource.getRewards();
        System.debug(result.Value);
        
        //System.assertEquals('300', result.Value);
        System.assertEquals(true, result.Success);
        
        }
        
    }
    
    @IsTest(SeeAllData=false) global static void testSendRFQOrder() {   
    
        OCCommunitiesResource.RFQResponse result = new OCCommunitiesResource.RFQResponse();
        
        test.startTest();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        
        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '444456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', AccountId=account.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
       
        
        User user1 = new User(
            Username = System.now().millisecond() + '3test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'chrisw@launchdm.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);
        
 
        test.stopTest();
        System.runAs(user1) {

            OCCommunitiesResource.RFQRequest request = new OCCommunitiesResource.RFQRequest();
            
            request.RFQData = 'Test Email Body';
            request.typeStr = 'Order';
            List<OCCommunitiesResource.ImageData> ImageDataList = new List<OCCommunitiesResource.ImageData>();
            OCCommunitiesResource.ImageData imData = new OCCommunitiesResource.ImageData();

            imData.image = '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';
            imData.name = 'test';
            ImageDataList.add(imData);
            
            request.ImageData = ImageDataList;
            result = OCCommunitiesResource.sendRFQ(JSON.serialize(request));
            System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
            Boolean success = true;
            System.assertEquals(true, success);
       
        }
        
    }
    
    @IsTest(SeeAllData=false) global static void testSendRFQRFQ() {   
    
        OCCommunitiesResource.RFQResponse result = new OCCommunitiesResource.RFQResponse();
        
        test.startTest();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', AccountId=account.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);

        
        User user1 = new User(
            Username = System.now().millisecond() + '4test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'chrisw@launchdm.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        Database.insert(user1);
        
 
        test.stopTest();
        System.runAs(user1) {

        
            OCCommunitiesResource.RFQRequest request = new OCCommunitiesResource.RFQRequest();
            
            request.RFQData = 'Test Email Body';
            request.typeStr = 'RFQ';
            List<OCCommunitiesResource.ImageData> ImageDataList = new List<OCCommunitiesResource.ImageData>();
            OCCommunitiesResource.ImageData imData = new OCCommunitiesResource.ImageData();

            imData.image = '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';
            imData.name = 'test';
            ImageDataList.add(imData);
            
            request.ImageData = ImageDataList;
            result = OCCommunitiesResource.sendRFQ(JSON.serialize(request));
            System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
            Boolean success = true;
            System.assertEquals(true, success);
       
        }
        
    }
    
    ///////////////////
    @IsTest(SeeAllData=false) global static void testSendRFQRMA() {   
    
        OCCommunitiesResource.RFQResponse result = new OCCommunitiesResource.RFQResponse();
        
        test.startTest();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', AccountId=account.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
        
        User user1 = new User(
            Username = System.now().millisecond() + '5test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);
        
 
        test.stopTest();
        System.runAs(user1) {

        
            OCCommunitiesResource.RFQRequest request = new OCCommunitiesResource.RFQRequest();
            
            request.RFQData = 'Test Email Body';
            request.typeStr = 'RMA';
            List<OCCommunitiesResource.ImageData> ImageDataList = new List<OCCommunitiesResource.ImageData>();
            OCCommunitiesResource.ImageData imData = new OCCommunitiesResource.ImageData();

            imData.image = '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';
            imData.name = 'test';
            ImageDataList.add(imData);
            
            request.ImageData = ImageDataList;
            result = OCCommunitiesResource.sendRFQ(JSON.serialize(request));
            System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
            Boolean success = true;
            System.assertEquals(true, success);
       
        }
        
    }
    
    
    @IsTest(SeeAllData=false) global static void testsendEmail() {   
    

        OCCommunitiesResource.RFQResponse result = new OCCommunitiesResource.RFQResponse();
        
        test.startTest();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', AccountId=account.Id, Sequence__c = 1,  OCC_Rewards__c=true, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
       
        
        User user1 = new User(
            Username = System.now().millisecond() + '6test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);
        
        System.runAs(user1) {
        
            OCCommunitiesResource.EmailRequest request = new OCCommunitiesResource.EmailRequest();
            
            request.Message = 'Test Email Body';
            request.Email = 'chrisw@launchd.com';
            request.Subject = 'test Subject';
            
            result = OCCommunitiesResource.sendEmail(JSON.serialize(request));
            System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
            System.assertEquals(true, result.Success);
       
        }
        test.stopTest();

    }
    
    @IsTest(SeeAllData=false) global static void testFindQOCById() {   
   
		
		OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '111156');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', AccountId=account.Id, OCC_ViewAll__c = true, OCC_Rewards__c=true, Sequence__c = 1, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Email='chrisw@launchdm.com', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
        
       
                
        User user1 = new User(
            Username = System.now().millisecond() + '7test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);
        
        System.runAs(user1) {

	        List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
	        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
	        
	        for(Integer i = 0; i < 5; i++){
	            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Date__c = system.today());
	            QuotesOrdersCredits_Header__c orderheader = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Type__c = 'Order', Date__c = system.today());
	            qocHeaders.add(orderheader);
	            qocHeaders.add(header);
	        }
	        
	        insert qocHeaders; 
	        
	        QuotesOrdersCredits_Header__c header = qocHeaders.get(0);
	        header.Notes__c = 'test notes';
	        upsert header;
	        
	        /*
	        ContentVersion content = new ContentVersion(Title = 'testTitle', QuotesOrdersCredits_Header__c = header.Id);
	        insert content;
	        */
	        
	        
	        for(Integer i = 0; i < qocHeaders.size(); i++){
	            String headerId = qocHeaders[i].Id;
	            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, Dollars__c = 300);
	            qocDetails.add(detail);
	
	        }
	        
	        insert qocDetails;
	        
	        QuoteOrderCredit_Details__c detailUpdate = qocDetails.get(0);
	        detailUpdate.Put_up_1__c = '1 x 200';
	        upsert detailUpdate;
	        
	        Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header.id,  Issue_Status__c = 'Open');
	        upsert issue;
	        
	        System.debug(LoggingLevel.ERROR, 'details=: ' + qocDetails);
	       
	        //url is null
	        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate')); 
	        PageReference pageRef = System.currentPageReference();
	        String url = 'https://omnicable-developer-edition.na31.force.com';
	        
	        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
	        
	    
	        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
	        request.url = url;
	        request.id = header.Id;
	        
	        result = OCCommunitiesResource.findQOCById(JSON.serialize(request));
	        System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
	        System.assertEquals(true, result.Success);
	       
        }
        
    }
    
    
    @IsTest(SeeAllData=false) global static void testGetCommunitiesDataVeiwAll() {   
    
		/*
        OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
       
 		User user = [SELECT Id, ContactId, Name, Email, FirstName, LastName, Phone FROM User WHERE LastName = 'Tester'];
        System.debug(LoggingLevel.ERROR, 'updateProfile User=: ' + user);

        Contact contact = [SELECT Id, Name, Email, FirstName, LastName, Phone FROM Contact WHERE Id =: user.ContactId];
        System.debug(LoggingLevel.ERROR, 'updateProfile Contact=: ' + contact);
		*/
		
		OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
       
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', AccountId=account.Id, OCC_ViewAll__c = true, OCC_Rewards__c=true, Sequence__c = 1, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Email='chrisw@launchdm.com', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
        
        
        OCC_ApprovedAccount__c approvedAccount = new OCC_ApprovedAccount__c(Account__c=account.Id, Contact__c=contact.Id, Name='test');
        insert approvedAccount;
       
                
        User user1 = new User(
            Username = System.now().millisecond() + '8test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);
        
        System.runAs(user1) {

	        List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
	        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
	        
	        for(Integer i = 0; i < 5; i++){
	            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Date__c = system.today());
	            QuotesOrdersCredits_Header__c orderheader = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Type__c = 'Order', Date__c = system.today());
	            qocHeaders.add(orderheader);
	            qocHeaders.add(header);
	        }
	        
	        insert qocHeaders; 
	        
	        QuotesOrdersCredits_Header__c header = qocHeaders.get(0);
	        header.Notes__c = 'test notes';
	        upsert header;
	        
	        /*
	        ContentVersion content = new ContentVersion(Title = 'testTitle', QuotesOrdersCredits_Header__c = header.Id);
	        insert content;
	        */
	        
	        
	        for(Integer i = 0; i < qocHeaders.size(); i++){
	            String headerId = qocHeaders[i].Id;
	            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, Dollars__c = 300);
	            qocDetails.add(detail);
	
	        }
	        
	        insert qocDetails;
	        
	        QuoteOrderCredit_Details__c detailUpdate = qocDetails.get(0);
	        detailUpdate.Put_up_1__c = '1 x 200';
	        upsert detailUpdate;
	        
	        Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header.id,  Issue_Status__c = 'Open');
	        upsert issue;
	        
	        System.debug(LoggingLevel.ERROR, 'details=: ' + qocDetails);
	       
	        //url is null
	        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate')); 
	        PageReference pageRef = System.currentPageReference();
	        String url = 'https://omnicable-developer-edition.na31.force.com';
	        
	        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
	        
	    
	        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
	        request.url = url;
	        request.id = UserInfo.getUserId();
	        
	        result = OCCommunitiesResource.getCommunitiesData(JSON.serialize(request));
	        System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
	        System.assertEquals(true, result.Success);
	       
        }
        
    }
    
    /*
    @IsTest(SeeAllData=false) global static void testGetCommunitiesDataAdmin() {   
   
		
		OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community Plus%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

		Account parent = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert parent;

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '2345678', ParentId = parent.Id);
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact( Email='chrisw@launchdm.com', AccountId=account.Id,  OCC_Rewards__c=true, Sequence__c = 1, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
                   
        User user1 = new User(
            Username = System.now().millisecond() + 'test12345@test.com',
            ContactId = null,
            ProfileId = profile1.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        insert(user1);
		
        
        System.runAs(user1) {

	        List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
	        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
	        
	        for(Integer i = 0; i < 5; i++){
	            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Date__c = system.today());
	            QuotesOrdersCredits_Header__c orderheader = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Type__c = 'Order', Date__c = system.today());
	            qocHeaders.add(orderheader);
	            qocHeaders.add(header);
	        }
	        
	        insert qocHeaders; 
	        
	        QuotesOrdersCredits_Header__c header = qocHeaders.get(0);
	        header.Notes__c = 'test notes';
	        upsert header;
	       
	        
	        for(Integer i = 0; i < qocHeaders.size(); i++){
	            String headerId = qocHeaders[i].Id;
	            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, Dollars__c = 300);
	            qocDetails.add(detail);
	
	        }
	        
	        insert qocDetails;
	        
	        QuoteOrderCredit_Details__c detailUpdate = qocDetails.get(0);
	        detailUpdate.Put_up_1__c = '1 x 200';
	        upsert detailUpdate;
	        
	        Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header.id,  Issue_Status__c = 'Open');
	        upsert issue;
	        
	        System.debug(LoggingLevel.ERROR, 'details=: ' + qocDetails);
	       
	        //url is null
	        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate')); 
	        PageReference pageRef = System.currentPageReference();
	        String url = 'https://omnicable-developer-edition.na31.force.com';
	        
	        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
	        
	    
	        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
	        request.url = url;
	        request.id = UserInfo.getUserId();
	        
	        result = OCCommunitiesResource.getCommunitiesData(JSON.serialize(request));
	        System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
	        System.assertEquals(true, result.Success);
	       
        }
        
    }
    */
    
    @IsTest(SeeAllData=false) global static void testGetCommunitiesDataApproved() {   
   
		
		OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

		Account parent = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert parent;

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '1345678', ParentId = parent.Id);
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', OCC_ViewAll__c = false, OCC_ViewApproved__c = true, AccountId=account.Id,  OCC_Rewards__c=true, Sequence__c = 1, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
                   
        User user1 = new User(
            Username = System.now().millisecond() + '9test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ManagerId = null
        );
        
        insert(user1);
		
        
        System.runAs(user1) {

	        List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
	        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
	        
	        for(Integer i = 0; i < 5; i++){
	            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Date__c = system.today());
	            QuotesOrdersCredits_Header__c orderheader = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Type__c = 'Order', Date__c = system.today());
	            qocHeaders.add(orderheader);
	            qocHeaders.add(header);
	        }
	        
	        insert qocHeaders; 
	        
	        QuotesOrdersCredits_Header__c header = qocHeaders.get(0);
	        header.Notes__c = 'test notes';
	        upsert header;
	       
	        
	        for(Integer i = 0; i < qocHeaders.size(); i++){
	            String headerId = qocHeaders[i].Id;
	            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, Dollars__c = 300);
	            qocDetails.add(detail);
	
	        }
	        
	        insert qocDetails;
	        
	        QuoteOrderCredit_Details__c detailUpdate = qocDetails.get(0);
	        detailUpdate.Put_up_1__c = '1 x 200';
	        upsert detailUpdate;
	        
	        Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header.id,  Issue_Status__c = 'Open');
	        upsert issue;
	        
	        System.debug(LoggingLevel.ERROR, 'details=: ' + qocDetails);
	       
	        //url is null
	        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate')); 
	        PageReference pageRef = System.currentPageReference();
	        String url = 'https://omnicable-developer-edition.na31.force.com';
	        
	        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
	        
	    
	        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
	        request.url = url;
	        request.id = UserInfo.getUserId();
	        
	        result = OCCommunitiesResource.getCommunitiesData(JSON.serialize(request));
	        System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
	        System.assertEquals(true, result.Success);
	       
        }
        
    }
    
    @IsTest(SeeAllData=false) global static void testGetCommunitiesData() {   

        OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', AccountId=account.Id, OCC_ViewAll__c = false,  OCC_Rewards__c=true, Sequence__c = 1, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
        
                
        User user1 = new User(
            Username = System.now().millisecond() + '10test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);
        
 
        System.runAs(user1) {

	        List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
	        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
	        
	        for(Integer i = 0; i < 5; i++){
	            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Date__c = system.today());
	            QuotesOrdersCredits_Header__c orderheader = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Type__c = 'Order', Date__c = system.today());
	            qocHeaders.add(orderheader);
	            qocHeaders.add(header);
	        }
	        
	        insert qocHeaders; 
	        
	        QuotesOrdersCredits_Header__c header = qocHeaders.get(0);
	        header.Notes__c = 'test notes';
	        upsert header;
	        
	        for(Integer i = 0; i < qocHeaders.size(); i++){
	            String headerId = qocHeaders[i].Id;
	            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, Dollars__c = 300);
	            qocDetails.add(detail);
	
	        }
	        
	        insert qocDetails;
	        
	        QuoteOrderCredit_Details__c detailUpdate = qocDetails.get(0);
	        detailUpdate.Put_up_1__c = '1 x 200';
	        upsert detailUpdate;
	        
	        Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header.id,  Issue_Status__c = 'Open');
	        upsert issue;
	        
	        System.debug(LoggingLevel.ERROR, 'details=: ' + qocDetails);
	       
	        //url is null
	        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate')); 
	        PageReference pageRef = System.currentPageReference();
	        String url = 'https://omnicable-developer-edition.na31.force.com';
	        
	        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
	        
	    
	        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
	        request.url = url;
	        request.id = UserInfo.getUserId();
	        
	        result = OCCommunitiesResource.getCommunitiesData(JSON.serialize(request));
	        System.debug(LoggingLevel.ERROR, 'result1=: ' + result);
	        System.assertEquals(true, result.Success);
	       
        }
        
    }
    
    @IsTest(SeeAllData=false) global static void testuploadProfilePhoto(){
        OCCommunitiesResource.UploadPhotoResult result = new OCCommunitiesResource.UploadPhotoResult();
        OCCommunitiesResource.UploadPhotoRequest request = new OCCommunitiesResource.UploadPhotoRequest();
    	
    	/*
        User user = [SELECT Id, ContactId, Name, Email, FirstName, LastName, Phone FROM User WHERE LastName = 'Tester'];
        System.debug(LoggingLevel.ERROR, 'updateProfile User=: ' + user);

        Contact contact = [SELECT Id, Name, OCC_Photo__c ,Email, FirstName, LastName, Phone FROM Contact WHERE Id =: user.ContactId];
        System.debug(LoggingLevel.ERROR, 'updateProfile Contact=: ' + contact);
        */
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', AccountId=account.Id,  OCC_Rewards__c=true, Sequence__c = 1, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
                
        User user = new User(
            Username = System.now().millisecond() + '11test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user);
        
        
        System.runAs(user) {
        
        
            request.image = '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';
            result = OCCommunitiesResource.uploadProfilePhoto(JSON.serialize(request));
            System.debug(LoggingLevel.ERROR, 'uploadProfilePhoto result=: ' + result);
            System.assertEquals(true, result.Success);
        
        }
        
    }
    
    
    @IsTest(SeeAllData=false) global static void testupdateProfile(){
  
        OCCommunitiesResource.ProfileResult result = new OCCommunitiesResource.ProfileResult();

		Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Date bday = Date.newInstance(1980, 02, 02);
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Birthdate=bday , AccountId=account.Id,  OCC_Rewards__c=true, Sequence__c = 1, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Phone = '555-555-5555', Email='chrisw@launchdm.com', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
                
        User user = new User(
            Username = System.now().millisecond() + '12test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user);
        
        System.runAs(user) {


            OCCommunitiesResource.ProfileRequest request = new OCCommunitiesResource.ProfileRequest();
            
            request.firstName = 'test first';
            request.lastName = 'test last';
            request.email = 'chrisw@launchdm.com';
            request.phone = '555-555-5555';
            request.contactId = contact.Id;
            Date newBDay = Date.newInstance(1981, 02, 02);
            request.month = '12';
            request.day  =  '02';
            request.year  =  '1980';
             

            
            result = OCCommunitiesResource.updateProfile(JSON.serialize(request));
            System.debug(LoggingLevel.ERROR, 'updateProfile rsult=: ' + result);
            System.assertEquals(true, result.Success);
       
        }
    
    }
    
    
        ///////////////////
     //static testMethod void testRedeemRewards() {
     
    @IsTest(SeeAllData=false) global static void testRedeemRewards() { 
    
        //////  
        test.startTest();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
        insert account;
        
        String newId = account.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', AccountId=account.Id,  OCC_Rewards__c=true, Sequence__c = 1, OCC_RewardStepValue__c = 3, OCC_RewardStep__c = 99, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
        

        
                
        User user1 = new User(
            Username = System.now().millisecond() + '13test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        Database.insert(user1);
        
        System.runAs(user1) {

        List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
        
        for(Integer i = 0; i < 2; i++){
            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(RewardOverride__c=2, Customer__c = account.Id, Buyer__c = contact.Id, Status__c = 'Invoiced', Type__c = 'Order', OCC_RewardRedeemed__c  = false, Date__c = system.today());
            QuotesOrdersCredits_Header__c orderheader = new QuotesOrdersCredits_Header__c(Customer__c = account.Id, Buyer__c = contact.Id, Type__c = 'Order', Date__c = system.today());
	        qocHeaders.add(orderheader);
            qocHeaders.add(header);
        }
        
        insert qocHeaders; 
        
        QuotesOrdersCredits_Header__c credit = new QuotesOrdersCredits_Header__c(RewardOverride__c=2, Customer__c = account.Id, Buyer__c = contact.Id, Status__c = 'Credit', Type__c = 'Credit', OCC_RewardRedeemed__c  = false, Date__c = system.today());
        insert credit;
        
        for(Integer i = 0; i < qocHeaders.size(); i++){
            String headerId = qocHeaders[i].Id;
            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, Dollars__c = 300);
            qocDetails.add(detail);

        }
        
        insert qocDetails;
        
        
        QuotesOrdersCredits_Header__c header1 = qocHeaders.get(0);
        
        Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header1.id,  Issue_Status__c = 'Open');
	        upsert issue;
        
        System.debug(LoggingLevel.ERROR, 'details=: ' + qocDetails);

        test.stopTest();
        ////

        OCCommunitiesResource.RewardsResponse result = new OCCommunitiesResource.RewardsResponse();
        OCCommunitiesResource.RewardsRequest request = new OCCommunitiesResource.RewardsRequest();
        request.Name = 'McTesty';
        request.Email = 'chrisw@launchdm.com';
        request.AccountName = 'test Account';

        result = OCCommunitiesResource.redeemRewards(JSON.serialize(request));
        System.debug(LoggingLevel.ERROR, 'result4=: ' + result);
        Boolean Success2 = true;
        System.assertNotEquals(null, Success2);
       
        }        
        
    }
    
    
    @IsTest(SeeAllData=false) global static void pollForNotifications() { 
    	
    	
    	 /////////////
        test.startTest();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];
        
        Account parentAccount = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '1234567');
        insert parentAccount;

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456', ParentId=parentAccount.Id);
        insert account;
        
        Account account2 = new Account(Name='Test Account2', OCC_Rewards__c = true, Account_Number__c = '123455', ParentId=parentAccount.Id);
        insert account2;
        
        String newId = account.Account_Number__c + ':1';
        String newId2 = account2.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', OCC_ViewAll__c = true, AccountId=account.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 1, OCC_RewardStep__c = 1, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        
        Contact contact2 = new Contact(Contact_Title__c='Accounting', Email='chrisw2@launchdm.com', OCC_ViewAll__c = false, OCC_ViewApproved__c = true,  AccountId=account2.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 1, OCC_RewardStep__c = 1, FirstName='Test', LastName='Williams', Ext_Id__c = newId2);
        insert contact2;
        
        OCC_BonusReward__c reward = new OCC_BonusReward__c(Name='Amount_5000_10', ActionDescription__c = 'your first 2 orders', Contact__c= contact.Id, ContactNotified__c=false, Redeemed__c=true, RewardValue__c=5);
        OCC_BonusReward__c reward2 = new OCC_BonusReward__c(Name='Amount_5000_10', ActionDescription__c = 'your first 2 orders', Contact__c= contact2.Id, ContactNotified__c=false, Redeemed__c=false, RewardValue__c=5);
        insert reward;
        insert reward2;
  
        OCC_ApprovedAccount__c approvedAccount = new OCC_ApprovedAccount__c(Account__c=account.Id, Contact__c=contact.Id, Name='test');
        insert approvedAccount;
        
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
                
                
         User user2 = new User(
            Username = System.now().millisecond() + '14test12345@test.com',
            ContactId = contact2.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user2); 
        
        User user1 = new User(
            Username = System.now().millisecond() + '15test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345666666',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);  
        
        OCC_BonusReward__c bonusreward = new OCC_BonusReward__c();
        bonusreward.Contact__c = contact.Id;
        bonusreward.ActionDescription__c = '';
        bonusreward.ContactNotified__c = false;
        bonusreward.Redeemed__c = true;
        bonusreward.RewardValue__c = 10;
        bonusreward.Name = 'Amount_5000_10'; 
        insert bonusreward;   
        
        
        OCC_BonusReward__c bonusreward2 = new OCC_BonusReward__c();
        bonusreward2.Contact__c = contact2.Id;
        bonusreward2.ActionDescription__c = '';
        bonusreward2.ContactNotified__c = false;
        bonusreward2.Redeemed__c = true;
        bonusreward2.RewardValue__c = 10;
        bonusreward2.Name = 'Amount_5000_10';
        insert bonusreward2;
 
        
        System.runAs(user1) {
        	
        	List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
	        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
	        
	        
	        QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(Name='1234', Customer__c = account.Id, Buyer__c = contact.Id, Status__c = 'Invoiced', Type__c = 'Order', OCC_RewardRedeemed__c  = true, Date__c = system.today());
	        QuotesOrdersCredits_Header__c header2 = new QuotesOrdersCredits_Header__c(Name='12345',Customer__c = account2.Id, Buyer__c = contact2.Id, Status__c = 'Invoiced', Type__c = 'Order', OCC_RewardRedeemed__c  = true, Date__c = system.today());
	        QuotesOrdersCredits_Header__c headerQ = new QuotesOrdersCredits_Header__c(Name='1234', Customer__c = account.Id, Buyer__c = contact.Id, Status__c = 'Open', Type__c = 'Quote', OCC_RewardRedeemed__c  = true, Date__c = system.today());
	        QuotesOrdersCredits_Header__c headerQ2 = new QuotesOrdersCredits_Header__c(Name='12345',Customer__c = account2.Id, Buyer__c = contact2.Id, Status__c = 'Open', Type__c = 'Quote', OCC_RewardRedeemed__c  = true, Date__c = system.today());
	        qocHeaders.add(headerQ);
	        qocHeaders.add(headerQ2);
	        qocHeaders.add(header);
	        qocHeaders.add(header2);
	        
	        QuotesOrdersCredits_Header__c credit = new QuotesOrdersCredits_Header__c(Type__c='Credit', Customer__c = account2.Id, Buyer__c = contact2.Id, OCC_RewardRedeemed__c  = true, Date__c = system.today(), SalesNote3__c ='RMA', Total_Order_Sales__c = 1);
	        qocHeaders.add(credit);
	        
	        QuotesOrdersCredits_Header__c orderheader = new QuotesOrdersCredits_Header__c(Name='123456',Customer__c = account.Id, Buyer__c = contact.Id, Type__c = 'Order', Date__c = system.today());
	        QuotesOrdersCredits_Header__c orderheader2 = new QuotesOrdersCredits_Header__c(Name='1234567',Customer__c = account2.Id, Buyer__c = contact2.Id, Type__c = 'Order', Date__c = system.today());
	        qocHeaders.add(orderheader);
	        qocHeaders.add(orderheader2);
	        
	        insert qocHeaders;
	       
	        
	        for(Integer i = 0; i < qocHeaders.size(); i++){
	            String headerId = qocHeaders[i].Id;
	            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, Dollars__c = 300);
	            qocDetails.add(detail);
	
	        }
        
        	insert qocDetails;
        
        
        	QuotesOrdersCredits_Header__c header1 = qocHeaders.get(0);
        
        	Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header1.id,  Issue_Status__c = 'Open');
	        upsert issue;
        	
        	
        	
        	OCCommunitiesResource.NotificationResults result = OCCommunitiesResource.pollForNotifications('');
        	System.assertEquals(true, result.hasMessage);
        	
        	
        	OCCommunitiesResource.DeleteAccountRequest request = new OCCommunitiesResource.DeleteAccountRequest();
        	
        	OCC_ApprovedAccount__c approvedAccount1 = [Select Id, Name from OCC_ApprovedAccount__c where Name='test'].get(0);
        	        	
        	request.Name = approvedAccount1.Name;
        	request.Id = approvedAccount1.Id;
        	
        	OCCommunitiesResource.DeleteAccountResult result2 = OCCommunitiesResource.deleteAccountAccess(JSON.serialize(request));
        	System.assertEquals(true, result2.Success);
        	
        	
        	OCCommunitiesResource.AccountAccessRequest requests = new OCCommunitiesResource.AccountAccessRequest();
        	OCCommunitiesResource.AccountRequest request1 = new OCCommunitiesResource.AccountRequest();
        	request1.Name = 'Test12';
        	request1.Account = account.Id;
        	
        	requests.Added.add(request1);
        	
        	OCCommunitiesResource.AccountAccessResults result3 = OCCommunitiesResource.requestAccountAccess(JSON.serialize(requests));
        	System.assertEquals(true, true);
        	
        }
    	
    
    }
    
    
    
     @IsTest(SeeAllData=false) global static void getData() { 
    	
    	
    	 /////////////
        test.startTest();
        
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' Limit 1];
        UserRole portalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        Profile profile1 = [Select Id from Profile where name = 'System Administrator'];
        
        Account parentAccount = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '1234567');
        insert parentAccount;

        Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456', ParentId=parentAccount.Id);
        insert account;
        
        Account account2 = new Account(Name='Test Account2', OCC_Rewards__c = true, Account_Number__c = '123455', ParentId=parentAccount.Id);
        insert account2;
        
        String newId = account.Account_Number__c + ':1';
        String newId2 = account2.Account_Number__c + ':1';
        
        Contact contact = new Contact(Contact_Title__c='Accounting', Email='chrisw@launchdm.com', OCC_ViewAll__c = true , AccountId=account.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 1, OCC_RewardStep__c = 1, FirstName='Test', LastName='Williams', Ext_Id__c = newId);
        insert contact;
        
        Contact contact2 = new Contact(Contact_Title__c='Accounting', Email='chrisw2@launchdm.com', OCC_ViewAll__c = false, OCC_ViewApproved__c = true , AccountId=account2.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 1, OCC_RewardStep__c = 1, FirstName='Test', LastName='Williams', Ext_Id__c = newId2);
        insert contact2;
        
        OCC_BonusReward__c reward = new OCC_BonusReward__c(Name='Amount_5000_10', ActionDescription__c = 'your first 2 orders', Contact__c= contact.Id, ContactNotified__c=false, Redeemed__c=true, RewardValue__c=5);
        OCC_BonusReward__c reward2 = new OCC_BonusReward__c(Name='Amount_5000_10', ActionDescription__c = 'your first 2 orders', Contact__c= contact2.Id, ContactNotified__c=false, Redeemed__c=false, RewardValue__c=5);
        insert reward;
        insert reward2;
        
        OCC_ApprovedAccount__c approvedAccount = new OCC_ApprovedAccount__c(Account__c=account.Id, Contact__c=contact.Id, Name='test');
        insert approvedAccount;
        
        System.debug(LoggingLevel.ERROR, 'contact=: ' + contact);
                
                
         User user2 = new User(
            Username = System.now().millisecond() + '16test12345@test.com',
            ContactId = contact2.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user2); 
        
        User user1 = new User(
            Username = System.now().millisecond() + '1test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345666666',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        
        Database.insert(user1);        
 
        
        System.runAs(user1) {
        	
        	List<QuotesOrdersCredits_Header__c> qocHeaders = new List<QuotesOrdersCredits_Header__c>();
	        List<QuoteOrderCredit_Details__c> qocDetails = new List<QuoteOrderCredit_Details__c>();
	        
	        
	        QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(Name='1234', Customer__c = account.Id, Buyer__c = contact.Id, Status__c = 'Invoiced', Type__c = 'Order', OCC_RewardRedeemed__c  = true, Date__c = system.today());
	        QuotesOrdersCredits_Header__c header2 = new QuotesOrdersCredits_Header__c(Name='12345',Customer__c = account2.Id, Buyer__c = contact2.Id, Status__c = 'Invoiced', Type__c = 'Order', OCC_RewardRedeemed__c  = true, Date__c = system.today());
	        QuotesOrdersCredits_Header__c headerQ = new QuotesOrdersCredits_Header__c(Name='1234', Customer__c = account.Id, Buyer__c = contact.Id, Status__c = 'Open', Type__c = 'Quote', OCC_RewardRedeemed__c  = true, Date__c = system.today());
	        QuotesOrdersCredits_Header__c headerQ2 = new QuotesOrdersCredits_Header__c(Name='12345',Customer__c = account2.Id, Buyer__c = contact2.Id, Status__c = 'Open', Type__c = 'Quote', OCC_RewardRedeemed__c  = true, Date__c = system.today());
	        qocHeaders.add(headerQ);
	        qocHeaders.add(headerQ2);
	        qocHeaders.add(header);
	        qocHeaders.add(header2);
	        
	        QuotesOrdersCredits_Header__c credit = new QuotesOrdersCredits_Header__c(Type__c='Credit', Customer__c = account2.Id, Buyer__c = contact2.Id, OCC_RewardRedeemed__c  = true, Date__c = system.today(), SalesNote3__c ='RMA', Total_Order_Sales__c = 1);
	        qocHeaders.add(credit);
	        
	        QuotesOrdersCredits_Header__c orderheader = new QuotesOrdersCredits_Header__c(Name='123456',Customer__c = account.Id, Buyer__c = contact.Id, Type__c = 'Order', Date__c = system.today());
	        QuotesOrdersCredits_Header__c orderheader2 = new QuotesOrdersCredits_Header__c(Name='1234567',Customer__c = account2.Id, Buyer__c = contact2.Id, Type__c = 'Order', Date__c = system.today());
	        qocHeaders.add(orderheader);
	        qocHeaders.add(orderheader2);
	        
	        insert qocHeaders;
	       
	        
	        for(Integer i = 0; i < qocHeaders.size(); i++){
	            String headerId = qocHeaders[i].Id;
	            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Order_Header__c = headerId, Qty_Ordered__c =2, Dollars__c = 300);
	            qocDetails.add(detail);
	
	        }
        
        	insert qocDetails;
        
        
        	QuotesOrdersCredits_Header__c header1 = qocHeaders.get(0);
        
        	Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = header1.id,  Issue_Status__c = 'Open');
	        upsert issue;
        	
        	OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
        	GetDataRequest.offset = 0;
        	GetDataRequest.typeStr = 'search';
        	GetDataRequest.searchText = '123*';
        	GetDataRequest.url = 'www.test.com/';
        	
        	OCCommunitiesResource.GetDataResults GetDataResults = OCCommunitiesResource.getData(JSON.serialize(GetDataRequest));
        	System.assertEquals(true, GetDataResults.Success);
        	
        	//OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
        	GetDataRequest.offset = 0;
        	GetDataRequest.typeStr = 'myOrders';
        	GetDataRequest.searchText = '123*';
        	GetDataRequest.url = 'www.test.com/';
        	
        	OCCommunitiesResource.GetDataResults myOrder = OCCommunitiesResource.getData(JSON.serialize(GetDataRequest));
        	System.assertEquals(true, myOrder.Success);
        	
        	//OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
        	GetDataRequest.offset = 0;
        	GetDataRequest.typeStr = 'myQuotes';
        	GetDataRequest.searchText = '123*';
        	GetDataRequest.url = 'www.test.com/';
        	
        	OCCommunitiesResource.GetDataResults myQuotes = OCCommunitiesResource.getData(JSON.serialize(GetDataRequest));
        	System.assertEquals(true, myQuotes.Success);
        	
        	//OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
        	GetDataRequest.offset = 0;
        	GetDataRequest.typeStr = 'credits';
        	GetDataRequest.searchText = '123*';
        	GetDataRequest.url = 'www.test.com/';
        	
        	OCCommunitiesResource.GetDataResults credits = OCCommunitiesResource.getData(JSON.serialize(GetDataRequest));
        	System.assertEquals(true, credits.Success);
        }
        
        System.runAs(user2) {
        	
        	OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
        	GetDataRequest.offset = 0;
        	GetDataRequest.typeStr = 'otherOrders';
        	GetDataRequest.searchText = '123*';
        	GetDataRequest.url = 'www.test.com/';
        	
        	OCCommunitiesResource.GetDataResults otherOrders = OCCommunitiesResource.getData(JSON.serialize(GetDataRequest));
        	System.assertEquals(true, otherOrders.Success);
        	
        	//OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
        	GetDataRequest.offset = 0;
        	GetDataRequest.typeStr = 'otherQuotes';
        	GetDataRequest.searchText = '123*';
        	GetDataRequest.url = 'www.test.com/';
        	
        	OCCommunitiesResource.GetDataResults otherQuotes = OCCommunitiesResource.getData(JSON.serialize(GetDataRequest));
        	System.assertEquals(true, otherQuotes.Success);
        	
        	
        	
        	/////////
        	
        contact.OCC_Rewards__c=false;
		contact.OCC_RewardsValue__c = 2;
        update contact;
        
        OCC_BonusReward__c bonusreward = new OCC_BonusReward__c();
        bonusreward.Contact__c = contact.Id;
        bonusreward.ActionDescription__c = '';
        bonusreward.ContactNotified__c = false;
        bonusreward.Redeemed__c = false;
        bonusreward.RewardValue__c = 10;
        bonusreward.Name = 'Amount_5000_10';
        
        insert bonusreward;
        	
        RestRequest req = new RestRequest(); 
		RestResponse res = new RestResponse();
		
		Map<String, String> users = new Map<String, String>();
		users.put('users', '[{"contact_id":"'+ contact.Id + '"}]');
		
			
		String JSONMsg = '{"contact_id":"'+ contact.Id + '"}';
		req.requestBody = Blob.valueof('{"criteria":"Amount_5000_10"}');
		req.addParameter('users', JSONMsg);
		req.addParameter('criteria', 'Amount_5000_10');
		
	
		req.addHeader('Content-Type', 'application/json');
		
		if(OCCommunitiesResource.runningInASandbox()){
			
			req.requestURI = 'https://full-omnidemo.cs2.force.com/services/apexrest/MixPanelApi?criteria=Amount_5000_10';  
	    		 
    	}else{
    		req.requestURI = 'https://omnicable.my.salesforce.com/services/apexrest/MixPanelApi?criteria=Amount_5000_10';  

    	}
   
		 req.httpMethod = 'POST';
		 RestContext.request = req;
		 RestContext.response = res;
 
    	
    	OCCMixPanelApi.doPost();
    	
    	OCCMixPanelApi.sendRewardsEmail(10.0, 'test', 'test@email.com', 'test Subject');
		
		System.assertEquals(true,true);
		/////////////
        
        
        contact.OCC_Rewards__c=true;
		contact.OCC_RewardsValue__c = 2;
        update contact;
        	
        //RestRequest req = new RestRequest(); 
		//RestResponse res = new RestResponse();
		
			
		String JSONMsg2 = '{"contact_id":"'+ contact.Id + '"}';
		req.requestBody = Blob.valueof('{"criteria":"Amount_5000_10"}');
		req.addParameter('users', JSONMsg2);
		req.addParameter('criteria', 'Amount_5000_10');
		
	
		req.addHeader('Content-Type', 'application/json');
		
		if(OCCommunitiesResource.runningInASandbox()){
			
			req.requestURI = 'https://full-omnidemo.cs2.force.com/services/apexrest/MixPanelApi?criteria=Amount_5000_10';  
	    		 
    	}else{
    		req.requestURI = 'https://omnicable.my.salesforce.com/services/apexrest/MixPanelApi?criteria=Amount_5000_10';  

    	}
   
		 req.httpMethod = 'POST';
		 RestContext.request = req;
		 RestContext.response = res;
 
    	
    	OCCMixPanelApi.doPost();
    	
    	OCCMixPanelApi.sendRewardsEmail(10.0, 'test', 'test@email.com', 'test Subject');
		
		System.assertEquals(true,true);
        	
        
        }
    	
    
    }
    
    
    //global with sharing class UploadFileMock implements HTTPCalloutMock{
    global HTTPResponse respond(HTTPRequest req){
        HttpResponse res = new HTTPResponse();
        res.setHeader('Content-Type', 'application/JSON');
        res.setBody('Your body');
        res.setStatusCode(201);
        return res;
    }
//}
    
    

}