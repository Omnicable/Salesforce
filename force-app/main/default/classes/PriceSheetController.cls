/**
 * @description       : Apex controller for the PriceSheetComponent
 * @author            : chrisw@launchdm.com
 * @group             : PriceSheet
 * @last modified on  : 02-04-2023
 * @last modified by  : chrisw@launchdm.com
 **/
public class PriceSheetController {

    static final Map<String,Set<String>> OVERRIDE_MAP = new Map<String,Set<String>>{'Buying Group'=> new Set<String>{'Region'}, 'Company' => new Set<String>{'Buying Group', 'Region'}, 'Region' => new Set<String>(), 'Accounts' => new Set<String>{'Company', 'Buying Group', 'Region'} };
    static final Map<String,Set<String>> PROFILE_PERMISSION_MAP = new Map<String,Set<String>>{'Region Mgr Platform'=> new Set<String>{'Accounts', 'Region'}, 'Management Platform User' => new Set<String>{'Accounts', 'Region'} };


    public class PriceBookResult{
        @AuraEnabled public List<PricebookEntry> entries = new List<PricebookEntry>();
        @AuraEnabled public List<PB_Account_Link__c> accounts = new List<PB_Account_Link__c>();
        @AuraEnabled public List<Price_Book_Family_Discount__c> discounts = new List<Price_Book_Family_Discount__c>();
    }

    public class PriceBookRecord{
        public String Name { get; set; }
        public String Size { get; set; }
        public Decimal UnitPrice { get; set; }
        public String ProductPackage { get; set; }
    }

    public Price_Book_Approval__c pba { get; set; }
    public PriceBook2 pb { get; set; }
    public List<PriceBookEntry> entries { get; set; }
    public Map<String,Map<String,Set<PriceBookRecord>>> entryCatMap { get; set; }
    public String csv { get; set; }
    public String docName { get; set; }
    public String test { get; set; }
    public Set<String> hiddenCategories { get; set; }
    public String hiddenString { get; set; }
    public Boolean hideAluminumPage { get; set; } 
    public Boolean hidePortableCordPage { get; set; }
    public Boolean hideMCPage { get; set; }
    public Boolean hideCommunicationPage { get; set; }
    public Boolean hideGroundingPage { get; set; }

    public PriceSheetController() {



        String pbaId = ApexPages.currentPage().getParameters().get('id');
        pba = PriceSheetController.getPriceBookApprovalById(pbaId); 
        pb = [SELECT Id, Name, Date__c, Synced_Date__c, (SELECT Id, Name, UnitPrice, ProductCode, Discount_Percent__c, Product2.Package__c, Product2.Part_Number__c, Product2.Size__c, Product2.Family, Product2.QuantityUnitOfMeasure, Product2.Category__c, Base_Price__c, Discount_Price__c, Price_Override__c FROM PricebookEntries WHERE Product2.Attachment_Visible__c = true ORDER BY Product2.Category__c, Product2.Family, Product2.Index__c) FROM Pricebook2 WHERE Id = :pba.Price_Book__c];
        entries = pb.PricebookEntries;
        docName = pb.Date__c + ' Price Sheet';


        hiddenCategories = new Set<String>();
        hiddenString = '';
        if(pba.Hidden_Pages__c != null && pba.Hidden_Pages__c != ''){

            String[] hiddenPages = pba.Hidden_Pages__c.split(';');
            System.debug('Hidden_Pages__c' + hiddenPages);
            for (String hiddenCategory : hiddenPages) {
                hiddenString += hiddenCategory;
                hiddenCategories.add(hiddenCategory);
            }
        }

        String pageName = ApexPages.currentPage().getUrl().replaceAll('\\?.*', '').replaceAll('/apex/', '');
        if(pageName == 'PriceBookAttachmentPDF' || pageName == 'PriceBookAttachmentPDFTEST'){

            entryCatMap = new Map<String,Map<String,Set<PriceBookRecord>>>();
            List<String> relevantCategories = PriceSheetController.getAvailableOptions(entries, 'Category__c');
            List<String> relevantFamily = PriceSheetController.getAvailableOptions(entries, 'Family');
            for (PriceBookEntry entry : entries) {
                test = entry.Name;
                PriceBookRecord pbrecord = new PriceBookRecord();
                pbrecord.Name=entry.name;
                pbrecord.UnitPrice=entry.UnitPrice; 
                pbrecord.Size=entry.Product2.Size__c;
                pbRecord.ProductPackage = entry.Product2?.Package__c;

                if(entryCatMap.get(entry.Product2?.Category__c) == null){

                    Map<String,Set<PriceBookRecord>> familyMap = new Map<String,Set<PriceBookRecord>>();
                    Set<PriceBookRecord> newSet = new Set<PriceBookRecord>();
                    newSet.add(pbrecord);
                    familyMap.put(entry.Product2.Family, newSet);
                    entryCatMap.put(entry.Product2?.Category__c, familyMap );
                }else{
                    Map<String,Set<PriceBookRecord>> familyMap = entryCatMap.get(entry.Product2?.Category__c);
                    if(familyMap.get(entry.Product2?.Family) == null){
                        Set<PriceBookRecord> newSet = new Set<PriceBookRecord>();
                        newSet.add(pbrecord);
                        familyMap.put(entry.Product2?.Family, newSet);
                    }else{

                        familyMap.get(entry.Product2?.Family).add(pbrecord);
                
                    }
                    
                    entryCatMap.put(entry.Product2?.Category__c, familyMap );

                }
                    
            }
        
        }else{

            csv = 'Part #' + ',' + 'Category' + ',' + 'Family' + ',' +  'Price' + '\n';
            for (PriceBookEntry entry : entries) {
                if(entry.Product2.Category__c != null && !hiddenCategories.contains(entry.Product2.Category__c)){
                    csv += entry.Product2.Part_Number__c + ' , ' + entry.Product2.Category__c.replaceAll(',', ' | ') + ' , ' + entry.Product2.Family + ' , ' + entry.UnitPrice + '\n';
                }
            }
        }
    }

