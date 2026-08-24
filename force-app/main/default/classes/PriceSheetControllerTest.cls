/**
 * @description       :
 * @author            : chrisw@launchdm.com
 * @group             : PriceSheet
 * @last modified on  : 09-28-2022
 * @last modified by  : chrisw@launchdm.com
 **/

@isTest
public class PriceSheetControllerTest {
    /**
     * @description
     * @author chrisw@launchdm.com | 09-03-2022
     * @param User user
     **/
    @testSetup
    public static void setup() {
        Account a = PriceSheetControllerTest.createAccount(1);
        List<Contact> contacts = PriceSheetControllerTest.createContacts(5, a);
        Pricebook2 standard = PriceSheetControllerTest.createStandardPB();
        List<Product2> prods = PriceSheetControllerTest.createProducts(5);
        List<PriceBook2> pbs = PriceSheetControllerTest.createPriceBooks(5);
        List<Pricebook2> customPbs = PriceSheetControllerTest.setCustomPriceBooks(pbs);
        List<PriceBookEntry> entries = PriceSheetControllerTest.createPriceBookEntries(5, prods, pbs);
        List<Price_Book_Approval__c> pbas = PriceSheetControllerTest.createPBAs(5, pbs);
        List<PB_Account_Link__c> links = PriceSheetControllerTest.createAccountLinks(5, a.Id, pbas);
        List<Price_Book_Family_Discount__c> discounts = PriceSheetControllerTest.createDiscounts(3, pbs);
    }

