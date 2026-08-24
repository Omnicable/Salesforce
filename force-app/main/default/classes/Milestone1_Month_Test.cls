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
private class Milestone1_Month_Test {
    
    @isTest
    static  void testMe() {
        Milestone1_Project__c testProject = Milestone1_Test_Utility.sampleProject('UNIT TEST PROJECT NAME ABC123XYZ UNIQUE' + System.now());
        testProject.Status__c = 'Active';
        testProject.Deadline__c = Date.today();
        insert testProject;
        
        Milestone1_Milestone__c testMilestone = Milestone1_Test_Utility.sampleMilestone(testProject.Id,null,'UNIT TEST MILESTONE NAME ACB123XYZ UNIQUE' + System.now());
        testMilestone.Deadline__c = Date.today();
        testMilestone.Complete__c = false;
        insert testMilestone;
        
        Milestone1_Task__c testTask = Milestone1_Test_Utility.sampleTask(testMilestone.Id);
        testTask.Complete__c = false;
        testTask.Start_Date__c = Date.today().addDays(-1);
        testTask.Due_Date__c = Date.today().addDays(-1);
        
        insert testTask;
        
        Milestone1_Month m = new Milestone1_Month( Date.today());
        system.assert(m!=null);
        List<Milestone1_Month.Week> l = m.getWeeks();
        for(Milestone1_Month.Week w : l)
        {
            List<Milestone1_Month.Day> days = w.getDays();
            for(Milestone1_Month.Day d : days)
            {
                system.debug(d.getDayOfYear());
                system.debug(d.getDayOfMonth());
                system.debug(d.getDayNumber());
                system.debug(d.getCSSName());
            }
        }
        system.debug(m.getFirstDate());
        system.debug(m.getWeekdayNames());
        system.debug(m.getYearName());
        system.debug(m.getMonthName());
        system.assert(m.getWeeks() != null);
        system.assert(m.getWeeks().size() > 3);
    }
    
