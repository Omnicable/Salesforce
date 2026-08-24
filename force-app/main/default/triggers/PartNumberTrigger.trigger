trigger PartNumberTrigger on Part_Numbers__c (after insert, after update, after delete) {

    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            List<PartNumber__e> events = new List<PartNumber__e>();
            for (Part_Numbers__c p : Trigger.new) {
                events.add(new PartNumber__e(Id__c = p.Id));
                events.add(new PartNumber__e(Item_Number__c = p.Item_Number__c));
            }

            EventBus.publish(events);
        }
    }
}