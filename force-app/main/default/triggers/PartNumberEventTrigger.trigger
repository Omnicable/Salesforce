trigger PartNumberEventTrigger on PartNumber__e (after insert) {
    Set<Id> partNumberIds = new Set<Id>();
    for (PartNumber__e evt : Trigger.new) {
        if (evt != null && !String.isBlank(evt.Id__c)) {
            partNumberIds.add(Id.valueOf(evt.Id__c));
        }
    }
    if (partNumberIds.isEmpty()) {
        return;
    }
    try {
        ProductSyncBatch batch = new ProductSyncBatch(partNumberIds);
        Database.executeBatch(batch);
    } catch (Exception e) {
        System.debug(LoggingLevel.WARN, 'PartNumberEventTrigger: ' + e.getMessage());
    }
    
}