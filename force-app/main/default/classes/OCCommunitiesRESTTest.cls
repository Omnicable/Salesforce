@isTest
public class OCCommunitiesRESTTest {
    
    @testSetup static void setup() {
        User user = [SELECT Id, Name FROM User WHERE Profile.Name = 'Omni System Admin' AND IsActive = true LIMIT 1];
        System.runAs(user) {
            
            Account account = new Account(Name='Test Account', OCC_Rewards__c = true, Account_Number__c = '123456');
            insert account;
            
            String newId = account.Account_Number__c + ':1';
            Contact contact = new Contact(LastName='My Contact', Contact_Title__c='Accounting', Email='test@omnicable.com', OCC_ViewAll__c =false, OCC_RewardsValue__c=1 ,AccountId=account.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 1, OCC_RewardStep__c = 1, FirstName='Test', Ext_Id__c = newId);
            insert contact;
            
            
            Account parentAccount = new Account(Name='Test Parent Account', OCC_Rewards__c = true, Account_Number__c = '1111111');
            insert parentAccount;
            String newId2 = parentAccount.Account_Number__c + ':1';
            
            Contact otherContact = new Contact(LastName='Other Contact', Contact_Title__c='Accounting', Email='test2@omnicable.com', OCC_ViewAll__c = true, OCC_ViewApproved__c = true , AccountId=parentAccount.Id, Sequence__c = 1, OCC_Rewards__c=true, OCC_RewardStepValue__c = 1, OCC_RewardStep__c = 1, FirstName='Test', Ext_Id__c = newId2);
            insert otherContact;
            
            createData();
        }
        
    }
    