    public static List<String> getAvailableOptions(List<PriceBookEntry> entries, String field){
        List<String> availableCategories = new List<String>();
        List<String> productIds = new List<String>();
        for(PriceBookEntry entry : entries){
            productIds.add(entry.Product2Id);
        }

        String query = 'SELECT count(id), ' + field + ' FROM Product2 WHERE Id IN: productIds GROUP BY ' + field;
        for (AggregateResult ar : Database.query(query))  {
            availableCategories.add((String)ar.get(field));
        }

        return availableCategories;
    }

    
    /**
    * @status Complete
    * @description get base price book or current price book if custom
    * @use PriceBookWizardComponentHelper.js
    * @author chrisw@launchdm.com | 07-27-2022 
    * @param String pbaId 
    * @return List<Pricebook2> 
    **/
    @AuraEnabled
    public static List<Pricebook2> getBasePriceBooks(String pbaId){
        Price_Book_Approval__c pba = [SELECT Id, Price_Book__c FROM Price_Book_Approval__c WHERE Id =: pbaId];
        List<Pricebook2> basePriceBooks = new List<PriceBook2>();

        List<Pricebook2> pbs = [SELECT Id, Name, Date__c, Synced_Date__c, Type__c, (SELECT Id, Name, UnitPrice, Margin__c, Unit_Cost__c, Price_Override__c, Discount_Percent__c, Product2.Category__c, Product2.Family, Product2.QuantityUnitOfMeasure FROM PricebookEntries WHERE Product2.Attachment_Visible__c = true ORDER BY Name ASC) FROM Pricebook2 WHERE (Type__c = 'Standard' OR Type__c = 'Base' OR Id =: pba.Price_Book__c) AND IsActive = true];
        for (PriceBook2 pb : pbs) {
            if(pb.PricebookEntries != null && pb.PricebookEntries.size() > 0){
                basePriceBooks.add(pb);
            }
        }
        
        return basePriceBooks;    
    }

    /**
    * @status Complete
    * @description Check if its a weekday to send attachment emails
    * @use PriceBookEmailBatchController.cls
    * @author chrisw@launchdm.com | 09-06-2022 
    * @return Boolean 
    **/
    public static Boolean shouldSendEmailToday(){
        Datetime dt = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        String dayOfWeek = dt.format('EEEE');
        return dayOfWeek != 'Saturday' && dayOfWeek != 'Sunday';
    }

    /**
    * @status Complete
    * @description search accounts 
    * @use AutoCompleteHelper.js
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param String searchString 
    * @return List<Account> 
    **/
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts(String searchString){
        searchString  = '%' + searchString + '%';
        List<Account> accounts = [SELECT Id, Name, Account_Number__c from Account WHERE (Name Like : searchString OR Account_Number__c Like: searchString) AND Active__c = 'A' LIMIT 10];
        return accounts;
    }

