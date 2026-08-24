/**
 * @description       : daily check to send emails if today is a weekday
 * @author            : chrisw@launchdm.com
 * @group             : PriceSheet
 * @last modified on  : 02-01-2023
 * @last modified by  : chrisw@launchdm.com
 **/
public class PriceBookEmailSchedule implements Schedulable {
    public void execute(SchedulableContext sc) {
        Boolean isWeekday = PriceSheetController.shouldSendEmailToday();
        if (isWeekday || Test.isRunningTest()) {
            PriceBookEmailBatchController batch = new PriceBookEmailBatchController();
            database.executebatch(batch, 50);
        } else {
            System.debug(Date.today() + ' is a Weekend');
        }
    }
}