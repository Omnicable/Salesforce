/**
 * @author Chris Williams <chrisw@launchdm.com>
 * @group On Call Notification
 * @since 2026-08-14
 * @description
 * Invocable Flow action that sends weekly on-call notification emails for {@link Event} records.
 *
 * Invoked by the scheduled Flow {@code Weekly_On_Call_Email}. For each
 * {@link WeeklyOnCallNotificationRequest}:
 * <ol>
 *   <li>Loads the {@code New_On_Call_Email} {@link EmailTemplate}</li>
 *   <li>Builds a {@link Messaging.SingleEmailMessage} using the template</li>
 *   <li>Sets TO addresses from optional Flow {@code recipients}, Event owner,
 *       {@code WhoId} Contact, and {@code Name_2__c} User</li>
 *   <li>Sends via {@link Messaging#sendEmail}</li>
 * </ol>
 *
 * Throws {@link AuraHandledException} when the email template is not found.
 *
 * @see WeeklyOnCallNotificationTest
 */
public without sharing class WeeklyOnCallNotification {

    /**
     * @description
     * When {@code true} in tests, {@link #getEmailTemplate} returns {@code null} so missing-template
     * behavior can be asserted without deleting org data.
     */
    @TestVisible
    private static Boolean forceMissingTemplateForTest = false;

    /**
     * @description
     * Invocable entry point that sends weekly on-call notification emails for the given events.
     * Resolves the email template once, then builds and sends one message per request.
     *
     * @param requests Flow inputs, each containing an {@link Event} and optional additional recipients.
     * @return List of {@link WeeklyOnCallNotificationResult} values describing send outcomes
     *         (one result per {@link Messaging.SendEmailResult}).
     */
    @InvocableMethod(
        label='Send Weekly On Call Notification'
        description='Send a weekly on call notification email to all usrs'
        category='On Call'
    )
    public static List<WeeklyOnCallNotificationResult> sendOnCallEmail(List<WeeklyOnCallNotificationRequest> requests) {
        List<WeeklyOnCallNotificationResult> results = new List<WeeklyOnCallNotificationResult>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        EmailTemplate template = getEmailTemplate();
        if (template == null) {
            System.debug('Email template not found');
            throw new AuraHandledException('Email template not found');
        }

        for (WeeklyOnCallNotificationRequest request : requests) {
            Event event = request.event;
            List<String> additionalRecipients =
                request.recipients != null ? request.recipients.split(',') : new List<String>();
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTemplateId(template.Id);
            email.setToAddresses(getToAddresses(event, additionalRecipients));
            email.setTargetObjectId(event.WhoId);
            email.setSaveAsActivity(false);
            emails.add(email);
        }

        if (!emails.isEmpty()) {
            Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(emails);
            for (Messaging.SendEmailResult emailResult : emailResults) {
                WeeklyOnCallNotificationResult result = new WeeklyOnCallNotificationResult();
                System.debug('EMAIL RESULT: ' + emailResult);
                if (!emailResult.isSuccess()) {
                    result.emailErrors.add(emailResult.getErrors().toString());
                    result.errors++;
                    System.debug('ERROR: ' + emailResult.getErrors());
                } else {
                    result.successes++;
                }
                results.add(result);
            }
        }

        return results;
    }

    /**
     * @description
     * Loads the on-call email template by developer name {@code New_On_Call_Email}.
     * Returns {@code null} when {@link #forceMissingTemplateForTest} is {@code true}.
     *
     * @return Matching {@link EmailTemplate}, or {@code null} when none exists / forced missing in tests.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static EmailTemplate getEmailTemplate() {
        if (Test.isRunningTest() && forceMissingTemplateForTest) {
            return null;
        }
        List<EmailTemplate> templates = [
            SELECT Id, Name, Subject, HtmlValue, Body
            FROM EmailTemplate
            WHERE DeveloperName = 'New_On_Call_Email'
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0];
    }

    /**
     * @description
     * Builds the TO address list for one on-call {@link Event}.
     *
     * Combines:
     * <ul>
     *   <li>Additional recipients supplied by Flow ({@link WeeklyOnCallNotificationRequest#recipients})</li>
     *   <li>Event owner ({@code OwnerId}) user email</li>
     *   <li>Related contact ({@code WhoId}) email</li>
     *   <li>Secondary user ({@code Name_2__c}) email</li>
     * </ul>
     *
     * @param event The on-call {@link Event} used to resolve Event-specific recipients.
     * @param additionalRecipients Emails from the request {@code recipients} string (comma-split).
     * @return List of email addresses to notify for this Event.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static List<String> getToAddresses(Event event, List<String> additionalRecipients) {
        List<String> toAddresses = new List<String>();
        toAddresses.addAll(additionalRecipients);

        List<User> owner = [
            SELECT Id, Email
            FROM User
            WHERE Id = :event.OwnerId
            LIMIT 1
        ];
        if (owner?.isEmpty() ? null : owner[0].Email != null) {
            toAddresses.add(owner[0].Email);
        }

        List<Contact> contact = [
            SELECT Id, Email
            FROM Contact
            WHERE Id = :event.WhoId
            LIMIT 1
        ];

        if (contact?.isEmpty() ? null : contact[0].Email != null) {
            toAddresses.add(contact[0].Email);
        }

        List<User> otherUser = [
            SELECT Id, Email
            FROM User
            WHERE Id = :event.Name_2__c
            LIMIT 1
        ];
        if (otherUser?.isEmpty() ? null : otherUser[0].Email != null) {
            toAddresses.add(otherUser[0].Email);
        }

        System.debug('TO ADDRESSES: ' + toAddresses);
        return toAddresses;
    }

    /**
     * @description Flow input payload for {@link #sendOnCallEmail}.
     */
    public class WeeklyOnCallNotificationRequest {
        /**
         * @description The on-call {@link Event} to send a notification for.
         */
        @InvocableVariable(
            label='Weekly On Call Notification Events'
            description='The events to send the weekly on call notification email'
            required=true
        )
        public Event event;

        /**
         * @description
         * Optional comma-separated email addresses added to the TO list in addition to
         * owner, {@code WhoId} Contact, and {@code Name_2__c} User.
         */
        @InvocableVariable(
            label='Additional Recipients'
            description='Comma separated list of email addresses to add to the recipients list in addition to the owner, contact, and secondary user'
            required=false
        )
        public String recipients;
    }

    /**
     * @description Flow output payload summarizing email send results for a request.
     */
    public class WeeklyOnCallNotificationResult {
        /** @description Error messages returned by failed {@link Messaging.SendEmailResult} entries. */
        @InvocableVariable(label='Email Errors')
        public List<String> emailErrors = new List<String>();

        /** @description Count of successfully sent emails. */
        @InvocableVariable(label='Email Successes')
        public Integer successes = 0;

        /** @description Count of failed email sends. */
        @InvocableVariable(label='Email Results')
        public Integer errors = 0;
    }
}