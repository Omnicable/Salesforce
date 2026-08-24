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
private class Milestone1_Project_Trigger_Utility_Test {

    @isTest
    /**
	* Test milestone delete
	*/
	static void testMilestoneDelete(){
		// Create project
		Milestone1_Project__c project = Milestone1_Test_Utility.sampleProject('My Test Project');
		
		insert project;
		
		// Create milestones
		List<Milestone1_Milestone__c> mList = new List<Milestone1_Milestone__c>();
		
		for(Integer i = 0; i < 101; i++){
			mList.add( Milestone1_Test_Utility.sampleMilestone(project.Id, null, 'My Test Milestone ' + i) );
		}

		try{
			insert mList;
		}
		catch(Exception e){
			system.assert( false, e.getMessage() );
		}

		// Delete and check if it was successful
		try{
			Test.startTest();
			Milestone1_Project_Trigger_Utility.handleProjectDeleteTrigger( new List<Milestone1_Project__c>{ project } );
			Test.stopTest();
			
			system.assertEquals(0, [SELECT count() FROM Milestone1_Milestone__c WHERE Project__c = :project.Id]);
		}
		catch(Exception e){
			system.assert( false, e.getMessage() );
		}
	}
}