    /**
     * @status Complete
    * @description generic search for company, buying group, or region depending on data
    * @use AutoCompleteHelper.js 
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param String searchString 
    * @param String objectApiName 
    * @param String idFieldApiName 
    * @param String valueFieldApiName 
    * @param String extendedWhereClause 
    * @param Integer maxRecords 
    * @return List<SObject> 
    **/
    @AuraEnabled(cacheable=true)
    public static List<SObject> getRecords(String searchString, String objectApiName, String idFieldApiName, String valueFieldApiName, String extendedWhereClause, Integer maxRecords){
        searchString = String.escapeSingleQuotes(searchString);
        objectApiName = String.escapeSingleQuotes(objectApiName);
        idFieldApiName = String.escapeSingleQuotes(idFieldApiName);
        valueFieldApiName = String.escapeSingleQuotes(valueFieldApiName);
        
        if(extendedWhereClause == null){
            extendedWhereClause = '';
        }
        
        String query = 'SELECT count(' + idFieldApiName + ') ' + idFieldApiName + ', ' + valueFieldApiName + ' FROM '+objectApiName+' WHERE '+valueFieldApiName+' LIKE \'%'+searchString+'%\' '+extendedWhereClause + 'GROUP BY ' + valueFieldApiName + ' LIMIT '+maxRecords;
        return Database.query(query);
    }

    /**
    * @status Complete
    * @description get price book approval request details by approval id
    * @use PriceSheetApprovalEntriesHelper.js
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param String approvalId 
    * @return PriceBookResult 
    * @status Needs Tested 
    **/
    @AuraEnabled
    public static PriceBookResult getApprovalEntries(String approvalId){
        ProcessInstanceWorkitem currApproval = [SELECT Id, ProcessInstance.Id, ProcessInstance.Status, ProcessInstance.TargetObjectId FROM ProcessInstanceWorkitem WHERE Id = :approvalId];
        Price_Book_Approval__c pba = [SELECT Id, Price_Book__c, Expiration__c from Price_Book_Approval__c WHERE Id =: currApproval.ProcessInstance.TargetObjectId];
        PriceBookResult results = new PriceBookResult();
        results.entries = [SELECT Id, Name, UnitPrice, ProductCode, Discount_Percent__c, Product2.Family, Margin__c, Unit_Cost__c, Discount_Price__c, Base_Price__c, Price_Override__c, Product2.Category__c, Product2.QuantityUnitOfMeasure FROM PricebookEntry WHERE Pricebook2Id =: pba.Price_Book__c AND isActive = true ORDER BY Name];
        results.accounts = [SELECT Id, Name, Account__c, Status__c, Account__r.Name, Account__r.Account_Number__c, Account__r.Owner.Name FROM PB_Account_Link__c WHERE Price_Book_Approval__c = : pba.Id];
        results.discounts = [SELECT Id, Name, Percent_Discount__c, Product_Family__c, Type__c FROM Price_Book_Family_Discount__c WHERE Price_Book__c = :pba.Price_Book__c];
        return results;
    }

    /**
    * @status Complete
    * @description get pricebook approval by id
    * @use AutoCompleteHelper.js, PriceBookWizardComponentController.js, PriceSheetController
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param String recordId 
    * @return Price_Book_Approval__c 
    * @status Complete 
    **/
    @AuraEnabled
    public static Price_Book_Approval__c getPriceBookApprovalById(String recordId){
        Price_Book_Approval__c pb = [SELECT Id, Name, Hidden_Pages__c, Price_Book__c, Status__c, Price_Book__r.Id, Price_Book__r.Name, Price_Book__r.Type__c, Type__c, Expiration__c, Company_Name__c, Buying_Group__c, Region_Number__c, Freight_Terms_Line_1__c, Freight_Terms_Line_2__c, Freight_Terms_Line_3__c, Freight_Terms_Line_4__c, (SELECT Id, Name, Account__c, Active__c , Email_Day__c, Status__c, Last_Email_Sent__c, Account__r.Name, Account__r.Account_Number__c, Account__r.Owner.Name FROM Price_Book_Links__r) from Price_Book_Approval__c WHERE Id =: recordId];
        return pb;
    }


    /**
    * @status Complete
    * @description save price book approval with selected priceBook
    * @use PriceBookWizardComponentHelper.js
    * @author chrisw@launchdm.com | 09-07-2022 
    * @param String pbaId 
    * @param String pbId 
    * @return String 
    **/
    @AuraEnabled
    public static String setPriceBook(String pbaId, String pbId){
        Price_Book_Approval__c pba = [SELECT Id, Price_Book__c FROM Price_Book_Approval__c WHERE Id =: pbaId];
        pba.Price_Book__c = pbId;
        System.debug('pba: ' + pba);
        Database.SaveResult res = Database.update(pba);
        return JSON.serialize(res);
    }


