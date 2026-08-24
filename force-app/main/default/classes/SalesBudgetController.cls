/**
 * @description       :
 * @author            : chrisw@launchdm.com
 * @group             : SalesBudgetReports
 * @last modified on  : 06-10-2022
 * @last modified by  : chrisw@launchdm.com
 **/
public class SalesBudgetController {
    public Boolean reportIsRunning { get; set; }
    public String attachmentId { get; set; }
    public String logoLink { get; set; }
    public String currentDate { get; set; }
    public SalesBudget.ReportResults results { get; set; }
    public Date today {
        get {
            return Date.today();
        }
    }
    
    public SalesBudgetController() {
        String range = ApexPages.currentPage().getParameters().get('range');
        results = (SalesBudget.ReportResults) JSON.deserializeStrict(
            SalesBudgetController.queryReportTotal(true, range, 'byDate'),
        SalesBudget.ReportResults.class
            );
        currentDate = results.lastRunDate.format('MM/dd/yy hh:mm a', UserInfo.getTimeZone().getID());
    }
    
    /**
     * @description Get appropriate report based on current user
     * @author chrisw@launchdm.com | 05-24-2022
     * @param Boolean showDetails
     * @param String range
     * @return String
     **/
    @AuraEnabled(cacheable=true)
    public static String queryReportTotal(Boolean showDetails, String range, String grouping) {
        SalesBudget.ReportResults results = new SalesBudget.ReportResults();
        
        User user = [SELECT Id, Name, ProfileId, UserRoleId, UserRole.Name, Region__c FROM User WHERE Id = :UserInfo.getUserId()];
        String regex = '[a-zA-Z]{1,}|\\-';
        String region = user.UserRole.Name.replaceAll(regex, '').trim();
        Boolean showGrouping = false;
        
        if (user.UserRole.Name.contains('SSC Manager')) {
            showGrouping = true;
            results = showDetails
                ? SalesBudgetController.sscManagerReport(range, region, user)
                : grouping == 'byDate'
                ? SalesBudgetController.sscManagerReportAggregate(range, region, user)
                : SalesBudgetController.sscManagerReportAggregateByUser(range, region, user);
        } else if (user.UserRole.Name.contains('RVP')) {
            results = showDetails
                ? SalesBudgetController.getRVPReport(range, user)
                : SalesBudgetController.getRVPReportAggregate(range, user);
        } else if (user.UserRole.Name.contains('Regional Manager')) {
            showGrouping = true;
            results = showDetails
                ? SalesBudgetController.regionalManagerReport(range, region, user)
                : grouping == 'byDate'
                ? SalesBudgetController.regionalManagerReportAggregate(range, region, user)
                : SalesBudgetController.regionalManagerReportAggregateByUser(range, region, user);
        } else {
            results = showDetails
                ? SalesBudgetController.getStandardReport(user, range)
                : SalesBudgetController.getStandardReportAggregate(user, range);
        }
        
        results.lastRunDate = Datetime.now();
        results.showGrouping = showGrouping;
        return JSON.serialize(results);
    }
    
    /**
     * @description Get user full report with all line items
     * @author chrisw@launchdm.com | 05-24-2022
     * @param User user
     * @param String range
     * @return SalesBudget.ReportResults
     **/
    public static SalesBudget.ReportResults getStandardReport(User user, String range) {
        System.debug('Method: getStandardReport');
        SalesBudget.ReportResults results = new SalesBudget.ReportResults();
        SalesBudget.Report report = new SalesBudget.Report();
        String userId = user.Id;
        
        String shQuery =
            'SELECT Id, Name, NetGP__c, Invoice_Date__c FROM SalesHistory__c WHERE Invoice_Date__c = ' +
            range +
            ' AND (Inside_Account_Manager__c = :userId OR Outside_Account_Manager__c =: userId)';
        for (SalesHistory__c sale : Database.query(shQuery)) {
            report.invoice += sale.NetGP__c;
            report.lineItems.add(new SalesBudget.LineItem(sale.Invoice_Date__c, sale.Name, sale.NetGP__c, 'Internal'));
        }
        
        // String eshQuery =
        //     'SELECT Id, Ext_Id__c, NetGP__c, Invoice_Date__c, Region__c FROM External_Sales_History__c WHERE Invoice_Date__c =' +
        //     range +
        //     '  AND User__c =: userId';
        // for (External_Sales_History__c externalSales : Database.query(eshQuery)) {
            //     report.invoice += externalSales.NetGP__c;
            //     report.lineItems.add(
            //         new SalesBudget.LineItem(
            //         externalSales.Invoice_Date__c,
            //     externalSales.Ext_Id__c,
            //     externalSales.NetGP__c,
            //     'External'
            //         )
            //         );
        // }
        
        String targetQuery =
            'SELECT count(id), CALENDAR_MONTH(Date__c)month, SUM(Target_Amount__c)target FROM Sales_Target__c WHERE User__c =: userId AND Date__c = ' +
            range +
            ' GROUP BY CALENDAR_MONTH(Date__c) LIMIT 2000';
        for (AggregateResult targetAgg : Database.query(targetQuery)) {
            Decimal target = (Decimal) targetAgg.get('target') != null ? (Decimal) targetAgg.get('target') : 0;
            report.target += target;
        }
        
        Period period = SalesBudgetController.getDateRange(range);
        report.percentage = report.target == 0 || report.invoice == 0 ? 0 : report.invoice / report.target;
        results.title = String.format(
            'GP$ Budget Report {0} to {1}',
        new List<String>{ period.StartDate.format(), period.EndDate.format() }
        );
        report.title = String.format(
            '{0}\'s GP$ Budget Report {1} to {2}',
        new List<String>{ user.Name, period.StartDate.format(), period.EndDate.format() }
        );
        results.reports.add(report);
        return results;
    }
    
