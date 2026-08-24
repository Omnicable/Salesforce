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
private class Milestone1_Milestone_Trigger_Utility_T {

    @isTest
    /**
	* Test batch update of milestones with parent milestones
	*/
	public static void testMilestoneBatchUpdate(){
		// Create project
		Milestone1_Project__c project = Milestone1_Test_Utility.sampleProject('My Project');
		
		insert project;
		
		// Create parent milestones
		List<Milestone1_Milestone__c> pList = new List<Milestone1_Milestone__c>();
		
		for(Integer i = 0; i < 101; i++){
			pList.add( Milestone1_Test_Utility.sampleMilestone(project.Id, null, 'My Parent Milestone ' + i) ); 
		}

		try{
			insert pList;
		}
		catch(Exception e){
			system.assert( false, e.getMessage() );
		}

		// Create milestones
		List<Milestone1_Milestone__c> mList = new List<Milestone1_Milestone__c>();
		
		for(Integer j = 0; j < 101; j++){
			mList.add( Milestone1_Test_Utility.sampleMilestone(project.Id, pList.get(j).Id, 'My Milestone ' + j ) );
		}
		
		try{
			insert mList;
		}
		catch(Exception e){
			system.assert( false, e.getMessage() );
		}
		
		try{
			update [SELECT Id FROM Milestone1_Milestone__c WHERE Id IN :mList];
			system.assert(true, 'Milestones update successful');
		}
		catch(Exception e){
			system.assert( false, e.getMessage() );
		}
	}
}