    /**
    * @status Complete
    * @description remove account from price book approval
    * @use AutoCompleteHelper.js
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param String recordId 
    * @return PB_Account_Link__c 
    * @status Complete 
    **/
    @AuraEnabled
    public static PB_Account_Link__c deletePBAccountLink(String recordId){
        PB_Account_Link__c link = [SELECT Id, Name, Price_Book_Approval__c FROM PB_Account_Link__c  WHERE Id = :recordId];
        delete link;

        /** Update price book approval to trigger auto status change */
        Price_Book_Approval__c pba = [SELECT Id, Name FROM Price_Book_Approval__c WHERe Id = : link.Price_Book_Approval__c];
        update pba;
        
        return link;
    }

    /**
    * @status Complete
    * @description add accounts to price book approval by selected a list of accounts
    * @note called from AutoComplete.cmp
    * @author chrisw@launchdm.com | 08-03-2022 
    * @param Price_Book_Approval__c pba 
    * @param List<String> accountIds 
    * @return Map<String, Object> 
    **/
    @AuraEnabled
    public static Map<String,Object> addAccounts(Price_Book_Approval__c pba, List<String> accountIds){

        Map<String,Object> results = new Map<String,Object>();

        /** Delete existing account links **/
        delete [SELECT Id, Account__c FROM PB_Account_Link__c WHERE Price_Book_Approval__c = :pba.Id];

        Set<String> existingAccountIds = new Set<String>();
        List<PB_Account_Link__c> existingLinks = new List<PB_Account_Link__c>();
        List<PB_Account_Link__c> overriddenLinks = new List<PB_Account_Link__c>();

        Set<String> overrides = OVERRIDE_MAP.get(pba.Type__c);

        /** Get existing account links on other price book approvals **/
        Map<String,PB_Account_Link__c> exisingMap = new Map<String,PB_Account_Link__c>();
        for(PB_Account_Link__c link : [SELECT Id, Name, Price_Book_Approval__c, Email_Day__c, Status__c, Last_Email_Sent__c, Price_Book_Approval__r.Name, Price_Book_Approval__r.Owner.Name, Price_Book_Approval__r.Type__c, Price_Book_Approval__r.Status__c, Account__c, Account__r.Name FROM PB_Account_Link__c WHERE Account__c IN :accountIds AND Price_Book_Approval__c != :pba.Id AND (Price_Book_Approval__r.Status__c = 'Pending' OR Price_Book_Approval__r.Status__c = 'Approved') ]){
            exisingMap.put(link.Account__c, link);
        }

        /** Create links between Accounts and Price Book Approvals **/
        List<PB_Account_Link__c> links = new List<PB_Account_Link__c>();
        for (Account act : [SELECT Id, Name, Price_Book_Approval__c FROM Account WHERE Id IN: accountIds AND Active__c = 'A' /*AND Id NOT IN :exisingMap.keySet()*/]) {
            PB_Account_Link__c link = new PB_Account_Link__c(Name = act.Name, Account__c = act.Id, Price_Book_Approval__c = pba.Id);
            PB_Account_Link__c existingLink = exisingMap.get(link.Account__c);

            if(existingLink == null){
                links.add(link);
            }else if(overrides.contains(existingLink.Price_Book_Approval__r.Type__c)){
                existingLink.Overridden_By__c = link.Price_Book_Approval__r.Name;
                overriddenLinks.add(existingLink);
                links.add(link);
            }else{
                link.Overridden_By__c = existingLink.Price_Book_Approval__r.Name;
                existingLinks.add(existingLink);
                links.add(link);
            }

        }

        results.put('newAccounts', links);
        results.put('existingLinks', existingLinks);

        if(existingLinks.size() > 0 || overriddenLinks.size() > 0){
            PriceSheetController.sendDupliceAccounts(pba, existingLinks, overriddenLinks);
        }
        
        insert links;
        update overriddenLinks;

        /** Update price book approval to trigger auto status change */
        update pba;
        
        return results;
    }

    /**
    * @status Complete
    * @description send email when duplicate account links are found
    * @use PriceSheetController
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param Price_Book_Approval__c pba 
    * @param List<PB_Account_Link__c> existingLinks 
    **/
    public static void sendDupliceAccounts(Price_Book_Approval__c pba, List<PB_Account_Link__c> existingLinks, List<PB_Account_Link__c> overriddenLinks){
        List<Messaging.SingleEmailMessage> mails =  new List<Messaging.SingleEmailMessage>();     
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(UserInfo.getUserId());
        mail.setSaveAsActivity(false);
        mail.setSubject('Duplicate Accounts for request: ' + pba.Name);
    
        String body = '';
        if(existingLinks.size() > 0){
            Integer index = 1;
            body = 'The following accounts are already part Price Book Approval Request... <br/>';
            for (PB_Account_Link__c link : existingLinks) {
                body += '<div> ' + index + '. ' + link.Name  + ' is already part of the ' + link.Price_Book_Approval__r.Name + ' created by ' + link.Price_Book_Approval__r.Owner.Name + ' </div>';
                index++;
            }
        }
        
        if(overriddenLinks.size() > 0){
            Integer oIndex = 1;
            body += '<br/> The following accounts where overridden by this request... <br/>';
            for (PB_Account_Link__c link : overriddenLinks) {
                body += '<div> ' + oIndex + '. ' + link.Name  + ' is already part of the ' + link.Price_Book_Approval__r.Name + ' created by ' + link.Price_Book_Approval__r.Owner.Name + ' </div>';
                oIndex++;
            }
        }
    
        mail.setHtmlBody(body);
        mails.add(mail);
        Messaging.sendEmail(mails);
    }

