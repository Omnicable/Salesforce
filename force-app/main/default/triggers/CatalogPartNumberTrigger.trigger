trigger CatalogPartNumberTrigger on Part_Numbers__c (after insert, after update) {
    
    Set<Id> partIds = new Set<Id>();
    for ( Part_Numbers__c part : Trigger.new ) {
        partIds.add(part.Spec_Sheet__c);
    }
    
    Spec_Sheet__c[] specUpdates = [select Id from Spec_Sheet__c where Id in : partIds];
    update specUpdates;
}