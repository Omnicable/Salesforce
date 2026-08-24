public class mycontroller2 {
    public string pcontactsIdN { get; set; }
    public integer currentcount { 
	   get {if(currentcount == NULL) currentcount = 15; return currentcount;} set; }
    private Account b;
    public mycontroller2(ApexPages.StandardController stdcontroller) {
    b = (Account)stdController.getRecord();
    }

    //constructor
    public mycontroller2() {}
    
    public List<Contact> getPcons()  {
        Set<Id> ids=new Set<Id>();
        for(Account a : [select id,Name,parentid from Account where (ParentAccount__c=:pcontactsIdN and ParentAccount__c <> '' and
                            ParentAccount__c <> '0')]) {
            ids.add(a.id);    // collect the parentid for each account in a set
        }
    
        //collect the all contacts related to these parent accountid
        List<contact> pcons=[select id,Name,accountId,Account.Name,Active__c,Contact_Title__c,Email,Phone from 
                                contact where Buyer__c='Y' and Account.id in:ids Order by Name Asc LIMIT:currentcount];
        

        return pcons;
    }
    
     // add more contacts to the page  
    public Void AddRows() {  
      currentcount += 25;   
    }  
}