    /**
    * @status Complete 
    * @description add accounts by company, buying group, or region
    * @use AutoCompleteHelper.js
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param Price_Book_Approval__c pba 
    * @param String field 
    * @param String value 
    * @return Map<String,Object> 
    **/
    @AuraEnabled
    public static Map<String,Object> setAccountsByType(Price_Book_Approval__c pba, String field, String value){
        String query = 'SELECT Id FROM Account WHERE ' + field + ' =: value';
        Map<ID, Account> acctMap = new Map<ID, Account>((List<Account>)Database.query(query));
        List<String> accountIds = (List<String>)JSON.deserialize(JSON.serialize(acctMap.keySet()), List<String>.class);
        return PriceSheetController.addAccounts(pba, accountIds);
    }


    /**
    * @status Complete
    * @description create or save custom price book and associate with price book approval
    * @use PriceBookWizardComponentHelper.js
    * @note switched params to strings to prevent certain users from getting internal error
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param Boolean shouldSave 
    * @param Pricebook2 pb 
    * @param List<PriceBookEntry> entries 
    * @param List<Price_Book_Family_Discount__c> discounts 
    * @param Price_Book_Approval__c pba 
    * @return PriceBook2 
    **/
    @AuraEnabled
    public static PriceBook2 saveCustomPriceBook(String shouldSaveStr, String pbStr, String entriesStr, String discountsStr, String pbaStr){
       Boolean shouldSave = (Boolean)JSON.deserialize(shouldSaveStr, Boolean.class);
       Pricebook2 pb = (Pricebook2)JSON.deserialize(pbStr, Pricebook2.class);
       List<PriceBookEntry> entries = (List<PriceBookEntry>)JSON.deserialize(entriesStr,  List<PriceBookEntry>.class);
       List<Price_Book_Family_Discount__c> discounts = (List<Price_Book_Family_Discount__c>)JSON.deserialize(discountsStr,  List<Price_Book_Family_Discount__c>.class);
       Price_Book_Approval__c pba = (Price_Book_Approval__c)JSON.deserialize(pbaStr, Price_Book_Approval__c.class);
       
        pb.IsActive = true;
        if(pb.Type__c != 'Custom'){
            pb.Date__c = Date.today();
            pb.Base_Price_Book__c = pb.Id;
            pb.Id = null;
            pb.Type__c = 'Custom';
        }

        upsert pb;

        for (PriceBookEntry entry : entries) {

            entry.IsActive = true;
            entry.UnitPrice = entry.UnitPrice != null ? entry.UnitPrice : 0; 

            if(!shouldSave){
                entry.Id = null;
                entry.Pricebook2Id = pb.Id;
                
            }
            
        }

        delete [SELECT Id FROM Price_Book_Family_Discount__c WHERE Price_Book__c =: pb.Id ];
        for (Price_Book_Family_Discount__c discount : discounts) {
            discount.Id = null;
            discount.Price_Book__c = pb.Id;
        }
    
        pba.Price_Book__c = pb.Id;

        upsert entries;
        insert discounts;
        update pba;
        return pb;
    }