    @IsTest
    static  void testClearEvents() {
        Milestone1_Project__c testProject = Milestone1_Test_Utility.sampleProject('UNIT TEST PROJECT NAME ABC123XYZ UNIQUE' + System.now());
        testProject.Status__c = 'Active';
        testProject.Deadline__c = Date.today();
        insert testProject;
        
        Milestone1_Milestone__c testMilestone = Milestone1_Test_Utility.sampleMilestone(testProject.Id,null,'UNIT TEST MILESTONE NAME ACB123XYZ UNIQUE' + System.now());
        testMilestone.Deadline__c = Date.today();
        testMilestone.Complete__c = false;
        insert testMilestone;
        
        Milestone1_Task__c testTask = Milestone1_Test_Utility.sampleTask(testMilestone.Id);
        testTask.Complete__c = false;
        testTask.Start_Date__c = Date.today().addDays(-1);
        testTask.Due_Date__c = Date.today().addDays(-1);
        
        insert testTask;
        
        Milestone1_Month m = new Milestone1_Month( Date.today());
        m.clearEvents();
        system.assert(m!=null);
        List<Milestone1_Month.Week> l = m.getWeeks();
        for(Milestone1_Month.Week w : l)
        {
            List<Milestone1_Month.Day> days = w.getDays();
            for(Milestone1_Month.Day d : days)
            {
                system.debug(d.getDayOfYear());
                system.debug(d.getDayOfMonth());
                system.debug(d.getDayNumber());
                system.debug(d.getCSSName());
            }
        }
        system.debug(m.getFirstDate());
        system.debug(m.getWeekdayNames());
        system.debug(m.getYearName());
        system.debug(m.getMonthName());
        system.assert(m.getWeeks() != null);
        system.assert(m.getWeeks().size() > 3);
    }
    
    
    @IsTest
    static  void testGetCurrentWeek() {
        Milestone1_Project__c testProject = Milestone1_Test_Utility.sampleProject('UNIT TEST PROJECT NAME ABC123XYZ UNIQUE' + System.now());
        testProject.Status__c = 'Active';
        testProject.Deadline__c = Date.today();
        insert testProject;
        
        Milestone1_Milestone__c testMilestone = Milestone1_Test_Utility.sampleMilestone(testProject.Id,null,'UNIT TEST MILESTONE NAME ACB123XYZ UNIQUE' + System.now());
        testMilestone.Deadline__c = Date.today();
        testMilestone.Complete__c = false;
        insert testMilestone;
        
        Milestone1_Task__c testTask = Milestone1_Test_Utility.sampleTask(testMilestone.Id);
        testTask.Complete__c = false;
        testTask.Start_Date__c = Date.today().addDays(-1);
        testTask.Due_Date__c = Date.today().addDays(-1);
        
        insert testTask;
        
        Milestone1_Month m = new Milestone1_Month( Date.today());
        m.getCurrentWeek(Date.today());
        system.assert(m!=null);
        List<Milestone1_Month.Week> l = m.getWeeks();
        for(Milestone1_Month.Week w : l)
        {
            List<Milestone1_Month.Day> days = w.getDays();
            for(Milestone1_Month.Day d : days)
            {
                system.debug(d.getDayOfYear());
                system.debug(d.getDayOfMonth());
                system.debug(d.getDayNumber());
                system.debug(d.getCSSName());
            }
        }
        system.debug(m.getFirstDate());
        system.debug(m.getWeekdayNames());
        system.debug(m.getYearName());
        system.debug(m.getMonthName());
        system.assert(m.getWeeks() != null);
        // system.assert(m.getWeeks().size() > 3);
    }
    
    
    @IsTest
    static  void testValidDateRange() {
        Milestone1_Project__c testProject = Milestone1_Test_Utility.sampleProject('UNIT TEST PROJECT NAME ABC123XYZ UNIQUE' + System.now());
        testProject.Status__c = 'Active';
        testProject.Deadline__c = Date.today();
        insert testProject;
        
        Milestone1_Milestone__c testMilestone = Milestone1_Test_Utility.sampleMilestone(testProject.Id,null,'UNIT TEST MILESTONE NAME ACB123XYZ UNIQUE' + System.now());
        testMilestone.Deadline__c = Date.today();
        testMilestone.Complete__c = false;
        insert testMilestone;
        
        Milestone1_Task__c testTask = Milestone1_Test_Utility.sampleTask(testMilestone.Id);
        testTask.Complete__c = false;
        testTask.Start_Date__c = Date.today().addDays(-1);
        testTask.Due_Date__c = Date.today().addDays(-1);
        
        insert testTask;
        
        Milestone1_Month m = new Milestone1_Month( Date.today());
        m.getValidDateRange();
        system.assert(m!=null);
        List<Milestone1_Month.Week> l = m.getWeeks();
        for(Milestone1_Month.Week w : l)
        {
            List<Milestone1_Month.Day> days = w.getDays();
            for(Milestone1_Month.Day d : days)
            {
                system.debug(d.getDayOfYear());
                system.debug(d.getDayOfMonth());
                system.debug(d.getDayNumber());
                system.debug(d.getCSSName());
            }
        }
        system.debug(m.getFirstDate());
        system.debug(m.getWeekdayNames());
        system.debug(m.getYearName());
        system.debug(m.getMonthName());
        system.assert(m.getWeeks() != null);
        system.assert(m.getWeeks().size() > 3);
    }
    
    
    

@IsTest
    static  void testSetEvents() {
        Milestone1_Project__c testProject = Milestone1_Test_Utility.sampleProject('UNIT TEST PROJECT NAME ABC123XYZ UNIQUE' + System.now());
        testProject.Status__c = 'Active';
        testProject.Deadline__c = Date.today();
        insert testProject;
        
        Milestone1_Milestone__c testMilestone = Milestone1_Test_Utility.sampleMilestone(testProject.Id,null,'UNIT TEST MILESTONE NAME ACB123XYZ UNIQUE' + System.now());
        testMilestone.Deadline__c = Date.today();
        testMilestone.Complete__c = false;
        insert testMilestone;
        
        Milestone1_Task__c testTask = Milestone1_Test_Utility.sampleTask(testMilestone.Id);
        testTask.Complete__c = false;
        testTask.Start_Date__c = Date.today().addDays(-1);
        testTask.Due_Date__c = Date.today().addDays(-1);
        
        insert testTask;
        
        Milestone1_Month m = new Milestone1_Month( Date.today());
        m.setEvents(new List<Milestone1_Calendar_Item>());
        system.assert(m!=null);
        List<Milestone1_Month.Week> l = m.getWeeks();
        for(Milestone1_Month.Week w : l)
        {
            List<Milestone1_Month.Day> days = w.getDays();
            for(Milestone1_Month.Day d : days)
            {
                system.debug(d.getDayOfYear());
                system.debug(d.getDayOfMonth());
                system.debug(d.getDayNumber());
                system.debug(d.getCSSName());
            }
        }
        system.debug(m.getFirstDate());
        system.debug(m.getWeekdayNames());
        system.debug(m.getYearName());
        system.debug(m.getMonthName());
        system.assert(m.getWeeks() != null);
        system.assert(m.getWeeks().size() > 3);
    }

}