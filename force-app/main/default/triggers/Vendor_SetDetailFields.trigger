trigger Vendor_SetDetailFields on Vendor__c (after insert) {
    List<QuoteOrderCredit_Details__c> detailsToUpdate = new List<QuoteOrderCredit_Details__c>();
    Set<Id> qocDetailIds = new Set<Id>();
    
    try{
        
        for (Vendor__c vendor : Trigger.new) {
            if(!qocDetailIds.contains(vendor.QuoteOrderCredit_Detail__c)){
                qocDetailIds.add(vendor.QuoteOrderCredit_Detail__c);
                QuoteOrderCredit_Details__c details = new QuoteOrderCredit_Details__c(Id=vendor.QuoteOrderCredit_Detail__c, Vendor_Name__c =vendor.name, Vendor_Item__c = vendor.Vendor_Item__c, Vendor_Number__c=vendor.Vendor_Number__c );
                detailsToUpdate.add(details);
            }        
        }
        
        update detailsToUpdate;
        
    }catch(Exception e){
        System.debug('Error: ' + e.getMessage());
    }
    
}