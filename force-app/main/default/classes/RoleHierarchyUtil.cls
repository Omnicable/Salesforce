/**
 * @description       : 
 * @author            : chrisw@launchdm.com
 * @group             : 
 * @last modified on  : 05-25-2022
 * @last modified by  : chrisw@launchdm.com
**/
public class RoleHierarchyUtil {

    public class RoleHierarchy{
        public Set<Id> regionIds = new Set<Id>();
        public Set<String> regionNames = new Set<String>();
        public Set<String> regionNumbers = new Set<String>();
    }

    String regex = '[a-zA-Z]{1,}|\\-';

    Set<Id> allSubRoles = new Set<Id>();

    public RoleHierarchy getSubRoles(Set<Id> roleIds, Integer maxLevel){

        for (Id roleId : roleIds) {
            if(!this.allSubRoles.contains(roleId)){
                this.allSubRoles.add(roleId);
            }
        }

        Map<ID, UserRole> childRoles = new Map<ID, UserRole>([SELECT Id, Name FROM UserRole WHERE (NOT Name LIKE '%User')  AND ParentRoleId IN: roleIds]);
        
        this.allSubRoles.addAll(childRoles.keySet());

        if(childRoles.size() != 0){
            this.getSubRoles(childRoles.keySet(), maxLevel++ );
        }


        RoleHierarchy results = new RoleHierarchy();
        results.regionIds = this.allSubRoles;

        For (UserRole role : [SELECT Id, Name FROM UserRole WHERE Id In: this.allSubRoles]){
            results.regionNames.add(role.Name);
        
            String regionNum = role.Name.replaceAll(regex, '').trim();
            if(regionNum != ''){
                results.regionNumbers.add(role.Name.replaceAll(regex, '').trim());
            }
        }

        System.debug('ALL ROLE DATA: ' + JSON.serialize(results));
        
        return results;

    }
}