    /**
    * @description get price book wizard modal default values
    * @use PriceBookWizardComponentHelper.js
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param Price_Book_Approval__c pba 
    * @return Map<String, Object> 
    **/
    @AuraEnabled
    public static Map<String,Object> getCustomPriceBookData(String priceBookId){
        //TODO: Review this method

        List<Price_Book_Family_Discount__c> discounts = [SELECT Id, Name, Percent_Discount__c, Product_Family__c, Type__c FROM Price_Book_Family_Discount__c WHERE Price_Book__c = :priceBookId];
        List<Pricebook2> pbs = [SELECT Id, Name, Type__c, (SELECT Id, Name, UnitPrice, ProductCode, Discount_Percent__c, Discount_Price__c, Base_Price__c, Price_Override__c, Product2.QuantityUnitOfMeasure, Product2.Family, Product2.Category__c, Unit_Cost__c FROM PricebookEntries WHERE Product2.Attachment_Visible__c = true ORDER BY Name ASC) FROM Pricebook2 WHERE Id = :priceBookId];

        Pricebook2 pb = pbs[0];
        
        for (PricebookEntry entry : pb.PricebookEntries) {
            entry.UnitPrice = entry.Product2.QuantityUnitOfMeasure == 'EA' ? entry.UnitPrice.round(System.RoundingMode.HALF_UP) : entry.UnitPrice;
        }

        Map<String,Object> res = new Map<String,Object>();
        res.put('discounts', discounts);
        res.put('priceBook', pb);

        List<Map<String,String>> familyOptions = new List<Map<String,String>>();
        List<Map<String,String>> categories = new List<Map<String,String>>();
        Schema.DescribeFieldResult objFieldDescribe = Product2.Family.getDescribe();
        List<Schema.PicklistEntry> lstPickListValues = objFieldDescribe.getPickListValues();
        for (Schema.PicklistEntry objPickList : lstPickListValues) {
            familyOptions.add(new Map<String,String>{'value' => objPickList.getValue(), 'label' => objPickList.getValue()});
        }

        //Get Categories
        Schema.DescribeFieldResult catFieldDescribe = Product2.Category__c.getDescribe();
        List<Schema.PicklistEntry> catPickListValues = catFieldDescribe.getPickListValues();
        for (Schema.PicklistEntry objPickList : catPickListValues) {
            categories.add(new Map<String,String>{'value' => objPickList.getValue(), 'label' => objPickList.getValue()});
        }

        res.put('familyOptions', familyOptions);
        res.put('categories', categories);
        return res;
    }

    /**
    * @status Complete 
    * @description auto set status to Not Ready or Ready to Submit depending on progress
    * @use PriceBookApprovalTrigger.trigger
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param Map<ID Price_Book_Approval__c> newMap 
    **/
    public static void setReadyStatus(Map<ID,Price_Book_Approval__c> newMap){
        //TODO: Review this method
        Map<ID, Price_Book_Approval__c> acctMap = new Map<ID, Price_Book_Approval__c>([SELECT Id, Price_Book__c, Status__c, (SELECT Id FROM Price_Book_Links__r LIMIT 1) FROM Price_Book_Approval__c WHERE Id IN : newMap.keySet() ]);
        for (Id key : newMap.keySet()) {
            Price_Book_Approval__c pba = acctMap.get(key);
            Price_Book_Approval__c newPBA = newMap.get(key);


            if(newPBA.Status__c == 'Ready to Submit' || newPBA.Status__c == 'Not Ready'){
                if (newPBA.Price_Book__c != null && pba.Price_Book_Links__r != null && pba.Price_Book_Links__r.size() != 0){
                    newMap.get(key).Status__c = 'Ready to Submit';
                }else if(newPBA.Price_Book__c == null || (pba.Price_Book_Links__r == null || pba.Price_Book_Links__r.size() == 0 )){
                    newMap.get(key).Status__c = 'Not Ready';
                }
            }

        }
    }

    /**
    * @status Complete 
    * @description recall pending or approved price book approval
    * @use PBRecallApprovalComponentHelper.js
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param String recordId 
    * @status String Complete
    **/
    @AuraEnabled
    public static void recallApproval(String recordId) {   

        Price_Book_Approval__c pba = [SELECT Id, Name FROM Price_Book_Approval__c WHERE Id =: recordId];
        Approval.UnLockResult unlockRes = Approval.Unlock(pba, false);
        System.debug('unlockRes: ' + unlockRes);
        pba.Status__c = 'Ready to Submit';

        if(Approval.isLocked(recordId)){
            Approval.unlock(recordId);
        }
        
        List<ProcessInstanceWorkitem> piwi = [SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId =: recordId];
        if(piwi.size() > 0){
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setAction('Removed');       
            req.setWorkitemId(piwi.get(0).Id);
            Approval.process(req,false);
        }
        
        update pba;
    }

