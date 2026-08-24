trigger SalesCallContest on Task (before insert, before update) {

    List<Task> TaskList = new List<Task>();
    Map<Id, Task> mapTasks = new Map<Id, Task>();
    Set<Id> tIds = new Set<Id>();

    for(Task t : Trigger.new){

         // WhatId is ID of a related Account, Opportunity, Campaign, Case, or custom object. Label 
         // is   Opportunity/Account ID.
         
        if (t.WhoId != null)  {
       
            //Accounts Id start with '001
            if( string.valueOf(t.WhoId).startsWith('003') ){

           	     if( string.valueOf(t.Subject).startsWith('Call') ){
           
                //Add the task to the Map and Set
                mapTasks.put(t.WhoId, t);
                tIds.add(t.WhoId);
                }
            }
        }
    }

    //Get all the contacts of the task
    List<Contact> cList = [Select SalesCallContest__c From Contact Where SalesCallContest__c = True and Id IN : tIds];

    //Update the field of task and get its value from contact
    for(Contact c : cList){
        Task t = mapTasks.get(c.Id);
        t.SalesCallContest__c = c.SalesCallContest__c;
    }

    //From the task in the map that had been updated, we transfer it to the instance of the original task
    for(Task t : Trigger.new){
        Task tmap = mapTasks.get(t.WhoId);
            if (tmap != null){
            t.SalesCallContest__c = tmap.SalesCallContest__c;
        }
    }

}