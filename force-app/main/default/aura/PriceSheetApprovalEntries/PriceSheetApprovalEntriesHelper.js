({
    getEntries: function (cmp) {

        var recordId = cmp.get('v.recordId');
        var action = cmp.get("c.getApprovalEntries");
        action.setParams({ approvalId: recordId });

        action.setCallback(this, function (response) {
            var state = response.getState();

            if (state == 'SUCCESS') {
                let results = response.getReturnValue();

                if(results.entries != null){
                    cmp.set('v.discounts', results.discounts);
                    this.setEntries(cmp, results.entries);
                    this.setAccounts(cmp, results.accounts);
                
                }else{
                    let container = cmp.find("entry-container");
                    $A.util.addClass(container, "slds-hidden");
                }
                
            } else {
                let container = cmp.find("entry-container");
                $A.util.addClass(container, "slds-hidden");
            }
        });

        $A.enqueueAction(action);

    },
    setEntries : function(cmp, entries){
        if(entries != null && entries.length > 0){
            var discounts = cmp.get('v.discounts');
            var discountObj =  discounts.reduce((obj, item) => {
                if(item.Type__c == 'All'){
                    obj['All'] = item.Percent_Discount__c;
                }else{
                    obj[item.Product_Family__c] = item.Percent_Discount__c;
                }
                return obj
            }, {})
    
            entries.forEach(entry => {
                entry.Family = entry.Product2.Family;
                entry.Category = entry.Product2.Category__c;
                entry.Discount = discountObj[entry.Family] || discountObj[entry.Category] || discountObj.All || 0;
                entry.QuantityUnitOfMeasure = entry.Product2.QuantityUnitOfMeasure;
                entry.Margin__c || 0;
                entry.errorClass = entry.Margin__c < .2 ? 'slds-text-color_error' : '';
                if(entry.Discount != 0 ){
                    entry.Discount_Price__c = entry.Base_Price__c - (entry.Base_Price__c * (entry.Discount / 100))
                    entry.Discount = entry.Discount / 100;
                }
            });
            cmp.set('v.entries', entries);
        }else{
            this.showToast(cmp, 'warning', 'Problem with this price book', 'This price book doesn\'t have any entries');

        }
    },
    setAccounts: function (cmp, accounts) {
        accounts.forEach(account => {
            account.Owner = account.Account__r.Owner.Name;
            account.Name = account.Account__r.Name;
            account.AccountNumber = account.Account__r.Account_Number__c;
        });
        cmp.set('v.accounts', accounts);
    },
    initColumns: function (cmp) {
        cmp.set('v.columns', [
            { label: 'Name', fieldName: 'Name', type: 'text', sortable: true, width: '100%' },
            { label: 'Category', fieldName: 'Category', type: 'text', sortable: true, width: '100%' },
            { label: 'Family', fieldName: 'Family', type: 'text', sortable: true, width: '100%' },
            { label: 'Cost', fieldName: 'Unit_Cost__c', type: 'currency', sortable: true, width: '100%' },
            { label: 'Discount', fieldName: 'Discount', type: 'percent', sortable: true, width: '100%', initialWidth:100  },
            { label: 'Override', fieldName: 'Price_Override__c', type: 'currency', sortable: true, width: '100%', editable: false , typeAttributes:{minimumFractionDigits :'0'}}, 
            { label: 'Margin', fieldName: 'Margin__c', type: 'percent', sortable: true, width: '100%', editable: false, initialWidth:100, cellAttributes: {
                class: {
                    fieldName: 'errorClass'
                }
            }} ,    
            { label: 'Final Price', fieldName: 'UnitPrice', type: 'currency', sortable: true, width: '100%', typeAttributes:{minimumFractionDigits :'2'} },

        ]);

        cmp.set('v.accountColumns', [
            { label: 'Name', fieldName: 'Name', type: 'text', sortable: true, width: 'auto' },
            { label: 'Account Number', fieldName: 'AccountNumber', type: 'text', sortable: true, width: 'auto' },
            { label: 'Owner', fieldName: 'Owner', type: 'text', sortable: true, width: 'auto' },

        ]);
    },
    sortBy: function(field, reverse, primer) {
        var key = primer
            ? function(x) {
                  return primer(x[field]);
              }
            : function(x) {
                  return x[field];
              };

        return function(a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    },
    sortEntries: function(cmp, event) {
        var sortedBy = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');

        var entries = cmp.get('v.entries');;
        entries.sort((this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1)));
        
        cmp.set('v.entries', entries);
        cmp.set('v.eSortDirection', sortDirection);
        cmp.set('v.eSortedBy', sortedBy);
    },
    sortAccounts: function(cmp, event) {
        var sortedBy = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');

        var accounts = cmp.get('v.accounts');;
        accounts.sort((this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1)));
        
        cmp.set('v.accounts', accounts);
        cmp.set('v.aSortDirection', sortDirection);
        cmp.set('v.aSortedBy', sortedBy);
    }
})