    private static void createData(){
        Contact contact = [SELECT id FROM Contact WHERE LastName ='My Contact'LIMIT 1];
        Account account = [SELECT id FROM Account WHERE Name ='Test Account' LIMIT 1];
        
        Contact otherContact = [SELECT id FROM Contact WHERE LastName='Other Contact' LIMIT 1];
        Account otherAccount = [SELECT id FROM Account WHERE Name = 'Test Parent Account' LIMIT 1];
        
        
        Spec_Sheet__c spec = new Spec_Sheet__c(Name = 'SpecSheet');
        insert spec;
        
        Part_Numbers__c part = new Part_Numbers__c(Name='Test_Part', Spec_Sheet__c=spec.Id);
        insert part;
        
        Alternative_Part_Number__c altPart = new Alternative_Part_Number__c(Account__c=account.Id, Part_Numbers__c=part.Id, Name='Test');
        insert altPart;
        
        Delivery_Address__c deliveryAddresses = new Delivery_Address__c(Account__c=account.Id, Name='Test Delivery Address', City__c='Test City', State__c='Test State', Street_Address__c='Test Street Address', Zip_Code__c='Test Zip Code');
        insert deliveryAddresses;
        
        
        List<QuotesOrdersCredits_Header__c> allHeaders = new List<QuotesOrdersCredits_Header__c>();
        //Unredeemed Invoiced Order with Override
        QuotesOrdersCredits_Header__c invoicedOrderOveride = new QuotesOrdersCredits_Header__c(Name='999999', RewardOverride__c=10, Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Status__c='Invoiced', Type__c='Order', Sub_Type__c='Blanket', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00);
        allHeaders.add(invoicedOrderOveride);
        QuotesOrdersCredits_Header__c invoicedOrder = new QuotesOrdersCredits_Header__c(Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Status__c='Invoiced', Type__c='Order', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00);
        allHeaders.add(invoicedOrder);
        QuotesOrdersCredits_Header__c returnedCreditOveride = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Status__c='Invoiced', Type__c='Credit', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00, SalesNote3__c ='RMA');
        allHeaders.add(returnedCreditOveride);
        QuotesOrdersCredits_Header__c returnedCredit = new QuotesOrdersCredits_Header__c(Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Status__c='Invoiced', Type__c='Credit', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00, SalesNote3__c ='RMA');
        allHeaders.add(returnedCredit);
        QuotesOrdersCredits_Header__c myQuote = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Type__c='RFQ', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00);
        allHeaders.add(myQuote);
        QuotesOrdersCredits_Header__c otherQuote = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = otherContact.Id, Date__c = system.today(), Type__c='Quote', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00);
        allHeaders.add(otherQuote);
        QuotesOrdersCredits_Header__c otherOrder = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = otherContact.Id, Date__c = system.today(), Type__c='Order', Status__c='Invoiced', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00);
        allHeaders.add(otherOrder);
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
        
        // insert invoicedOrderOveride;
        // insert invoicedOrderDetailsOveride;
        
        // //Unredeemed Invoiced Order without Override
        
        // insert invoicedOrderDetails;
        
        // //Undredeemed Credit with Override
        // insert returnedCreditOveride;
        // insert returnedCreditDetailsOveride;
        
        // //Undredeemed Credit with Override
        // insert returnedCredit;
        // insert returnedCreditDetails;
        
        //Select Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c , TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Quote' OR Type__c = 'RFQ') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 10 Offset :offset
        // QuotesOrdersCredits_Header__c myQuote = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = contact.Id, Date__c = system.today(), Type__c='RFQ', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00);
        // insert myQuote;
        
        //Other Quotes
        // QuotesOrdersCredits_Header__c otherQuote = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = otherContact.Id, Date__c = system.today(), Type__c='Quote', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00);
        // insert otherQuote;
        
        //Other Order
        // QuotesOrdersCredits_Header__c otherOrder = new QuotesOrdersCredits_Header__c(RewardOverride__c=10, Customer__c=account.Id, Buyer__c = otherContact.Id, Date__c = system.today(), Type__c='Order', Status__c='Invoiced', OCC_RewardRedeemed__c=false, New_Total_Order_Sales__c=100.00, Total_Order_Sales__c=100.00);
        // insert otherOrder;
        
        
        //Content Document Link
        ContentVersion contentVersion = new ContentVersion(Title = 'Cables', PathOnClient = 'Cables.jpg', VersionData = Blob.valueOf('Test Content'), IsMajorVersion = true);
        insert contentVersion;
        List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.ContentDocumentId = documents[0].Id;
        cdl.shareType = 'V';
        cdl.LinkedEntityId = invoicedOrderOveride.Id;
        insert cdl;
        
        //Create Bonus Reward
        OCC_BonusReward__c bonus = new OCC_BonusReward__c(Name='Bonus', Contact__c=contact.Id, ActionDescription__c='', RewardValue__c=2, Redeemed__c=true, ContactNotified__c=false);
        insert bonus;
        
        //Pending Issue
        Pending_Issue__c issue = new Pending_Issue__c(Account__c = account.Id, Order__c = invoicedOrderOveride.id,  Issue_Status__c = 'Open');
        upsert issue;
        
    }
    
    @IsTest private static void testGetRewards() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/rewards/' + contact.Id;  //Request URL
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response= res;
        
        Test.startTest();
        OCCommunitiesResource.RewardsResponse rr = OCCommunitiesREST_Rewards.getRewards();
        OCCommunitiesResource.RewardsResponse rr1 = OCCommunitiesResource.getRewards();
        
        System.assertNotEquals(rr, null);
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    @IsTest private static void testSendRFQOrder() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/sendrfq/' + contact.Id;   //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        OCCommunitiesResource.RFQRequest request = new OCCommunitiesResource.RFQRequest();
        
        request.RFQData = 'Test Email Body';
        request.typeStr = 'Order';
        List<OCCommunitiesResource.ImageData> ImageDataList = new List<OCCommunitiesResource.ImageData>();
        OCCommunitiesResource.ImageData imData = new OCCommunitiesResource.ImageData();
        
        imData.image = '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';
        imData.name = 'test';
        ImageDataList.add(imData);
        
        request.ImageData = ImageDataList;
        request.AccountNumber = account.Account_Number__c;
        Test.startTest();
        OCCommunitiesResource.RFQResponse rr = OCCommunitiesREST_Sendrfq.sendRFQ(request.RFQData,request.Id,request.image,request.imageData,request.imageTitle,request.typeStr,request.AccountNumber);
        OCCommunitiesResource.RFQResponse rr1 = OCCommunitiesResource.sendRFQ(JSON.serialize(request));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
        
    }
    
    @IsTest private static void testSendRFQRFQ() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/sendrfq/' + contact.Id;   //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        OCCommunitiesResource.RFQRequest request = new OCCommunitiesResource.RFQRequest();
        
        request.RFQData = 'Test Email Body';
        request.typeStr = 'RFQ';
        List<OCCommunitiesResource.ImageData> ImageDataList = new List<OCCommunitiesResource.ImageData>();
        OCCommunitiesResource.ImageData imData = new OCCommunitiesResource.ImageData();
        
        imData.image = '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';
        imData.name = 'test';
        ImageDataList.add(imData);
        
        request.ImageData = ImageDataList;
        
        Test.startTest();
        OCCommunitiesResource.RFQResponse rr = OCCommunitiesREST_Sendrfq.sendRFQ(request.RFQData,request.Id,request.image,request.imageData,request.imageTitle,request.typeStr,request.AccountNumber);
        OCCommunitiesResource.RFQResponse rr1 = OCCommunitiesResource.sendRFQ(JSON.serialize(request));
        //            System.assertEquals(rr.Success, true);  TO FIX
        
        Test.stopTest();
        
    }
    
    @IsTest private static void testSendRFQRMA() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/sendrfq/' + contact.Id;   //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        OCCommunitiesResource.RFQRequest request = new OCCommunitiesResource.RFQRequest();
        
        request.RFQData = 'Test Email Body';
        request.typeStr = 'RMA';
        List<OCCommunitiesResource.ImageData> ImageDataList = new List<OCCommunitiesResource.ImageData>();
        OCCommunitiesResource.ImageData imData = new OCCommunitiesResource.ImageData();
        
        imData.image = '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';
        imData.name = 'test';
        ImageDataList.add(imData);
        
        request.ImageData = ImageDataList;
        
        Test.startTest();
        OCCommunitiesResource.RFQResponse rr = OCCommunitiesREST_Sendrfq.sendRFQ(request.RFQData,request.Id,request.image,request.imageData,request.imageTitle,request.typeStr,request.AccountNumber);
        OCCommunitiesResource.RFQResponse rr1 = OCCommunitiesResource.sendRFQ(JSON.serialize(request));
        Test.stopTest();
    }
    
    @IsTest private static void testSendEmail() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/sendemail/' + contact.Id;   //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        OCCommunitiesResource.EmailRequest request = new OCCommunitiesResource.EmailRequest();
        
        request.Message = 'Test Email Body';
        request.Email = 'chrisw@launchd.com';
        request.Subject = 'test Subject';
        
        Test.startTest();
        OCCommunitiesResource.RFQResponse rr = OCCommunitiesREST_SendEmail.sendEmail(request.Email,request.Subject,request.Email);
        OCCommunitiesResource.RFQResponse rr1 = OCCommunitiesResource.sendEmail(JSON.serialize(request));
        System.debug(JSON.serialize(rr));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    @IsTest private static void testFindQOCById() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/qoc/' + contact.Id; //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        // // QuotesOrdersCredits_Header__c header = qocHeaders.get(0);
        QuotesOrdersCredits_Header__c header = [Select Id, Notes__c, Name from QuotesOrdersCredits_Header__c WHERE Name='999999'];
        header.Notes__c = 'test notes';
        
        //url is null
        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate'));
        PageReference pageRef = System.currentPageReference();
        String url = 'https://omnicable-developer-edition.na31.force.com';
        
        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
        
        
        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
        request.url = url;
        request.id = header.Id;
        
        Test.startTest();
        OCCommunitiesResource.QOCDataResult rr = OCCommunitiesREST_QOC.findQOCById(request.id,request.url);
        OCCommunitiesResource.QOCDataResult rr1 = OCCommunitiesResource.findQOCById(JSON.serialize(request));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    
    @IsTest private static void testGetCommunitiesDataViewAll() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/communitiesdata/' + contact.Id; //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate'));
        PageReference pageRef = System.currentPageReference();
        String url = 'https://omnicable-developer-edition.na31.force.com';
        
        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
        
        
        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
        request.url = url;
        request.id = UserInfo.getUserId();
        
        Test.startTest();
        OCCommunitiesResource.QOCDataResult rr = OCCommunitiesREST_Communitiesdata.getCommunitiesData(request.id,request.url);
        OCCommunitiesResource.QOCDataResult rr1 = OCCommunitiesResource.getCommunitiesData(JSON.serialize(request));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    @IsTest private static void testGetCommunitiesDataApproved() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/communitiesdata/' + contact.Id; //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        //url is null
        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate'));
        PageReference pageRef = System.currentPageReference();
        String url = 'https://omnicable-developer-edition.na31.force.com';
        
        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
        
        
        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
        request.url = url;
        request.id = UserInfo.getUserId();
        
        Test.startTest();
        OCCommunitiesResource.QOCDataResult rr = OCCommunitiesREST_Communitiesdata.getCommunitiesData(request.id,request.url);
        OCCommunitiesResource.QOCDataResult rr1 = OCCommunitiesResource.getCommunitiesData(JSON.serialize(request));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    @IsTest private static void testGetCommunitiesData() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/communitiesdata/' + contact.Id; //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        //url is null
        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate'));
        PageReference pageRef = System.currentPageReference();
        String url = 'https://omnicable-developer-edition.na31.force.com';
        
        System.debug(LoggingLevel.ERROR, 'url=: ' + url);
        
        
        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
        request.url = url;
        request.id = UserInfo.getUserId();
        
        Test.startTest();
        OCCommunitiesResource.QOCDataResult rr = OCCommunitiesREST_Communitiesdata.getCommunitiesData(request.id,request.url);
        OCCommunitiesResource.QOCDataResult rr1 = OCCommunitiesResource.getCommunitiesData(JSON.serialize(request));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    @IsTest private static void testGetInitialData() {
        
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/communitiesdata/' + contact.Id; //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        Test.setCurrentPageReference(new PageReference('Page.OmniCableTemplate'));
        PageReference pageRef = System.currentPageReference();
        String url = 'https://omnicable-developer-edition.na31.force.com';
        
        OCCommunitiesResource.QOCRequest request = new OCCommunitiesResource.QOCRequest();
        request.url = url;
        request.id = UserInfo.getUserId();
        
        Test.startTest();
        OCCommunitiesResource.QOCDataResult rr =  OCCommunitiesResourceHelper.getInitialData(request, contact.Id);
        OCCommunitiesResource.QOCDataResult rr1 = OCCommunitiesResource.getInitialData(JSON.serialize(request));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    @IsTest private static void testUploadProfilePhoto() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/profilePhoto/' + contact.Id; //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        OCCommunitiesResource.UploadPhotoRequest request = new OCCommunitiesResource.UploadPhotoRequest();
        request.image = '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';
        
        Test.startTest();
        OCCommunitiesResource.UploadPhotoResult rr = OCCommunitiesREST_ProfilePhoto.uploadProfilePhoto(request.image,request.title);
        OCCommunitiesResource.UploadPhotoResult rr1 = OCCommunitiesResource.uploadProfilePhoto(JSON.serialize(request));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    @IsTest private static void testUpdateProfile() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/profile/' + contact.Id;  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
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
        
        Test.startTest();
        OCCommunitiesResource.ProfileResult rr = OCCommunitiesREST_Profile.updateProfile(request.firstName,request.lastName,request.email,request.phone,request.month,request.day,request.year);
        OCCommunitiesResource.ProfileResult rr1 = OCCommunitiesResource.updateProfile(JSON.serialize(request));
        //        System.assertEquals(rr.Success, true); TO FIX
        Test.stopTest();
    }
    
    @IsTest private static void testRedeemRewards() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/redeemrewards/' + contact.Id;  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        OCCommunitiesResource.RewardsResponse result = new OCCommunitiesResource.RewardsResponse();
        OCCommunitiesResource.RewardsRequest request = new OCCommunitiesResource.RewardsRequest();
        request.Name = 'McTesty';
        request.Email = 'chrisw@launchdm.com';
        request.AccountName = 'test Account';
        
        Test.startTest();
        OCCommunitiesResource.RewardsResponse rr = OCCommunitiesREST_RedeemRewards.redeemRewards(request.Name,request.Email,request.AccountName);
        OCCommunitiesResource.RewardsResponse rr1 = OCCommunitiesResource.redeemRewards(JSON.serialize(request));
        System.assertEquals(rr.Success, true);
        Test.stopTest();
    }
    
    @IsTest private static void pollForNotifications() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/pollfornotifications/' + contact.Id;  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        
        Test.startTest();
        OCCommunitiesResource.NotificationResults result = OCCommunitiesREST_PollForNotifications.pollForNotifications();
        System.assertEquals(true, result.hasMessage);
        Test.stopTest();
    }
    
    @IsTest private static void getData() {
        
        User user = [SELECT Id, Name FROM User WHERE Profile.Name = 'Omni System Admin'  AND IsActive = true LIMIT 1];
        System.runAs(user) {
            
            Contact contact = [SELECT id FROM Contact LIMIT 1];
            contact.OCC_ViewAll__c = true;
            update contact;
            Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
            
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            
            req.requestURI = '/services/apexrest/occommunities/v1/getdata/' + contact.Id;  //Request URL
            req.httpMethod = 'POST';//HTTP Request Type
            RestContext.request = req;
            RestContext.response= res;
            
            Test.startTest();
            OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'search';
            GetDataRequest.searchText = 'cont';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults GetDataResults = OCCommunitiesREST_GetData.getData(GetDataRequest.offset,GetDataRequest.typeStr,GetDataRequest.searchText,GetDataRequest.url);
            System.assertEquals(true, GetDataResults.Success);
            
            //OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'myOrders';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults myOrder = OCCommunitiesREST_GetData.getData(GetDataRequest.offset,GetDataRequest.typeStr,GetDataRequest.searchText,GetDataRequest.url);
            System.assertEquals(true, myOrder.Success);
            
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'otherOrders';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults otherOrders = OCCommunitiesREST_GetData.getData(GetDataRequest.offset,GetDataRequest.typeStr,GetDataRequest.searchText,GetDataRequest.url);
            System.assertEquals(true, otherOrders.Success);
            
            //OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'myQuotes';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults myQuotes = OCCommunitiesREST_GetData.getData(GetDataRequest.offset,GetDataRequest.typeStr,GetDataRequest.searchText,GetDataRequest.url);
            System.assertEquals(true, myQuotes.Success);
            
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'otherQuotes';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults otherQuotes = OCCommunitiesREST_GetData.getData(GetDataRequest.offset,GetDataRequest.typeStr,GetDataRequest.searchText,GetDataRequest.url);
            System.assertEquals(true, otherQuotes.Success);
            
            //OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'credits';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults credits = OCCommunitiesREST_GetData.getData(GetDataRequest.offset,GetDataRequest.typeStr,GetDataRequest.searchText,GetDataRequest.url);
            OCCommunitiesResource.GetDataResults rr1 = OCCommunitiesResource.getData(JSON.serialize(GetDataRequest));
            System.assertEquals(true, credits.Success);
            Test.stopTest();
        }
    }
    
    /*
    @IsTest private static void getDataPortal() {
        
        User user = [SELECT Id, Name FROM User WHERE Profile.Name = 'Omni System Admin' AND Name = 'John Dean' AND IsActive = true LIMIT 1];
        System.runAs(user) {
            
            Contact contact = [SELECT id FROM Contact LIMIT 1];
            contact.OCC_ViewAll__c = true;
            update contact;
            Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
            
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            
            req.requestURI = '/services/apexrest/occommunities/v1/getdata/' + contact.Id;  //Request URL
            req.httpMethod = 'POST';//HTTP Request Type
            RestContext.request = req;
            RestContext.response= res;
            
            Test.startTest();
            OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'search';
            GetDataRequest.searchText = 'cont';
            GetDataRequest.url = 'www.test.com/';
            
            System.debug('GetDataRequest: ' + GetDataRequest);
            OCCommunitiesResource.GetDataResults GetDataResults = OCCommunitiesResource.getDataPortal(JSON.serialize(GetDataRequest));
            System.assertEquals(true, GetDataResults.Success);
            
            //OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'myOrders';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults myOrder = OCCommunitiesResource.getDataPortal(JSON.serialize(GetDataRequest));
            System.assertEquals(true, myOrder.Success);
            
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'otherOrders';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults otherOrders = OCCommunitiesResource.getDataPortal(JSON.serialize(GetDataRequest));
            System.assertEquals(true, otherOrders.Success);
            
            //OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'myQuotes';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults myQuotes = OCCommunitiesResource.getDataPortal(JSON.serialize(GetDataRequest));
            System.assertEquals(true, myQuotes.Success);
            
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'otherQuotes';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults otherQuotes = OCCommunitiesResource.getDataPortal(JSON.serialize(GetDataRequest));
            System.assertEquals(true, otherQuotes.Success);
            
            //OCCommunitiesResource.GetDataRequest GetDataRequest = new OCCommunitiesResource.GetDataRequest();
            GetDataRequest.offset = 0;
            GetDataRequest.typeStr = 'credits';
            GetDataRequest.searchText = '123*';
            GetDataRequest.url = 'www.test.com/';
            
            OCCommunitiesResource.GetDataResults credits = OCCommunitiesResource.getDataPortal(JSON.serialize(GetDataRequest));
            System.assertEquals(true, credits.Success);
            Test.stopTest();
        }
    }
     */
    
    @IsTest private static void testRequestAccountAccess() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Account_Number__c FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/accountaccess/' + contact.Id;  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        OCCommunitiesResource.AccountAccessRequest requests = new OCCommunitiesResource.AccountAccessRequest();
        OCCommunitiesResource.AccountRequest request1 = new OCCommunitiesResource.AccountRequest();
        request1.Name = 'Test12';
        request1.Account = account.Id;
        
        requests.Added.add(request1);
        
        Test.startTest();
        OCCommunitiesResource.AccountAccessResults result = OCCommunitiesREST_AccountAccess.requestAccountAccess(requests.CreateRequest,requests.DeleteAccountLinks,requests.DeletedIds,requests.Added,requests.RegionalManagerId);
        OCCommunitiesResource.AccountAccessResults rr1 = OCCommunitiesResource.requestAccountAccess(JSON.serialize(requests));
        //     	System.assertEquals(false, result.Success);  TO FIX
        Test.stopTest();
    }
    
    @IsTest private static void testDeleteAccountAccess() {
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        Account account = [SELECT id, Name FROM Account LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/deleteaccountaccess/' + contact.Id;  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        RestContext.request = req;
        RestContext.response= res;
        
        OCCommunitiesResource.DeleteAccountRequest request = new OCCommunitiesResource.DeleteAccountRequest();
        request.Name = account.Name;
        request.Id = account.Id;
        
        
        Test.startTest();
        OCCommunitiesResource.DeleteAccountResult result = OCCommunitiesREST_DeleteAccountAccess.deleteAccountAccess(request.Id,request.Name);
        OCCommunitiesResource.DeleteAccountResult rr1 = OCCommunitiesResource.deleteAccountAccess(JSON.serialize(request));
        System.assertEquals(true, result.Success);
        Test.stopTest();
    }
    
    
    @IsTest
    private static void testGetUserIdByContactId() {
        User user = [SELECT Id, Name, ContactId FROM User WHERE ContactId != null LIMIT 1];
        System.debug('Contact Id: ' + user.ContactId);
        Id userId = OCCommunitiesResourceHelper.getUserIdByContactId(user.ContactId);
        System.assertEquals(user.Id, userId);
    }
    
    @IsTest
    private static void testGetContactIdOfRequest() {
        User user = [SELECT Id, Name, ContactId FROM User WHERE Profile.Name = 'Omni System Admin' AND IsActive = true LIMIT 1];
        Contact contact = [SELECT id FROM Contact LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/occommunities/v1/rewards/' + contact.Id;  //Request URL
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response= res;
        
        Id contactId = OCCommunitiesResourceHelper.getContactIdOfRequest();
        System.assertEquals(contact.Id, contactId);
    }
    
    @IsTest
    private static void testSendEmailController() {
        String[] toAddress  = new String[]{'chrisw@launchdm.com'};
        String[] bccAddress  = new String[]{'chris@launchdm.com'};
        Boolean success = OCCommunitiesResourceHelper.sendEmail(toAddress, bccAddress, 'Subject', 'body');
        System.assertEquals(success, true);
    }
    
    @IsTest
    private static void testGetContactIdByUserId() {
        User user = [SELECT Id, ContactId from User WHERE ContactId != null LIMIT 1];
        Id contactId = OCCommunitiesResourceHelper.getContactIdByUserId(user.Id);
        System.assertEquals(contactId, user.ContactId);
    }
    
    @IsTest
    private static void testUpdateContactRewards() {
        Contact contact = [SELECT id, OCC_RewardsTotal__c FROM Contact LIMIT 1];
        Set<Id> contactIds = new Set<id>();
        contactIds.add(contact.Id);
        OCCommunitiesResourceHelper.updateContactRewards(contactIds);
        Contact updatedContact = [SELECT id, OCC_RewardsTotal__c FROM Contact WHERE Id =: contact.Id LIMIT 1];
        System.assert(updatedContact.OCC_RewardsTotal__c != null);
    }
    
    @IsTest
    private static void testGetAlternativePartNumbers() {
        
        Account account = [SELECT id FROM Account WHERE Name ='Test Account' LIMIT 1];
        List<String> accountList = new List<String>();
        accountList.add(account.Id);
        List<Alternative_Part_Number__c> altParts =  OCCommunitiesResourceHelper.getAlternativePartNumbersAll(account.Id);
        System.assert(altParts.size() > 0);
    }
    
    @IsTest
    private static void testGetDeliveryAddresses() {
        Account account = [SELECT id FROM Account WHERE Name ='Test Account' LIMIT 1];
        List<String> accountList = new List<String>();
        accountList.add(account.Id);
        List<Delivery_Address__c> addresses =  OCCommunitiesResourceHelper.getDeliveryAddresses(account.Id);
        System.assert(addresses.size() > 0);
    }
    
    @IsTest
    private static void testGetAlternativePartNumbersSingle() {
        Account account = [SELECT id FROM Account WHERE Name ='Test Account' LIMIT 1];
        List<Alternative_Part_Number__c> altParts =  OCCommunitiesResourceHelper.getAlternativePartNumbers(account.Id);
        System.assert(altParts.size() > 0);
    }
    
    @IsTest
    private static void testGetAllMasterOrders() {
        Account account = [SELECT id FROM Account WHERE Name ='Test Account' LIMIT 1];
        List<String> accountIds = new List<String>();
        accountIds.add(account.Id);
        List<OCCommunitiesResource.QOCTypeData> allMasterOrders =  OCCommunitiesResourceHelper.getAllMasterOrders(account.Id);
        System.assert(allMasterOrders.size() > 0);
    }
    
    
    
}