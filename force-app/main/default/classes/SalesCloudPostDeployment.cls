/**
 * @description Stateful batch utility for post-deployment data maintenance on integration objects in a
 *              {@code CreatedDate} window. Queries {@link QuotesOrdersCredits_Header__c},
 *              {@link QuoteOrderCredit_Details__c}, or {@link Part_Numbers__c} by Id and creation date, then
 *              bulk-updates, bulk-deletes, or counts rows for dry-run verification ({@code test} action).
 *              <p>
 *              Intended for one-off sandbox cleanup, redeploy touch-ups, or validating row counts before DML.
 *              Not wired to platform events or sync classes; run manually via {@code Database.executeBatch}.
 *              </p>
 * @see QOCUpdateBulk
 */
public  class SalesCloudPostDeployment implements Database.Batchable<SObject>, Database.Stateful {
    
    /**
     * @description {@link OpportunityTeamMember#OpportunityAccessLevel} for read/write team access.
     */
    private static final String OPPORTUNITY_TEAM_ACCESS_EDIT = 'Edit';
    
    /**
     * @description Opportunity user lookup fields mapped to {@link OpportunityTeamMember#TeamMemberRole}.
     */
    private static final Map<String, String> OPPORTUNITY_TEAM_FIELD_TO_ROLE = new Map<String, String>{
        'Agent__c' => 'Agent',
        'Capital_Projects_Sales_Specialist__c' => 'Capital Projects Sales Specialist',
        'Entered_By__c' => 'Entered By',
        'Inside_AM__c' => 'Inside AM',
        'Outside_AM__c' => 'Outside AM',
        'Quotation_Specialist__c' => 'Quotation Specialist'
    };

    /**
     * @description {@link UserLicense} names eligible for {@link OpportunityTeamMember} rows in this org.
     */
    private static final Set<String> ELIGIBLE_TEAM_MEMBER_LICENSES = new Set<String>{
        'Salesforce',
        'Salesforce Platform'
    };
    
    /**
     * @description Inclusive lower bound for {@code CreatedDate} filtering in {@link #start}.
     */
    private Date startDate;
    
    /**
     * @description Exclusive upper bound for {@code CreatedDate} filtering in {@link #start}.
     */
    private Date endDate;
    
    /**
     * @description Sample row whose {@link SObject#getSObjectType()} selects the target object in {@link #start}.
     */
    private sObject recordType;
    
    /**
     * @description Batch action: {@code update}, {@code delete}, {@code addMembers}, or {@code test} (count-only, no DML).
     */
    private String action;
    
    /**
     * @description Running total of rows processed when {@link #action} is {@code test}; logged in {@link #finish}.
     */
    Integer total = 0;
    
    /**
     * @description Captures the date range, target object type, and maintenance action for the batch run.
     * @param startDate  Inclusive {@code CreatedDate} lower bound.
     * @param endDate    Exclusive {@code CreatedDate} upper bound.
     * @param recordType Any row instance whose type is {@link QuotesOrdersCredits_Header__c},
     *                   {@link QuoteOrderCredit_Details__c}, or {@link Part_Numbers__c}.
     * @param action     {@code update}, {@code delete}, or {@code test}.
     */
    public SalesCloudPostDeployment(Date startDate, Date endDate, sObject recordType, String action) {
        this.startDate = startDate;
        this.endDate = endDate;
        this.recordType = recordType;
        this.action = action;
    }
    
