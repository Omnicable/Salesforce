/**
 * @description       : 
 * @author            : chrisw@launchdm.com
 * @group             : 
 * @last modified on  : 04-30-2022
 * @last modified by  : chrisw@launchdm.com
**/
@isTest(SeeAllData=true)
public class OC_AccountTriggerAsyncTest {
    static testMethod void AccountTriggerTest() {
        User u118 = [select Id,Sales_Number__c from User where isActive = True and Sales_Number__c <>'' LIMIT 1];
        List<User> users = [Select Id, Email from User where isActive = true and Sales_Number__c <> '' Limit 2];
        List<Account> accounts= [select id, name, OwnerID, ParentAccount__c, Account_Number__c from account where Active__c ='A' and Account_Number__c <>'' LIMIT 2];
            Account aRum = accounts.get(0);
            Account parentaRum = accounts.get(1); 
            aRum.Salesperson_Code__c = u118.Sales_Number__c;
            aRum.OwnerId = u118.Id ;
            aRum.Agent__c = u118.Id;
            aRum.Account_Owner_2__c = u118.Id;
            aRum.ParentAccount__c = parentaRum.Account_Number__c;
        update aRum;
    }
}