    /**
    * @status Complete 
    * @description submit price book approval request
    * @use PBSubmitApprovalComponentHelper.js
    * @author chrisw@launchdm.com | 08-04-2022 
    * @param String recordId 
    * @status Complete
    **/
    @AuraEnabled
    public static Map<String,String> submitPriceBookApproval(String recordId) {   
        Map<String,String> results = new Map<String,String>();
        Profile userProfile = [SELECT Id, Name FROM Profile WHERE Id =: UserInfo.getProfileId()];
        Boolean hasPermission = userProfile.Name == 'Region Mgr Platform' || userProfile.Name == 'Management Platform User' ? true : false;
        List<PermissionSetAssignment> pset = [SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId= :UserInfo.getUserId() AND PermissionSet.Name = 'Price_Book_Admin'];
        Price_Book_Approval__c pba = [SELECT Id, Name, Expiration__c, Expiration_Date__c, Type__c, Price_Book__r.Type__c, (SELECT Id FROM Price_Book_Links__r LIMIT 1)  FROM Price_Book_Approval__c WHERE Id =: recordId];


        if(pba.Price_Book__c != null && pba.Price_Book_Links__r != null && pba.Price_Book_Links__r.size() > 0){
            results.put('type', 'success');
            if(pba.Price_Book__r.Type__c == 'Custom' && (pset.size() == 0 && !hasPermission)){
                pba.Status__c = 'Pending';
                results.put('title', 'Price Book is Pending');
                results.put('message', 'The request has been submitted.  The status is now pending until its approved or rejected.  If you need to make any changes to the request, please recall the approval, make the changes and resubmit');
    
            }else{
                pba.Status__c = 'Approved';
                results.put('title', 'Price Book is Ready');
                results.put('message', 'No approval required');
                switch on pba.Expiration__c {
                    when '30 Days' {
                        pba.Expiration_Date__c = Date.today() + 31;
                    }
                    when '60 Days' {
                        pba.Expiration_Date__c = Date.today() + 61;
                    }
                    when '90 Days' {
                        pba.Expiration_Date__c = Date.today() + 91;
                    }
                    when else {	
                        pba.Expiration_Date__c = Date.today() + 352;
                    }
                }
            }

        }else{

            pba.Status__c = 'Not Ready';
            results.put('type', 'error');
            results.put('title', 'Approval Not Ready For Submission');
            results.put('message', 'This approval still needs Accounts and/or a Price Book');
        }
        
        update pba;
        return results;
    }

    /**
    * @status Complete 
    * @description update account email day
    * @use AutoCompleteHelper.js
    * @author chrisw@launchdm.com | 09-02-2022 
    * @param List<Account> accounts 
    * @return string 
    **/
    @AuraEnabled
    public static string updateEmailDay(List<Account> accounts){
        update accounts;
        return 'Email days successfually updated';
    }

    public static void addToStandardPriceBook(List<Product2> products){
        System.debug('add to pricebook products: ' + products);
        PriceBook2 standardPB = [SELECT Id FROM PriceBook2 WHERE IsStandard = true];

        List<Id> product2Ids = new List<Id>();
        for (Product2 product : products) {
            product2Ids.add(product.Id);
        }

        Map<String,PriceBookEntry> existingEntryMap = new Map<String,PricebookEntry>();
        for (PriceBookEntry entry : [SELECT Id, ProductCode, Base_Price__c, UnitPrice FROM PricebookEntry WHERE Pricebook2.IsStandard = true AND Product2Id IN :product2Ids]) {
            existingEntryMap.put(entry.ProductCode, entry);
        }

        List<PriceBookEntry> newEntries = new List<PriceBookEntry>();
        for (Product2 product : products) {
            if(existingEntryMap.get(product.ProductCode) != null){
                PricebookEntry entry = existingEntryMap.get(product.ProductCode);
                if(entry.Base_Price__c != product.Unit_Price__c || entry.UnitPrice != product.Unit_Price__c){
                    entry.Base_Price__c = product.Unit_Price__c;
                    entry.UnitPrice = product.Unit_Price__c;
                    newEntries.add(entry);
                }
                
            }else{
                PriceBookEntry entry = new PriceBookEntry(IsActive=true, Base_Price__c=product.Unit_Price__c, UnitPrice=product.Unit_Price__c ?? 0, 
                Pricebook2Id=standardPB.Id, Product2Id=product.Id, UseStandardPrice=false, Item_Number_Ref__c=product.Id);
                newEntries.add(entry);
            }
        }

        
        List<Database.upsertResult> res = Database.upsert(newEntries, false);
        System.debug('RES: ' + res);
    }

