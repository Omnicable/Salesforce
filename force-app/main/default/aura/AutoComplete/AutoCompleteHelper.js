({
    doInit : function(cmp, event, helper){
        cmp.set('v.isLoading', true);
        var recordId = cmp.get('v.recordId');
        var action = cmp.get("c.getPriceBookApprovalById");
        action.setParams({ "recordId" : recordId });
        action.setCallback(this,function(response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                let data = response.getReturnValue();
                switch (data.Type__c) {
                    case 'Buying Group':
                        cmp.set('v.valueFieldApiName', 'Buying_Group__c');
                        cmp.set('v.label', 'Search Buying Groups');
                        cmp.set('v.inputValue', data[cmp.get('v.valueFieldApiName')] || "");
                        break;
                    case 'Company':
                        cmp.set('v.valueFieldApiName', 'Company_Name__c');
                        cmp.set('v.label', 'Search Companies');
                        cmp.set('v.inputValue', data[cmp.get('v.valueFieldApiName')] || "");
                        break;
                    case 'Region':
                        cmp.set('v.valueFieldApiName', 'Region_Number__c');
                        cmp.set('v.label', 'Search Regions');
                        cmp.set('v.inputValue', data[cmp.get('v.valueFieldApiName')] || "");
                        break;
                    case 'Accounts':
                        cmp.set('v.valueFieldApiName', 'Name');
                        cmp.set('v.label', 'Search Accounts');
                        break;
                }
                
                cmp.set('v.typeLabel', data.Type__c);
                cmp.set('v.pba', data);
                this.setDefaultAccounts(cmp);
                
            } else{
                let message = response.getError()[0].message;
                this.showToast(cmp, 'error', 'Error', message);
        
            }

        });
        $A.enqueueAction(action);
    },
    evaluateStatus : function(cmp){
        let type = cmp.get('v.typeLabel');
        let status = cmp.get('v.pba').Status__c;
        let disabled = false;
        
        if(type == 'Accounts'){
            let selectedValue = cmp.get('v.selectedValue');
            disabled = selectedValue == '' || status == 'Pending' || status == 'Approved' ? true : false;
        }else{
            let selectedAccounts = cmp.get('v.selectedAccounts');
            disabled = selectedAccounts.length == 0 || status == 'Pending' || status == 'Approved' ? true : false;
        }

       cmp.set('v.editDisabled', disabled);
    },
    initColumns : function(cmp){
        var actions = [
            { label: 'Remove Account', name: 'delete' },
        ]
        this.getAccountColumns(cmp, 'v.columns', actions);

        

        // cmp.set('v.columns', [
        //     {label: 'Name', fieldName: 'AccountUrl', type: 'url', width: 'auto' ,typeAttributes:{
        //         label: {
        //             fieldName: 'Name'
        //         },
        //         target: '_blank'
        //     }},
        //     { label: 'Active', fieldName: 'Active__c', type: 'boolean', sortable: true, editable:false, width: 'auto', initialWidth: 100 },
        //     { label: 'Status', fieldName: 'Status__c', type: 'text', sortable: true, editable:false, width: 'auto' },
        //     { label: 'Last Email Date', fieldName: 'Last_Email_Sent__c', type: 'date', sortable: true, editable:false, width: 'auto' ,  initialWidth: 150, typeAttributes: {
        //         day: 'numeric',
        //         month: 'short',
        //         year: 'numeric',
        //         hour: '2-digit',
        //         minute: '2-digit',
        //         second: '2-digit',
        //         hour12: true
        //       }},
        //     { label: 'Email Day', fieldName: 'Email_Day__c', type: 'number', sortable: true, editable:true, width: 'auto', initialWidth: 100 },
        //     { type: 'action', typeAttributes: { rowActions: actions } },
        // ])
    },
    setDefaultAccounts : function(cmp){
        let data = cmp.get('v.pba');
        //TODO: get this to works with set selected
        let selectedAccounts = [];
        if(data.Price_Book_Links__r != null){
            data.Price_Book_Links__r.forEach(accountLink => {
                accountLink.AccountUrl = '/lightning/r/Account/' + accountLink.Account__c +'/view';
                selectedAccounts.push(accountLink);
            });
            cmp.set('v.selectedAccounts', selectedAccounts);
            cmp.set('v.isSaved', true);
        }
    },
    setSelectedAccounts : function(cmp, searchResults){
        let selectedAccounts = cmp.get('v.selectedAccounts');
        searchResults.forEach(o1 => {
            let index = selectedAccounts.findIndex(x => x.Account__c == o1.Id ||  x.Id == o1.Id);
            o1.added = index == -1 ? false : true;
        });
        cmp.set('v.results', searchResults);
    },
    searchAccounts : function(cmp, searchString){
        cmp.set('v.isSearching', true);
        var action = cmp.get("c.getAccounts");
        action.setParams({
            "searchString" : searchString
        });
        action.setCallback(this,function(response) {
            
            var state = response.getState();
            if (state === "SUCCESS") {
                const serverResult = response.getReturnValue();
                // cmp.set("v.results", serverResult);
                this.setSelectedAccounts(cmp, serverResult);
                if(serverResult.length>0){
                    cmp.set("v.openDropDown", true);
                    cmp.set("v.noResults", false);
                }else{
                    cmp.set("v.noResults", true);
                }
            } else{
                this.showToast(cmp, 'Error', 'error', 'something went wrong');
            }

            cmp.set('v.isSearching', false);
        });
        $A.enqueueAction(action);
    },
    searchRecords : function(cmp, searchString) {
        
        cmp.set('v.isSearching', true);
        var action = cmp.get("c.getRecords");
        action.setParams({
            "searchString" : searchString,
            "objectApiName" : cmp.get("v.objectApiName"),
            "idFieldApiName" : cmp.get("v.idFieldApiName"),
            "valueFieldApiName" : cmp.get("v.valueFieldApiName"),
            "extendedWhereClause" : cmp.get("v.extendedWhereClause"),
            "maxRecords" : cmp.get("v.maxRecords")
        });
        action.setCallback(this,function(response) {
            
            var state = response.getState();
            if (state === "SUCCESS") {
                const serverResult = response.getReturnValue();
                const results = [];
                serverResult.forEach(element => {
                    const result = {id : element[cmp.get("v.idFieldApiName")], value : element[cmp.get("v.valueFieldApiName")]};
                    results.push(result);
                });
                cmp.set("v.results", results);
                if(serverResult.length>0){
                    cmp.set("v.openDropDown", true);
                }
            } else{
                this.showToast(cmp, 'Error', 'error', 'something went wrong');
            }

            cmp.set('v.isSearching', false);
        });
        $A.enqueueAction(action);
    },
    addAccountList : function(cmp){
        
        cmp.set('v.isLoading', true);
        var action = cmp.get("c.addAccounts");
        let pba = cmp.get("v.pba");
        let accountList = cmp.get('v.selectedAccounts');
        let accountIds = [];
        accountList.forEach(element => {
            accountIds.push(element.Account__c);
        });
  
        action.setParams({ "pba" : pba, "accountIds": accountIds });
        action.setCallback(this,function(response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                const results = response.getReturnValue();
                if(results.existingLinks.length == 0){
                    const message = results.newAccounts.length + ' accounts added to this price book request';
                    this.showToast(cmp, 'success', 'Saved', message);
                    cmp.set('v.isSaved', true);
                    $A.get('e.force:refreshView').fire();
                }else{
                    const message = results.existingLinks.length + '  accounts are already part of another request.  Please check your email for a detailed list';
                    this.showToast(cmp, 'warning', 'Partial Save', message);
                    $A.get('e.force:refreshView').fire();
                }

                // results.newAccounts.forEach(accountLink => {
                //     accountLink.AccountUrl = '/lightning/r/Account/' + accountLink.Account__c +'/view';
                //     selectedAccounts.push(accountLink);
                // });

                // cmp.set('v.selectedAccounts', results.newAccounts);
                
                
            } else{
                let message = response.getError()[0];
                this.showToast(cmp, 'error','Problem adding Accounts', message);
            }
        });
        $A.enqueueAction(action);
    },
    removeAccount : function(cmp, recordId){
        cmp.set('v.isLoading', true);
        var action = cmp.get("c.deletePBAccountLink");
        action.setParams({recordId: recordId});
        action.setCallback(this, function(response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                const res = response.getReturnValue();

                let allAccounts = cmp.get('v.selectedAccounts');
                let updatedList = allAccounts.filter(account => account.Id != res.Id);
                cmp.set('v.selectedAccounts', updatedList);

                let message = res.Name + ' successfully removed from this request';
                this.showToast(cmp, 'success', 'Saved', message);
                $A.get('e.force:refreshView').fire();
                
            } else{
                let message = response.getError()[0];
                this.showToast(cmp, 'error','Error', message);
            }
        });

        $A.enqueueAction(action);
    },
    setAccounts : function(cmp){
        
        cmp.set('v.isLoading', true);
        var action = cmp.get("c.setAccountsByType");
        let pba = cmp.get("v.pba");
        let value = cmp.get('v.selectedValue');
        let field = cmp.get("v.valueFieldApiName");
        pba[field] = value;

        action.setParams({ "pba" : pba , "field": field, "value": value });
        action.setCallback(this,function(response) {
            // cmp.set('v.isLoading', false);
            // var state = response.getState();
            // if (state === "SUCCESS") {
            //     const message = response.getReturnValue();
            //     this.showToast(cmp, 'success', 'Saved', message);
            //     $A.get('e.force:refreshView').fire();
                
            // } else{
            //     let message = response.getError()[0];
            //     this.showToast(cmp, 'error','Problem adding Accounts', message);
            // }

            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                const results = response.getReturnValue();
                if(results.existingLinks.length == 0){
                    const message = results.newAccounts.length + ' accounts added to this price book request';
                    this.showToast(cmp, 'success', 'Saved', message);
                    cmp.set('v.isSaved', true);
                    $A.get('e.force:refreshView').fire();
                }else{
                    const message = results.existingLinks.length + '  accounts are already part of another request.  Please check your email for a detailed list';
                    this.showToast(cmp, 'warning', 'Partial Save', message);
                    $A.get('e.force:refreshView').fire();
                }

                // results.newAccounts.forEach(accountLink => {
                //     accountLink.AccountUrl = '/lightning/r/Account/' + accountLink.Account__c +'/view';
                //     selectedAccounts.push(accountLink);
                // });

                // cmp.set('v.selectedAccounts', results.newAccounts);
                
                
            } else{
                let message = response.getError()[0];
                this.showToast(cmp, 'error','Problem adding Accounts', message);
            }
        });
        $A.enqueueAction(action);
    },
    clearOption : function (component) {
        component.set("v.results", []);
        component.set("v.openDropDown", false);
        component.set("v.inputValue", "");
        component.set("v.selectedOption", "");
        component.set('v.selectedValue', "");
    },
    handleSave : function(cmp, accounts){
        cmp.set('v.isLoading', true);
        var action = cmp.get("c.updateEmailDay");
        action.setParams({ "accounts" : accounts});
        action.setCallback(this,function(response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                const message = response.getReturnValue();
                this.showToast(cmp, 'success', 'Saved', message);
                $A.get('e.force:refreshView').fire();
                
            } else{
                let message = response.getError()[0];
                this.showToast(cmp, 'error','Problem adding Accounts', message);
            }
        });
        $A.enqueueAction(action);
    },
    showToast : function(cmp, type, title, message){
        cmp.find('notifLib').showToast({
            "title": title,
            "message": message,
            "variant": type,
            "mode": "pester"
        });
    }
})