    /**
     * @description Returns a query locator for Ids in the configured date range on the constructor target type.
     * @param bc Batch context supplied by the platform.
     * @return Query locator for headers, details, or parts; empty query when the type is unrecognized.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (recordType.getSObjectType() == Schema.QuotesOrdersCredits_Header__c.SObjectType) {
            return Database.getQueryLocator([
                SELECT Id, CreatedDate
                FROM QuotesOrdersCredits_Header__c
                WHERE CreatedDate >= :startDate AND CreatedDate < :endDate
            ]);
        } else if (recordType.getSObjectType() == Schema.QuoteOrderCredit_Details__c.SObjectType) {
            return Database.getQueryLocator([
                SELECT Id, CreatedDate
                FROM QuoteOrderCredit_Details__c
                WHERE CreatedDate >= :startDate AND CreatedDate < :endDate
            ]);
        } else if (recordType.getSObjectType() == Schema.Part_Numbers__c.SObjectType) {
            return Database.getQueryLocator([
                SELECT Id, CreatedDate
                FROM Part_Numbers__c
                WHERE CreatedDate >= :startDate AND CreatedDate < :endDate and Item_Number__c != null
            ]);
        } else if (recordType.getSObjectType() == Schema.Opportunity_Sync_Item__c.SObjectType) {
            return Database.getQueryLocator([
                SELECT Id, CreatedDate
                FROM Opportunity_Sync_Item__c
                WHERE CreatedDate >= :startDate AND CreatedDate < :endDate
            ]);
        } else if (recordType.getSObjectType() == Schema.Opportunity.SObjectType) {
            return Database.getQueryLocator([
                SELECT
                    Id,
                    CreatedDate,
                    Agent__c,
                    Capital_Projects_Sales_Specialist__c,
                    Entered_By__c,
                    Inside_AM__c,
                    Outside_AM__c,
                    Quotation_Specialist__c
                FROM Opportunity
                WHERE CreatedDate >= :startDate AND CreatedDate < :endDate
                ORDER BY CloseDate DESC
            ]);
        }else {
            return Database.getQueryLocator('SELECT Id FROM Part_Numbers__c WHERE Id = null');
        }
    }
    
    /**
     * @description Applies {@link #action} to one batch chunk: update, delete, or test (accumulate {@link #total} only).
     * @param bc    Batch context supplied by the platform.
     * @param scope Chunk of rows from {@link #start}.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        total += scope.size();
        
        if (action == 'update') {
            update scope;
        } else if (action == 'delete') {
            delete scope;
        } else if (action == 'test') {
            System.debug('scope: ' + scope);
        }else if (action == 'addMembers') {
            addOpportunityMembers(scope);
        }
    }
    
    /**
     * @description Adds eligible users from configured Opportunity lookup fields to each opportunity team with
     *              read/write ({@code Edit}) access. Only active Standard users with a Salesforce CRM license are
     *              added; skips users already on the team.
     * @param scope Opportunity rows from {@link #start}, including team-member lookup fields.
     */
    public static void addOpportunityMembers(List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }
        
        Set<Id> opportunityIds = new Set<Id>();
        Map<String, OpportunityTeamMember> membersByOppAndUser = new Map<String, OpportunityTeamMember>();
        
