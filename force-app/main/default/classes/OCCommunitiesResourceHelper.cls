global class OCCommunitiesResourceHelper {

    public static OCCommunitiesResource.UploadPhotoResult uploadProfilePhoto(OCCommunitiesResource.UploadPhotoRequest request, Id contactId){
        OCCommunitiesResource.UploadPhotoResult result = new OCCommunitiesResource.UploadPhotoResult();
         
        try{
            /*
            Blob imageBlob = EncodingUtil.base64Decode(request.image);
            
            ConnectApi.CommunityPage communityPage = ConnectApi.Communities.getCommunities(ConnectApi.CommunityStatus.Live);
            List<ConnectApi.Community> community = communityPage.communities;

            //TODO: Will there only be 1 community?
            System.debug('#####' + community[0]);
            
            ConnectApi.BinaryInput fileUpload = new ConnectApi.BinaryInput(imageBlob, 'image/jpg', request.title);
            ConnectApi.Photo photoProfile = ConnectApi.ChatterUsers.setPhoto(community[0].id, UserInfo.getUserId() ,fileUpload);
            */

            List<Contact> contacts = [Select Id, Name, OCC_Photo__c from Contact where Id =: contactId];
            Contact contact = null;
            if (Contacts.size() > 0){
                contact = Contacts.get(0);
                contact.OCC_Photo__c = '<img alt="contact-image" src="data:image/jpeg;base64,' + request.image + '"></img>';
                upsert contact;
            }
            
            contact = [Select Id, Name, OCC_Photo__c from Contact where Id =: contactId].get(0);
            result.Contact = contact;
            
            result.Success = true;
        }catch(Exception e){
            result.Success = false;
            result.Message = e.getMessage();
        }
        
        return result;
    }

    public static OCCommunitiesResource.RewardsResponse getRewards(Id contactId) {
        OCCommunitiesResource.RewardsResponse result = new OCCommunitiesResource.RewardsResponse();
        
        try {

            
            List<Contact> Contacts = [Select OCC_Rewards__c, OCC_RewardsValue__c  from Contact where Id =: contactId];
            Contact contact = null;
            if (Contacts.size() > 0){
                contact = Contacts.get(0);
            }
            
            Decimal total = 0;
            
            if(contact.OCC_RewardsValue__c != NULL){
                total +=  contact.OCC_RewardsValue__c;
            }
            
            for(QuotesOrdersCredits_Header__c header : [Select OCC_Rewards__c, RewardOverride__c, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where Buyer__r.Id =:contactId AND Status__c = 'Invoiced' AND Type__c = 'Order' AND OCC_RewardRedeemed__c = false]){
                if(header.OCC_Rewards__c != NULL){
                    
                    if(header.RewardOverride__c != null){
                        total += header.RewardOverride__c;
                    }else{
                        total += header.OCC_Rewards__c;
                    }
                    
                }                
                
            }
            
            for(QuotesOrdersCredits_Header__c header : [Select OCC_Rewards__c, RewardOverride__c, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where Buyer__r.Id =:contactId AND Type__c = 'Credit' AND CreditRMAPortalType__c = 'Return' AND OCC_RewardRedeemed__c = false]){
                if(header.OCC_Rewards__c != NULL){
                    
                    if(header.RewardOverride__c != null){
                        total += header.RewardOverride__c;
                    }else{
                        total += header.OCC_Rewards__c;
                    }
                    
                }
            }
            

            result.Value = String.valueOf(total);
            result.Message = String.valueOf(total);
            result.Success = true;
        } catch (Exception e) {
            
            result.Success = false;
            result.Message = e.getMessage();

            
        }
        
        System.debug('TOTAL: ' + result.Value);
        return result;
    }
    
    public static OCCommunitiesResource.QOCDataResult findQOCById(OCCommunitiesResource.QOCRequest request,Id contactId){
        OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
        

        try{                        
            QuotesOrdersCredits_Header__c header =  [Select Id,  Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Purchase_Agent__r.Name, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c,  Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c WHERE QuotesOrdersCredits_Header__c.Id =: request.Id AND Buyer__c =: contactId AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'];
            
            if(header != null){
                
                OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                quoteData.header = header;
                result.quotes.add(quoteData);
                    
                List<QuoteOrderCredit_Details__c> details = [Select Id, Customer_Item__c, CableCode__c, Item_Markings__c, SalesPricePortal__c, NotesPortal__c, TotalDollarsPortal__c, Put_up_1__c, Put_up_2__c, Put_up_3__c, Put_up_4__c, Put_up_5__c, Put_up_6__c, Put_up_7__c, Spec_Sheet__c, C2SPRC__c, Name, Dollars__c, Expected_Date__c, Freight_Terms__c, Freight_Carrier__c, Item_Description__c,  Line_Item__c, Line_Number__c, Line_Status__c, Qty_Ordered__c, Qty_Shipped__c, TrackingURL__c, Order_Header__c, Received_Complete__c from QuoteOrderCredit_Details__c where Order_Header__c =: header.Id AND Line_Status__c != 'Cancelled'];
                quoteData.details.addAll(details);
                
                List<ContentDocumentLink> docs = [Select Id, ContentDocumentId, ContentDocument.title, LinkedEntityId from ContentDocumentLink where LinkedEntityId =: header.Id];
                for(ContentDocumentLink contentDoc : [Select Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, ContentDocument.title, LinkedEntityId from ContentDocumentLink where LinkedEntityId =: header.Id]) {
                                    
                    OCCommunitiesResource.QOCAttachment att = new OCCommunitiesResource.QOCAttachment();
                    att.title = contentDoc.ContentDocument.title;
                    att.url = request.url + '/sfc/servlet.shepherd/version/download/' + contentDoc.ContentDocument.LatestPublishedVersionId;
                    att.image = request.url + '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + contentDoc.ContentDocument.LatestPublishedVersionId;
                    quoteData.attachments.add(att);
                }
                
            }else{
                result.Message = 'No results found for Id: ' + request.Id;
            }
            
            result.Success = true;
            
        }catch(Exception e){
            //result.Message = e.getMessage();
            result.Message = 'No results found for Id: ' + request.Id;
        }
        
        return result;
    }

    public static OCCommunitiesResource.QOCDataResult getCommunitiesData(OCCommunitiesResource.QOCRequest request, Id contactId){
        OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
        
        try{

            Map<String, OCCommunitiesResource.QOCTypeData> qocMap = new Map<String, OCCommunitiesResource.QOCTypeData>();
            Map<String, OCCommunitiesResource.QOCTypeData> pendingMap = new Map<String, OCCommunitiesResource.QOCTypeData>();
            
            List<String> headerIds = new List<String>();
            List<String> pendingHeaderIds = new List<String>();
            
            List<String> accountIds = new List<String>();
            
            // List<User> Users = [Select Name, AccountId,FirstName, FullPhotoUrl, Photo__c, LastName, CommunityNickname, Email, Phone, UserRole.Name, ContactId, UserRoleId from User where ContactId =: contactId ];
            // String roleId;
            // if (Users.size() > 0){
            //     result.user = Users.get(0);
            //     result.BuyerId = contactId;  
            //     roleId = result.user.UserRoleId;
            // }
            
            List<Contact> Contacts = [Select Email, Name, OCC_Hide_Account_Access_Panel__c, Phone, FirstName, LastName, Buyer__c, PhotoUrl, OCC_Photo__c, OCC_ViewAll__c, OCC_ViewApproved__c, OCC_Rewards__c, Birthdate, OCC_RewardsValue__c, AccountId from Contact where Id =: contactId];
            Contact contact = null;
            String accountId;
            if (Contacts.size() > 0){
                contact = Contacts.get(0);
                result.contact = contact;
                result.Rewards = contact.OCC_Rewards__c;
                accountId = contact.AccountId;
                
                //Add own account Id
                accountIds.add(accountId);
            }  
            
            
            List<Account> Accounts = [Select (SELECT Id, Name, Area_Account_Manager__c, Area_Account_Manager__r.Name from Job_Areas__r), Id, Active__c, Account_Number__c, Name, ParentId, OCC_Rewards__c, Phone, ShippingAddress, Outside_Salesperson__r.UserRole.Name, Outside_Salesperson__r.Name,  Outside_Salesperson__r.FullPhotoUrl, Outside_Salesperson__r.Photo__c , Outside_Salesperson__r.Email, Outside_Salesperson__r.ManagerId, Outside_Salesperson__r.Phone, BillingAddress , Owner.UserRole.Name, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone, Owner.FullPhotoUrl, Owner.Photo__c from Account where Id =: accountId];
            List<Account> childAccounts = new List<Account>();
            List<Account> allAccounts = new List<Account>();
            
            System.debug(LoggingLevel.ERROR, 'Accounts=: ' + Accounts.size());
            
            //account = users account           
            Account account = null;
            if (Accounts.size() > 0){
                account = Accounts.get(0);
                result.account = account;
                result.manager1 = account.Owner;
                result.manager2 = account.Outside_Salesperson__r;
                
                List<User> otherManagers = [Select Name, UserRole.Name, Email, Phone, FullPhotoUrl, Photo__c, ManagerId from User where Id  =: account.Outside_Salesperson__r.ManagerId];
                if (otherManagers.size() > 0){
                    result.manager3 = otherManagers.get(0);
                   
                }
                
                
                //parent account
                Account parentAccount = null;
                List<Account> ParentAccounts = [Select (SELECT Id, Name, Area_Account_Manager__c, Area_Account_Manager__r.Name from Job_Areas__r), Id, Active__c, Account_Number__c, Name, ParentId, OCC_Rewards__c, Phone, ShippingAddress, Outside_Salesperson__r.UserRole.Name, Outside_Salesperson__r.Name,  Outside_Salesperson__r.FullPhotoUrl, Outside_Salesperson__r.Photo__c , Outside_Salesperson__r.Email, Outside_Salesperson__r.ManagerId, Outside_Salesperson__r.Phone, BillingAddress , Owner.UserRole.Name, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone, Owner.FullPhotoUrl, Owner.Photo__c from Account where Id =: account.ParentId];
                if(ParentAccounts.size() > 0){
                    parentAccount = ParentAccounts.get(0);
                    //NOTE: Removed 10-15-19
                    //accountIds.add(parentAccount.Id);
                }
                
                
                //get all accounts where id = your account or parent account = parentId
                System.debug(LoggingLevel.ERROR, 'parentAccount: ' + parentAccount);
                if(contact.OCC_ViewAll__c == true){
                    
                    if(parentAccount != null){
                        childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: parentAccount.Id Or Id =: account.Id Or Id =: parentAccount.Id) AND Active__c != 'D' ORDER BY Name];
                    }else{
                        childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: account.Id Or Id =: account.Id) AND Active__c != 'D' ORDER BY Name];
                        
                    }
                    
                    result.childAccounts = childAccounts;
                    
                    //Add all child accounts because contact has access
                    for (Account act : result.childAccounts) {
                        accountIds.add(act.Id);
                    }

                    
                }else if(contact.OCC_ViewApproved__c == true){
                    
                    List<String> approvedAccountIds = new List<String>();
                    for(OCC_ApprovedAccount__c approvedAccount : [Select Contact__c, Status__c, Account__c, Account__r.Active__c, Account__r.Name FROM OCC_ApprovedAccount__c where Contact__c =: contact.Id AND (Status__c = 'Accepted' OR Status__c = 'Pending')]){
                        approvedAccountIds.add(approvedAccount.Account__c);
                        result.approvedAccounts.add(approvedAccount);
                        accountIds.add(approvedAccount.Account__c);
                    }
                    
                    result.approvedAccountIds = approvedAccountIds;
                    childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (/*ParentId =: account.Id Or */Id =: account.Id OR Id IN: approvedAccountIds) AND Active__c != 'D' ORDER BY Name];
                    
                    
                    if(parentAccount != null){
                        allAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: parentAccount.Id Or Id =: account.Id Or Id =: parentAccount.Id) AND Active__c != 'D' ORDER BY Name];
                        // allAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: parentAccount.Id Or Id =: account.Id) AND Active__c != 'D' ORDER BY Name];

                    }else{
                        allAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: account.Id Or Id =: account.Id) AND Active__c != 'D' ORDER BY Name];
                    }
                    
                    result.allAccounts = allAccounts;
                    result.childAccounts = childAccounts;

                    //Add all accounts contact has access to and child accounts
                    // for (Account act : result.allAccounts) {
                    //     accountIds.add(act.Id);
                    // }

                    for (Account act : result.childAccounts) {
                        accountIds.add(act.Id);
                    }



                }else{

                    childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: account.Id Or Id =: account.Id) AND Active__c != 'D' ORDER BY Name];
                    result.childAccounts = childAccounts;

                    //Only contact's account and child accounts
                    for (Account act : result.childAccounts) {
                        accountIds.add(act.Id);
                    }


                }
            
                
            }
            
            
            List<OCC_ContactSlider__c> contactSlider = [Select Name, URL__c, LinkUrl__c, Index__c from OCC_ContactSlider__c where Contact__c =: contactId ORDER BY OCC_ContactSlider__c.Index__c];
            
            if (contactSlider.size() == 0){
                contactSlider = [Select Name, URL__c, LinkUrl__c, Index__c from OCC_ContactSlider__c where Contact__c = Null ORDER BY OCC_ContactSlider__c.Index__c];
            }
            
            result.contactSlider = contactSlider;
            result.Message = String.valueOf(contactSlider.size());
            
       //     System.debug(LoggingLevel.ERROR, 'Occ1=: ' + user);
            
            
            // List<UserRole> roles = [Select Id, Name from UserRole where Id =: roleId];
            
            // Removed:  This should not be used  since everything relies on contact
            // if(contact == null){
            //     result.AccountType = 'System Admin';
                
            //     for(QuotesOrdersCredits_Header__c header : [Select Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c,  Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c,  Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c from QuotesOrdersCredits_Header__c WHERE QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND (QuotesOrdersCredits_Header__c.Status__c != 'Cancelled') AND (Type__c = 'RFQ' OR Type__c ='Release') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                 
            //         OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
            //         quoteData.header = header;
            //         qocMap.put(header.Id, quoteData);
            //         headerIds.add(header.Id);
            //         result.quotes.add(quoteData);                    
            //     }
                
            //     for(QuotesOrdersCredits_Header__c header : [Select Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c,  Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c,  Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c from QuotesOrdersCredits_Header__c WHERE QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND (QuotesOrdersCredits_Header__c.Status__c != 'Cancelled') AND (Type__c = 'Order') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                 
            //         OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
            //         quoteData.header = header;
            //         qocMap.put(header.Id, quoteData);
            //         headerIds.add(header.Id);
            //         result.orders.add(quoteData);                    
            //     }
                                
            // }else 
            
            if (contact.OCC_ViewAll__c == true){
                result.AccountType = 'View All';
                
                for(QuotesOrdersCredits_Header__c header : [Select Id, of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c IN: childAccounts OR Buyer__c =: contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'RFQ' OR Type__c = 'Release') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                 
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    headerIds.add(header.Id);
                    result.quotes.add(quoteData);
                    
                }
                                
                for(QuotesOrdersCredits_Header__c header : [Select Id, of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c IN: childAccounts OR Buyer__c =: contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND Type__c = 'Order' ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                 
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    headerIds.add(header.Id);
                    result.orders.add(quoteData);
                    
                }


            }else if (contact.OCC_ViewApproved__c == true){
                
                //TODO: add approved accounts
                result.AccountType = 'View Approved Accounts';
                for(QuotesOrdersCredits_Header__c header : [Select Id, of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c IN: childAccounts OR Buyer__c =: contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'RFQ' Or Type__c ='Release') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                 
                   OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                   quoteData.header = header;
                   qocMap.put(header.Id, quoteData);
                   headerIds.add(header.Id);
                   result.quotes.add(quoteData);
                }
                
                for(QuotesOrdersCredits_Header__c header : [Select Id, of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c IN: childAccounts OR Buyer__c =: contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Order') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                 
                   OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                   quoteData.header = header;
                   qocMap.put(header.Id, quoteData);
                   headerIds.add(header.Id);
                   result.orders.add(quoteData);
                }
                
            
            }else{
                result.AccountType = 'View Mine Only';
                for(QuotesOrdersCredits_Header__c header : [Select Id,  of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c , TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'RFQ' OR Type__c = 'Release') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                 
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    headerIds.add(header.Id);
                    result.quotes.add(quoteData);                   
                    
                }
                
                for(QuotesOrdersCredits_Header__c header : [Select Id,  of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c , TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Order') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                 
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    headerIds.add(header.Id);
                    result.orders.add(quoteData);                   
                    
                }

            }
       
            
            for(QuoteOrderCredit_Details__c detail : [Select Id, Customer_Item__c, CableCode__c, Item_Markings__c, SalesPricePortal__c, NotesPortal__c, TotalDollarsPortal__c, Put_up_1__c, Put_up_2__c, Put_up_3__c, Put_up_4__c, Put_up_5__c, Put_up_6__c, Put_up_7__c, Spec_Sheet__c, C2SPRC__c, Name, Dollars__c, Expected_Date__c, Freight_Terms__c, Freight_Carrier__c, Item_Description__c,  Line_Item__c, Line_Number__c, Line_Status__c, Qty_Ordered__c, Qty_Shipped__c, TrackingURL__c, Order_Header__c, Received_Complete__c from QuoteOrderCredit_Details__c where Order_Header__c IN: headerIds AND Line_Status__c != 'Cancelled' ORDER BY QuoteOrderCredit_Details__c.Line_Number__c]) {
            
                OCCommunitiesResource.QOCTypeData quoteData =  qocMap.get(detail.Order_Header__c);
                if(quoteData != null) {
                    quoteData.details.add(detail);
                }   
            }
            
            /*
            for(QuoteOrderCredit_Details__c pendingDetail : [Select Id, SalesPricePortal__c, TotalDollarsPortal__c, Put_up_1__c, Put_up_2__c, Put_up_3__c, Put_up_4__c, Put_up_5__c, Put_up_6__c, Put_up_7__c,  Spec_Sheet__c, C2SPRC__c, Name, Dollars__c, Expected_Date__c, Freight_Terms__c, Freight_Carrier__c, Item_Description__c, Line_Item__c, Line_Number__c, Line_Status__c, Qty_Ordered__c, TrackingURL__c, Order_Header__c from QuoteOrderCredit_Details__c where Order_Header__c IN: pendingHeaderIds AND Line_Status__c != 'Cancelled' ORDER BY QuoteOrderCredit_Details__c.Line_Number__c]) {
        
                OCCommunitiesResource.QOCTypeData quoteData =  pendingMap.get(pendingDetail.Order_Header__c);
                if(quoteData != null) {
                    quoteData.details.add(pendingDetail);
                }  
                
            } 
            */
            
            List<ContentDocumentLink> docs = [Select Id, ContentDocumentId, ContentDocument.title, LinkedEntityId from ContentDocumentLink where LinkedEntityId IN: headerIds];
            result.Message = String.valueOf(docs.size());
           
            for(ContentDocumentLink contentDoc : [Select Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, ContentDocument.title, LinkedEntityId from ContentDocumentLink where LinkedEntityId IN: headerIds]) {
                OCCommunitiesResource.QOCTypeData quoteData =  qocMap.get(contentDoc.LinkedEntityId);
                if(quoteData != null) {
                                        
                    OCCommunitiesResource.QOCAttachment att = new OCCommunitiesResource.QOCAttachment();
                    att.title = contentDoc.ContentDocument.title;
                    att.url = request.url + '/sfc/servlet.shepherd/version/download/' + contentDoc.ContentDocument.LatestPublishedVersionId;
                    att.image = request.url + '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + contentDoc.ContentDocument.LatestPublishedVersionId;
                    quoteData.attachments.add(att);
                }
                
            }                     
            /*
            for(ContentVersion content : [Select Id, Title, QuotesOrdersCredits_Header__c from ContentVersion where QuotesOrdersCredits_Header__c IN: headerIds]) {
            
                OCCommunitiesResource.QOCTypeData quoteData =  qocMap.get(content.QuotesOrdersCredits_Header__c);
                if(quoteData != null) {
                    QOCAttachment att = new QOCAttachment();
                    att.title = content.Title;
                    att.url = request.url + '/sfc/servlet.shepherd/version/download/' + content.Id;
                    att.image = request.url + '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + content.Id;
                    quoteData.attachments.add(att);
                }   
            }
            */
            
            result.rmfPOValues = OCCommunitiesResourceHelper.getPicklistValue('QuotesOrdersCredits_Header__c', 'RMF_PO__c');

            /*
            for (Account act : result.allAccounts) {
                accountIds.add(act.Id);
            }

            for (Account act : result.childAccounts) {
                accountIds.add(act.Id);
            }

            for (String id : result.approvedAccountIds) {
                accountIds.add(id);
            }
            */

            // result.alternativePartNumbers = OCCommunitiesResourceHelper.getAlternativePartNumbersAll(accountIds);
            // result.deliveryAddresses = OCCommunitiesResourceHelper.getDeliveryAddresses(accountIds);
            System.debug('ACCOUNT IDS: ' + accountIds);
            // result.masterOrders = OCCommunitiesResourceHelper.getAllMasterOrders(accountIds);
            result.siteUrl = URL.getSalesforceBaseUrl().toExternalForm();
            // result.roles = roles;
            result.Success = true;
            
        }catch(Exception e){
            result.Success = false;
            result.Message = e.getMessage();
        }
        
        return result;
    
    }

     /**
     * @name sendRFQ
     * @description Send the request for release and email appropriate managers
     * @param Boolean favorite
     * @param OCCommunitiesResource.RFQRequest request
     * @param Id Contact id 
    **/
    public static OCCommunitiesResource.RFQResponse sendRFQ(OCCommunitiesResource.RFQRequest request, Id contactId) {
        OCCommunitiesResource.RFQResponse result = new OCCommunitiesResource.RFQResponse();
        
        try{
    
            String baseBody = request.RFQData;
            String contactName = '';
            
            List<Contact> Contacts = [Select Email, Name, FirstName, LastName, AccountId from Contact where Id =: contactId];
            Contact contact = null;
            if (Contacts.size() > 0){
                contact = Contacts.get(0);
                contactName = contact.Name;
                System.debug(LoggingLevel.ERROR, 'RFQ- got contact = ' + contact.Email);
            }
            
            //TODO:  get manager email from account number request.AccountNumber
            String managerEmail = '';
            List<Account> Accounts = [Select Id, ParentId, Account_Number__c, Outside_Salesperson__r.Email, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone from Account where Account_Number__c =: request.AccountNumber];
            Account account = null;
            if (Accounts.size() > 0){           
                account = Accounts.get(0);
                managerEmail = account.Owner.Email;
            }
            
            //TODO: Check emails
             String[] toAddress = new String[]{contact.Email};
             
            if(toAddress.size() > 0) {
               
                Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();  
                //NOTE: toggle comment setToAddresses
                message.setToAddresses(toAddress);
                
                if (request.imageData != null && request.imageData.size() > 0){
                    List<Messaging.EmailFileAttachment> efas = new List<Messaging.EmailFileAttachment>();
                    
                    for(Integer i=0; i< request.imageData.size(); i++){
                        OCCommunitiesResource.ImageData imgData = request.imageData.get(i);
                        Blob imageBlob = EncodingUtil.base64Decode(imgData.image);
                        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                        efa.setBody(imageBlob);
                        efa.setFileName(imgData.name);
                        efas.add(efa);
                    }
                    message.setFileAttachments(efas);
                }
            
                message.setSaveAsActivity(true);
                
                if(request.typeStr.equals('RMA')){
                    if(!runningInASandbox()){
                        message.setBccAddresses(new String[] {'portal@omnicable.com', managerEmail});
                        message.setCcAddresses(new String[] {'RMAs@omnicable.com'});
                        message.setSubject('RMA Request Received from myomnicable.com');
                    }else{
                        message.setSubject('TEST-RMA Request Received from myomnicable.com');
                    }
                    
                    message.setSenderDisplayName('RMAs@omnicable.com');
                    message.setReplyTo('RMAs@omnicable.com');
                    baseBody = contact.FirstName + ', <br> <br>' +  'We have received your RMA request below from <a href="https://myomnicable.com"> myomnicable.com </a> and will contact you shortly. <br> <br> '  + baseBody + '<br> <br> <br> Thank you, <br> Omni Cable';
                    
                }else if(request.typeStr.equals('RFQ')){
                    //NOTE: toggle comment setBccAddresses
                    message.setBccAddresses(new String[] {'portal@omnicable.com'});
                    message.setCcAddresses(new String[] {managerEmail});
                    message.setSubject('RFQ Received from myomnicable.com');
                    message.setReplyTo(managerEmail);
                    message.setSenderDisplayName(managerEmail);
                    String siteUrl = URL.getSalesforceBaseUrl().toExternalForm();
                    
                    QuotesOrdersCredits_Header__c newQOC = new QuotesOrdersCredits_Header__c( RFQ_Text__c = request.RFQData, Customer__c = account.Id, Date__c = date.today(), Job_Reference__c = request.jobReferenceNumber, Mark_Number__c = request.markNumber, Buyer__c = contactId, Type__c = 'RFQ');
                    insert newQOC;
                    
                    QuotesOrdersCredits_Header__c newFullQOC = [Select Id,  of_Lines__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Customer__r.ShippingStreet, Customer__r.ShippingCity, Customer__r.ShippingState, Customer__r.ShippingPostalCode, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c,  Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c WHERE Id = :newQOC.Id];
                    
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = newFullQOC;
                    result.quoteData = quoteData;
                    
                    baseBody = contact.FirstName + ', <br> <br>' +  'We have received your request for release from <a href="https://myomnicable.com"> myomnicable.com </a>. You will receive your quote shortly. <br> <br> <b>RFQ #:</b> ' +  newFullQOC.RFQNumber__c + '<br>'  + baseBody + '<br> <br> <br> Thanks for the opportunity, <br> Omni Cable';
                    
                }else if(request.typeStr.equals('Order')){
                    if(!runningInASandbox()){
                        message.setBccAddresses(new String[] {'portal@omnicable.com'});
                        message.setCcAddresses(new String[] {managerEmail});
                        message.setSubject('Order Received from myomnicable.com');
                    }else{
                        message.setSubject('TEST-Order Received from myomnicable.com');
                    }
                    
                    message.setSenderDisplayName(managerEmail);
                    message.setReplyTo(managerEmail);
                    baseBody = contact.FirstName + ', <br> <br>' +  'Thank you for placing your order through <a href="https://myomnicable.com"> myomnicable.com </a>. You will receive an order confirmation shortly. <br> <br> '  + baseBody + '<br> <br> <br> Thank you, <br> Omni Cable';
                }
              
                
                message.setPlainTextBody(baseBody);
                message.setHtmlBody(baseBody);
    
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });
                
            }
            
            result.Success = true;
                        
        } catch (Exception e) {
            
            result.Success = false;
            result.Message = e.getMessage();
            
        }
        
        return result;
    }
    
    public static OCCommunitiesResource.RFQResponse sendEmail(OCCommunitiesResource.EmailRequest request, Id contactId) {
        OCCommunitiesResource.RFQResponse result = new OCCommunitiesResource.RFQResponse();
        
        
        try{
        
            System.debug(LoggingLevel.ERROR, 'RFQ- about to parese send data');

            System.debug(LoggingLevel.ERROR, 'RFQ- data parsed');
            
            String contactName = '';
            
            List<Contact> Contacts = [Select Email, Name, FirstName, LastName, AccountId from Contact where Id =: contactId];
            Contact contact = null;
            String accountId;
            if (Contacts.size() > 0){
                contact = Contacts.get(0);
                accountId = contact.AccountId;
                contactName = contact.Name;
                System.debug(LoggingLevel.ERROR, 'RFQ- got contact = ' + contact.Email);
            }
            
            String managerEmail = '';
            List<Account> Accounts = [Select Outside_Salesperson__r.Email, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone from Account where Id =: accountId];
            Account account = null;
            if (Accounts.size() > 0){
                account = Accounts.get(0);
                managerEmail = account.Outside_Salesperson__r.Email;
            }
            
             String[] toAddress = new String[]{request.Email};
             
            if(toAddress.size() > 0) {
               
                Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();  
                message.setToAddresses(toAddress);
                if(managerEmail != null){
                    message.setCcAddresses(new String[] {managerEmail});
                }
                message.setSaveAsActivity(true);
                message.setSubject(request.Subject);
                
                String baseBody = request.Message;
                
                message.setPlainTextBody(baseBody);
                message.setHtmlBody(baseBody);
    
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });
                
            }
            
            result.Success = true;
            
        } catch (Exception e) {
            
            result.Success = false;
            result.Message = e.getMessage();
            
        }
        
        return result;
    }
    
    public static OCCommunitiesResource.RewardsResponse redeemRewards(OCCommunitiesResource.RewardsRequest request, Id contactId) { // redeemRewards(String name, String email, Integer amount, String message) {    
        
        OCCommunitiesResource.RewardsResponse result = new OCCommunitiesResource.RewardsResponse();
        //if (test.isRunningTest()) Test.setMock(HttpCalloutMock.class, new OCCommunitiesResourceTest());
        
        try {       
   
            Contact contact = [Select OCC_PendingRedeemIssue__c, OCC_Rewards__c, FirstName, LastName, Email, Name, OCC_RewardsValue__c, AccountId, Account.Name, Account.OCC_Rewards__c, Account.Owner.Email, Account.Additional_Salesperson__r.Email, Account.Outside_Salesperson__r.Email, Account.Outside_Salesperson__r.UserRole.Name from Contact where Id =: contactId FOR UPDATE];

            if(contact != null && contact.Account != null && contact.Account.OCC_Rewards__c == true && contact.OCC_PendingRedeemIssue__c == false){
                String name = (contact != null && contact.Name != null && contact.Name != '') ? contact.Name : request.Name;
                
                HeaderCalculationResult headerResults = getHeaderAndTotals(contact);
                List<QuotesOrdersCredits_Header__c> redeemedHeaders = headerResults.headers;
                Decimal total = headerResults.total;
                result.OrginalValue = String.valueOf(total);

                if(total > 0){
                    HttpResponse res = tangoRewardCall(contact, request.Email, total);
                    if (String.valueOf(res.getStatusCode()).startsWith('2')){
                        
                        Boolean saveResuls = updateHeaderQocs(redeemedHeaders, contact);

                        contact.OCC_RewardsValue__c = 0;
                        contact.OCC_RewardsTotal__c = 0; 
                        contact.OCC_PendingRedeemIssue__c = !saveResuls;
                        Database.SaveResult contactResult = Database.update(contact, false);
                        
                        String body = 'Account: ' + contact.Account.Name + ' <br/><br/>  Contact: ' + contact.Name + '<br/><br/> Redeemed Amount: '  + total + ' <br/><br/> Redeemed Date: ' +  System.now(); 
                        String[] bccAddresses =  getManagerEmails(contact);
                        sendEmail(new String[] {'portal@omnicable.com'},  bccAddresses, 'Tango Redeedemed by: ' + contact.Name , body);
                        System.debug(LoggingLevel.INFO, 'Redeem - Success - before values updated ' + res.getBody());
                        result.Success = true;
                    }else{
                        System.debug(LoggingLevel.ERROR, 'Redeem - Failure - before values updated ' + res.getBody());
                        String body = 'Contact: ' + contact.Name + '<br/><br/> Total: ' + total + ' <br/><br/> Issue: The following contact tried to redeem their Tango Rewards with the following error.  <br/><br/> Tango Request Body: ' + res.getBody();
                        sendEmail(new String[] {'portal@omnicable.com'},  new String[] {}, 'Tango Request Error', body);
                        result.Message = 'Sorry but we are unable to process your request at the moment.  An email has been sent to nofity us of the issue';
                        result.Success = false;
                    }
                    result.Value = getRewards(contactId).Value;
                }else{
                    result.Success = false;
                    result.Value = '0';
                    result.Message = 'You have 0 Tang Rewards to redeem at this time.';
                }
                
                
            }else{
                result.Success = false;
                result.Value = '0';

                if(contact != null && contact.OCC_PendingRedeemIssue__c == true){
                    result.Message = 'Rewards are temporarily unavailable.';
                }else{
                    result.Message = 'Tango Rewards are not available for this account.';
                }
            }
            
        } catch(Exception e) {

            //TODO: Update contact to pendign issue because something went wrong
            // Database.rollback(sp);
            result.Success = false;
            result.Message = e.getMessage();
            System.debug('Error: ' + e.getMessage());
        }
        System.debug('Results: ' + result);
        return result;

    } 

    public static String[] getManagerEmails(Contact contact){

        String[] bccAddresses =  new String[]{};
                        
        if(contact.Account.Owner != null && contact.Account.Owner.Email != null){
            bccAddresses.add(contact.Account.Owner.Email);
        }

        if(contact.Account.Outside_Salesperson__r != null && contact.Account.Outside_Salesperson__r.Email != null && contact.Account.Outside_Salesperson__r.UserRole != null &&  contact.Account.Outside_Salesperson__r.UserRole.Name != null && contact.Account.Outside_Salesperson__r.UserRole.Name != 'District Sales Manager 13'){
            bccAddresses.add(contact.Account.Outside_Salesperson__r.Email);
        }

        if(contact.Account.Additional_Salesperson__r != null && contact.Account.Additional_Salesperson__r.Email != null){
            bccAddresses.add(contact.Account.Additional_Salesperson__r.Email);
        }

        System.debug('Manager Emails Redeem: ' + bccAddresses);
        return bccAddresses;
    }

    public static Boolean updateHeaderQocs(List<QuotesOrdersCredits_Header__c> redeemedHeaders, Contact contact){
        
        //TODO: Production
        Database.SaveResult[] quoteResults = Database.update(redeemedHeaders, false);   
        Boolean saveSuccess = true;
        Map<String,String> errorMap = new Map<String,String>();

        try{

            for (Integer i = 0; i < redeemedHeaders.size(); i++) {
                Database.SaveResult s = quoteResults[i];
                QuotesOrdersCredits_Header__c origRecord = redeemedHeaders[i];
                if (!s.isSuccess()) {

                    saveSuccess = false;
                    String error = '';  
                    for(Database.Error err : s.getErrors()) {
                        error += 'Error Code: ' + err.getStatusCode() + '--' + ' Message: ' + err.getMessage() + ' Fields: ' + err.getFields();
                    }
                    errorMap.put(origRecord.Id, error);
                } 
            }
    
            System.debug('Save Success = ' + saveSuccess);
            if (!saveSuccess){
                contact.OCC_PendingRedeemIssue__c = true;
                update contact;
                System.debug('Error Map: ' + errorMap);
                String body = 'Contact: ' + contact.Name + '<br/><br/> Issue: There was an issue updating orders after the following the above users tango redemption.  Please manually check the following headers to confirm the OCC_RewardRedeemed is checked <br/><br/> Headers Ids: ' + String.valueOf(errorMap);
                sendEmail(new String[] {'portal@omnicable.com'}, new String[] {}, 'Order Issue: Tango Rewards Error', body);
            }

        }catch(Exception e){
            contact.OCC_PendingRedeemIssue__c = true;
            update contact;
            System.debug('Error Map: ' + errorMap);
            String body = 'Contact: ' + contact.Name + '<br/><br/> Issue: There was an issue updating orders after the following the above users tango redemption.  Please manually check the following headers to confirm the OCC_RewardRedeemed is checked <br/><br/> Headers Ids: ' + String.valueOf(errorMap);
            sendEmail(new String[] {'portal@omnicable.com'}, new String[] {}, 'Order Issue: Tango Rewards Error', body);
        }


       return saveSuccess;

    }

    public class HeaderCalculationResult {
        public Decimal total = 0;
        public List<QuotesOrdersCredits_Header__c> headers = new List<QuotesOrdersCredits_Header__c>();
    }

    public static HeaderCalculationResult getHeaderAndTotals(Contact contact){
        Decimal total = 0;
        if(contact.OCC_RewardsValue__c != NULL){
            total = total + contact.OCC_RewardsValue__c;
            // contact.OCC_RewardsValue__c = 0;
        }
            
        List<QuotesOrdersCredits_Header__c> redeemedHeaders = new List<QuotesOrdersCredits_Header__c>();
        for(QuotesOrdersCredits_Header__c order : [Select Id, OCC_Rewards__c, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where Buyer__r.Id =:contact.Id AND ((Status__c = 'Invoiced' AND Type__c = 'Order') OR (Type__c = 'Credit' AND CreditRMAPortalType__c = 'Return')) AND OCC_RewardRedeemed__c  = false AND (OCC_Rewards__c != 0 OR RewardOverride__c != null)FOR UPDATE]){
            if(order.OCC_Rewards__c != null){
                if(order.RewardOverride__c != null){
                    total = total + order.RewardOverride__c;
                }else{
                    total = total + order.OCC_Rewards__c;
                }
            } 
            order.OCC_RewardRedeemed__c = true;  
            redeemedHeaders.add(order);                  
        }
        
        HeaderCalculationResult result = new HeaderCalculationResult();
        result.total = total;
        result.headers = redeemedHeaders;
        return result;
    }

	private static HttpResponse tangoRewardCall(Contact contact, String email, Decimal total) {
        if (test.isRunningTest()) Test.setMock(HttpCalloutMock.class, new OCCommunitiesResourceTest());
        System.debug('tangoreward call started');
        Http httpProtocol = new Http();
        HttpRequest req = new HttpRequest(); 
        req.setHeader('content-type', 'application/json;charset=UTF-8');
        String endpoint ='';
        String message = 'Congratulations!';
        
        if(runningInASandbox()){
            endpoint = 'https://integration-api.tangocard.com/raas/v2/orders';
            req.setHeader('authorization', 'Basic T21uaUNhYmxlOkZkU1ohTFVXJEBIYXVERlVzdHRuWk9Abk5veklleWpTZndUJGplU3pHcVA=');
        
            String testFirstName = 'Chris';
            String testLastName = 'Williams';
            String testEmail = 'chriswill412@gmail.com';
            req.setBody('{"accountIdentifier":"omnicable","customerIdentifier":"omnicable","subject":"Test Subject","message": "' + message + '","amount":1.0,"sendEmail":true, "etid":"E000000", "utid":"U561593","recipient":{"email":"' + testEmail+ '","firstName":"' + contact.FirstName + '","lastName":"' + contact.LastName + '"},"sender":{"email":"portal@omnicable.com","firstName":"OmniCable"}}');
            
        }else{
            endpoint = 'https://api.tangocard.com/raas/v2/orders';
            req.setHeader('authorization', 'Basic T21uaUNhYmxlOk5EWmREaWRZbCFRJGtUTkVjWWxJYmlkTk1SVXByd1YmQ3dURlhmYmohaUI=');
            req.setBody('{"accountIdentifier":"omnicable","customerIdentifier":"omnicable","message": "' + message + '","amount":"' + total + '","sendEmail":true, "utid":"U561593","recipient":{"email":"' + contact.Email + '","firstName":"' + contact.FirstName + '","lastName":"' + contact.lastName + '"},"sender":{"email":"portal@omnicable.com","firstName":"OmniCable"}, "etid":"E838072"}');             
            
        }
        
        req.setMethod('POST');
        req.setEndPoint(endpoint);
		HttpResponse response = new Http().send(req);
        return response;
	}

    public static Boolean sendEmail(String[] toAddresses, String[] bccAddresses, String subject, String body){
        Boolean success = true;
        try {
            Messaging.reserveMassEmailCapacity(toAddresses.size());
            System.debug('Preparing to Send email');
            Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();  
            
            //TODO: Production
            emailMessage.setToAddresses(toAddresses);
            emailMessage.setBccAddresses(bccAddresses);

            // emailMessage.setToAddresses(new String[] {'chrisw@launchdm.com'});
            // emailMessage.setBccAddresses(new String[] {'chriswill412@gmail.com'});

            emailMessage.setSubject(subject);
            emailMessage.setHtmlBody(body);
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { emailMessage });
            System.debug('Email Results: ' + results);
            success = true;
        }catch(Exception e){
            System.debug('Email Error: ' + e.getMessage());
            success = false;
        }

        
        return success;
    }
    
    public static OCCommunitiesResource.ProfileResult updateProfile(OCCommunitiesResource.ProfileRequest request){
        
        OCCommunitiesResource.ProfileResult result = new OCCommunitiesResource.ProfileResult();
         
        try{
            
            List<Contact> Contacts = [Select Name, FirstName, LastName, Email, Phone, Birthdate from Contact where Id =: request.contactId];
            Contact contact = null;
            if (Contacts.size() > 0){
                contact = Contacts.get(0);
            }
            
            if (request.firstName != null && request.firstName != ''){
                contact.FirstName = request.firstName;
            }
            
            if (request.lastName != null && request.lastName != ''){
                contact.LastName = request.lastName;
            }
            
            if (request.email != null && request.email != ''){
                contact.Email = request.email;
            }
            
            if (request.phone != null && request.phone != ''){
                contact.Phone = request.phone;
            }
            
            if (request.month != null && request.month != ''){
                Date bday = Date.newInstance(Integer.valueOf(request.year), Integer.valueOf(request.month), Integer.valueOf(request.day));
                contact.Birthdate = bday;
            }
            
            update contact;
            result.Success = true;
        }catch (Exception e){
            result.Success = false;
            result.Message = e.getMessage();
            
        }
        
        return result;
    }
  
    public static OCCommunitiesResource.AccountAccessResults requestAccountAccess(OCCommunitiesResource.AccountAccessRequest request, Id contactId){
        
        OCCommunitiesResource.AccountAccessResults result = new OCCommunitiesResource.AccountAccessResults();
        
        try{
            List<User> Users = [Select Id from User where ContactId =: contactId ];
            String userId;
            if (Users.size() > 0){
                userId = Users.get(0).Id;
            }
            Contact contact = [SELECT AccountId FROM Contact WHERE Id =: contactId];

            String accountId = contact.AccountId;

            List<OCC_ApprovedAccount__c> deleteAccounts = [SELECT Id, Name from OCC_ApprovedAccount__c WHERE (Account__c IN: request.DeletedIds AND Contact__c =: contactId)];
            if(deleteAccounts.size() > 0){
                delete request.DeleteAccountLinks;
            }
            
            List<OCC_ApprovedAccount__c> approvedAccounts = new List<OCC_ApprovedAccount__c>();
            for(Integer i=0; i < request.Added.size(); i++){
                OCCommunitiesResource.AccountRequest currRequest = request.Added.get(i);
                OCC_ApprovedAccount__c  approvedAccount = new OCC_ApprovedAccount__c(Name=currRequest.Name, Account__c=currRequest.Account, Contact__c=contactId);
                approvedAccounts.add(approvedAccount);
                result.requestedIds.add(currRequest.Account);
            }
            
            if(approvedAccounts.size() > 0){
                insert approvedAccounts;
            }
            
            
            Account account = null;
            List<Account> Accounts = [Select Id, Active__c, Account_Number__c, Name, ParentId, OCC_Rewards__c, Phone, ShippingAddress, Outside_Salesperson__r.UserRole.Name, Outside_Salesperson__r.Name,  Outside_Salesperson__r.FullPhotoUrl, Outside_Salesperson__r.Photo__c , Outside_Salesperson__r.Email, Outside_Salesperson__r.ManagerId, Outside_Salesperson__r.Phone, BillingAddress , Owner.UserRole.Name, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone, Owner.FullPhotoUrl, Owner.Photo__c from Account where Id =: accountId];
            if(Accounts.size() > 0){
                account = Accounts.get(0);
            }
            
            User johnUser = [select Name, Email, Id from User where Email = 'jdean@omnicable.com' LIMIT 1];
            // if(runningInASandbox()){
            //     johnUser = [select Name, Email, Id from Contact where Email = 'jdean@omnicable.net'].get(0);
            // }else{
            //     johnUser = [select Name, Email, Id from Contact where Email = 'jdean@omnicable.com'].get(0);
            // }
            
            
            for(Integer i=0; i < approvedAccounts.size(); i++){
                // Create an approval request
                Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
                req1.setComments('Submitting Request for Account Access');
                req1.setObjectId(approvedAccounts.get(i).Id);
                
                Id[] approvalIds = new List<Id>();
                
                /*
                Group approvalGroup = null;
                
                List<Group> approvalGroups = [SELECT Id FROM Group WHERE Name =: user.Name AND Type='Queue'];
                
                if(approvalGroups.size() == 0){
                    approvalGroup = new Group(Name=user.Name, Type='Queue');
                    insert approvalGroup;
                    
                    List<GroupMember> GMlist = new List<GroupMember>();
                    
                    if(!runningInASandbox()){
                        
                        GMlist = new List<GroupMember>{
                            new GroupMember(GroupId  = approvalGroup.Id, UserOrGroupId = request.RegionalManagerId),
                            new GroupMember(GroupId  = approvalGroup.Id, UserOrGroupId = johnUser.Id)
                        };
                        
                    }else{
                        
                        GMlist = new List<GroupMember>{
                            new GroupMember(GroupId  = approvalGroup.Id, UserOrGroupId = user.Id),
                            new GroupMember(GroupId  = approvalGroup.Id, UserOrGroupId = johnUser.Id)
                        };
                        
                    }

                    insert GMlist;
                }else{
                    approvalGroup = approvalGroups.get(0);
                }
                
                */
                
                 if(!runningInASandbox()){
                    
                    if(request.RegionalManagerId != null){
                        approvalIds.add(Id.valueOf(request.RegionalManagerId));
                    }else{
                        approvalIds.add(johnUser.Id);
                    }
                    
                }else{
                    
                    approvalIds.add(userId);
                    
                }
                
                
                req1.setNextApproverIds(approvalIds);
        
                // Submit the approval request
                Approval.ProcessResult prcessResult = Approval.process(req1);
                
            }
            
            /*
            String[] toAddress = new String[]{};
            
            if(!runningInASandbox()){
                toAddress = new String[]{'chrisw@launchdm.com'};
            }else{
                toAddress = new String[]{'chrisw@launchdm.com'};
                
            }
            
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();  
            message.setToAddresses(toAddress);
            message.setHtmlBody(baseBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });
            */
            
            result.Success = true;
            result.Message = 'Request Successfully Submitted';
        }catch (Exception e){
            result.Success = false;
            result.Message =  result.Message + ' ' + e.getMessage();
            
        }
        
        return result;
    }
    
    public static OCCommunitiesResource.DeleteAccountResult deleteAccountAccess(OCCommunitiesResource.DeleteAccountRequest request, Id contactId){
        
        OCCommunitiesResource.DeleteAccountResult result = new OCCommunitiesResource.DeleteAccountResult();
                
        try{
            

            String Name = request.Name;
            String Id = request.Id;
            
            List<OCC_ApprovedAccount__c> accounts = [Select Id, Account__c from OCC_ApprovedAccount__c where (Account__c =: Id AND Contact__c =: contactId)];
            
            if(accounts.size() > 0){
                delete accounts;
            }
            

            result.DeletedId = Id;
            result.Success = true;
            result.Message = Name + ' Successfully Deleted';
        }catch (Exception e){
            result.Success = false;
            result.Message =  result.Message + ' ' + e.getMessage();
            
        }
        
        return result;
    } 

    public static OCCommunitiesResource.NotificationResults pollForNotifications( Id contactId){
        OCCommunitiesResource.NotificationResults results = new OCCommunitiesResource.NotificationResults();
        
        List<Contact> Contacts = [SELECT Id, Name, OCC_Rewards__c FROM Contact WHERE Id=:contactId];
        Contact contact = null;
        if(Contacts.size() > 0){
            contact = Contacts.get(0);
            
            List<OCC_BonusReward__c> BonusRewards = [SELECT Id, Name, Contact__c, ActionDescription__c, Redeemed__c, RedeemMessage__c, RewardValue__c FROM OCC_BonusReward__c WHERE Contact__c =: contactId AND Redeemed__c = true AND ContactNotified__c = false];
            
            if(BonusRewards.size() > 0){
                OCC_BonusReward__c BonusReward = BonusRewards.get(0);
                BonusReward.ContactNotified__c = true;
                results.Message = BonusReward.RedeemMessage__c;
                results.hasMessage = true;
                update BonusReward;
            }
            
        }
        
        return results;
    
    }
    
    public static OCCommunitiesResource.GetDataResults getData(OCCommunitiesResource.GetDataRequest request, Id contactId){
        OCCommunitiesResource.GetDataResults result = new OCCommunitiesResource.GetDataResults();
        
        try{
            
            Integer offset = request.offset;
            
            Map<String, OCCommunitiesResource.QOCTypeData> qocMap = new Map<String, OCCommunitiesResource.QOCTypeData>();            
            Set<Id> headerIds = new Set<Id>();        
            List<Account> childAccounts = new List<Account>();
                
            List<Contact> Contacts = [Select Email, Name, Phone, FirstName, LastName, PhotoUrl, OCC_Photo__c, OCC_ViewAll__c, OCC_ViewApproved__c, OCC_Rewards__c, Birthdate, AccountId from Contact where Id =: contactId];
            Contact contact = null;
            String accountId;
            if (Contacts.size() > 0){
                contact = Contacts.get(0);
                accountId = contact.AccountId;
            }
            
            //Get User Account
            List<Account> Accounts = [Select (SELECT Id, Name, Area_Account_Manager__c, Area_Account_Manager__r.Name from Job_Areas__r) Id, Active__c, Account_Number__c, Name, ParentId, OCC_Rewards__c, Phone, ShippingAddress, Outside_Salesperson__r.UserRole.Name, Outside_Salesperson__r.Name,  Outside_Salesperson__r.FullPhotoUrl, Outside_Salesperson__r.Photo__c , Outside_Salesperson__r.Email, Outside_Salesperson__r.ManagerId, Outside_Salesperson__r.Phone, BillingAddress , Owner.UserRole.Name, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone, Owner.FullPhotoUrl, Owner.Photo__c from Account where Id =: accountId];
            Account account = null;
            if(Accounts.size() > 0){
                account = Accounts.get(0);
            }
            
            //Get Parent Account
            Account parentAccount = null;
            List<Account> ParentAccounts = [Select (SELECT Id, Name, Area_Account_Manager__c, Area_Account_Manager__r.Name from Job_Areas__r), Id, Active__c, Account_Number__c, Name, ParentId, OCC_Rewards__c, Phone, ShippingAddress, Outside_Salesperson__r.UserRole.Name, Outside_Salesperson__r.Name,  Outside_Salesperson__r.FullPhotoUrl, Outside_Salesperson__r.Photo__c , Outside_Salesperson__r.Email, Outside_Salesperson__r.ManagerId, Outside_Salesperson__r.Phone, BillingAddress , Owner.UserRole.Name, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone, Owner.FullPhotoUrl, Owner.Photo__c from Account where Id =: account.ParentId];
            if(ParentAccounts.size() > 0){
                parentAccount = ParentAccounts.get(0);
            }
            
            if(contact.OCC_ViewAll__c == true){
                
                if(parentAccount != null){
                    childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: parentAccount.Id Or Id =: account.Id Or Id =: parentAccount.Id) AND Active__c != 'D' ORDER BY Name];
                }else{
                    childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: account.Id Or Id =: account.Id) AND Active__c != 'D' ORDER BY Name];
                    
                }
                
           
            }else if(contact.OCC_ViewApproved__c == true){
                List<String> approvedAccountIds = new List<String>();
                for(OCC_ApprovedAccount__c approvedAccount : [Select Contact__c, Status__c, Account__c, Account__r.Active__c, Account__r.Name FROM OCC_ApprovedAccount__c where Contact__c =: contact.Id AND (Status__c = 'Accepted' OR Status__c = 'Pending')]){
                    approvedAccountIds.add(approvedAccount.Account__c);
                }
                
                //if(approvedAccountIds.size() > 0 && (approvedAccountIds.get(0) != account.Id)){
                //  childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (/*Id =: account.Id OR*/ Id IN: approvedAccountIds) AND Active__c != 'D' ORDER BY Name];
                //}
                
                childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (/*Id =: account.Id OR*/ Id IN: approvedAccountIds) AND Active__c != 'D' ORDER BY Name];
                                
    
            }else{
            
                //childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: account.Id Or Id =: account.Id) AND Active__c != 'D' ORDER BY Name];
                
            }
            
            if(request.typeStr.equals('myQuotes')){
                
                Integer TotalCount = [Select COUNT() from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId AND /*QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND*/ QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Quote' OR Type__c = 'RFQ') LIMIT 2000];
                result.totalCount = TotalCount;
            
                for(QuotesOrdersCredits_Header__c header : [Select Id, of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c , TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId AND /*QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND*/ QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Quote' OR Type__c = 'RFQ') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 10 Offset :offset]) {
                         
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    headerIds.add(header.Id);
                    result.quotes.add(quoteData);
                }
                
            }else if(request.typeStr.equals('otherQuotes')){
                
                Integer TotalCount = [Select COUNT() from QuotesOrdersCredits_Header__c  where (Customer__c IN: childAccounts AND Buyer__c != :contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Quote' OR Type__c = 'RFQ') LIMIT 2000];
                result.totalCount = TotalCount;
                
                for(QuotesOrdersCredits_Header__c header : [Select Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c IN: childAccounts AND Buyer__c != :contactId) AND /*QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND*/ QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Quote' OR Type__c = 'RFQ') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 10 Offset: request.offset]) {
                     
                        OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                        quoteData.header = header;
                        qocMap.put(header.Id, quoteData);
                        headerIds.add(header.Id);
                        result.quotes.add(quoteData);                    
                 }
                
            }else if(request.typeStr.equals('myOrders')){
                
                Integer TotalCount = [Select COUNT() from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND Type__c = 'Order' AND Sub_Type__c='Blanket' LIMIT 2000];
                result.totalCount = TotalCount;
            
                for(QuotesOrdersCredits_Header__c header : [Select Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c , TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND Type__c = 'Order' AND Sub_Type__c='Blanket' ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 10 Offset :offset]) {
                         
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    headerIds.add(header.Id);
                    result.quotes.add(quoteData);
                }
                
            }else if(request.typeStr.equals('otherOrders')){
                
                Integer TotalCount = [Select COUNT() from QuotesOrdersCredits_Header__c  where (Customer__c IN: childAccounts AND Buyer__c != :contactId) AND /*QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND*/ QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND Type__c = 'Order' AND Sub_Type__c='Blanket' LIMIT 2000];
                result.totalCount = TotalCount;
                
                for(QuotesOrdersCredits_Header__c header : [Select Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c IN: childAccounts AND Buyer__c != :contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND Type__c = 'Order' AND Sub_Type__c='Blanket' ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 10 Offset: request.offset]) {
                     
                        OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                        quoteData.header = header;
                        qocMap.put(header.Id, quoteData);
                        headerIds.add(header.Id);
                        result.quotes.add(quoteData);                    
                 }
                 
            }else if(request.typeStr.equals('credits')){
                
                Integer TotalCount = [Select COUNT() from QuotesOrdersCredits_Header__c  where (Customer__c IN: childAccounts OR Buyer__c = :contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Credit' AND (CreditRMAPortalType__c = 'Credit' OR CreditRMAPortalType__c = 'Return')) LIMIT 2000];
                result.totalCount = TotalCount;
                
                for(QuotesOrdersCredits_Header__c header : [Select Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c IN: childAccounts OR Buyer__c = :contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Credit' AND (CreditRMAPortalType__c = 'Credit' OR CreditRMAPortalType__c = 'Return')) ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 10 Offset: request.offset]) {
                     
                        OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                        quoteData.header = header;
                        qocMap.put(header.Id, quoteData);
                        headerIds.add(header.Id);
                        result.quotes.add(quoteData);                    
                 }
                 
            }else if(request.typeStr.equals('search')){
                
                String soslSearch = request.searchText + '*';
                List<List<SObject>> allResults = [FIND :soslSearch RETURNING QuoteOrderCredit_Details__c (Order_Header__c WHERE Line_Status__c != 'Cancelled'  /*AND Date_Line_Entered__c = LAST_90_DAYS*/)];
                List<QuoteOrderCredit_Details__c> allDetails = ((List<QuoteOrderCredit_Details__c>)allResults[0]);

                for(QuoteOrderCredit_Details__c detail: allDetails){
                    if(!headerIds.contains(detail.Order_Header__c)){
                        headerIds.add(detail.Order_Header__c);
                    }
                }   
                        
                //search by header
                Integer counter = 0;
                String soqlSearch = request.searchText + '%';
                for(QuotesOrdersCredits_Header__c header : [Select Id, OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c WHERE Status__c != 'Cancelled' /*AND Date__c = LAST_90_DAYS*/ AND (Customer__c IN: childAccounts OR Buyer__c =: contactId) AND (Id IN :headerIds OR (Name LIKE :soqlSearch OR Status__c LIKE :soqlSearch OR Customer_PO__c LIKE :soqlSearch OR Job_Reference__c LIKE :soqlSearch OR Mark_Number__c LIKE :soqlSearch OR Buyer__r.Name LIKE :soqlSearch OR TotalOrderSalesPortal__c LIKE :soqlSearch)) ORDER BY Date__c DESC]) {
                 
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    
                    if(header.Type__c == 'Quote' || header.Type__c == 'RFQ') {
                        result.quotes.add(quoteData);
                    //NOTE: only add blanket master orders
                    } else if(header.Type__c == 'Order' && header.Sub_Type__c == 'Blanket') {
                        result.orders.add(quoteData);
                    } else if(header.Type__c == 'Credit' && (header.CreditRMAPortalType__c == 'Credit' || header.CreditRMAPortalType__c == 'Return')) {
                        result.credits.add(quoteData);
                    }
                    
                    if(!headerIds.contains(header.Id)){
                        headerIds.add(header.Id);
                    }
                    
                    counter++;
                      
                 }
                 
                 result.Message = 'term= ' + soqlSearch + ' details = ' + String.valueOf(allDetails.size()) + 'allQOCS = ' + String.valueOf(counter);
            }
            
            for(QuoteOrderCredit_Details__c detail : [Select Id, Customer_Item__c, CableCode__c, Item_Markings__c, SalesPricePortal__c, NotesPortal__c, TotalDollarsPortal__c, Put_up_1__c, Put_up_2__c, Put_up_3__c, Put_up_4__c, Put_up_5__c, Put_up_6__c, Put_up_7__c, Spec_Sheet__c, C2SPRC__c, Name, Dollars__c, Expected_Date__c, Freight_Terms__c, Freight_Carrier__c, Item_Description__c,  Line_Item__c, Line_Number__c, Line_Status__c, Qty_Ordered__c, Qty_Shipped__c, TrackingURL__c, Order_Header__c, Received_Complete__c from QuoteOrderCredit_Details__c where Order_Header__c IN: headerIds AND Line_Status__c != 'Cancelled' ORDER BY QuoteOrderCredit_Details__c.Line_Number__c]) {
            
                OCCommunitiesResource.QOCTypeData quoteData =  qocMap.get(detail.Order_Header__c);
                if(quoteData != null) {
                    quoteData.details.add(detail);
                }   
            }
            
           if(headerIds.size() > 0){
            
               for(ContentDocumentLink contentDoc : [Select Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, ContentDocument.title, LinkedEntityId from ContentDocumentLink where LinkedEntityId IN :headerIds]) {
                    
                    OCCommunitiesResource.QOCTypeData quoteData =  qocMap.get(contentDoc.LinkedEntityId);
                    if(quoteData != null && contentDoc.ContentDocument != null && !contentDoc.ContentDocument.title.contains('Invoice')) {
                        
                        OCCommunitiesResource.QOCAttachment att = new OCCommunitiesResource.QOCAttachment();
                        att.title = contentDoc.ContentDocument.title;
                        att.url = request.url + '/sfc/servlet.shepherd/version/download/' + contentDoc.ContentDocument.LatestPublishedVersionId;
                        att.image = request.url + '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + contentDoc.ContentDocument.LatestPublishedVersionId;
                        quoteData.attachments.add(att);
                    }
                    
               }
            
           }
            
            
            
            result.Success = true;
        }catch(Exception e){
            
            result.Message = e.getMessage();
            
        }
                
        return result;
    }

    public static Boolean runningInASandbox() {
        return [SELECT Id, IsSandbox FROM Organization LIMIT 1].IsSandbox;
    }
    
    public static Id getContactIdByUserId(Id userId){
        List<User> users = [SELECT ContactId FROM User WHERE Id =: userId];
        if(users.size() > 0){
            return users.get(0).ContactId;
        }else{
            return null;
        }
    }

    public static Id getUserIdByContactId(Id contactId){
        List<User> users = [SELECT Id FROM User WHERE ContactId =: contactId];
        if(users.size() > 0){
            return users.get(0).Id;
        }else{
            return null;
        }
    }

    public static Id getContactIdOfRequest(){
        RestRequest request = RestContext.request;
        return request.requestURI.substring(request.requestURI.lastIndexOf('/')+1);
    }

    public static void updateContactRewards(Set<Id> contactIds){
        List<Contact> updatedContacts = new List<Contact>();
        for(Contact contact : [Select Id, OCC_RewardStep__c , OCC_RewardStepValue__c, OCC_RewardsTotal__c, OCC_RewardsValue__c from Contact where Id IN: contactIds]){
            HeaderCalculationResult headerResults = getHeaderAndTotals(contact);
            Decimal total = headerResults.total;
            System.debug('Contact Total: ' + total);
            contact.OCC_RewardsTotal__c = total;
            updatedContacts.add(contact);
        }

        update updatedContacts;
        
    }


    /**
    * @name getPicklistValue
    * @description Get picklist value for a given object and field
    * @param String objectName
    * @param String fieldName
    **/
    public static List<String> getPicklistValue(String objectName, String fieldName){
        List<String> myPicklist  = new List<String>(); 
        String[] types = new String[]{objectName};

        Schema.DescribeSobjectResult[] results = Schema.describeSObjects(types);

        for(Schema.DescribeSobjectResult res : results) {
            Schema.SObjectField sfield = res.fields.getMap().get(fieldName);
            for (Schema.PicklistEntry f : sfield.getDescribe().getPicklistValues()){
                myPicklist.add(f.getLabel());
            }
        }

        return myPicklist;

    }

    public class updateValue{
        String id;
        Boolean value;
    }

    /**
    * @name toggleReleaseReceive
    * @description Update release detail recieved value
    * @param String Id
    * @param String value
    **/
    @RemoteAction
    webservice static Boolean toggleReleaseReceive(String params){

        JSONParser parser = JSON.createParser(params);
        updateValue request = (updateValue)parser.readValueAs(updateValue.class);

        QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Id=request.id, Received_Complete__c=request.value);
        Update detail;
        return detail.Received_Complete__c;
    }


    /**
    * @name getAlternativePartNumbers
    * @description Gets all alternative part numbers for a given account
    * @param String accountId
    **/
    @RemoteAction
    public static List<Alternative_Part_Number__c> getAlternativePartNumbersAll(String accountId){
        // System.debug('accountIds: ' + accountIds);
        // List<String> partNames = new List<String>();
        // List<Alternative_Part_Number__c> alternativePartsupdate = new List<Alternative_Part_Number__c>();
        // Map<String, Alternative_Part_Number__c> partsMap = new Map<String, Alternative_Part_Number__c>();
        // List<Alternative_Part_Number__c> allParts = [SELECT Id, Name, Account__c, Cable_Code__c, Part_Numbers__c, Part_Numbers__r.Id, Part_Numbers__r.Name, Part_Numbers__r.Item_Description_OPUS__c, Closed__c from Alternative_Part_Number__c WHERE Account__c IN: accountIds AND Closed__c = false ORDER BY NAME ASC];


        // for (Alternative_Part_Number__c part : allParts) {
        //     partNames.add(part.Part_Numbers__r.Name);
        //     partsMap.put(part.Part_Numbers__r.Name, part);
        // }

        // for(QuoteOrderCredit_Details__c foundDetails : [Select Id, Name, Line_Item__c, Line_Status__c, Order_Header__c from QuoteOrderCredit_Details__c WHERE Line_Item__c IN: partNames AND Line_Status__c != 'Cancelled' AND Order_Header__r.Customer__c IN: accountIds AND (Order_Header__r.Type__c = 'Release' OR  ( Order_Header__r.Type__c = 'Order' AND  Order_Header__r.Sub_Type__c='Change Order'))]){
            
        //     if(partsMap.get(foundDetails.Line_Item__c) != null){
        //         Alternative_Part_Number__c part =  partsMap.get(foundDetails.Line_Item__c);
        //         part.Closed__c = true;
        //         alternativePartsupdate.add(part);
        //     }

        // }
        
        
        
        
        // return alternativePartsupdate;
        return [SELECT Id, Name, Account__c, Cable_Code__c, Part_Numbers__c, Part_Numbers__r.Id, Part_Numbers__r.Name, Part_Numbers__r.Item_Description_OPUS__c from Alternative_Part_Number__c WHERE Account__c =: accountId ORDER BY NAME ASC];
    }

    /**
    * @name getAlternativePartNumbers
    * @description Gets all alternative part numbers for a given account
    * @param String accountId
    **/
    @RemoteAction
    public static List<Alternative_Part_Number__c> getAlternativePartNumbers(String accountId){
        return [SELECT Id, Name, Account__c, Cable_Code__c, Part_Numbers__c, Part_Numbers__r.Id, Part_Numbers__r.Name, Part_Numbers__r.Item_Description_OPUS__c from Alternative_Part_Number__c WHERE Account__c =: accountId];
    }

    /**
    * @name getAllMasterOrders
    * @description Get master order for all accounts
    * @param String accountId
    **/
    @RemoteAction
    public static List<OCCommunitiesResource.QOCTypeData> getAllMasterOrders(String accountId){
        List<OCCommunitiesResource.QOCTypeData> allMasterOrders = new List<OCCommunitiesResource.QOCTypeData>();
        List<String> headerIds = new List<String>();
        Map<String, OCCommunitiesResource.QOCTypeData> qocMap = new Map<String, OCCommunitiesResource.QOCTypeData>();  

        for(QuotesOrdersCredits_Header__c header : [Select /*(SELECT Id, Name from Delivery_Addresses__r), (SELECT Id, Name from RMF_PO__r)*/ (SELECT Id, Name, Account__c, Part_Numbers__c, Part_Numbers__r.Id, Part_Numbers__r.Name, Part_Numbers__r.Item_Description_OPUS__c from Alternative_Part_Numbers__r), Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c =: accountId /*AND Buyer__c != :contactId*/) AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND Type__c = 'Order' AND (Sub_Type__c='Blanket' /*OR Sub_Type__c='Change Order'*/) ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC ]) {
            OCCommunitiesResource.QOCTypeData orderData = new OCCommunitiesResource.QOCTypeData();
            orderData.header = header;
            qocMap.put(header.Id, orderData);
            headerIds.add(header.Id);
            allMasterOrders.add(orderData);                    
        }

        for(QuoteOrderCredit_Details__c detail : [Select Id, Customer_Item__c, CableCode__c, Item_Markings__c, SalesPricePortal__c, NotesPortal__c, TotalDollarsPortal__c, Put_up_1__c, Put_up_2__c, Put_up_3__c, Put_up_4__c, Put_up_5__c, Put_up_6__c, Put_up_7__c, Spec_Sheet__c, C2SPRC__c, Name, Dollars__c, Expected_Date__c, Freight_Terms__c, Freight_Carrier__c, Item_Description__c,  Line_Item__c, Line_Number__c, Line_Status__c, Qty_Ordered__c, Qty_Shipped__c, TrackingURL__c, Order_Header__c, Received_Complete__c from QuoteOrderCredit_Details__c where Order_Header__c IN: headerIds AND Line_Status__c != 'Cancelled' ORDER BY QuoteOrderCredit_Details__c.Line_Number__c]) {
            OCCommunitiesResource.QOCTypeData orderData =  qocMap.get(detail.Order_Header__c);
            if(orderData != null) {
                orderData.details.add(detail);
            }   
        }

        return allMasterOrders;
    }

    /**
    * @name getDeliveryAddresses
    * @description Gets all delivery addresses for a given account
    * @param String accountId
    **/
    @RemoteAction
    public static List<Delivery_Address__c> getDeliveryAddresses(String accountId){
        return [SELECT Id, Name, Account__c from Delivery_Address__c WHERE Account__c =: accountId];
    }

    /**
    * @name getInitialData
    * @description Gets initial data for communities site.  This method was created just in case external site uses getCommunitiesData
    * @param String accountId
    **/
    public static OCCommunitiesResource.QOCDataResult getInitialData(OCCommunitiesResource.QOCRequest request, Id contactId){
        OCCommunitiesResource.QOCDataResult result = new OCCommunitiesResource.QOCDataResult();
        
        try{

            Contact contact = [Select Region__c, Email, Name, OCC_Hide_Account_Access_Panel__c, Phone, FirstName, LastName, Buyer__c, PhotoUrl, OCC_Photo__c, OCC_ViewAll__c, OCC_ViewApproved__c, OCC_Rewards__c, Birthdate, OCC_RewardsValue__c, AccountId from Contact where Id =: contactId LIMIT 1];
            result.contact = contact;
            result.Rewards = contact.OCC_Rewards__c;
            
            Account account = [Select (SELECT Id, Name, Area_Account_Manager__c, Area_Account_Manager__r.Name from Job_Areas__r), Id, Active__c, Account_Number__c, Name, ParentId, OCC_Rewards__c, Phone, ShippingAddress, Outside_Salesperson__r.UserRole.Name, Outside_Salesperson__r.Name,  Outside_Salesperson__r.FullPhotoUrl, Outside_Salesperson__r.Photo__c , Outside_Salesperson__r.Email, Outside_Salesperson__r.ManagerId, Outside_Salesperson__r.Phone, BillingAddress , Owner.UserRole.Name, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone, Owner.FullPhotoUrl, Owner.Photo__c from Account where Id =: contact.AccountId LIMIT 1];
            result.account = account;
            result.manager1 = account.Owner;
            result.manager2 = account.Outside_Salesperson__r;

            List<User> otherManagers = [Select Name, UserRole.Name, Email, Phone, FullPhotoUrl, Photo__c, ManagerId from User where Id  =: account.Outside_Salesperson__r.ManagerId];
            if (otherManagers.size() > 0){
                result.manager3 = otherManagers.get(0);
            }

            Map<String, OCCommunitiesResource.QOCTypeData> qocMap = new Map<String, OCCommunitiesResource.QOCTypeData>();
            Map<String, OCCommunitiesResource.QOCTypeData> pendingMap = new Map<String, OCCommunitiesResource.QOCTypeData>();
            
            Set<Id> headerIds = new Set<Id>(); 
            result.AccountType = 'View Mine Only';
            for(QuotesOrdersCredits_Header__c header : [Select Id,  of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c , TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c  where Customer__c =: account.Id AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Release' OR Type__c = 'RFQ' OR Sub_Type__c = 'Change Order') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 5]) {
                OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                quoteData.header = header;
                qocMap.put(header.Id, quoteData);
                headerIds.add(header.Id);
                result.quotes.add(quoteData);                   
            }
            
            List<OCC_ContactSlider__c> contactSlider = [Select Name, URL__c, LinkUrl__c, Index__c from OCC_ContactSlider__c where Contact__c =: contactId ORDER BY OCC_ContactSlider__c.Index__c];
            
            if (contactSlider.size() == 0){
                contactSlider = [Select Name, URL__c, LinkUrl__c, Index__c from OCC_ContactSlider__c where Contact__c = Null ORDER BY OCC_ContactSlider__c.Index__c];
            }
            
            result.contactSlider = contactSlider;
            result.Message = String.valueOf(contactSlider.size());
       
            for(QuoteOrderCredit_Details__c detail : [Select Id, Customer_Item__c, CableCode__c, Item_Markings__c, SalesPricePortal__c, NotesPortal__c, TotalDollarsPortal__c, Put_up_1__c, Put_up_2__c, Put_up_3__c, Put_up_4__c, Put_up_5__c, Put_up_6__c, Put_up_7__c, Spec_Sheet__c, C2SPRC__c, Name, Dollars__c, Expected_Date__c, Freight_Terms__c, Freight_Carrier__c, Item_Description__c,  Line_Item__c, Line_Number__c, Line_Status__c, Qty_Ordered__c, Qty_Shipped__c, TrackingURL__c, Order_Header__c, Received_Complete__c from QuoteOrderCredit_Details__c where Order_Header__c IN: headerIds AND Line_Status__c != 'Cancelled' ORDER BY QuoteOrderCredit_Details__c.Line_Number__c]) {
                OCCommunitiesResource.QOCTypeData quoteData =  qocMap.get(detail.Order_Header__c);
                if(quoteData != null) {
                    quoteData.details.add(detail);
                }   
            }
            
            List<ContentDocumentLink> docs = [Select Id, ContentDocumentId, ContentDocument.title, LinkedEntityId from ContentDocumentLink where LinkedEntityId IN: headerIds];
            result.Message = String.valueOf(docs.size());
           
            OCCommunitiesResourceHelper.getDocuments(qocMap, request.url, headerIds);                    
            
            result.rmfPOValues = OCCommunitiesResourceHelper.getFieldDependencies('Account', 'Portal_PO_Selector__c', 'Portal_POs__c', account.Account_Number__c);
            result.alternativePartNumbers = OCCommunitiesResourceHelper.getAlternativePartNumbersAll(account.Id);
            result.filteredAlternativePartNumbers = OCCommunitiesResourceHelper.getFilteredAlternativeParts(result.alternativePartNumbers, headerIds, account.Id);
            result.deliveryAddresses = OCCommunitiesResourceHelper.getDeliveryAddresses(account.Id);
            result.masterOrders = OCCommunitiesResourceHelper.getAllMasterOrders(account.Id);
            result.siteUrl = URL.getSalesforceBaseUrl().toExternalForm();
            result.Success = true;
            
        }catch(Exception e){
            result.Success = false;
            result.Message = e.getMessage();
        }
           
        return result;
    }

    /**
    * @name getDataPortal
    * @description Gets quote/order/credit for communities.  This method was created just in case external site uses getCommunitiesData
    * @param String accountId
    **/
    public static OCCommunitiesResource.GetDataResults getDataPortal(OCCommunitiesResource.GetDataRequest request, Id contactId){
        OCCommunitiesResource.GetDataResults result = new OCCommunitiesResource.GetDataResults();
        
        try{
            Integer offset = request.offset;
            Map<String, OCCommunitiesResource.QOCTypeData> qocMap = new Map<String, OCCommunitiesResource.QOCTypeData>();            
            Set<Id> headerIds = new Set<Id>();        
            AccountAccess access = OCCommunitiesResourceHelper.getAccountAccess(contactId);
            
            if(request.typeStr.equals('myQuotes')){
                Integer totalCount = [Select COUNT() from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Release' OR Type__c = 'RFQ' OR Sub_Type__c = 'Change Order' ) LIMIT 2000];
                result.totalCount = totalCount;
                for(QuotesOrdersCredits_Header__c header : [Select Id, of_Lines__c, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Notes__c, Name, Purchase_Agent__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c , TotalDollars__c, Outside_AM_Name__r.Name, Outside_AM_Name__r.UserRole.Name, Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, Entered_By__r.Name, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c  where Buyer__c =: contactId AND /*QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND*/ QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Release' OR Type__c = 'RFQ' OR Sub_Type__c = 'Change Order' ) ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 10 Offset :offset]) {
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    headerIds.add(header.Id);
                    result.quotes.add(quoteData);
                }
                
            }else if(request.typeStr.equals('otherQuotes')){
                Integer totalCount = [Select COUNT() from QuotesOrdersCredits_Header__c  where (Customer__c =: access.contact.AccountId AND Buyer__c != :contactId) /*AND QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS*/ AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Release' OR Type__c = 'RFQ' OR Sub_Type__c = 'Change Order' ) LIMIT 2000];
                result.totalCount = totalCount;
                for(QuotesOrdersCredits_Header__c header : [Select Id, Ship_to_Address_1__c, Ship_to_Address_2__c, Ship_to_City__c, Ship_to_State__c, Ship_to_Zip_Code__c,  OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c where (Customer__c =: access.contact.AccountId AND Buyer__c != :contactId) AND /*QuotesOrdersCredits_Header__c.Date__c = LAST_90_DAYS AND*/ QuotesOrdersCredits_Header__c.Status__c != 'Cancelled' AND (Type__c = 'Release' OR Type__c = 'RFQ' OR Sub_Type__c = 'Change Order') ORDER BY QuotesOrdersCredits_Header__c.Date__c DESC LIMIT 10 Offset: request.offset]) {
                        OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                        quoteData.header = header;
                        qocMap.put(header.Id, quoteData);
                        headerIds.add(header.Id);
                        result.quotes.add(quoteData);                    
                }
                
            }else if(request.typeStr.equals('search')){
                String soslSearch = request.searchText + '*';
                List<List<SObject>> alternativeParts = [FIND :soslSearch RETURNING Alternative_Part_Number__c (Id, Name, Account__c, Cable_Code__c, Part_Numbers__c, Part_Numbers__r.Id, Part_Numbers__r.Name, Part_Numbers__r.Item_Description_OPUS__c WHERE Account__c =: access.mainAccount.Id)];
                List<Alternative_Part_Number__c> allparts = ((List<Alternative_Part_Number__c>)alternativeParts[0]);
                List<String> partIds = new List<String>();
                List<String> partNames = new List<String>();
                Map<String, Alternative_Part_Number__c> partMap = new  Map<String, Alternative_Part_Number__c>();
                System.debug('allparts: ' + allparts);
                for(Alternative_Part_Number__c part: allparts){
                    partNames.add(part.Part_Numbers__r.Name);
                    partMap.put(part.Id, part);
                    if(!partIds.contains(part.Id)){
                        partIds.add(part.Id);
                    }
                }  

                /** NOTE: Search details by part name */
                for(QuoteOrderCredit_Details__c findDetailsByPart : [Select Id, Name, Line_Item__c, Line_Status__c, Order_Header__c from QuoteOrderCredit_Details__c WHERE Line_Item__c IN: partNames AND Line_Status__c != 'Cancelled' AND Order_Header__r.Customer__c =: access.mainAccount.Id]){
                    if(!headerIds.contains(findDetailsByPart.Order_Header__c)){
                        headerIds.add(findDetailsByPart.Order_Header__c);
                    }
                }

                List<List<SObject>> allResults = [FIND :soslSearch RETURNING QuoteOrderCredit_Details__c (Order_Header__c WHERE Line_Status__c != 'Cancelled' AND Order_Header__r.Customer__c =: access.mainAccount.Id)];
                List<QuoteOrderCredit_Details__c> allDetails = ((List<QuoteOrderCredit_Details__c>)allResults[0]);
                for(QuoteOrderCredit_Details__c detail: allDetails){
                    if(!headerIds.contains(detail.Order_Header__c)){
                        headerIds.add(detail.Order_Header__c);
                    }
                }   
                        
                /** NOTE: Search headers */
                Integer counter = 0;
                String soqlSearch = '%' + request.searchText + '%';
                for(QuotesOrdersCredits_Header__c header : [Select Id, OCC_RewardRedeemed__c, Order_Number__c, RFQNumber__c, RFQ_Text__c, CreditRMAPortalType__c, TotalOrderSalesPortal__c, CreatedDate, Name, Purchase_Agent__c, Notes__c, Status__c, Type__c, OCC_Rewards__c, Customer__c, Customer__r.ShippingAddress, Customer__r.BillingAddress, Customer__r.Name, Customer__r.OCC_Rewards__c, Total_Order_Sales__c, TotalDollars__c, Outside_AM_Name__r.Name,Outside_AM_Name__r.UserRole.Name,  Outside_AM_Name__r.FullPhotoUrl, Outside_AM_Name__r.Photo__c, Outside_AM_Name__r.Email, Outside_AM_Name__r.Phone, Inside_AM_Name__r.Email, Inside_AM_Name__r.FullPhotoUrl, Inside_AM_Name__r.Photo__c, Inside_AM_Name__r.Phone, Inside_AM_Name__r.Name, Entered_By__c, Date__c, Buyer__c, Job_Reference__c, Mark_Number__c, Payment_Terms__c, Customer_PO__c, Customer_Name__c, Customer__r.OwnerId, Buyer__r.Name, RewardOverride__c, RMF_PO__c, Sub_Type__c from QuotesOrdersCredits_Header__c WHERE Status__c != 'Cancelled' AND (Customer__c IN: access.childAccounts OR Buyer__c =: contactId) AND (Id IN :headerIds OR (Name LIKE :soqlSearch OR Status__c LIKE :soqlSearch OR Customer_PO__c LIKE :soqlSearch OR Job_Reference__c LIKE :soqlSearch OR Mark_Number__c LIKE :soqlSearch OR Buyer__r.Name LIKE :soqlSearch OR TotalOrderSalesPortal__c LIKE :soqlSearch)) ORDER BY Date__c DESC]) {
                 
                    OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();
                    quoteData.header = header;
                    qocMap.put(header.Id, quoteData);
                    
                    if(header.Type__c == 'Release' || header.Type__c == 'RFQ' || header.Sub_Type__c == 'Change Order' /*|| (header.Type__c == 'Order' && header.Sub_Type__c == 'Change Order')*/) {
                        result.quotes.add(quoteData);
                    } else if(header.Type__c == 'Order' && (header.Sub_Type__c == 'Blanket')) {
                        result.orders.add(quoteData);
                    } 
                    
                    if(!headerIds.contains(header.Id)){
                        headerIds.add(header.Id);
                    }
                    
                    counter++;
                      
                 }
                 
                 result.Message = 'term= ' + soqlSearch + ' details = ' + String.valueOf(allDetails.size()) + 'allQOCS = ' + String.valueOf(counter);
            }
            
            for(QuoteOrderCredit_Details__c detail : [Select Id, Customer_Item__c, CableCode__c, Item_Markings__c, SalesPricePortal__c, NotesPortal__c, TotalDollarsPortal__c, Put_up_1__c, Put_up_2__c, Put_up_3__c, Put_up_4__c, Put_up_5__c, Put_up_6__c, Put_up_7__c, Spec_Sheet__c, C2SPRC__c, Name, Dollars__c, Expected_Date__c, Freight_Terms__c, Freight_Carrier__c, Item_Description__c,  Line_Item__c, Line_Number__c, Line_Status__c, Qty_Ordered__c, Qty_Shipped__c, TrackingURL__c, Order_Header__c, Received_Complete__c from QuoteOrderCredit_Details__c where Order_Header__c IN: headerIds AND Line_Status__c != 'Cancelled' ORDER BY QuoteOrderCredit_Details__c.Line_Number__c]) {
                OCCommunitiesResource.QOCTypeData quoteData =  qocMap.get(detail.Order_Header__c);
                if(quoteData != null) {
                    quoteData.details.add(detail);
                }   
            }

            OCCommunitiesResourceHelper.getDocuments(qocMap, request.url, headerIds);    
            result.Success = true;

        }catch(Exception e){
            result.Message = e.getMessage();
        }
                
        return result;
    }

    global class AccountAccess{
        Account mainAccount = new Account();
    	List<Account> allAccounts = new List<Account>();
        List<Account> childAccounts = new List<Account>();
        List<String> accessAccountIds = new List<String>();
        Contact contact = new Contact();
    }


   /**
    * @name getDeliveryAddresses
    * @description Gets all delivery addresses for a given account
    * @param String accountId
    **/
    @RemoteAction
    public static AccountAccess getAccountAccess(String contactId){
        AccountAccess access = new AccountAccess();

        List<Contact> contacts = [Select Email, Name, Phone, FirstName, LastName, PhotoUrl, OCC_Photo__c, OCC_ViewAll__c, OCC_ViewApproved__c, OCC_Rewards__c, Birthdate, AccountId from Contact where Id =: contactId];
        Contact contact = new Contact();
       
        if (contacts.size() > 0){
            contact = contacts.get(0);
            access.contact = contact;
        }
        
        //Get User Account
        List<Account> accounts = [Select (SELECT Id, Name, Area_Account_Manager__c, Area_Account_Manager__r.Name from Job_Areas__r) Id, Active__c, Account_Number__c, Name, ParentId, OCC_Rewards__c, Phone, ShippingAddress, Outside_Salesperson__r.UserRole.Name, Outside_Salesperson__r.Name,  Outside_Salesperson__r.FullPhotoUrl, Outside_Salesperson__r.Photo__c , Outside_Salesperson__r.Email, Outside_Salesperson__r.ManagerId, Outside_Salesperson__r.Phone, BillingAddress , Owner.UserRole.Name, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone, Owner.FullPhotoUrl, Owner.Photo__c from Account where Id =: contact.AccountId];
        Account account = null;
        if(Accounts.size() > 0){
            account = accounts.get(0);
            access.mainAccount = account;
        }
        
        //Get Parent Account
        Account parentAccount = null;
        List<Account> parentAccounts = [Select (SELECT Id, Name, Area_Account_Manager__c, Area_Account_Manager__r.Name from Job_Areas__r), Id, Active__c, Account_Number__c, Name, ParentId, OCC_Rewards__c, Phone, ShippingAddress, Outside_Salesperson__r.UserRole.Name, Outside_Salesperson__r.Name,  Outside_Salesperson__r.FullPhotoUrl, Outside_Salesperson__r.Photo__c , Outside_Salesperson__r.Email, Outside_Salesperson__r.ManagerId, Outside_Salesperson__r.Phone, BillingAddress , Owner.UserRole.Name, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone, Owner.FullPhotoUrl, Owner.Photo__c from Account where Id =: account.ParentId];
        if(ParentAccounts.size() > 0){
            parentAccount = parentAccounts.get(0);
        }
        
        if(contact.OCC_ViewAll__c == true){
            
            if(parentAccount != null){
                access.childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: parentAccount.Id Or Id =: account.Id Or Id =: parentAccount.Id) AND Active__c != 'D' ORDER BY Name];
            }else{
                access.childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: account.Id Or Id =: account.Id) AND Active__c != 'D' ORDER BY Name];
            }
        
        }else if(contact.OCC_ViewApproved__c == true){

            List<String> approvedAccountIds = new List<String>();
            for(OCC_ApprovedAccount__c approvedAccount : [Select Contact__c, Status__c, Account__c, Account__r.Active__c, Account__r.Name FROM OCC_ApprovedAccount__c where Contact__c =: contact.Id AND (Status__c = 'Accepted' OR Status__c = 'Pending')]){
                approvedAccountIds.add(approvedAccount.Account__c);
            }
            access.childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (Id IN: approvedAccountIds) AND Active__c != 'D' ORDER BY Name];
                            

        }else{
            
            //TODO: determin if viewing my account only contains all children as well
            //childAccounts = [SELECT Name, Active__c, Account_Number__c, Phone, Id, ShippingAddress FROM Account WHERE (ParentId =: account.Id Or Id =: account.Id) AND Active__c != 'D' ORDER BY Name];
            
        }

        return access;
    }

    /**
    * @name getFilteredAlternativeParts
    * @description Gets all alternative part numbers for a given account and filter losded
    * @param List<Alternative_Part_Number__c>
    * @param List<String> headerIds
    **/
    @RemoteAction
    public static List<Alternative_Part_Number__c> getFilteredAlternativeParts(List<Alternative_Part_Number__c> allparts, Set<Id> headerIds, String accountId){
        List<String> partNames = new List<String>();
        List<Alternative_Part_Number__c> alternativePartsupdate = new List<Alternative_Part_Number__c>();
        Map<String, Alternative_Part_Number__c> partsMap = new Map<String, Alternative_Part_Number__c>();
        System.debug('allparts: ' + allparts);

        for (Alternative_Part_Number__c part : allParts) {
            partNames.add(part.Part_Numbers__r.Name);
            partsMap.put(part.Name.trim(), part);
            //partsMap.put(part.Part_Numbers__r.Name, part);

        }

        System.debug('headerIds: ' + headerIds);

        /* get all details for header ids */
        for(QuoteOrderCredit_Details__c detail : [Select Id, Name, Line_Item__c, Customer_Item__c, Item_Markings__c, Line_Status__c, Order_Header__c, Qty_Ordered__c, Qty_Shipped__c,  Order_Header__r.Type__c, Order_Header__r.Sub_Type__c from QuoteOrderCredit_Details__c WHERE Order_Header__r.Customer__c =: accountId AND Line_Status__c != 'Cancelled' /*AND (Order_Header__r.Type__c = 'Release' OR  ( Order_Header__r.Type__c = 'Order' AND  Order_Header__r.Sub_Type__c='Change Order'))*/]){
            System.debug('detail: ' + detail);
            if(!String.isBlank(detail.Customer_Item__c)){

                
                // NOTE: remove if quanity remaining is 0
                if(partsMap.get(detail.Customer_Item__c.trim()) != null && detail.Qty_Ordered__c == detail.Qty_Shipped__c){
                    Alternative_Part_Number__c part =  partsMap.get(detail.Customer_Item__c.trim());
                    System.debug('PART QTY 0: ' + part);
                    part.Closed__c = true;
                    if(!alternativePartsupdate.contains(part)){
                        alternativePartsupdate.add(part);
                    }
                }

                // NOTE: remove if part of a release or if part of an order with subtype change order
                if(partsMap.get(detail.Customer_Item__c.trim()) != null && (detail.Order_Header__r.Type__c == 'Release' || (detail.Order_Header__r.Type__c == 'Order' &&  detail.Order_Header__r.Sub_Type__c == 'Change Order')) ){
                    Alternative_Part_Number__c part =  partsMap.get(detail.Customer_Item__c.trim());
                    System.debug('PART RELEASE: ' + part);
                    part.Closed__c = true;
                    if(!alternativePartsupdate.contains(part)){
                        alternativePartsupdate.add(part);
                    }
                    
                }

            }else{
                System.debug(detail.Name + 'has null Customer_Item__c');
            }

        }
        
        Update alternativePartsupdate; 
        return [SELECT Id, Name, Account__c, Cable_Code__c, Part_Numbers__c, Part_Numbers__r.Id, Part_Numbers__r.Name, Part_Numbers__r.Item_Description_OPUS__c from Alternative_Part_Number__c WHERE Account__c =: accountId AND Closed__c = false ORDER BY NAME ASC];
    }

    public class MyPickListInfo{
        public String validFor;
    }

    /**
    * @name getFieldDependencies
    * @description get dependent list based on account number
    * @param String objectName
    * @param String controllingField
    * @param String dependentField
    * @param String AccountNumber
    * @return List<String> dependentFields
    **/
    public static List<String> getFieldDependencies(String objectName, String controllingField, String dependentField, String AccountNumber){
        Map<String, List<String>> controllingInfo = new Map<String, List<String>>();

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);

        Schema.DescribeSObjectResult describeResult = objType.getDescribe();
        Schema.DescribeFieldResult controllingFieldInfo = describeResult.fields.getMap().get(controllingField).getDescribe();
        Schema.DescribeFieldResult dependentFieldInfo = describeResult.fields.getMap().get(dependentField).getDescribe();

        List<Schema.PicklistEntry> controllingValues = controllingFieldInfo.getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldInfo.getPicklistValues();

        for(Schema.PicklistEntry currControllingValue : controllingValues)
        {
            System.debug('ControllingField: Label:' + currControllingValue.getLabel());
            controllingInfo.put(currControllingValue.getLabel(), new List<String>());
        }

        for(Schema.PicklistEntry currDependentValue : dependentValues)
        {
            String jsonString = JSON.serialize(currDependentValue);

            MyPickListInfo info = (MyPickListInfo) JSON.deserialize(jsonString, MyPickListInfo.class);

            String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(info.validFor)).toUpperCase();

            System.debug('DependentField: Label:' + currDependentValue.getLabel() + ' ValidForInHex:' + hexString + ' JsonString:' + jsonString);

            Integer baseCount = 0;

            for(Integer curr : hexString.getChars())
            {
                Integer val = 0;

                if(curr >= 65)
                {
                    val = curr - 65 + 10;
                }
                else
                {
                    val = curr - 48;
                }

                if((val & 8) == 8)
                {
                    System.debug('Dependent Field: ' + currDependentValue.getLabel() + ' Partof ControllingField:' + controllingValues[baseCount + 0].getLabel());
                    controllingInfo.get(controllingValues[baseCount + 0].getLabel()).add(currDependentValue.getLabel());
                }
                if((val & 4) == 4)
                {
                    System.debug('Dependent Field: ' + currDependentValue.getLabel() + ' Partof ControllingField:' + controllingValues[baseCount + 1].getLabel());
                    controllingInfo.get(controllingValues[baseCount + 1].getLabel()).add(currDependentValue.getLabel());                    
                }
                if((val & 2) == 2)
                {
                    System.debug('Dependent Field: ' + currDependentValue.getLabel() + ' Partof ControllingField:' + controllingValues[baseCount + 2].getLabel());
                    controllingInfo.get(controllingValues[baseCount + 2].getLabel()).add(currDependentValue.getLabel());                    
                }
                if((val & 1) == 1)
                {
                    System.debug('Dependent Field: ' + currDependentValue.getLabel() + ' Partof ControllingField:' + controllingValues[baseCount + 3].getLabel());
                    controllingInfo.get(controllingValues[baseCount + 3].getLabel()).add(currDependentValue.getLabel());                    
                }

                baseCount += 4;
            }            
        } 

        System.debug('ControllingInfo: ' + controllingInfo);

        List<String> results = new List<String>();
        if(controllingInfo.get(AccountNumber) != null){
            results = controllingInfo.get(AccountNumber);
        }

        return results;
    }

    /**
    * @name getDocuments
    * @description get documents for all quote/order/credits
    * @param Map<String, OCCommunitiesResource.QOCTypeData> qocMap
    * @param String url
    * @param Set<Id> headerIds
    * @return Map<String, OCCommunitiesResource.QOCTypeData> qocMap
    **/
    public static Map<String, OCCommunitiesResource.QOCTypeData> getDocuments(Map<String, OCCommunitiesResource.QOCTypeData> qocMap, String url, Set<Id> headerIds){

        User user = [SELECT Id, Name, Profile.name from User WHERE Id =: UserInfo.getUserId()];
        Boolean invoiceAccess = user.Profile.name == 'E.D. Portal User' ? true : false;
        OCCommunitiesResource.QOCTypeData quoteData = new OCCommunitiesResource.QOCTypeData();

        List<ContentDocumentLink> links = [Select Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, ContentDocument.title, LinkedEntityId from ContentDocumentLink where LinkedEntityId IN :headerIds];
        for(ContentDocumentLink contentDoc : [Select Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, ContentDocument.title, LinkedEntityId from ContentDocumentLink where LinkedEntityId IN :headerIds]) {
                    
            quoteData =  qocMap.get(contentDoc.LinkedEntityId);
            if(quoteData != null && contentDoc.ContentDocument != null && (!contentDoc.ContentDocument.title.toLowerCase().contains('invoice') || invoiceAccess)) {
                
                OCCommunitiesResource.QOCAttachment att = new OCCommunitiesResource.QOCAttachment();
                att.title = contentDoc.ContentDocument.title;
                att.url = url + '/sfc/servlet.shepherd/version/download/' + contentDoc.ContentDocument.LatestPublishedVersionId;
                att.image = url + '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + contentDoc.ContentDocument.LatestPublishedVersionId;
                quoteData.attachments.add(att);
            }
            
        }

        return qocMap;
    }

}