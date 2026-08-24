/**
 * @description       : Sales Budget object used by the Sales Budget Report
 * @author            : chrisw@launchdm.com
 * @group             : SalesBudgetReports
 * @last modified on  : 05-26-2022
 * @last modified by  : chrisw@launchdm.com
 **/
public class SalesBudget {
    public class ReportResults {
        public List<Report> reports { get; set; }
        public DateTime lastRunDate { get; set; }
        public String title { get; set; }
        public List<Period> reportPeriod { get; set; }
        public Boolean showGrouping { get; set; }

        public ReportResults() {
            this.reports = new List<Report>();
            this.lastRunDate = DateTime.now();
            this.title = '';
        }
    }

    public class Report {
        public Decimal invoice { get; set; }
        public Decimal target { get; set; }
        public String title { get; set; }
        public Decimal percentage { get; set; }
        public List<LineItem> lineItems { get; set; }
        public List<AgrregateLineItem> aggregatelineItems { get; set; }
        public Map<Integer, Decimal> targets = new Map<Integer, Decimal>();
        public String grouping { get; set; }

        public Report() {
            this.invoice = 0;
            this.target = 0;
            this.title = '';
            this.percentage = 0;
            this.lineItems = new List<LineItem>();
            this.aggregatelineItems = new List<AgrregateLineItem>();
            this.targets = new Map<Integer, Decimal>();
            this.grouping = 'region';
        }
    }

    public class LineItem implements Comparable {
        public Date invoiceDate { get; set; }
        public String invoiceNumber { get; set; }
        public Decimal dollarAmount { get; set; }
        public String type { get; set; }

        // public LineItem(){
        //     this.invoiceDate = Date.today();
        //     this.invoiceNumber = '';
        //     this.dollarAmount = 0;
        //     this.type = '';
        // }

        public LineItem(Date invoiceDate, String invoiceNumber, Decimal dollarAmount, String type) {
            this.invoiceDate = invoiceDate;
            this.invoiceNumber = invoiceNumber;
            this.dollarAmount = dollarAmount;
            this.type = type;
        }

        public Integer compareTo(Object compareTo) {
            LineItem compareToOppy = (LineItem) compareTo;
            Integer returnValue = 0;

            if (this.invoiceDate == compareToOppy.invoiceDate) {
                returnValue = 0;
            } else if (this.invoiceDate > compareToOppy.invoiceDate) {
                returnValue = 1;
            } else if (this.invoiceDate < compareToOppy.invoiceDate) {
                returnValue = -1;
            }

            return returnValue;
        }
    }

    public class AgrregateLineItem {
        public String region { get; set; }
        public Integer month { get; set; }
        public Decimal invoice { get; set; }
        public Decimal target { get; set; }
        public String managerName { get; set; }

        // public AgrregateLineItem(){
        //     this.month = 1;
        //     this.invoice = 0;
        //     this.target = 0;
        //     this.region = '';
        // }

        public AgrregateLineItem(Integer month, Decimal invoice, Decimal target, String region, String managerName) {
            this.month = month;
            this.invoice = invoice;
            this.target = target;
            this.region = region;
            this.managerName = managerName;
        }
    }
}