    /**
    * @status Complete
    * @description check account availability when price book is approved
    * @use PriceBookApprovalTrigger.Trigger
    * @author chrisw@launchdm.com | 09-02-2022 
    * @param Map<Id Price_Book_Approval__c> newMap 
    * @param Map<Id Price_Book_Approval__c> oldMap 
    **/
    public static void checkLinkStatus(Map<Id, Price_Book_Approval__c> newMap, Map<Id,Price_Book_Approval__c> oldMap){

        List<String> pbaIds = new List<String>();

        for (Id key : newMap.keySet()) {
            if(oldMap.get(key).Status__c != 'Approved' && newMap.get(key).Status__c == 'Approved') {
                pbaIds.add(key);
            }
        }

        /** All the ones that I want to add */
        List<String> accountIds = new List<String>();
        List<PB_Account_Link__c> links = new List<PB_Account_Link__c>();
        for(PB_Account_Link__c link : [SELECT Id, Name, Account__c, Active__c , Email_Day__c, Status__c, Last_Email_Sent__c, Price_Book_Approval__c, Price_Book_Approval__r.Name, Price_Book_Approval__r.Status__c, Price_Book_Approval__r.Type__c, Account__r.Name, Account__r.Account_Number__c, Account__r.Owner.Name FROM PB_Account_Link__c WHERE Price_Book_Approval__c IN : pbaIds]){
            links.add(link);
            accountIds.add(link.Account__c);
        }

        /** existing ones */
        Map<String,PB_Account_Link__c> exisingMap = new Map<String,PB_Account_Link__c>();
        for(PB_Account_Link__c link : [SELECT Id, Name, Price_Book_Approval__c, Email_Day__c, Status__c, Last_Email_Sent__c, Price_Book_Approval__r.Name, Price_Book_Approval__r.Owner.Name, Price_Book_Approval__r.Type__c, Price_Book_Approval__r.Status__c, Account__c, Account__r.Name FROM PB_Account_Link__c WHERE Account__c IN :accountIds AND Price_Book_Approval__c NOT IN :pbaIds AND (Price_Book_Approval__r.Status__c = 'Approved' AND Active__c = true) ]){
            exisingMap.put(link.Account__c, link);
        }

        List<PB_Account_Link__c> allupdates = new List<PB_Account_Link__c>();

        for (PB_Account_Link__c link : links) {
            String typeStr = link.Price_Book_Approval__r.Type__c;
            Set<String> overrides = OVERRIDE_MAP.get(typeStr);
            
            if(exisingMap.get(link.Account__c) != null){
                PB_Account_Link__c existingLink = exisingMap.get(link.Account__c);

                if(overrides.contains(existingLink.Price_Book_Approval__r.Type__c)){
                    link.Active__c = true;
                    existingLink.Active__c = false;
                    existingLink.Overridden_By__c = link.Price_Book_Approval__r.Name;
                    allupdates.add(link);
                    allupdates.add(existingLink);
                }else{
                    link.Active__c = false;
                    link.Overridden_By__c = existingLink.Price_Book_Approval__r.Name;
                    allupdates.add(link);
                    allupdates.add(existingLink);
                }

            }else{
                link.Active__c = true;
                allupdates.add(link);
            }

        }

        update allupdates;
    }

    /**
    * @status Complete
    * @description removes all accounts from approval if type is changed
    * @use PriceBookApprovalTrigger.Trigger
    * @author chrisw@launchdm.com | 09-06-2022 
    * @param Map<Id Price_Book_Approval__c> newMap 
    * @param Map<Id Price_Book_Approval__c> oldMap 
    **/
    public static void handleTypeChange(Map<Id,Price_Book_Approval__c> newMap, Map<Id,Price_Book_Approval__c> oldMap){
        for(Id key : newMap.keySet()){ 
            Price_Book_Approval__c newPBA = newMap.get(key);
            Price_Book_Approval__c oldPBA = oldMap.get(key);
            if(newPBA.Type__c != oldPBA.Type__c){
                delete [SELECT Id FROM PB_Account_Link__c WHERE Price_Book_Approval__c IN: newMap.keySet()];
            }
            
        }
    }

    public static void checkPermission(List<Price_Book_Approval__c> approvals, Map<Id,Price_Book_Approval__c> oldMap){
        Profile p = [SELECT Id, Name FROM Profile WHERE Id =: UserInfo.getProfileId()];
        List<PermissionSetAssignment> pset = [SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId= :UserInfo.getUserId() AND PermissionSet.Name = 'Price_Book_Admin'];

        Boolean admin = pset.size() > 0 || p.Name ==  'System Administrator' || p.Name == 'Omni System Admin';

        if(!admin){

            for(Price_Book_Approval__c approval : approvals){
                
                if(approval.Id == null|| oldMap.get(approval.Id) == null || oldMap.get(approval.Id).Type__c != approval.Type__c){
                    if((PROFILE_PERMISSION_MAP.get(p.Name) == null && approval.Type__c != 'Accounts') || (PROFILE_PERMISSION_MAP.get(p.Name) != null && !PROFILE_PERMISSION_MAP.get(p.Name).contains(approval.Type__c))){
                        approval.addError('You don\'t have permission to create Price Book Approvals with a type of ' + approval.Type__c);
                    }
                }

            }
        }
    }
}