    /**
     * @description create standard price book for testing
     * @author chrisw@launchdm.com | 09-06-2022
     * @return Pricebook2
     **/
    public static Pricebook2 createStandardPB() {
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        update standardPricebook;
        return standardPricebook;
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
     * @description create test contacts
     * @author chrisw@launchdm.com | 09-03-2022
     * @param Integer size
     * @param String acountId
     * @return List<Contact>
     **/
    public static List<Contact> createContacts(Integer size, Account a) {
        List<Contact> contacts = new List<Contact>();

        for (Integer i = 0; i < size; i++) {
            String newId = a.Account_Number__c + ':' + i;
            Contact contact = new Contact(
                LastName = 'My Contact',
                Contact_Title__c = 'Accounting',
                Email = 'test@omnicable.com',
                AccountId = a.Id,
                Sequence__c = i,
                FirstName = 'Test',
                Ext_Id__c = newId,
                DSP_Purchaser__c = true
            );
            contacts.add(contact);
        }

        insert contacts;
        return contacts;
    }

    /**
     * @description create price book approvals for testing
     * @author chrisw@launchdm.com | 09-06-2022
     * @param Integer count
     * @param List<Pricebook2> pbs
     * @return List<Price_Book_Approval__c>
     **/
    public static List<Price_Book_Approval__c> createPBAs(Integer count, List<Pricebook2> pbs) {
        User user = [SELECT Id FROM User LIMIT 1];
        List<String> statuses = new List<String>{ 'Approved', 'Ready to Submit', 'Not Ready', 'Pending' };
        List<Price_Book_Approval__c> records = new List<Price_Book_Approval__c>();
        for (Integer i = 0; i < count; i++) {
            Price_Book_Approval__c record = new Price_Book_Approval__c(
                Name = 'PBA' + String.valueOf(i),
                Status__c = statuses.get(Math.min(i, statuses.size() - 1)),
                Type__c = 'Accounts',
                Expiration__c = '30 Days',
                From_User__c = user.Id,
                Price_Book__c = pbs[i].Id
            );
            records.add(record);
        }

        Price_Book_Approval__c expiredRecord = new Price_Book_Approval__c(
            Expiration_Date__c = Date.today().addDays(-5),
            Name = 'PBA-Expired',
            Status__c = 'Approved',
            Type__c = 'Accounts',
            Expiration__c = '30 Days',
            From_User__c = user.Id,
            Price_Book__c = pbs[0].Id
        );
        records.add(expiredRecord);

        insert records;
        return records;
    }

    /**
     * @description create products for testing
     * @author chrisw@launchdm.com | 09-06-2022
     * @param Integer count
     * @return List<Product2>
     **/
    public static List<Product2> createProducts(Integer count) {
        List<Product2> records = new List<Product2>();
        List<PriceBookEntry> entries = new List<PriceBookEntry>();

        for (Integer i = 0; i < count; i++) {
            Product2 record = new Product2(
                Attachment_Visible__c = true,
                Name = 'Product' + String.valueOf(i),
                ProductCode = 'Product' + String.valueOf(i),
                Unit_Price__c = Decimal.valueOf(count),
                Family = 'Family',
                Category__c = 'Category' + String.valueOf(i)
            );
            records.add(record);
        }
        insert records;

        // for (Product2 prod : records) {
        //     PricebookEntry record = new PricebookEntry(Product2Id=prod.Id, Base_Price__c = prod.Unit_Price__c, UnitPrice = prod.Unit_Price__c, Pricebook2Id=Test.getStandardPricebookId());
        //     entries.add(record);
        // }
        // // insert entries;

        return records;
    }

    /**
     * @description create price book entries for testing
     * @author chrisw@launchdm.com | 09-06-2022
     * @param Integer count
     * @param List<Product2> prods
     * @param List<PriceBook2> pbs
     * @return List<PricebookEntry>
     **/
    public static List<PricebookEntry> createPriceBookEntries(Integer count, List<Product2> prods, List<PriceBook2> pbs) {
        List<PricebookEntry> records = new List<PricebookEntry>();
        for (Product2 prod : prods) {
            for (PriceBook2 pb : pbs) {
                PricebookEntry record = new PricebookEntry(
                    Product2Id = prod.Id,
                    Base_Price__c = prod.Unit_Price__c,
                    UnitPrice = prod.Unit_Price__c,
                    Pricebook2Id = pb.Id
                );
                records.add(record);
            }
        }
        insert records;
        return records;
    }

    /**
     * @description create base price books for testing
     * @author chrisw@launchdm.com | 09-06-2022
     * @param Integer count
     * @return List<PriceBook2>
     **/
    public static List<PriceBook2> createPriceBooks(Integer count) {
        List<Pricebook2> records = new List<Pricebook2>();
        for (Integer i = 0; i < count; i++) {
            String typeStr = math.mod(i, 2) == 0 ? 'Base' : 'Custom';
            Pricebook2 record = new Pricebook2(Name = 'PB' + String.valueOf(i), Type__c = typeStr, Date__c = Date.today(), IsActive = true);
            records.add(record);
        }
        insert records;
        return records;
    }

    /**
     * @description create custom price books for testing
     * @author chrisw@launchdm.com | 09-06-2022
     * @param List<Pricebook2> pbs
     * @return List<PriceBook2>
     **/
    public static List<PriceBook2> setCustomPriceBooks(List<Pricebook2> pbs) {
        for (PriceBook2 pb : pbs) {
            if (pb.Type__c == 'Custom') {
                pb.Base_Price_Book__c = pbs[0].Id;
            }
        }

        update pbs;

        PriceBook2 updateStandard = pbs[0];
        updateStandard.Name = 'Changed';
        update updateStandard;

        return pbs;
    }

    /**
     * @description create account links for testing
     * @author chrisw@launchdm.com | 09-06-2022
     * @param Integer count
     * @param String accountId
     * @param List<Price_Book_Approval__c> pbas
     * @return List<PB_Account_Link__c>
     **/
    public static List<PB_Account_Link__c> createAccountLinks(Integer count, String accountId, List<Price_Book_Approval__c> pbas) {
        List<PB_Account_Link__c> records = new List<PB_Account_Link__c>();
        PB_Account_Link__c record = new PB_Account_Link__c(
            Name = 'AccountLink' + String.valueOf(0),
            Price_Book_Approval__c = pbas[0].Id,
            Account__c = accountId,
            Active__c = true
        );
        records.add(record);
        insert records;
        return records;
    }

    /**
     * @description create discounts for testing
     * @author chrisw@launchdm.com | 09-06-2022
     * @param Integer count
     * @param List<Pricebook2> pbs
     * @return List<Price_Book_Family_Discount__c>
     **/
    public static List<Price_Book_Family_Discount__c> createDiscounts(Integer count, List<Pricebook2> pbs) {
        String[] types = new List<String>{ 'Category', 'Family', 'All' };
        List<Price_Book_Family_Discount__c> records = new List<Price_Book_Family_Discount__c>();
        for (Integer i = 0; i < count; i++) {
            for (PriceBook2 pb : pbs) {
                Price_Book_Family_Discount__c record = new Price_Book_Family_Discount__c(
                    Name = types.get(i),
                    Type__c = types.get(i),
                    Percent_Discount__c = Decimal.valueOf(count),
                    Price_Book__c = pb.Id,
                    Product_Family__c = types.get(i)
                );
                records.add(record);
            }
        }
        insert records;
        return records;
    }

    @isTest
    public static void getPriceBookApprovalByIdTest() {
        Price_Book_Approval__c pba = [SELECT Id, Price_Book__c FROM Price_Book_Approval__c LIMIT 1];
        Price_Book_Approval__c found = PriceSheetController.getPriceBookApprovalById(pba.Id);
        System.assert(found != null);
    }

    @isTest
    public static void getBasePriceBooksTest() {
        Price_Book_Approval__c pba = [SELECT Id, Price_Book__c FROM Price_Book_Approval__c LIMIT 1];
        List<Pricebook2> found = PriceSheetController.getBasePriceBooks(pba.Id);
        System.assert(found.size() > 0);
    }

    @isTest
    public static void shouldSendEmailTodayTest() {
        Boolean shouldSend = PriceSheetController.shouldSendEmailToday();
        System.assert(shouldSend != null);
    }

    @isTest
    public static void getAccountsTest() {
        List<Account> acts = PriceSheetController.getAccounts('test');
        System.assert(acts.size() > 0);
    }

    @isTest
    public static void getRecordsBGTest() {
        List<SObject> results = PriceSheetController.getRecords('test', 'Account', 'Id', 'Buying_Group__c', '', 5);
        System.assert(results.size() > 0);
    }

    @isTest
    public static void getRecordsCompanyTest() {
        List<SObject> results = PriceSheetController.getRecords('test', 'Account', 'Id', 'Company_Name__c', '', 5);
        System.assert(results.size() > 0);
    }

    @isTest
    public static void getRecordsRegionTest() {
        List<SObject> results = PriceSheetController.getRecords('6', 'Account', 'Id', 'Region__c', '', 5);
        System.assert(results.size() > 0);
    }

    @isTest
    public static void setPriceBookTest() {
        Price_Book_Approval__c pba = [SELECT Id, Price_Book__c FROM Price_Book_Approval__c LIMIT 1];
        String results = PriceSheetController.setPriceBook(pba.Id, pba.Price_Book__c);
        System.assert(results != null);
    }

    @isTest
    public static void deletePBAccountLinkTest() {
        PB_Account_Link__c link = [SELECT Id FROM PB_Account_Link__c LIMIT 1];
        PB_Account_Link__c results = PriceSheetController.deletePBAccountLink(link.Id);

        List<PB_Account_Link__c> links = [SELECT Id FROM PB_Account_Link__c WHERE Id = :link.Id];
        System.assert(links.size() == 0);
    }

    @isTest
    public static void addAccountsTest() {
        Price_Book_Approval__c pba = [SELECT Id, Name, Type__c FROM Price_Book_Approval__c LIMIT 1];
        Map<ID, Account> acctMap = new Map<ID, Account>((List<Account>) [SELECT Id FROM Account]);
        List<String> idList = new List<String>();
        idList.addAll((List<String>) JSON.deserialize(JSON.serialize(acctMap.keySet()), List<String>.class));
        Map<String, Object> results = PriceSheetController.addAccounts(pba, idList);
        Object newAccounts = results.get('newAccounts');

        System.assert(newAccounts != null);
    }

    @isTest
    public static void setAccountsByTypeTest() {
        Price_Book_Approval__c pba = [SELECT Id, Name, Type__c FROM Price_Book_Approval__c LIMIT 1];
        Map<String, Object> results = PriceSheetController.setAccountsByType(pba, 'Company_Name__c', 'Test Company');
        Object newAccounts = results.get('newAccounts');
        System.assert(newAccounts != null);
    }

    @isTest
    public static void saveCustomPriceBookTest() {
        Price_Book_Approval__c pba = [SELECT Id, Type__c, Price_Book__c FROM Price_Book_Approval__c LIMIT 1];
        PriceBook2 pb = [
            SELECT
                Id,
                Type__c,
                Name,
                Date__c,
                (
                    SELECT
                        Id,
                        Name,
                        UnitPrice,
                        ProductCode,
                        Discount_Percent__c,
                        Discount_Price__c,
                        Base_Price__c,
                        Price_Override__c,
                        Product2.QuantityUnitOfMeasure,
                        Product2.Family,
                        Product2.Category__c,
                        Unit_Cost__c
                    FROM PricebookEntries
                )
            FROM Pricebook2
            LIMIT 1
        ];
        List<Price_Book_Family_Discount__c> discounts = [
            SELECT Id, Name, Percent_Discount__c, Product_Family__c, Type__c
            FROM Price_Book_Family_Discount__c
            WHERE Price_Book__c = :pba.Price_Book__c
        ];
        PriceBook2 res = PriceSheetController.saveCustomPriceBook(
            JSON.serialize(true),
            JSON.serialize(pb),
            JSON.serialize(pb.PriceBookEntries),
            JSON.serialize(discounts),
            JSON.serialize(pba)
        );
        System.assert(res != null);
    }

    @isTest
    public static void getCustomPriceBookDataTest() {
        Price_Book_Approval__c pba = [
            SELECT Id, Name, Type__c, Price_Book__c
            FROM Price_Book_Approval__c
            WHERE Price_Book__c != null
            LIMIT 1
        ];
        Map<String, Object> res = PriceSheetController.getCustomPriceBookData(pba.Price_Book__c);
        System.assert(res != null);
    }

    @isTest
    public static void submitPriceBookApprovalTest() {
        Price_Book_Approval__c pba = [SELECT Id, Name, Type__c, Price_Book__c FROM Price_Book_Approval__c LIMIT 1];
        Map<String, Object> res = PriceSheetController.submitPriceBookApproval(pba.Id);
        System.assert(res != null);
    }

    @isTest
    public static void updateEmailDayTest() {
        List<Account> accounts = [SELECT Id FROM Account];
        String res = PriceSheetController.updateEmailDay(accounts);
        System.assert(res != null);
    }

    @isTest
    public static void getApprovalEntriesTest() {
        User user = [SELECT Id, ManagerId FROM User LIMIT 1];

        // user[0].ManagerId = user[1].Id;
        // update user;

        Price_Book_Approval__c pba = [SELECT Id, Status__c FROM Price_Book_Approval__c WHERE Status__c = 'Ready to Submit' LIMIT 1];
        pba.Status__c = 'Pending';
        // update pba;

        Test.StartTest();

        Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
        req1.setComments('Submitting request for approval.');
        req1.setObjectId(pba.Id);

        // Submit on behalf of a specific submitter
        //req1.setSubmitterId(user.Id);

        // Submit the record to specific process and skip the criteria evaluation
        req1.setProcessDefinitionNameOrId('Price_Book_Approval');
        req1.setSkipEntryCriteria(true);

        // Submit the approval request for the account
        Approval.ProcessResult result = Approval.process(req1);

        ProcessInstanceWorkitem piwi = [
            SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :pba.Id
        ];

        PriceSheetController.PriceBookResult res = PriceSheetController.getApprovalEntries(piwi.Id);

        PriceSheetController.recallApproval(pba.Id);

        System.assert(res != null);
        Test.StopTest();
    }

    @isTest
    public static void sendDupliceAccountsTest() {
        Price_Book_Approval__c pba = [SELECT Id, Name, Status__c FROM Price_Book_Approval__c LIMIT 1];
        List<PB_Account_Link__c> existingLink = [
            SELECT Id, Name, Price_Book_Approval__r.Name, Price_Book_Approval__r.Owner.Name
            FROM PB_Account_Link__c
            LIMIT 2
        ];
        PriceSheetController.sendDupliceAccounts(pba, existingLink, existingLink);
    }

    @isTest
    public static void syncBasePriceTest() {
        List<Pricebook2> pbs = [SELECT Id, Name, Base_Price_Book__c FROM Pricebook2 WHERE isStandard = false];
        List<PriceBookEntry> entries = [SELECT Id, Name, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pbs[0].Id LIMIT 1];
        for (PriceBookEntry entry : entries) {
            entry.UnitPrice += 2.0;
        }
        update entries;

        for (PriceBook2 pb : pbs) {
            if (pb.Base_Price_Book__c == null) {
                pb.Name = 'Change again';
            }
        }

        update pbs;
    }

    @isTest
    public static void renderPDFTest() {
        Price_Book_Approval__c pba = [SELECT Id, Name, Status__c FROM Price_Book_Approval__c LIMIT 1];

        Test.startTest();
        PageReference pdf = Page.PriceBookAttachmentPDF;
        pdf.getParameters().put('id', (String) pba.Id);
        pdf.setRedirect(true);
        // Blob pdfBlob = pdf.getContent();
        // System.assert(pdfBlob != null);
        Test.setCurrentPage(pdf);

        PriceSheetController controller = new PriceSheetController();

        Test.stopTest();
        System.assert(true);
    }

    @isTest
    public static void renderCSVTest() {
        Price_Book_Approval__c pba = [SELECT Id, Name, Status__c FROM Price_Book_Approval__c LIMIT 1];

        Test.startTest();
        PageReference pdf = Page.PriceBookAttachmentExcel;
        pdf.getParameters().put('id', (String) pba.Id);
        pdf.setRedirect(true);
        // Blob pdfBlob = pdf.getContent();
        // System.assert(pdfBlob != null);
        Test.setCurrentPage(pdf);

        PriceSheetController controller = new PriceSheetController();

        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void PriceBookEmailBatchControllerTest() {
        PriceBookEmailBatchController obj = new PriceBookEmailBatchController();
        DataBase.executeBatch(obj);
    }

    @isTest
    static void ScheduleableTest() {
        SchedulableContext sc = null;
        PriceBookEmailSchedule emailschedule = new PriceBookEmailSchedule();
        emailschedule.execute(sc);

        PriceBookExpirationCheckSchedule expireSchedule = new PriceBookExpirationCheckSchedule();
        expireSchedule.execute(sc);
    }
}