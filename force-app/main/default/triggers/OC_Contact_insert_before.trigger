trigger OC_Contact_insert_before on Contact (before insert, before update) {
	Set<Id> aIdSet = new Set<Id>();
	Map<Id,List<Contact>> acMap = new Map<Id,List<Contact>>();
	for (Contact c : Trigger.new ) {
		System.debug('c: ' + c);
		if ( c.AccountId != null && c.Sequence__c == null ) {
			List<Contact> cList = acMap.get(c.AccountId);
			if (cList == null) {
				cList = new List<Contact>();
				acMap.put(c.Accountid,cList);
			}
			cList.add(c);
		}
	}
	if ( ! acMap.isEmpty() ) {
		Map<Id,Account> aMap = new Map<Id,Account>([select Id,Account_Number__c from Account where Id in :acMap.keySet()]);
		Map<Id,Decimal> sMap = new Map<Id,Decimal>();
		for (AggregateResult ar : [select AccountId,max(Sequence__c) MS from Contact where AccountId in :acMap.keySet() and Sequence__c<>null group by AccountId]) {
			sMap.put((Id)ar.get('AccountId'),(Decimal)ar.get('MS'));
		}
		for (Id aId : acMap.keySet()) {
			Account a = aMap.get(aId);
			String an = a.Account_Number__c;
			if ( an==null ) an = a.Id;
			Decimal i = sMap.get(aId);
			if ( i==null) i=0;
			for (Contact c : acMap.get(aId)) {
				c.Sequence__c = ++i;
				c.Ext_Id__c = an+':'+i;
				System.debug('c_updated_sequence: ' + c);
			}
		}
	}
}