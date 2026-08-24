/**
 * @description       :
 * @author            : chrisw@launchdm.com
 * @group             : SalesBudgetReports
 * @last modified on  : 05-26-2022
 * @last modified by  : chrisw@launchdm.com
 **/
@isTest(SeeAllData=true)
public class SalesBudgetControllerTest {
    /**
     * @description create all required test data to sest SalesBudgetController.cls
     * @author chrisw@launchdm.com | 05-25-2022
     **/
    public static void setup(User user) {
        User apiUser = [SELECT Id, Name FROM User WHERE ProfileId = '00e60000001BWSc' AND IsActive = true LIMIT 1];
        System.runAs(apiUser) {
            Account account = [SELECT Id FROM Account WHERE Region_Number__c = '6' LIMIT 1];
            SalesBudgetControllerTest.createBudgetData(account, user, 3);
        }
    }
    
    /**
     * @description create test contacts
     * @author chrisw@launchdm.com | 04-04-2022
     * @param Integer size
     * @param String acountId
     * @return List<Contact>
     **/
    public static List<Contact> createContacts(Integer size, String acountId) {
        List<Contact> contacts = new List<Contact>();
        
        for (Integer i = 0; i < size; i++) {
            Contact contact = new Contact(
                Contact_Title__c = 'Accounting',
            Email = 'test' + i + '@test.com',
            OCC_RewardsValue__c = 1,
            AccountId = acountId,
            Sequence__c = i,
            OCC_Rewards__c = true,
            OCC_RewardStepValue__c = 1,
            OCC_RewardStep__c = 1,
            FirstName = 'Test',
            LastName = 'Williams',
            Ext_Id__c = String.valueOf(i)
                );
            contacts.add(contact);
        }
        
        insert contacts;
        return contacts;
    }
    
    /**
     * @description create test users
     * @author chrisw@launchdm.com | 04-04-2022
     * @param Integer size
     * @param String profileId
     * @param List<Contact> contacts
     * @return List<User>
     **/
    public static List<User> createUsers(Integer size, String profileId, List<Contact> contacts) {
        List<String> userRoles = new List<String>{ 'RVP Central', 'Regional Manager 6', 'Account Manager 6' };
        List<UserRole> newRoles = new List<UserRole>();
        
        for (Integer i = 0; i < size; i++) {
            UserRole r = new UserRole(DeveloperName = 'MyCustomRole', Name = 'My Role');
            
            if (newRoles.get(i - 1) != null) {
                r.ParentRoleId = newRoles.get(i - 1).Id;
            }
            
            upsert r;
            newRoles.add(r);
        }
        
        List<User> users = new List<User>();
        
        for (Integer i = 0; i < size; i++) {
            User user = new User(
                Username = System.now().millisecond() + '2test12345@test.com',
            ContactId = contacts.get(i).Id,
            ProfileId = profileId,
            Alias = 'test' + i,
            Email = 'test' + i + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty' + i,
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            UserRoleId = newRoles.get(i).Id,
            Region__c = '6'
                );
            
            users.add(user);
        }
        
        insert users;
        return users;
    }
    
    public static void createBudgetData(Account account, User user, Integer size) {
        List<Sales_History_Line_Item__c> items = new List<Sales_History_Line_Item__c>();
        List<External_Sales_History__c> externalSalesHistory = new List<External_Sales_History__c>();
        List<Sales_Target__c> salesTargets = new List<Sales_Target__c>();
        
        SalesHistory__c sh = new SalesHistory__c(
            Customer__c = account.Id,
        Invoice_Date__c = Date.today(),
        Name = user.Name,
        Inside_Account_Manager__c = user.Id
            );
        insert sh;
        
        for (Integer i = 0; i < size; i++) {
            Sales_History_Line_Item__c lineItem = new Sales_History_Line_Item__c(
                Line_Total__c = 100,
            Line__c = String.valueOf(i),
            Line_Type__c = 'Regular',
            Sales_History__c = sh.Id
                );
            items.add(lineItem);
            
            External_Sales_History__c exSH = new External_Sales_History__c(
                User__c = user.Id,
            Ext_Id__c = String.valueOf(i),
            Invoice_Date__c = Date.today(),
            Total_Invoice_Dollars__c = 100,
            Region__c = user.Region__c
                );
            externalSalesHistory.add(exSH);
            
            Sales_Target__c target = new Sales_Target__c(
                Ext_Id__c = String.valueOf(i),
            Date__c = Date.today(),
            Region_Number__c = '6',
            Target_Amount__c = 100,
            User__c = user.Id
                );
            salesTargets.add(target);
        }
        
        insert items;
        insert externalSalesHistory;
        insert salesTargets;
    }
    
