public class PricebookEntryPriceBatchSync implements Database.Batchable<sObject>, Database.Stateful {
    public Set<Id> pbIds;
    public Map<Id, Pricebook2> pbMap;
    Map<String, PriceBookEntry> baseEntryMap = new Map<String, PriceBookEntry>();

    public PricebookEntryPriceBatchSync(Map<Id, Pricebook2> pbMap) {
        this.pbIds = pbMap.keySet();
        this.pbMap = pbMap;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (PriceBookEntry entry : [
            SELECT Id, UnitPrice, ProductCode, LastModifiedDate, Pricebook2Id
            FROM PricebookEntry
            WHERE
                (PriceBook2.isStandard = true
                OR PriceBook2.Type__c = 'Standard'
                OR PriceBook2.Type__c = 'Base')
                AND PriceBook2Id IN :this.pbIds
        ]) {
            this.baseEntryMap.put(entry.ProductCode + entry.Pricebook2Id, entry);
        }

        String query = 'SELECT Id, Base_Price__c, UnitPrice, LastModifiedDate, ProductCode, Price_Override__c, Discount_Percent__c, Discount_Price__c, Pricebook2Id, Product2.Category__c, Product2.Family, Pricebook2.Base_Price_Book__c FROM PricebookEntry WHERE PriceBook2.Base_Price_Book__c IN :pbIds AND PriceBook2.Base_Price_Book__r.isActive = true ORDER BY Product2.Index__c';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<PriceBookEntry> entries) {
        List<PricebookEntry> updatedEntries = new List<PricebookEntry>();

        for (PriceBookEntry entry : entries) {
            PriceBookEntry parentEntry = baseEntryMap.get(entry.ProductCode + entry.Pricebook2.Base_Price_Book__c);
            System.debug('parentEntry: ' + parentEntry);
            if(parentEntry == null){

                updatedEntries.add(entry);

            }else if (entry.Base_Price__c != parentEntry.UnitPrice) {
                entry.Base_Price__c = parentEntry.UnitPrice;

                if (entry.Discount_Percent__c != null && entry.Discount_Percent__c != 0) {
                    entry.Discount_Price__c = entry.Base_Price__c - (entry.Base_Price__c * (entry.Discount_Percent__c / 100));
                }

                if (entry.Price_Override__c != null) {
                    entry.UnitPrice = entry.Price_Override__c;
                } else if (entry.Discount_Price__c != null) {
                    entry.UnitPrice = entry.Discount_Price__c;
                } else {
                    entry.UnitPrice = entry.Base_Price__c;
                }

                updatedEntries.add(entry);
            }
        }
        System.debug('Entries: ' + updatedEntries);
        upsert updatedEntries;
    }

    public void finish(Database.BatchableContext bc) {
      

        User user = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId()];
        if (String.isBlank(user.Email)) {
            return;
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(new List<String>{ user.Email });
        message.setSubject('Pricebook Entry Sync Complete');

        String emailBody = 'The following related Pricebooks have finished syncing... <br> <br>';
        for (Id key : this.pbMap.keySet()) {
            Pricebook2 pb = this.pbMap.get(key);
            emailBody += pb.Name + '<br>';
        }

        message.setHtmlBody(emailBody);

        if (Test.isRunningTest()) {
            return;
        }
        // allOrNone=false: orgs without single-email permission must not fail the batch.
        Messaging.SendEmailResult[] messageRes = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ message },
            false
        );
        if (!messageRes.isEmpty()) {
            System.debug('Message Res: ' + messageRes[0].isSuccess());
        }
    }
}