public class PricebookEntryProductBatchSync implements Database.Batchable<sObject>, Database.Stateful {
    public Set<Id> pbIds;
    public Map<Id, Pricebook2> pbMap;
    Map<String, PriceBookEntry> baseEntryMap = new Map<String, PriceBookEntry>();

    public PricebookEntryProductBatchSync(Map<Id, Pricebook2> pbMap) {
        this.pbIds = pbMap.keySet();
        this.pbMap = pbMap;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (PriceBookEntry entry : [
            SELECT Id, UnitPrice, ProductCode, LastModifiedDate, Pricebook2Id, Base_Price__c, Product2Id
            FROM PricebookEntry
            WHERE
                (PriceBook2.isStandard = true
                OR PriceBook2.Type__c = 'Standard'
                OR PriceBook2.Type__c = 'Base')
                AND PriceBook2Id IN :this.pbIds
        ]) {
            this.baseEntryMap.put(entry.ProductCode, entry);
        }

        String query = 'SELECT Id FROM PriceBook2 WHERE Base_Price_Book__c IN :pbIds  AND Base_Price_Book__r.isActive = true ORDER BY CreatedDate DESC';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<PriceBook2> pricebooks) {
        List<PricebookEntry> newEntries = new List<PricebookEntry>();
        List<String> pricebookIds = new List<String>();
        for (PriceBook2 pb : pricebooks) {
            pricebookIds.add(pb.Id);
        }
        System.debug('pricebookIds: ' + pricebookIds);

        // Map<String,PricebookEntry> productMap = new Map<String,PricebookEntry>();
        Map<String,Map<String,PricebookEntry>> pricebookEntryMaps = new    Map<String,Map<String,PricebookEntry>>();
        //NOTE possible reverse the loop to see if new produt is included
        for (PriceBook2 pb : [SELECT Id, (SELECT Id, Base_Price__c, UnitPrice, LastModifiedDate, ProductCode, Product2Id, Price_Override__c, Discount_Percent__c, Discount_Price__c, Pricebook2Id, Product2.Category__c, Product2.Family FROM PricebookEntries), Base_Price_Book__c FROM PriceBook2 WHERE Id IN :pricebookIds]) {
            System.debug('pricebook: ' + pb);
            for (PriceBookEntry entry : pb.PricebookEntries) {
                
                Map<String,PricebookEntry> productMap = new Map<String,PricebookEntry>();
                productMap.put(entry.ProductCode, entry);
                pricebookEntryMaps.put(pb.Id, productMap);

                // System.debug('entry: ' + entry);
                // if(baseEntryMap.get(entry.ProductCode) == null){
                //     PriceBookEntry newEntry = new PriceBookEntry(IsActive=true, Base_Price__c=entry.UnitPrice, UnitPrice=entry.UnitPrice, 
                //     Pricebook2Id=pb.Id, Product2Id=entry.Product2Id, UseStandardPrice=false);
                //     newEntries.add(newEntry);
                // }
            }
        }

        for(String pbId : pricebookEntryMaps.keySet()){ 

            Map<String,PricebookEntry> productMap = pricebookEntryMaps.get(pbId);
            for(String productKey : baseEntryMap.keySet()){ 
                // PricebookEntry item = baseEntryMap.get(key);
                if(!productMap.containsKey(productKey)){
                    PricebookEntry entry = baseEntryMap.get(productKey);
                    PriceBookEntry newEntry = new PriceBookEntry(IsActive=true, Base_Price__c=entry.UnitPrice, UnitPrice=entry.UnitPrice, 
                    Pricebook2Id=pbId, Product2Id=entry.Product2Id, UseStandardPrice=false);
                    newEntries.add(newEntry);
                }
                
            }
        }


        System.debug('NEW_Entries: ' + newEntries);
        List<Database.upsertResult> res = Database.upsert(newEntries, false);
    }

    public void finish(Database.BatchableContext bc) {
        PricebookEntryPriceBatchSync pricebookEntrySync = new PricebookEntryPriceBatchSync(pbMap);
        database.executebatch(pricebookEntrySync, 1000);
    }
}