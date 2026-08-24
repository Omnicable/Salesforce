trigger CatalogFieldIgnoreTrigger on Catalog_Field_Ignore__c (after insert, after update, after delete) {
    
    Set<Id> specIds = new Set<Id>();
    if(trigger.isDelete) {
        for ( Catalog_Field_Ignore__c ignore : Trigger.old ) {
            specIds.add(ignore.Spec_Sheet__c);
        }
    } else {
        for ( Catalog_Field_Ignore__c ignore : Trigger.new ) {
            specIds.add(ignore.Spec_Sheet__c);
        }
    }
    
    Part_Numbers__c[] partUpdates = [select Id from Part_Numbers__c where Spec_Sheet__c in : specIds];

    update partUpdates;
    
}