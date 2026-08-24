public class OCC_ContactRewardSchedulable implements Schedulable {
	public void execute(SchedulableContext sc) {
		ContactRewardTotalBatch batch = new ContactRewardTotalBatch();
		database.executebatch(batch);
	}
}