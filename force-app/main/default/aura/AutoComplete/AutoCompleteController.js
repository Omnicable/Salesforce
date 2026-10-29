({
    doInit : function(cmp, event, helper){
        cmp.set('v.selectedAccounts', []);
        helper.initColumns(cmp);
        helper.doInit(cmp);
    },
    searchHandler : function (cmp, event, helper) {
        var type = cmp.get('v.typeLabel');

        cmp.get('v.isSearching', true);
        const searchString = cmp.find('enter-search').get('v.value');
        if (searchString.length >= 0) {

            if (cmp.get("v.inputSearchFunction")) {
                clearTimeout(cmp.get("v.inputSearchFunction"));
            }

            var inputTimer = setTimeout($A.getCallback(function () {

                type == 'Accounts' ? helper.searchAccounts(cmp, searchString) : helper.searchRecords(cmp, searchString);
                
            }), 800);
            cmp.set("v.inputSearchFunction", inputTimer);
        } else{
            cmp.get('v.isSearching', false);
            cmp.set("v.results", []);
            cmp.set("v.openDropDown", false);
        }
    },

    addAccount : function (cmp, event, helper){
        let accounts = cmp.get('v.results');
        let value = event.getSource().get("v.value");
        value.added = value.added == undefined || value.added == false ? true : false;
        value.AccountUrl  = '/lightning/r/Account/' + value.Id +'/view';
        value.Account__c = value.Id;
        var foundIndex = accounts.findIndex(x => x.Id == value.Id);
        accounts[foundIndex] = value;
        cmp.set('v.results', accounts);

        let addedAccounts = cmp.get('v.selectedAccounts');
        var foundI = addedAccounts.findIndex(x => x.Account__c == value.Id || x.Id == value.Id);
        if(foundI == -1){
            addedAccounts.push(value);
        }else{
            addedAccounts.splice(foundI, 1);
        }

        cmp.set('v.selectedAccounts', addedAccounts);

        // helper.setAddedAccounts(cmp);
        
    },
    optionClickHandler : function (cmp, event, helper) {
        cmp.set("v.inputValue", "");
        cmp.set("v.selectedOption", "");

        
        const selectedId = event.target.closest('li').dataset.id;
        const selectedValue = event.target.closest('li').dataset.value;
        cmp.set('v.selectedValue', selectedValue);
        cmp.set("v.inputValue", selectedValue);
        cmp.set("v.openDropDown", false);
        cmp.set("v.selectedOption", selectedId);
    },

    hideResults : function(cmp, event, helper){
        cmp.set("v.openDropDown", false);
    },

    possibleClear : function (cmp, event, helper){
        const searchString = cmp.find('enter-search').get('v.value');
        if(searchString == ''){
            helper.clearOption(cmp);
        }
    },

    clearOption : function (cmp, event, helper) {
        cmp.set("v.results", []);
        cmp.set("v.openDropDown", false);
        cmp.set("v.inputValue", "");
        cmp.set("v.selectedOption", "");
    },
    setAccounts : function (cmp, event, helper){
        let type = cmp.get('v.typeLabel')
        if(type != 'Accounts'){
            helper.setAccounts(cmp);
        }else{
            helper.addAccountList(cmp);
        }
        
    },
    handleSave: function (cmp, event, helper) {

        let selectedAccounts = cmp.get('v.selectedAccounts')
        let isSaved = cmp.get('v.isSaved');
        if(selectedAccounts.length > 0  && isSaved ){
            var updates = [];
            var accounts = cmp.get('v.selectedAccounts');
            var draftValues = event.getParam('draftValues');

            draftValues.forEach(value => {
                let account = accounts.find(a => a.Id === value.Id);
                if(account != null){
                    let newAccount = {'sobjectType': 'Account', Id: account.Account__c, Price_Book_Email_Day__c: value.Email_Day__c};
                    updates.push(newAccount);
                }
            });

            if(updates.length > 0){
                helper.handleSave(cmp, updates);
            }

        }else{
            helper.showToast(cmp, 'error','Save Account Required', 'You must click Save Account before editing the account\'s Email Day');
        }

        

       
    },
    handleCancelEdition: function (cmp) {
        // do nothing for now...
    },
    handleSectionToggle: function (cmp, event) {
        var openSections = event.getParam('openSections');

        if (openSections.length === 0) {
            cmp.set('v.activeSectionsMessage', "All sections are closed");
        } else {
            cmp.set('v.activeSectionsMessage', "Open sections: " + openSections.join(', '));
        }
    },
    removeAccount: function (cmp, event, helper) {
        var account = event.getParam('row');
        var accounts = cmp.get('v.selectedAccounts');

        if (window.confirm("Are you sure you want to remove the " + account.Name + " account?")) {
            if(account.added != null && account.added == true){
                var foundIndex = accounts.findIndex(x => x.Id == account.Id);
                accounts.splice(foundIndex, 1);
                cmp.set('v.selectedAccounts', accounts);
            }else{
                helper.removeAccount(cmp, account.Id);

            }
        }
    },
    handleSort: function(cmp, event, helper) {
        helper.handleSort(cmp, event, 'v.selectedAccounts');
    },
})