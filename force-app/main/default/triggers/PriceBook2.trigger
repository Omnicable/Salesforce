/**
 * @description       :
 * @author            : chrisw@launchdm.com
 * @group             : PriceSheet
 * @last modified on  : 12-01-2022
 * @last modified by  : chrisw@launchdm.com
 **/
trigger PriceBook2 on PriceBook2(after update) {
    PricebookEntryProductBatchSync pricebookEntrySync = new PricebookEntryProductBatchSync(Trigger.newMap);
    database.executebatch(pricebookEntrySync, 3);
}