    /**
     * @description Get Regional VP full report with all line items
     * @author chrisw@launchdm.com | 05-24-2022
     * @param String range
     * @param User user
     * @return SalesBudget.ReportResults
     **/
    public static SalesBudget.ReportResults getRVPReport(String range, User user) {
        String roleId = user.UserRoleId;
        String roleName = user.userRole.Name;
        SalesBudget.ReportResults results = new SalesBudget.ReportResults();
        
        Map<String, SalesBudget.Report> roleReportMap = new Map<String, SalesBudget.Report>();
        
        RoleHierarchyUtil.RoleHierarchy roleH = new RoleHierarchyUtil().getSubRoles(new Set<Id>{ roleId }, 1);
        Set<Id> regionIds = roleH.regionIds;
        Set<String> regionNames = roleH.regionNames;
        Set<String> regionNumbers = roleH.regionNumbers;
        
        for (String region : regionNumbers) {
            if (region != '') {
                SalesBudget.Report rep = new SalesBudget.Report();
                roleReportMap.put(region, rep);
            }
        }
        
        String sQuery =
            'SELECT Id, Name, NetGP__c, Region__c, Invoice_Date__c FROM SalesHistory__c WHERE Invoice_Date__c = ' +
            range +
            ' AND (Region__c IN :regionNumbers)';
        for (SalesHistory__c sale : Database.query(sQuery)) {
            if (roleReportMap.get(sale.Region__c) != null) {
                SalesBudget.Report rep = roleReportMap.get(sale.Region__c);
                rep.invoice += sale.NetGP__c;
                rep.lineItems.add(new SalesBudget.LineItem(sale.Invoice_Date__c, sale.Name, sale.NetGP__c, 'Internal'));
            }
        }
        
        // String esQuery =
        //     'SELECT Id, Ext_Id__c,NetGP__c, Invoice_Date__c, Region__c, User__r.Region__c FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
        //     range +
        //     ' AND (Region__c IN: regionNumbers OR User__r.Region__c IN :regionNumbers)';
        // for (External_Sales_History__c externalSales : Database.query(esQuery)) {
            //     SalesBudget.Report rep;
            //     if (roleReportMap.get(externalSales.Region__c) != null) {
                //         rep = roleReportMap.get(externalSales.Region__c);
            //     } else {
                //         rep = roleReportMap.get(externalSales.User__r.Region__c);
            //     }
            
            //     rep.invoice += externalSales.NetGP__c;
            //     rep.lineItems.add(
            //         new SalesBudget.LineItem(
            //         externalSales.Invoice_Date__c,
            //     externalSales.Ext_Id__c,
            //     externalSales.NetGP__c,
            //     'External'
            //         )
            //         );
        // }
        
        String stQuery =
            'SELECT Date__c, Region_Number__c, Target_Amount__c, User__c, User__r.Region__c, User__r.UserRole.Id FROM Sales_Target__c WHERE  Date__c = ' +
            range +
            ' AND (User__r.Region__c IN: regionNumbers OR Region_Number__c IN: regionNumbers)';
        for (Sales_Target__c salesTarget : Database.query(stQuery)) {
            SalesBudget.Report rep;
            if (roleReportMap.get(salesTarget.Region_Number__c) != null) {
                rep = roleReportMap.get(salesTarget.Region_Number__c);
            } else {
                rep = roleReportMap.get(salesTarget.User__r.Region__c);
            }
            
            rep.target += salesTarget.Target_Amount__c;
        }
        
        for (String key : roleReportMap.keySet()) {
            SalesBudget.Report rep = roleReportMap.get(key);
            rep.percentage = rep.target == 0 || rep.invoice == 0 ? 0 : rep.invoice / rep.target;
            rep.lineItems.sort();
            rep.title = String.format('Region {0} GP$ Budget Report', new List<String>{ key });
                    results.reports.add(roleReportMap.get(key));
                }
                
                return results;
            }
            
