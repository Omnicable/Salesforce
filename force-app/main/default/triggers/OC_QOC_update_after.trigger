trigger OC_QOC_update_after on QuotesOrdersCredits_Header__c (after update) {
	Set<Id> qIdSet = new Set<Id>();
	for ( Integer I = 0; i < Trigger.new.size(); i++ ) {
		QuotesOrdersCredits_Header__c qn = Trigger.new[i];
		QuotesOrdersCredits_Header__c qo = Trigger.old[i];
		if ( (qo.Type__c=='Quote' && qn.Type__c!='Quote')||(qn.Type__c=='Quote' && qo.Status__c=='Open' && qn.Status__c!='Open') ) {
			qIdSet.add(qn.Id);
		}
	}
	List<Task> nTasks = new List<Task>();
	for ( Task t : [Select Id From Task where Subject like 'Open Quote%' and Status<>'Completed' and WhatId in :qIdSet] ) {
		nTasks.add( new Task(Id = t.Id, Status = 'Completed'));
	}
	if ( ! nTasks.isEmpty() ) update nTasks;
}