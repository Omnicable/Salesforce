/**
 * @description       : daily check for expired price book approvals, marks pba as expired and deactivates custom price books
 * @author            : chrisw@launchdm.com
 * @group             : PriceSheet
 * @last modified on  : 09-28-2022
 * @last modified by  : chrisw@launchdm.com
**/
public class PriceBookExpirationCheckSchedule implements Schedulable{

    public void execute(SchedulableContext sc) {
        List<Pricebook2> expiredPB = new List<Pricebook2>();
        List<Price_Book_Approval__c> expiredApprovals = new List<Price_Book_Approval__c>();

        for (Price_Book_Approval__c pba : [SELECT Id, Expiration_Date__c, Price_Book__c, Price_Book__r.Type__c FROM Price_Book_Approval__c WHERE Expiration_Date__c < TODAY AND Status__c != 'Expired']) {
            pba.Status__c = 'Expired';
            expiredApprovals.add(pba);

            if(pba.Price_Book__r.Type__c == 'Custom'){
                PriceBook2 pb = new Pricebook2(Id=pba.Price_Book__c, IsActive = false);
                expiredPB.add(pb);
            }
        }

        update expiredPB;
        update expiredApprovals;
    }
    
}