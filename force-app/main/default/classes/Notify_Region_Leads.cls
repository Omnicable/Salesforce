/**
 * Region lead notifications. Email is sent from an {@code @future} method so delivery is not rolled back
 * when the invoking Flow/transaction fails after this action runs.
 */
public without sharing class Notify_Region_Leads {
    private static final String REGION_LEAD_TEMPLATE_ID = '00Xdy000001cT5FEAU';

    public Notify_Region_Leads() {
    }

    @InvocableMethod(
        label='Notify Region Lead'
        description='Notify Region Leads for Capital Projects and LODs'
        category='Opportunity'
    )
    public static List<OutputClass> notifyLeads(List<OpportunityInput> inputs) {
        List<OutputClass> outputs = new List<OutputClass>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        List<String> oppIdStrings = collectOpportunityIdStrings(inputs);
        if (oppIdStrings.isEmpty()) {
            for (Integer i = 0; i < inputs.size(); i++) {
                outputs.add(new OutputClass(false));
            }
            return outputs;
        }

        sendRegionLeadEmailsAsync(oppIdStrings);

        for (OpportunityInput input : inputs) {
            outputs.add(new OutputClass(input != null && input.recordId != null));
        }
        return outputs;
    }

    /**
     * Sends the region-lead template after commit (via {@code @future}).
     */
    public static void sendEmails(List<OpportunityInput> inputs) {
        List<String> oppIdStrings = collectOpportunityIdStrings(inputs);
        if (!oppIdStrings.isEmpty()) {
            sendRegionLeadEmailsAsync(oppIdStrings);
        }
    }

    @future
    private static void sendRegionLeadEmailsAsync(List<String> opportunityIdStrings) {
        if (opportunityIdStrings == null || opportunityIdStrings.isEmpty()) {
            return;
        }

        // Stored templates used with setTemplateId + setToAddresses require targetObjectId on send.
        // Use renderStoredEmailTemplate(templateId, whoId, whatId) to merge recipient + Opportunity,
        // then deliver to the real inbox with setTreatTargetObjectAsRecipient(false) + setToAddresses.
        List<User> notifyUsers = resolveNotifyUsers();
        if (notifyUsers.isEmpty() || String.isBlank(notifyUsers[0].Email)) {
            System.debug(LoggingLevel.ERROR, 'Notify_Region_Leads: no User/Email for region lead notify');
            return;
        }
        Id notifyUserId = notifyUsers[0].Id;
        String toEmail = notifyUsers[0].Email.trim();
        Id templateId = resolveTemplateId();

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<String> emailContextOppIds = new List<String>();
        for (String sid : opportunityIdStrings) {
            Id oppId = (Id) sid;
            try {
                Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(
                    templateId,
                    notifyUserId,
                    oppId
                );
                email.setTreatTargetObjectAsRecipient(false);
                email.setToAddresses(new List<String>{ toEmail });
                email.setSaveAsActivity(false);
                email.setUseSignature(false);
                emails.add(email);
                emailContextOppIds.add(sid);
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Notify_Region_Leads render failed opp=' + sid + ' ' + e.getMessage()
                );
            }
        }

        if (emails.isEmpty()) {
            return;
        }

        Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                String ctx = i < emailContextOppIds.size() ? emailContextOppIds[i] : String.valueOf(i);
                System.debug(
                    LoggingLevel.ERROR,
                    'Notify_Region_Leads send failed: ' + results[i].getErrors() + ' opp=' + ctx
                );
            }
        }
    }

    private static Id resolveTemplateId() {
        if (Test.isRunningTest()) {
            List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate LIMIT 1];
            if (!templates.isEmpty()) {
                return templates[0].Id;
            }
        }
        return (Id) REGION_LEAD_TEMPLATE_ID;
    }

    private static List<User> resolveNotifyUsers() {
        if (Test.isRunningTest()) {
            return [
                SELECT Id, Email
                FROM User
                WHERE Email != NULL AND IsActive = TRUE
                LIMIT 1
            ];
        }
        return [
            SELECT Id, Email
            FROM User
            WHERE Username = 'launchdm@omnicable.com.partial'
            LIMIT 1
        ];
    }

    private static List<String> collectOpportunityIdStrings(List<OpportunityInput> inputs) {
        List<String> out = new List<String>();
        if (inputs == null) {
            return out;
        }
        for (OpportunityInput input : inputs) {
            if (input != null && input.recordId != null) {
                out.add(String.valueOf(input.recordId));
            }
        }
        return out;
    }

    public class OpportunityInput {
        @InvocableVariable(label='Opportunity Record ID' required=true)
        public Id recordId;

        @InvocableVariable(label='Region Name')
        public String regionName;
    }

    public class OutputClass {
        @InvocableVariable(label='Success')
        public Boolean success;

        public OutputClass() {
            this.success = false;
        }

        public OutputClass(Boolean success) {
            this.success = success;
        }
    }
}