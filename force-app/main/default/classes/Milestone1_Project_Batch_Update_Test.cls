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
private class Milestone1_Project_Batch_Update_Test {
    
    @isTest
    public static void testMilestoneBatchUpdate(){
        // Create projects
        List<Milestone1_Project__c> pList = new List<Milestone1_Project__c>();
        
        for(Integer i = 0; i < 200; i++){
            pList.add( Milestone1_Test_Utility.sampleProject('My Project ' + i) );
        }
        
        insert pList;
        
        // Extract project Ids and run in batch
        Set<Id> idSet = new Set<Id>();
        
        for(Milestone1_Project__c p : pList){
            idSet.add( p.Id );
        }
        
        Test.StartTest();
        
        Database.executeBatch( new Milestone1_Project_Batch_Update(idSet) );
        
        Test.StopTest();
        
        // Test records were updated
        List<Milestone1_Project__c> result = [SELECT Id, LastModifiedDate, CreatedDate FROM Milestone1_Project__c WHERE Id IN :idSet];
        Set<Id> idRes = new Set<Id>();
        
        for(Milestone1_Project__c p : result){
            if( p.LastModifiedDate > p.CreatedDate ){
                idRes.add( p.Id );
            }
        }
        
        System.Assert( idSet.containsAll(idRes) && idRes.containsAll(idSet) );
    }
}