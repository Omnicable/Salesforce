/**
 * @description       : Send pricebook attachment emails
 * @author            : chrisw@launchdm.com
 * @group             : PriceSheet
 * @last modified on  : 02-07-2023
 * @last modified by  : chrisw@launchdm.com
 **/
global class PriceBookEmailBatchController implements Database.Batchable<sObject>, Database.Stateful {
    class PriceBookAttachment {
        String title;
        Blob pdf;
        Blob csv;
    }

    global Map<String, PriceBookAttachment> pdfMap = new Map<String, PriceBookAttachment>();
    global Map<String, List<Contact>> accountContactMap = new Map<String, List<Contact>>();
    global OrgWideEmailAddress orgWideEmailAddress = new OrgWideEmailAddress();
    global boolean shouldSend;

    global PriceBookEmailBatchController() {
        List<OrgWideEmailAddress> addresses = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE DisplayName = 'OmniCable Sales'
        ];
        if (addresses.size() > 0) {
            this.orgWideEmailAddress = addresses.get(0);
        }
    }
    global Database.QueryLocator start(Database.BatchableContext bc) {
        /** Double check to see if today is a weekday */
        this.shouldSend = PriceSheetController.shouldSendEmailToday();
        Integer day = Date.today().day();
        String query = 'SELECT Id, Price_Book_Approval__c, Price_Book_Approval__r.Name, Price_Book_Approval__r.Price_Book__c, Price_Book_Approval__r.From_User__r.Name, Price_Book_Approval__r.From_User__r.Email, Account__c, Account__r.Name, Account__r.Price_Book_Email_Day__c, Account__r.Owner.Email FROM PB_Account_Link__c WHERE Active__c = true AND  Price_Book_Approval__r.Status__c = \'Approved\' AND (Account__r.Price_Book_Email_Day__c = :day OR Delayed_Email__c = true) ORDER BY Account__c';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<PB_Account_Link__c> accounts) {
        if (this.shouldSend) {
            List<String> pbaIds = new List<String>();
            List<String> accountIds = new List<String>();
            Map<String, String> sentFromMap = new Map<String, String>();

            for (PB_Account_Link__c link : accounts) {
                pbaIds.add(link.Price_Book_Approval__c);
                accountIds.add(link.Account__c);
            }

            this.buildPriceBookMap(pbaIds);
            this.buildContactMap(accountIds);

            List<Attachment> attachments = new List<Attachment>();
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

            for (PB_Account_Link__c link : accounts) {
                link.Delayed_Email__c = false;
                link.Last_Email_Sent__c = DateTime.now();
                List<Contact> contacts = accountContactMap.get(link.Account__c);
                if (contacts != null && contacts.size() > 0) {
                    //TODO: Update name with date
                    PriceBookAttachment attachment = pdfMap.get(link.Price_Book_Approval__c);
                    Attachment pdfAttachment = new Attachment(
                        Body = attachment.pdf,
                        Name = attachment.title + '.pdf',
                        ContentType = 'application/pdf',
                        IsPrivate = false,
                        ParentId = link.Account__c 
                    );
                    Attachment csvAttachment = new Attachment(
                        Body = attachment.csv,
                        Name = attachment.title + '.csv',
                        ContentType = 'text/csv',
                        IsPrivate = false,
                        ParentId = link.Account__c
                    );
                    attachments.add(pdfAttachment);
                    attachments.add(csvAttachment);

                    for (Contact c : contacts) {
                        sentFromMap.put(c.Id, link.Price_Book_Approval__r.From_User__c);
                        Messaging.SingleEmailMessage email = this.buildEmailTemplate(link, c, attachment);
                        emails.add(email);
                    }

                    
                } else {
                    System.debug('No Contacts for Account ' + link.Account__c);
                }
            }

            try {
                Messaging.reserveSingleEmailCapacity(emails.size());
                insert attachments;
                update accounts;
                Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(emails, false);
                this.buildEmailReport(emailResults, emails, sentFromMap);
            } catch (Exception e) {

                for (PB_Account_Link__c link : accounts) {
                    link.Delayed_Email__c = true;
                    link.Delayed_Reason__c = e.getMessage();
                }

                update accounts;
            }
        } else {

            try{

                for (PB_Account_Link__c link : accounts) {
                    link.Delayed_Email__c = true;
                    link.Delayed_Reason__c = 'Weekend';
                }
    
                update accounts;

            }catch(Exception e){
                String body = 'Error: ' + e.getStackTraceString() + '\n' + 'Accounts: ' + JSON.serialize(accounts);
                this.sendEmailError(body);
            }

            
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('PriceBookEmailBatchController Complete');
    }

    /**
     * @description create a pricebook email report for all outgoing emails for a given day
     * @author chrisw@launchdm.com | 02-04-2023
     * @param Messaging.SendEmailResult[] results
     * @param List<Messaging.SingleEmailMessage> emails
     **/
    public void buildEmailReport(
        Messaging.SendEmailResult[] results,
        List<Messaging.SingleEmailMessage> emails,
        Map<String, String> sentFromMap
    ) {
        try {
            List<Contact> contactErrors = new List<Contact>();

            Datetime now = Datetime.now();
            Integer offset = UserInfo.getTimezone().getOffset(now);
            Datetime local = now.addSeconds(offset / 1000);

            Price_Book_Email_Report__c report = new Price_Book_Email_Report__c(
                Name = 'Email Report: ' + System.now().format('MM/dd/yyyy h:mm:ss a')
            );
            insert report;

            List<Price_Book_Email_Item__c> items = new List<Price_Book_Email_Item__c>();

            for (Integer i = 0; i < results.size(); i++) {
                Price_Book_Email_Item__c item = new Price_Book_Email_Item__c(
                    Price_Book_Email_Report__c = report.Id,
                    Contact__c = emails.get(i).targetobjectid,
                    From_User__c = sentFromMap.get(emails.get(i).targetobjectid)
                );
                Messaging.SendEmailResult res = results.get(i);
                if (res.isSuccess()) {
                    item.Success__c = true;
                    item.Message__c = 'Sent';
                } else {
                    item.Success__c = false;
                    item.Message__c = '';
                    for (Messaging.SendEmailError error : res.getErrors()) {
                        item.Message__c += error.getMessage() + ' ';
                    }
                }
                items.add(item);
            }
            insert items;
        } catch (Exception e) {
            System.debug(e.getStackTraceString());
        }
    }

    /**
     * @description build map of price books and attachment for use in execution method
     * @author chrisw@launchdm.com | 08-23-2022
     * @param List<String> pbaIds
     **/
    public void buildPriceBookMap(List<String> pbaIds) {
        List<String> pbIds = new List<String>();
        for (AggregateResult ar : [
            SELECT count(Id), Price_Book_Approval__c
            FROM PB_Account_Link__c
            WHERE Price_Book_Approval__c IN :pbaIds
            GROUP BY Price_Book_Approval__c
        ]) {
            String pbaId = (String) ar.get('Price_Book_Approval__c');
            if (pdfMap.get(pbaId) == null) {
                PageReference pdf = Page.PriceBookAttachmentPDF;
                pdf.getParameters().put('id', (String) pbaId);
                pdf.setRedirect(true);

                PageReference csv = Page.PriceBookAttachmentExcel;
                csv.getParameters().put('id', (String) pbaId);
                csv.setRedirect(true);

                DateTime dt = DateTime.now();
                String monthYear = dt.format('MMMM yyyy');

                PriceBookAttachment attachment = new PriceBookAttachment();

                if (!Test.isRunningTest()) {
                    Blob csvBlob = csv.getContent();
                    Blob pdfBlob = pdf.getContent();
                    attachment.pdf = pdfBlob;
                    attachment.csv = csvBlob;
                } else {
                    attachment.pdf = Blob.valueof('1');
                    attachment.csv = Blob.valueof('2');
                }

                attachment.title = monthYear + ' Price Sheet';
                pdfMap.put(pbaId, attachment);
            }
        }
    }

    /**
     * @description build map of contacts and account ids for use in the execute method
     * @author chrisw@launchdm.com | 08-23-2022
     * @param List<String> accountIds
     **/
    public void buildContactMap(List<String> accountIds) {
        for (Account a : [
            SELECT Id, Name, (SELECT Id, Name, Email, DSP_Purchaser__c FROM Contacts WHERE DSP_Purchaser__c = true)
            FROM Account
            WHERE Id IN :accountIds
        ]) {
            accountContactMap.put(a.Id, a.Contacts);
        }
    }

    public Messaging.SingleEmailMessage buildEmailTemplate(PB_Account_Link__c link, Contact c, PriceBookAttachment attachment) {
        EmailTemplate template = [
            SELECT Id, Subject, Description, HtmlValue, DeveloperName, Body
            FROM EmailTemplate
            WHERE name = 'PriceBookAttachmentEmail'
        ];
        DateTime dt = DateTime.now();
        String monthYear = dt.format('MMMM yyyy');
        Messaging.EmailFileAttachment pdf = new Messaging.EmailFileAttachment();
        Messaging.EmailFileAttachment csv = new Messaging.EmailFileAttachment();
        pdf.setFileName(monthYear + ' Price Sheet.pdf');
        pdf.setBody(attachment.pdf);
        csv.setFileName(monthYear + ' Price Sheet.csv');
        csv.setBody(attachment.csv);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTemplateID(template.Id);
        if (this.orgWideEmailAddress != null) {
            mail.setOrgWideEmailAddressId(this.orgWideEmailAddress.Id);
        }
        mail.setReplyTo(link.Price_Book_Approval__r.From_User__r.Email);
        // mail.setSenderDisplayName(link.Price_Book_Approval__r.From_User__r.Name);
        mail.setCcAddresses(new List<String>{ link.Price_Book_Approval__r.From_User__r.Email, link.Account__r.Owner.Email });
        mail.setWhatId(link.Price_Book_Approval__c);
        mail.setTargetObjectId(c.Id);
        mail.setSubject(monthYear + ' Price Sheet');
        mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ pdf, csv });
        mail.setHtmlBody(template.HtmlValue);
        mail.setTreatBodiesAsTemplate(true);

        return mail;
    }

    public void sendEmailError(String body){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject('Error updating weekend price books');
        String[] toAddress = new String[]{'chrisw@launchdm.com'};
        mail.setToAddresses(toAddress);
        mail.setPlainTextBody(body);
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        emails.add(mail);
        Messaging.sendEmail(emails, false);

    }
}