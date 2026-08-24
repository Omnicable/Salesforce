/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class Milestone1_Expense_Trigger_Utility_Test {

    @isTest
    static void testTriggerUtility()
    {
        List<Milestone1_Expense__c> recs = new List<Milestone1_Expense__c>{new Milestone1_Expense__c()};
        Milestone1_Expense_Trigger_Utility.handleExpenseBeforeTrigger(recs);
        for(Milestone1_Expense__c rec : recs)
        {
            System.assertEquals(UserInfo.getUserId(),rec.Incurred_By__c, 'Mismatch userId and recIncurred_By__c');
            System.assertEquals(Date.today(),rec.Date_Incurred__c, 'Mismatch date and recDate_Incurred__c');
        }
    }
}