    @IsTest
    public static void getStandardReport() {
        User user = [SELECT Id, Region__c, Name, UserRole.Name FROM User WHERE UserRole.Name = 'Account Manager 6' AND IsActive = true LIMIT 1];
        SalesBudgetControllerTest.setup(user);
        System.runAs(user) {
            System.debug('user: ' + JSON.serialize(user));
            System.debug(UserInfo.getUserId());
            String res = SalesBudgetController.queryReportTotal(true, 'THIS_MONTH', 'byDate');
            String resAgg = SalesBudgetController.queryReportTotal(false, 'THIS_MONTH', 'byDate');
            
            System.debug('res: ' + res);
            System.debug('resAgg: ' + resAgg);
            System.assert(res != null && resAgg != null);
        }
    }
    
    @IsTest
    public static void getRegionalManageReport() {
        User runUser = [SELECT Id, Region__c, Name, UserRole.Name FROM User WHERE UserRole.Name = 'Regional Manager 6' AND IsActive = true LIMIT 1 ];
        User user = [SELECT Id, Region__c, Name, UserRole.Name FROM User WHERE UserRole.Name = 'Account Manager 6' AND IsActive = true LIMIT 1];
        SalesBudgetControllerTest.setup(user);
        System.runAs(runUser) {
            System.debug('user: ' + JSON.serialize(user));
            System.debug(UserInfo.getUserId());
            String res = SalesBudgetController.queryReportTotal(true, 'THIS_MONTH', 'byDate');
            String resAgg = SalesBudgetController.queryReportTotal(false, 'THIS_YEAR', 'byDate');
            String resAggByDate = SalesBudgetController.queryReportTotal(false, 'THIS_YEAR', 'byUser');
            
            System.debug('res: ' + res);
            System.debug('resAgg: ' + resAgg);
            System.assert(res != null && resAgg != null && resAggByDate != null);
        }
    }
    
    @IsTest
    public static void getSSCManageReport() {
        User runUser = [SELECT Id, Region__c, Name, UserRole.Name FROM User WHERE UserRole.Name = 'SSC Manager' AND IsActive = true LIMIT 1];
        User user = [SELECT Id, Region__c, Name, UserRole.Name FROM User WHERE UserRole.Name = 'Account Manager 6' AND IsActive = true LIMIT 1];
        SalesBudgetControllerTest.setup(user);
        System.runAs(runUser) {
            System.debug('user: ' + JSON.serialize(user));
            System.debug(UserInfo.getUserId());
            String res = SalesBudgetController.queryReportTotal(true, 'THIS_MONTH', 'byDate');
            String resAgg = SalesBudgetController.queryReportTotal(false, 'THIS_YEAR', 'byDate');
            String resAggByUser = SalesBudgetController.queryReportTotal(false, 'THIS_YEAR', 'byUser');
            
            System.debug('res: ' + res);
            System.debug('resAgg: ' + resAgg);
            System.assert(res != null && resAgg != null && resAggByUser != null);
        }
    }
    
    @IsTest
    public static void getRVPReport() {
        User runUser = [SELECT Id, Region__c, Name, UserRole.Name FROM User WHERE UserRole.Name = 'RVP Central' AND IsActive = true LIMIT 1];
        User user = [SELECT Id, Region__c, Name, UserRole.Name FROM User WHERE UserRole.Name = 'Regional Manager 6' AND IsActive = true LIMIT 1];
        SalesBudgetControllerTest.setup(user);
        System.runAs(runUser) {
            System.debug('user: ' + JSON.serialize(user));
            System.debug(UserInfo.getUserId());
            String res = SalesBudgetController.queryReportTotal(true, 'THIS_MONTH', 'byDate');
            String resAgg = SalesBudgetController.queryReportTotal(false, 'THIS_QUARTER', 'byDate');
            
            System.debug('res: ' + res);
            System.debug('resAgg: ' + resAgg);
            System.assert(res != null && resAgg != null);
        }
    }
}