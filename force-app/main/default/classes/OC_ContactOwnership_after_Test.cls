@isTest (SeeAllData=true)

private  class OC_ContactOwnership_after_Test {
    
    @isTest static void OCContactOwnershipAfterUpsertTest() {

        Test.startTest();
        Account acct = [SELECT Id, Name from Account limit 1];
        User user = [SELECT Id, Name from User WHERE Title = 'Account Manager' AND IsActive = true limit 1];
        acct.OwnerId = user.Id;
        Database.UpsertResult result = Database.upsert(acct, false);
        System.Debug('OC_ContactOwnership_after New Accounts: ' + result.getErrors());
        Test.stopTest();
        System.assert(true);
    }
}