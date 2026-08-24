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
private class Milestone1_Milestone_Batch_Update_Test {
    
    @isTest
    public static void testMilestoneBatchUpdate(){
        // Create a project with milestones
        Milestone1_Project__c         project = Milestone1_Test_Utility.sampleProject('My Project');
        List<Milestone1_Milestone__c> mList   = new List<Milestone1_Milestone__c>();
        
        insert project;
        
        for(Integer i = 0; i < 200; i++){
            mList.add( Milestone1_Test_Utility.sampleMilestone(project.Id, null, 'My Test Milestone ' + i) );
        }
        
        insert mList;
        
        // Extract milestones Ids and run in batch
        Set<Id> idSet = new Set<Id>();
        
        for(Milestone1_Milestone__c m : mList){
            idSet.add( m.Id );
        }
        
        Test.StartTest();
        
        Database.executeBatch( new Milestone1_Milestone_Batch_Update(idSet) );
        
        Test.StopTest();
        
        // Test records were updated
        List<Milestone1_Milestone__c> result = [SELECT Id, LastModifiedDate, CreatedDate FROM Milestone1_Milestone__c WHERE Project__c = :project.Id];
        
        idSet.clear();
        for(Milestone1_Milestone__c m : result){
            if( m.LastModifiedDate > m.CreatedDate ){
                idSet.add( m.Id );
            }
        }
        
        System.AssertEquals( 200, idSet.size() );
    }
}