        try{
            
            for (SObject row : scope) {
                Opportunity opportunity = (Opportunity) row;
                if (opportunity.Id == null) {
                    continue;
                }
                opportunityIds.add(opportunity.Id);
                
                for (String fieldName : OPPORTUNITY_TEAM_FIELD_TO_ROLE.keySet()) {
                    Id userId = (Id) opportunity.get(fieldName);
                    if (userId == null) {
                        continue;
                    }
                    String memberKey = opportunityTeamMemberKey(opportunity.Id, userId);
                    if (membersByOppAndUser.containsKey(memberKey)) {
                        continue;
                    }
                    membersByOppAndUser.put(
                        memberKey,
                    new OpportunityTeamMember(
                        OpportunityId = opportunity.Id,
                    UserId = userId,
                    TeamMemberRole = OPPORTUNITY_TEAM_FIELD_TO_ROLE.get(fieldName),
                    OpportunityAccessLevel = OPPORTUNITY_TEAM_ACCESS_EDIT
                        )
                        );
                }
            }
            
            if (membersByOppAndUser.isEmpty()) {
                return;
            }
            
            Set<Id> userIds = new Set<Id>();
            for (OpportunityTeamMember member : membersByOppAndUser.values()) {
                userIds.add(member.UserId);
            }
            
            Set<String> existingMemberKeys = new Set<String>();
            for (OpportunityTeamMember existingMember : [
        SELECT OpportunityId, UserId
        FROM OpportunityTeamMember
        WHERE OpportunityId IN :opportunityIds AND UserId IN :userIds
    ]) {
                existingMemberKeys.add(opportunityTeamMemberKey(existingMember.OpportunityId, existingMember.UserId));
            }
            
            Set<Id> eligibleUserIds = getEligibleTeamMemberUserIds(userIds);

            List<OpportunityTeamMember> membersToInsert = new List<OpportunityTeamMember>();
            for (String memberKey : membersByOppAndUser.keySet()) {
                if (existingMemberKeys.contains(memberKey)) {
                    continue;
                }
                OpportunityTeamMember member = membersByOppAndUser.get(memberKey);
                if (!eligibleUserIds.contains(member.UserId)) {
                    continue;
                }
                membersToInsert.add(member);
            }
            
            if (!membersToInsert.isEmpty()) {
                Database.insert(membersToInsert, false);
            }
            
        }catch(Exception e) {
            System.debug('addOpportunityMembers error: ' + e.getMessage());
            System.debug('addOpportunityMembers error: ' + e.getStackTraceString());
        }
        
        
    }
    
    /**
     * @description Resolves active Standard users with an eligible Salesforce license from the candidate set.
     * @param userIds Distinct user Ids referenced on Opportunity team-member lookup fields.
     * @return User Ids that may be added as {@link OpportunityTeamMember} rows.
     */
    private static Set<Id> getEligibleTeamMemberUserIds(Set<Id> userIds) {
        Set<Id> eligibleUserIds = new Set<Id>();
        if (userIds == null || userIds.isEmpty()) {
            return eligibleUserIds;
        }
        for (User u : [
            SELECT Id
            FROM User
            WHERE Id IN :userIds
                AND IsActive = true
                AND UserType = 'Standard'
                AND Profile.UserLicense.Name IN :ELIGIBLE_TEAM_MEMBER_LICENSES
        ]) {
            eligibleUserIds.add(u.Id);
        }
        return eligibleUserIds;
    }

    /**
     * @description Stable composite key for an opportunity/user team-member pair.
     * @param opportunityId Opportunity Id.
     * @param userId        User Id.
     * @return String key of the form {@code "<opportunityId>#<userId>"}.
     */
    private static String opportunityTeamMemberKey(Id opportunityId, Id userId) {
        return String.valueOf(opportunityId) + '#' + String.valueOf(userId);
    }
    
    /**
     * @description Batch completion hook; logs {@link #total} when {@link #action} is {@code test}.
     * @param bc Batch context supplied by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('SalesCloudPostDeployment total: ' + total);
    }
    
    public static void scheduleSync() {
        String suffix = Test.isRunningTest() ? String.valueOf(Datetime.now().getTime()) : '';
        
        System.schedule('OpportunitySyncScheduler 00' + suffix, '0 00 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 05' + suffix, '0 05 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 10' + suffix, '0 10 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 15' + suffix, '0 15 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 20' + suffix, '0 20 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 25' + suffix, '0 25 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 30' + suffix, '0 30 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 35' + suffix, '0 35 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 40' + suffix, '0 40 * * * ?', new OpportunitySyncScheduler());
        System.schedule('OpportunitySyncScheduler 45' + suffix, '0 45 * * * ?', new OpportunitySyncScheduler());
        
        
        System.schedule('OpportunityDetailSyncScheduler 03' + suffix, '0 03 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 08' + suffix, '0 08 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 13' + suffix, '0 13 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 18' + suffix, '0 18 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 23' + suffix, '0 23 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 28' + suffix, '0 28 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 33' + suffix, '0 33 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 38' + suffix, '0 38 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 43' + suffix, '0 43 * * * ?', new OpportunityLineSyncScheduler());
        System.schedule('OpportunityDetailSyncScheduler 48' + suffix, '0 48 * * * ?', new OpportunityLineSyncScheduler());
    }
}