            /**
             * @description Get Corporate Sales Manager report and all line items for full report
             * @author chrisw@launchdm.com | 05-24-2022
             * @param String range
             * @param String region
             * @param User user
             * @return SalesBudget.ReportResults
             **/
            public static SalesBudget.ReportResults sscManagerReport(String range, String region, User user) {
                SalesBudget.ReportResults results = new SalesBudget.ReportResults();
                SalesBudget.Report report = new SalesBudget.Report();
                String userId = user.Id;
                
                String shQuery =
                    'SELECT Id, Name, NetGP__c, Region__c, Invoice_Date__c FROM SalesHistory__c WHERE Invoice_Date__c = ' +
                    range +
                    ' AND (Inside_Account_Manager__r.ManagerId = :userId OR Outside_Account_Manager__r.ManagerId =: userId)';
                for (SalesHistory__c sale : Database.query(shQuery)) {
                    report.invoice += sale.NetGP__c;
                    report.lineItems.add(new SalesBudget.LineItem(sale.Invoice_Date__c, sale.Name, sale.NetGP__c, 'Internal'));
                }
                
                // String eshQuery =
                //     'SELECT Id, Ext_Id__c, NetGP__c, Invoice_Date__c, Region__c FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
                //     range +
                //     ' AND User__r.ManagerId =: userId';
                // for (External_Sales_History__c externalSales : Database.query(eshQuery)) {
                    //     report.invoice += externalSales.NetGP__c;
                    //     report.lineItems.add(
                    //         new SalesBudget.LineItem(
                    //         externalSales.Invoice_Date__c,
                    //     externalSales.Ext_Id__c,
                    //     externalSales.NetGP__c,
                    //     'External'
                    //         )
                    //         );
                // }
                
                String stQuery =
                    'SELECT Date__c, Region_Number__c, Target_Amount__c, User__c FROM Sales_Target__c WHERE Date__c = ' +
                    range +
                    ' AND User__r.ManagerId =: userId';
                for (Sales_Target__c salesTarget : Database.query(stQuery)) {
                    report.target += salesTarget.Target_Amount__c;
                }
                
                report.percentage = report.target == 0 || report.invoice == 0 ? 0 : report.invoice / report.target;
                Period period = SalesBudgetController.getDateRange(range);
                report.title = String.format(
                    'Region {0} GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                results.title = String.format(
                    'Region {0} GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                results.reports.add(report);
                return results;
            }
            
            /**
             * @description Get Regional Manager report and all line items for full report
             * @author chrisw@launchdm.com | 05-24-2022
             * @param String range
             * @param String region
             * @param User user
             * @return SalesBudget.ReportResults
             **/
            public static SalesBudget.ReportResults regionalManagerReport(String range, String region, User user) {
                SalesBudget.ReportResults results = new SalesBudget.ReportResults();
                SalesBudget.Report report = new SalesBudget.Report();
                String userId = user.Id;
                
                String shQuery =
                    'SELECT Id, Name, NetGP__c, Region__c, Invoice_Date__c FROM SalesHistory__c WHERE Invoice_Date__c = ' +
                    range +
                    ' AND (Region__c =: region)';
                for (SalesHistory__c sale : Database.query(shQuery)) {
                    report.invoice += sale.NetGP__c;
                    report.lineItems.add(new SalesBudget.LineItem(sale.Invoice_Date__c, sale.Name, sale.NetGP__c, 'Internal'));
                }
                
                // String eshQuery =
                //     'SELECT Id, Ext_Id__c, NetGP__c, Invoice_Date__c, Region__c FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
                //     range +
                //     ' AND ((User__c =: userId OR User__r.Region__c =: region OR Region__c =: region))';
                // for (External_Sales_History__c externalSales : Database.query(eshQuery)) {
                    //     report.invoice += externalSales.NetGP__c;
                    //     report.lineItems.add(
                    //         new SalesBudget.LineItem(
                    //         externalSales.Invoice_Date__c,
                    //     externalSales.Ext_Id__c,
                    //     externalSales.NetGP__c,
                    //     'External'
                    //         )
                    //         );
                // }
                
                String stQuery =
                    'SELECT Date__c, Region_Number__c, Target_Amount__c, User__c FROM Sales_Target__c WHERE Date__c = ' +
                    range +
                    ' AND ((User__c =: userId OR User__r.Region__c =: region OR Region_Number__c =: region))';
                for (Sales_Target__c salesTarget : Database.query(stQuery)) {
                    report.target += salesTarget.Target_Amount__c;
                }
                
                report.percentage = report.target == 0 || report.invoice == 0 ? 0 : report.invoice / report.target;
                Period period = SalesBudgetController.getDateRange(range);
                report.title = String.format(
                    'Region {0} GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                results.title = String.format(
                    'Region {0} GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                results.reports.add(report);
                return results;
            }
            
            /**
             * @description Get aggregate totals for reports by user
             * @author chrisw@launchdm.com | 05-22-2022
             * @param String userId
             * @return SalesBudget.ReportResults
             **/
            public static SalesBudget.ReportResults getStandardReportAggregate(User user, String range) {
                System.debug('Method: getStandardReportAggregate');
                SalesBudget.ReportResults results = new SalesBudget.ReportResults();
                SalesBudget.Report report = new SalesBudget.Report();
                String userId = user.Id;
                
                String salesQuery =
                    'SELECT count(id), CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal FROM SalesHistory__c WHERE Invoice_Date__c = ' +
                    range +
                    ' AND (Inside_Account_Manager__c =: userId OR Outside_Account_Manager__c =: userId) GROUP BY CALENDAR_MONTH(Invoice_Date__c) LIMIT 2000';
                for (AggregateResult salesAgg : Database.query(salesQuery)) {
                    Decimal invoiceAmount = (Decimal) salesAgg.get('invoiceTotal') != null ? (Decimal) salesAgg.get('invoiceTotal') : 0;
                    Integer month = (Integer) salesAgg.get('month');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, user.Region__c, ''));
                }
                
                // String extSalesQuery =
                //     'SELECT count(id), CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal  FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
                //     range +
                //     ' AND User__c =: userId GROUP BY CALENDAR_MONTH(Invoice_Date__c) LIMIT 2000';
                // for (AggregateResult exSalesAgg : Database.query(extSalesQuery)) {
                    //     Decimal invoiceAmount = (Decimal) exSalesAgg.get('invoiceTotal') != null ? (Decimal) exSalesAgg.get('invoiceTotal') : 0;
                    //     Integer month = (Integer) exSalesAgg.get('month');
                    //     report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, user.Region__c, ''));
                // }
                
                String targetQuery =
                    'SELECT count(id), CALENDAR_MONTH(Date__c)month, SUM(Target_Amount__c)target FROM Sales_Target__c WHERE User__c =: userId AND Date__c = ' +
                    range +
                    ' GROUP BY CALENDAR_MONTH(Date__c) LIMIT 2000';
                for (AggregateResult targetAgg : Database.query(targetQuery)) {
                    Decimal target = (Decimal) targetAgg.get('target') != null ? (Decimal) targetAgg.get('target') : 0;
                    Integer month = (Integer) targetAgg.get('month');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, 0, target, user.Region__c, ''));
                }
                
                Period period = SalesBudgetController.getDateRange(range);
                report.title = String.format(
                    '{0} \'s GP$ Budget Report {1} to {2}',
                new List<String>{ user.Name, period.StartDate.format(), period.EndDate.format() }
                );
                results.title = String.format(
                    '{0} \'s GP$ Budget Report {1} to {2}',
                new List<String>{ user.Name, period.StartDate.format(), period.EndDate.format() }
                );
                report.grouping = 'month';
                results.reports.add(report);
                return results;
            }
            
            /**
             * @description Get Regional Manager aggregate report
             * @author chrisw@launchdm.com | 05-24-2022
             * @param String range
             * @param String region
             * @param User user
             * @return SalesBudget.ReportResults
             **/
            public static SalesBudget.ReportResults regionalManagerReportAggregate(String range, String region, User user) {
                SalesBudget.ReportResults results = new SalesBudget.ReportResults();
                SalesBudget.Report report = new SalesBudget.Report();
                String userId = user.Id;
                
                String salesQuery =
                    'SELECT count(id), CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal, Customer__r.Region_Number__c userRegion FROM SalesHistory__c WHERE Invoice_Date__c = ' +
                    range +
                    ' AND Region__c =: region GROUP BY CALENDAR_MONTH(Invoice_Date__c), Customer__r.Region_Number__c LIMIT 2000';
                System.debug('salesQuery:' + salesQuery);
                for (AggregateResult salesAgg : Database.query(salesQuery)) {
                    Decimal invoiceAmount = (Decimal) salesAgg.get('invoiceTotal') != null ? (Decimal) salesAgg.get('invoiceTotal') : 0;
                    Integer month = (Integer) salesAgg.get('month');
                    String regionNumber = (String) salesAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, ''));
                }
                // String extSalesQuery =
                //     'SELECT count(id), Region__c, User__r.Region__c userRegion, CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
                //     range +
                //     ' AND (User__c =: userId OR User__r.Region__c =: region OR Region__c =: region) GROUP BY CALENDAR_MONTH(Invoice_Date__c), Region__c, User__r.Region__c LIMIT 2000';
                // System.debug('extSalesQuery:' + extSalesQuery);
                // for (AggregateResult exSalesAgg : Database.query(extSalesQuery)) {
                    //     Decimal invoiceAmount = (Decimal) exSalesAgg.get('invoiceTotal') != null ? (Decimal) exSalesAgg.get('invoiceTotal') : 0;
                    //     Integer month = (Integer) exSalesAgg.get('month');
                    //     String regionNumber = (String) exSalesAgg.get('Region__c') != null
                    //         ? (String) exSalesAgg.get('Region__c')
                    //         : (String) exSalesAgg.get('userRegion');
                    //     report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, ''));
                // }
                
                String targetQuery =
                    'SELECT count(id), Region_Number__c, User__r.Region__c userRegion, CALENDAR_MONTH(Date__c)month, SUM(Target_Amount__c)target FROM Sales_Target__c WHERE (User__c =: userId OR User__r.Region__c =: region OR Region_Number__c =: region)  AND Date__c = ' +
                    range +
                    ' GROUP BY CALENDAR_MONTH(Date__c), Region_Number__c, User__r.Region__c LIMIT 2000';
                System.debug('targetQuery:' + targetQuery);
                for (AggregateResult targetAgg : Database.query(targetQuery)) {
                    Decimal target = (Decimal) targetAgg.get('target') != null ? (Decimal) targetAgg.get('target') : 0;
                    Integer month = (Integer) targetAgg.get('month');
                    String regionNumber = (String) targetAgg.get('Region_Number__c') != null
                        ? (String) targetAgg.get('Region_Number__c')
                        : (String) targetAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, 0, target, regionNumber, ''));
                }
                
                Period period = SalesBudgetController.getDateRange(range);
                report.title = String.format(
                    'Region {0} GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                results.title = String.format(
                    'Region {0} GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                report.grouping = 'month';
                results.reports.add(report);
                return results;
            }
            
            /**
             * @description Get Regional Manager aggregate report
             * @author chrisw@launchdm.com | 05-24-2022
             * @param String range
             * @param String region
             * @param User user
             * @return SalesBudget.ReportResults
             **/
            public static SalesBudget.ReportResults sscManagerReportAggregate(String range, String region, User user) {
                SalesBudget.ReportResults results = new SalesBudget.ReportResults();
                SalesBudget.Report report = new SalesBudget.Report();
                String userId = user.Id;
                
                String salesQuery =
                    'SELECT count(id), CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal, Customer__r.Region_Number__c userRegion FROM SalesHistory__c WHERE Invoice_Date__c = ' +
                    range +
                    ' AND (Inside_Account_Manager__r.ManagerId = :userId OR Outside_Account_Manager__r.ManagerId =: userId) GROUP BY CALENDAR_MONTH(Invoice_Date__c), Customer__r.Region_Number__c LIMIT 2000';
                System.debug('salesQuery:' + salesQuery);
                for (AggregateResult salesAgg : Database.query(salesQuery)) {
                    Decimal invoiceAmount = (Decimal) salesAgg.get('invoiceTotal') != null ? (Decimal) salesAgg.get('invoiceTotal') : 0;
                    Integer month = (Integer) salesAgg.get('month');
                    String regionNumber = (String) salesAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, ''));
                }
                // String extSalesQuery =
                //     'SELECT count(id), Region__c, User__r.Region__c userRegion, CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
                //     range +
                //     ' AND User__r.ManagerId =: userId GROUP BY CALENDAR_MONTH(Invoice_Date__c), Region__c, User__r.Region__c LIMIT 2000';
                // System.debug('extSalesQuery:' + extSalesQuery);
                // for (AggregateResult exSalesAgg : Database.query(extSalesQuery)) {
                    //     Decimal invoiceAmount = (Decimal) exSalesAgg.get('invoiceTotal') != null ? (Decimal) exSalesAgg.get('invoiceTotal') : 0;
                    //     Integer month = (Integer) exSalesAgg.get('month');
                    //     String regionNumber = (String) exSalesAgg.get('Region__c') != null
                    //         ? (String) exSalesAgg.get('Region__c')
                    //         : (String) exSalesAgg.get('userRegion');
                    //     report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, ''));
                // }
                
                String targetQuery =
                    'SELECT count(id), Region_Number__c, User__r.Region__c userRegion, CALENDAR_MONTH(Date__c)month, SUM(Target_Amount__c)target FROM Sales_Target__c WHERE User__r.ManagerId =: userId  AND Date__c = ' +
                    range +
                    ' GROUP BY CALENDAR_MONTH(Date__c), Region_Number__c, User__r.Region__c LIMIT 2000';
                System.debug('targetQuery:' + targetQuery);
                for (AggregateResult targetAgg : Database.query(targetQuery)) {
                    Decimal target = (Decimal) targetAgg.get('target') != null ? (Decimal) targetAgg.get('target') : 0;
                    Integer month = (Integer) targetAgg.get('month');
                    String regionNumber = (String) targetAgg.get('Region_Number__c') != null
                        ? (String) targetAgg.get('Region_Number__c')
                        : (String) targetAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, 0, target, regionNumber, ''));
                }
                
                Period period = SalesBudgetController.getDateRange(range);
                report.title = String.format(
                    'SSC Manager GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                results.title = String.format(
                    'SSC Manager GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                report.grouping = 'month';
                results.reports.add(report);
                return results;
            }
            
            /**
             * @description Get Regional Manager aggregate report
             * @author chrisw@launchdm.com | 05-24-2022
             * @param String range
             * @param String region
             * @param User user
             * @return SalesBudget.ReportResults
             **/
            public static SalesBudget.ReportResults regionalManagerReportAggregateByUser(String range, String region, User user) {
                SalesBudget.ReportResults results = new SalesBudget.ReportResults();
                SalesBudget.Report report = new SalesBudget.Report();
                String userId = user.Id;
                String profileName = 'Cloned Platform User';
                
                String salesQuery =
                    'SELECT count(id), Inside_Account_Manager__r.Name managerName, Customer__r.Name, CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal, Customer__r.Region_Number__c userRegion FROM SalesHistory__c WHERE Invoice_Date__c = ' +
                    range +
                    ' AND Inside_Account_Manager__r.ManagerId = :userId AND Inside_Account_Manager__r.Profile.Name =: profileName  GROUP BY Inside_Account_Manager__r.Name, Customer__r.Name, Customer__r.Region_Number__c, CALENDAR_MONTH(Invoice_Date__c) LIMIT 2000';
                System.debug('salesQuery:' + salesQuery);
                for (AggregateResult salesAgg : Database.query(salesQuery)) {
                    Decimal invoiceAmount = (Decimal) salesAgg.get('invoiceTotal') != null ? (Decimal) salesAgg.get('invoiceTotal') : 0;
                    Integer month = (Integer) salesAgg.get('month');
                    String managerName = (String) salesAgg.get('managerName');
                    String regionNumber = (String) salesAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, managerName));
                }
                // String extSalesQuery =
                //     'SELECT count(id), User__r.Name managerName, Region__c, User__r.Region__c userRegion, CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
                //     range +
                //     ' AND User__r.ManagerId =: userId AND User__r.Profile.Name =: profileName  GROUP BY User__r.Name, Region__c, User__r.Region__c, CALENDAR_MONTH(Invoice_Date__c) LIMIT 2000';
                // System.debug('extSalesQuery:' + extSalesQuery);
                // for (AggregateResult exSalesAgg : Database.query(extSalesQuery)) {
                    //     Decimal invoiceAmount = (Decimal) exSalesAgg.get('invoiceTotal') != null ? (Decimal) exSalesAgg.get('invoiceTotal') : 0;
                    //     Integer month = (Integer) exSalesAgg.get('month');
                    //     String managerName = (String) exSalesAgg.get('managerName');
                    //     String regionNumber = (String) exSalesAgg.get('Region__c') != null
                    //         ? (String) exSalesAgg.get('Region__c')
                    //         : (String) exSalesAgg.get('userRegion');
                    //     report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, managerName));
                // }
                
                String targetQuery =
                    'SELECT count(id), User__r.Name managerName, Region_Number__c, User__r.Region__c userRegion, CALENDAR_MONTH(Date__c)month, SUM(Target_Amount__c)target FROM Sales_Target__c WHERE User__r.ManagerId =: userId AND User__r.Profile.Name =: profileName AND Date__c = ' +
                    range +
                    ' GROUP BY User__r.Name, Region_Number__c, User__r.Region__c, CALENDAR_MONTH(Date__c) LIMIT 2000';
                System.debug('targetQuery:' + targetQuery);
                for (AggregateResult targetAgg : Database.query(targetQuery)) {
                    Decimal target = (Decimal) targetAgg.get('target') != null ? (Decimal) targetAgg.get('target') : 0;
                    Integer month = (Integer) targetAgg.get('month');
                    String managerName = (String) targetAgg.get('managerName');
                    String regionNumber = (String) targetAgg.get('Region_Number__c') != null
                        ? (String) targetAgg.get('Region_Number__c')
                        : (String) targetAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, 0, target, regionNumber, managerName));
                }
                
                Period period = SalesBudgetController.getDateRange(range);
                report.title = String.format(
                    'Region {0} GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                results.title = String.format(
                    'Region {0} GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                report.grouping = 'managerName';
                results.reports.add(report);
                return results;
            }
            
            /**
             * @description Get Regional Manager aggregate report
             * @author chrisw@launchdm.com | 05-24-2022
             * @param String range
             * @param String region
             * @param User user
             * @return SalesBudget.ReportResults
             **/
            public static SalesBudget.ReportResults sscManagerReportAggregateByUser(String range, String region, User user) {
                SalesBudget.ReportResults results = new SalesBudget.ReportResults();
                SalesBudget.Report report = new SalesBudget.Report();
                String userId = user.Id;
                String profileName = 'Cloned Platform User';
                
                String salesQuery =
                    'SELECT count(id), Inside_Account_Manager__r.Name managerName, Customer__r.Name, CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal, Customer__r.Region_Number__c userRegion FROM SalesHistory__c WHERE Invoice_Date__c = ' +
                    range +
                    ' AND Inside_Account_Manager__r.ManagerId = :userId AND Inside_Account_Manager__r.Profile.Name =: profileName GROUP BY Inside_Account_Manager__r.Name, Customer__r.Name, Customer__r.Region_Number__c, CALENDAR_MONTH(Invoice_Date__c) LIMIT 2000';
                System.debug('salesQuery:' + salesQuery);
                for (AggregateResult salesAgg : Database.query(salesQuery)) {
                    Decimal invoiceAmount = (Decimal) salesAgg.get('invoiceTotal') != null ? (Decimal) salesAgg.get('invoiceTotal') : 0;
                    Integer month = (Integer) salesAgg.get('month');
                    String managerName = (String) salesAgg.get('managerName');
                    String regionNumber = (String) salesAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, managerName));
                }
                // String extSalesQuery =
                //     'SELECT count(id), User__r.Name managerName, Region__c, User__r.Region__c userRegion, CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
                //     range +
                //     ' AND User__r.ManagerId =: userId AND User__r.Profile.Name =: profileName GROUP BY User__r.Name, Region__c, User__r.Region__c, CALENDAR_MONTH(Invoice_Date__c) LIMIT 2000';
                // System.debug('extSalesQuery:' + extSalesQuery);
                // for (AggregateResult exSalesAgg : Database.query(extSalesQuery)) {
                    //     Decimal invoiceAmount = (Decimal) exSalesAgg.get('invoiceTotal') != null ? (Decimal) exSalesAgg.get('invoiceTotal') : 0;
                    //     Integer month = (Integer) exSalesAgg.get('month');
                    //     String managerName = (String) exSalesAgg.get('managerName');
                    //     String regionNumber = (String) exSalesAgg.get('Region__c') != null
                    //         ? (String) exSalesAgg.get('Region__c')
                    //         : (String) exSalesAgg.get('userRegion');
                    //     report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, managerName));
                // }
                
                String targetQuery =
                    'SELECT count(id), User__r.Name managerName, Region_Number__c, User__r.Region__c userRegion, CALENDAR_MONTH(Date__c)month, SUM(Target_Amount__c)target FROM Sales_Target__c WHERE User__r.ManagerId =: userId AND User__r.Profile.Name =: profileName  AND Date__c = ' +
                    range +
                    ' GROUP BY User__r.Name, Region_Number__c, User__r.Region__c, CALENDAR_MONTH(Date__c) LIMIT 2000';
                System.debug('targetQuery:' + targetQuery);
                for (AggregateResult targetAgg : Database.query(targetQuery)) {
                    Decimal target = (Decimal) targetAgg.get('target') != null ? (Decimal) targetAgg.get('target') : 0;
                    Integer month = (Integer) targetAgg.get('month');
                    String managerName = (String) targetAgg.get('managerName');
                    String regionNumber = (String) targetAgg.get('Region_Number__c') != null
                        ? (String) targetAgg.get('Region_Number__c')
                        : (String) targetAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, 0, target, regionNumber, managerName));
                }
                
                Period period = SalesBudgetController.getDateRange(range);
                report.title = String.format(
                    'SSC Manager GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                results.title = String.format(
                    'SSC Manager GP$ Budget Report {1} to {2}',
                new List<String>{ region, period.StartDate.format(), period.EndDate.format() }
                );
                report.grouping = 'managerName';
                results.reports.add(report);
                return results;
            }
            
            /**
             * @description Get the aggregate GP$ Budget Report for Regional VPs
             * @author chrisw@launchdm.com | 05-24-2022
             * @param SalesBudget.Report report
             * @param String range
             * @param User user
             * @param Boolean showDetails
             * @return SalesBudget.ReportResults
             **/
            public static SalesBudget.ReportResults getRVPReportAggregate(String range, User user) {
                SalesBudget.ReportResults results = new SalesBudget.ReportResults();
                SalesBudget.Report report = new SalesBudget.Report();
                String userId = user.Id;
                String role = user.UserRole.Name;
                String roleId = user.UserRoleId;
                
                RoleHierarchyUtil.RoleHierarchy roleH = new RoleHierarchyUtil().getSubRoles(new Set<Id>{ roleId }, 1);
                Set<Id> regionIds = roleH.regionIds;
                Set<String> regionNames = roleH.regionNames;
                Set<String> regionNumbers = roleH.regionNumbers;
                
                String salesQuery =
                    'SELECT count(id), CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal, Customer__r.Region_Number__c userRegion FROM SalesHistory__c WHERE Invoice_Date__c = ' +
                    range +
                    ' AND (Region__c IN :regionNumbers)  GROUP BY CALENDAR_MONTH(Invoice_Date__c), Customer__r.Region_Number__c LIMIT 2000';
                for (AggregateResult salesAgg : Database.query(salesQuery)) {
                    Decimal invoiceAmount = (Decimal) salesAgg.get('invoiceTotal') != null ? (Decimal) salesAgg.get('invoiceTotal') : 0;
                    Integer month = (Integer) salesAgg.get('month');
                    String regionNumber = (String) salesAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, ''));
                }
                
                // String extSalesQuery =
                //     'SELECT count(id), Region__c, User__r.Region__c userRegion, CALENDAR_MONTH(Invoice_Date__c)month, SUM(NetGP__c)invoiceTotal FROM External_Sales_History__c WHERE Invoice_Date__c = ' +
                //     range +
                //     ' AND (Region__c IN :regionNumbers OR User__r.Region__c IN :regionNumbers) GROUP BY CALENDAR_MONTH(Invoice_Date__c), Region__c, User__r.Region__c LIMIT 2000';
                // for (AggregateResult exSalesAgg : Database.query(extSalesQuery)) {
                    //     Decimal invoiceAmount = (Decimal) exSalesAgg.get('invoiceTotal') != null ? (Decimal) exSalesAgg.get('invoiceTotal') : 0;
                    //     Integer month = (Integer) exSalesAgg.get('month');
                    //     String regionNumber = (String) exSalesAgg.get('Region__c') != null
                    //         ? (String) exSalesAgg.get('Region__c')
                    //         : (String) exSalesAgg.get('userRegion');
                    //     report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, invoiceAmount, 0, regionNumber, ''));
                // }
                
                String targetQuery =
                    'SELECT count(id), Region_Number__c, User__r.Region__c userRegion, CALENDAR_MONTH(Date__c)month, SUM(Target_Amount__c)target FROM Sales_Target__c WHERE (User__r.Region__c IN :regionNumbers OR Region_Number__c =: regionNumbers) AND Date__c = ' +
                    range +
                    ' GROUP BY CALENDAR_MONTH(Date__c), Region_Number__c, User__r.Region__c LIMIT 2000';
                for (AggregateResult targetAgg : Database.query(targetQuery)) {
                    Decimal target = (Decimal) targetAgg.get('target') != null ? (Decimal) targetAgg.get('target') : 0;
                    Integer month = (Integer) targetAgg.get('month');
                    String regionNumber = (String) targetAgg.get('Region_Number__c') != null
                        ? (String) targetAgg.get('Region_Number__c')
                        : (String) targetAgg.get('userRegion');
                    report.aggregatelineItems.add(new SalesBudget.AgrregateLineItem(month, 0, target, regionNumber, ''));
                }
                
                Period period = SalesBudgetController.getDateRange(range);
                report.title = String.format(
                    '{0}\'s GP$ Budget Report {1} to {2}',
                new List<String>{ user.UserRole.Name, period.StartDate.format(), period.EndDate.format() }
                );
                results.title = String.format(
                    '{0}\'s GP$ Budget Report {1} to {2}',
                new List<String>{ user.UserRole.Name, period.StartDate.format(), period.EndDate.format() }
                );
                results.reports.add(report);
                return results;
            }
            
            /**
             * @description Get dates based on selected range and fiscal information
             * @author chrisw@launchdm.com | 05-24-2022
             * @param String range
             * @return Period
             **/
            public static Period getDateRange(String range) {
                String typeStr = '';
                String rangeStr = '';
                if (range.toLowerCase().contains('quarter')) {
                    typeStr = 'Quarter';
                    rangeStr = 'THIS_QUARTER';
                } else if (range.toLowerCase().contains('month')) {
                    typeStr = 'Month';
                    rangeStr = 'THIS_MONTH';
                } else {
                    typeStr = 'Year';
                    rangeStr = 'THIS_FISCAL_YEAR';
                }
                
                String reportPeriodQuery =
                    'Select p.Type, p.SystemModstamp, p.StartDate, p.QuarterLabel, p.PeriodLabel, p.Number, p.IsForecastPeriod, p.Id, p.FiscalYearSettingsId, p.EndDate From Period p where p.Type =: typeStr AND p.StartDate = ' +
                    rangeStr +
                    ' LIMIT 1';
                return Database.query(reportPeriodQuery);
            }
        }