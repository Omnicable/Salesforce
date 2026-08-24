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
private class Milestone1_Summary2_Test {
    
    @isTest
    static  void testController() {
        
        //make sure it shows active projects
        Milestone1_Summary2 summary2 = new Milestone1_Summary2();
        
        //important for new installs
        if (summary2.settings == null) {
            summary2.settings = new Milestone1_Settings__c();
        }
        
        if (summary2.settings.Report_Id_Blocked_Tasks_by_Project__c == null) {
            summary2.settings.Report_Id_Blocked_Tasks_by_Project__c = 'a';
            summary2.settings.Report_Id_My_tasks_by_project__c = 'b';
            summary2.settings.Report_Id_Overdue_Tasks_by_Project__c = 'c';
        }
        
        Integer i = summary2.getProjects().size();
        
        Milestone1_Project__c p1 = Milestone1_Test_Utility.sampleProjectActive('Controller Test');
        insert p1;
        
        
        
        //make sure we get page references back
        summary2.targetProject = p1.id;
        
        System.assert(summary2.view() != null);
        System.assert(summary2.viewMyTasks() != null);
        System.assert(summary2.viewBlockedTasks() != null);
        System.assert(summary2.viewOverdueTasks() != null);
        
        summary2.initialize();
        System.assert(summary2.recentItems != null);
        
        //Test.setFixedSearchResults(new Id[] {p1.Id});
        summary2.searchText = 's';
        summary2.searchProjects();
        System.assertEquals(true, summary2.hasSearchLengthError);
        
        
        summary2.searchText = 'Test';
        summary2.searchProjects();
        System.assert(summary2.hasSearchResultsError);
        System.assert(!summary2.hasProjectResults);
        System.assert(!summary2.hasMilestoneResults);
        System.assert(!summary2.hasTaskResults);
        
        
        
        System.assertEquals(1, summary2.pageNumber);
        
        
        if(summary2.hasNext == true)
        {
            summary2.next();
        }
        if(summary2.hasPrevious == true)
        {
            summary2.previous();
        }
        
    }
    
    // @IsTest
    // static  void testViewOpenTasks() {
        //     // Test that the viewOpenTasks method returns a non-null PageReference
        //     Milestone1_Summary2 summary2 = new Milestone1_Summary2();
        //     summary2.targetProject = Milestone1_Test_Utility.sampleProjectActive('Test Project').Id;
        //     System.assert(summary2.viewOpenTasks() != null);
    // }
    
    
    // @IsTest
    // static  void testViewMilestoneOpenTasks() {
        //     // Test that the viewMilestoneOpenTasks method returns a non-null PageReference
        //     Milestone1_Summary2 summary2 = new Milestone1_Summary2();
        //     summary2.targetProject = Milestone1_Test_Utility.sampleProjectActive('Test Project').Id;
        //     System.assert(summary2.viewMilestoneOpenTasks() != null);
    // }
    
    
    @IsTest
    static  void testIncompleteTasksByProject() {
        // Test that the incompleteTasksByProject method returns a non-null PageReference
        Milestone1_Summary2 summary2 = new Milestone1_Summary2();
        summary2.targetProject = Milestone1_Test_Utility.sampleProjectActive('Test Project').Id;
        System.assert(summary2.incompleteTasksByProject() != null);
    }
    
    
    @IsTest
    static  void testIncompleteTasksByPriority() {
        // Test that the incompleteTasksByPriority method returns a non-null PageReference
        Milestone1_Summary2 summary2 = new Milestone1_Summary2();
        System.assert(summary2.incompleteTasksByPriority() != null);
    }
    
    
    @IsTest
    static  void testMyLateTasks() {
        // Test that the summaryMyLateTasks method returns a non-null PageReference
        Milestone1_Summary2 summary2 = new Milestone1_Summary2();
        System.assert(summary2.summaryMyLateTasks() != null);
    }
    
    
    @IsTest
    static  void testMyBlockedTasks() {
        // Test that the summaryMyBlockedTasks method returns a non-null PageReference
        Milestone1_Summary2 summary2 = new Milestone1_Summary2();
        System.assert(summary2.summaryMyBlockedTasks() != null);
    }
    
}