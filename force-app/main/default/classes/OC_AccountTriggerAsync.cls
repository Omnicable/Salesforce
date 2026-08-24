/**
 * @description       : 
 * @author            : chrisw@launchdm.com
 * @last modified on  : 04-30-2022
 * @last modified by  : chrisw@launchdm.com
**/
public class OC_AccountTriggerAsync {
  @future
  public static void updateAccountTeamMember(String accounts) {
    List<Account> accts = (List<Account>) JSON.deserialize(
      accounts,
      List<Account>.class
    );

    try {
      Set<Id> aIds = new Set<Id>();
      Set<String> addedShare = new Set<String>();
      for (Account a : accts) {
        aIds.add(a.Id);
      }
      List<AccountTeamMember> atList = new List<AccountTeamMember>();
      Map<String, AccountShare> asMap = new Map<String, AccountShare>();

      for (AccountShare acs : [
        SELECT Id, UserOrGroupId, AccountId
        FROM AccountShare
        WHERE AccountId IN :aIds AND RowCause != 'Owner'
      ]) {
        asMap.put(acs.AccountId + ':' + acs.UserOrGroupId, acs);
      }
      for (AccountTeamMember at : [
        SELECT Id, UserId, AccountId
        FROM AccountTeamMember
        WHERE AccountId IN :aIds
      ]) {
        //if (asMap.get(at.AccountId+':'+at.UserId)!=null)
        atList.add(at);
      }
      Database.Delete(asMap.values(), false);
      Database.Delete(AtList, false);

      Map<String, List<Id>> uMap = new Map<String, List<Id>>();
      Map<Id, User> uIdMap = new Map<Id, User>();
      for (User u : [
        SELECT Id, Sales_Number__c
        FROM User
        WHERE Sales_Number__c LIKE '___%' AND IsActive = true
      ]) {
        uIdMap.put(u.Id, u);
        String k = u.Sales_Number__c.substring(0, 3);
        List<Id> uL = uMap.get(k);
        if (uL == null) {
          uL = new List<Id>();
          uMap.put(k, uL);
        }
        uL.add(u.Id);
      }
      Map<Integer, List<Id>> regMap = new Map<Integer, List<Id>>();
      for (User u : [
        SELECT Id, Region__c
        FROM User
        WHERE
          Profile.Name = 'Region Mgr Platform'
          AND Region__c != null
          AND IsActive = true
      ]) {
        Integer r = Integer.valueOf(u.Region__c);
        List<Id> uList = regMap.get(r);
        if (uList == null) {
          uList = new List<Id>();
          regMap.put(r, uList);
        }
        uList.add(u.Id);
      }
      AtList.clear();
      List<AccountShare> AsList = new List<AccountShare>();
      Database.SaveResult[] result;
      for (Account a : accts) {
        String k = a.Id;
        system.debug('Outside_Salesperson__c =' + a.Outside_Salesperson__c);
        if (a.Outside_Salesperson__c != null) {
          addedShare.add(k + a.Outside_Salesperson__c);
          AtList.add(
            new AccountTeamMember(
              AccountId = a.Id,
              UserId = a.Outside_Salesperson__c,
              TeamMemberRole = 'Sales Rep'
            )
          );
          AsList.add(
            new AccountShare(
              AccountId = a.Id,
              UserOrGroupId = a.Outside_Salesperson__c,
              OpportunityAccessLevel = 'Edit',
              CaseAccessLevel = 'Edit',
              //ContactAccessLevel='Edit',
              AccountAccessLevel = 'Edit'
            )
          );
        }

		/**Add Account Owner 2 */
		if(a.Account_Owner_2__c != null){
			addedShare.add(k + a.Account_Owner_2__c);
			AtList.add(
				new AccountTeamMember(
				AccountId = a.Id,
				UserId = a.Account_Owner_2__c,
				TeamMemberRole = 'Sales Rep'
				)
			);
			AsList.add(
				new AccountShare(
				  AccountId = a.Id,
				  UserOrGroupId = a.Account_Owner_2__c,
				  OpportunityAccessLevel = 'Edit',
				  CaseAccessLevel = 'Edit',
				  AccountAccessLevel = 'Edit'
				)
			);
		}

    /**Add Account Owner 2 */
		if(a.Agent__c != null){
			addedShare.add(k + a.Agent__c);
			AtList.add(
				new AccountTeamMember(
				AccountId = a.Id,
				UserId = a.Agent__c,
				TeamMemberRole = 'Sales Rep'
				)
			);
			AsList.add(
				new AccountShare(
				  AccountId = a.Id,
				  UserOrGroupId = a.Agent__c,
				  OpportunityAccessLevel = 'Edit',
				  CaseAccessLevel = 'Edit',
				  AccountAccessLevel = 'Edit'
				)
			);
		}

        system.debug('Owner =' + a.OwnerId);
        if (a.OwnerId != null && !addedShare.contains(k + a.OwnerId)) {
          addedShare.add(k + a.OwnerId);
          AtList.add(
            new AccountTeamMember(
              AccountId = a.Id,
              UserId = a.OwnerId,
              TeamMemberRole = 'Sales Rep'
            )
          );
          /*
AsList.add(new AccountShare(AccountId=a.Id,UserOrGroupId=a.OwnerId,
OpportunityAccessLevel='Edit',
CaseAccessLevel='Edit',
//ContactAccessLevel='Edit',
	AccountAccessLevel='Edit'));
*/
        }
        system.debug('Region_Number__c =' + a.Region_Number__c);
        if (a.Region_Number__c != null) {
          Integer r = Integer.valueOf(a.Region_Number__c);
          List<Id> uL = regMap.get(r);
          if (uL != null) {
            for (Id i : uL) {
              if (!addedShare.contains(k + i)) {
                addedShare.add(k + i);
                system.debug('manager ' + i);
                AtList.add(
                  new AccountTeamMember(
                    AccountId = a.Id,
                    UserId = i,
                    TeamMemberRole = 'Regional Manager'
                  )
                );
                AsList.add(
                  new AccountShare(
                    AccountId = a.Id,
                    UserOrGroupId = i,
                    OpportunityAccessLevel = 'Edit',
                    CaseAccessLevel = 'Edit',
                    //ContactAccessLevel='Edit',
                    AccountAccessLevel = 'Edit'
                  )
                );
              }
            }
          }
        }
        User u = uIdMap.get(a.OwnerId);
        if (u != null) {
          List<Id> uL = uMap.get(u.Sales_Number__c.substring(0, 3));
          if (uL != null) {
            for (Id i : uL) {
              if (!addedShare.contains(k + i)) {
                addedShare.add(k + i);
                AtList.add(
                  new AccountTeamMember(
                    AccountId = a.Id,
                    UserId = i,
                    TeamMemberRole = 'Sales Rep'
                  )
                );
                AsList.add(
                  new AccountShare(
                    AccountId = a.Id,
                    UserOrGroupId = i,
                    OpportunityAccessLevel = 'Edit',
                    CaseAccessLevel = 'Edit',
                    //ContactAccessLevel='Edit',
                    AccountAccessLevel = 'Edit'
                  )
                );
              }
            }
          }
        }
        if (AtList.size() > 180) {
          system.debug('AtList = ' + AtList);
          result = Database.Insert(AtList, false);
          system.debug('AsList = ' + AsList);
          result = Database.Insert(AsList, false);
          AtList.clear();
          AsList.clear();
        }
      }
      if (!AtList.isEmpty()) {
        system.debug('AtList = ' + AtList);
        result = Database.Insert(AtList, false);
        system.debug('AsList = ' + AsList);
        result = Database.Insert(AsList, false);
      }
    } catch (Exception e) {
      system.debug('Unhandled exception: ' + e);
    }
  }
}