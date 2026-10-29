({
    localGetRecord : function(cmp){
        cmp.set('v.isLoading', true);
        var recordId = cmp.get('v.recordId');
        var action = cmp.get("c.getPriceBookApprovalById");
        action.setParams({ "recordId" : recordId });
        action.setCallback(this,function(response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                let data = response.getReturnValue();
                cmp.set('v.pba', data);                
            } else{
                this.showToast(cmp, 'error', 'error', 'something went wrong');
            }
        });
        $A.enqueueAction(action);
    },
    executeApexPromise : function( cmp, apexAction, params ) {
        var p = new Promise( $A.getCallback( function( resolve , reject ) { 
            var action                          = cmp.get("c."+apexAction+"");
            action.setParams( params );
            action.setCallback( this , function(callbackResult) {
                if(callbackResult.getState()=='SUCCESS') {
                    resolve( callbackResult.getReturnValue() );
                }
                if(callbackResult.getState()=='ERROR') {
                    console.log('ERROR', callbackResult.getError() ); 
                    reject( callbackResult.getError() );
                }
            });
            $A.enqueueAction( action );
        }));            
        return p;
    },

    showToast : function(cmp, type, title, message){
        cmp.find('notifLib').showToast({
            "title": title,
            "message": message,
            "variant": type,
            "mode": "pester"
        });
    },

    getEntryColumns : function(cmp, colAttr, overrideEditable){
        cmp.set(colAttr, [
            { label: 'Name', fieldName: 'Name', type: 'text', sortable: true, width: 'auto' },
            { label: 'Unit', fieldName: 'QuantityUnitOfMeasure', type: 'text', sortable: true, width: 'auto' , initialWidth:75},
            { label: 'Category', fieldName: 'Category', type: 'text', sortable: true, width: 'auto' },
            { label: 'Product Group', fieldName: 'Family', type: 'text', sortable: true, width: 'auto' },
            { label: 'Cost', fieldName: 'Unit_Cost__c', type: 'currency', sortable: true, width: 'auto', initialWidth:100},
            { label: 'Discount %', fieldName: 'Discount', type: 'percent', sortable: true, width: 'auto', initialWidth:110},
            { label: 'Override', fieldName: 'Price_Override__c', type: 'currency', sortable: true, width: 'auto', editable: overrideEditable , initialWidth:125, typeAttributes:{minimumFractionDigits :'2'}}, 
            { label: 'Margin %', fieldName: 'Margin__c', type: 'percent', sortable: true, width: 'auto', editable: false, initialWidth:110, cellAttributes: {
                class: {
                    fieldName: 'errorClass'
                }
            }} ,    
            { label: 'Final Price', fieldName: 'UnitPrice', type: 'currency', sortable: true, width: 'auto', initialWidth:125, typeAttributes:{minimumFractionDigits :'2'} },

        ]);
    },

    getAccountColumns : function(cmp, colAttr, actions){

        if(actions != null){
            cmp.set(colAttr, [
                {label: 'Name', sortable: true, fieldName: 'AccountUrl', type: 'url', width: 'auto' ,typeAttributes:{
                    label: {
                        fieldName: 'Name'
                    },
                    target: '_blank'
                }},
                { label: 'Active', fieldName: 'Active__c', type: 'boolean', sortable: true, editable:false, width: 'auto', initialWidth: 100 },
                { label: 'Status', fieldName: 'Status__c', type: 'text', sortable: true, editable:false, width: 'auto' },
                { label: 'Last Email Date', fieldName: 'Last_Email_Sent__c', type: 'date', sortable: true, editable:false, width: 'auto' ,  initialWidth: 150, typeAttributes: {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit',
                    hour12: true
                  }},
                { label: 'Email Day', fieldName: 'Email_Day__c', type: 'number', sortable: true, editable:true, width: 'auto', initialWidth: 100 },
                { type: 'action', typeAttributes: { rowActions: actions } },
            ]);
        }else{
            cmp.set(colAttr, [
                {label: 'Name', fieldName: 'AccountUrl', type: 'url', width: 'auto' ,sortable: true, typeAttributes:{
                    label: {
                        fieldName: 'Name'
                    },
                    target: '_blank'
                }},
                { label: 'Active', fieldName: 'Active__c', type: 'boolean', sortable: true, editable:false, width: 'auto', initialWidth: 100 },
                { label: 'Status', fieldName: 'Status__c', type: 'text', sortable: true, editable:false, width: 'auto' },
                { label: 'Last Email Date', fieldName: 'Last_Email_Sent__c', type: 'date', sortable: true, editable:false, width: 'auto' ,  initialWidth: 150, typeAttributes: {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit',
                    hour12: true
                  }},
                { label: 'Email Day', fieldName: 'Email_Day__c', type: 'number', sortable: true, editable:true, width: 'auto', initialWidth: 100 },
            ])
        }

    },
    handleSort: function(cmp, event, attributeName) {
        var sortedBy = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');

        var cloneData = cmp.get(attributeName);
        cloneData.sort((this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1)));
        
        cmp.set(attributeName, cloneData);
        cmp.set('v.sortDirection', sortDirection);
        cmp.set('v.sortedBy', sortedBy);
    },
    sortBy: function (field, reverse, primer) {
        var key = primer
            ? function (x) {
                return primer(x[field]);
            }
            : function (x) {
                return x[field];
            };

        return function (a, b) {
            a = key(a) == undefined ? 0 : key(a);
            b = key(b) == undefined ? 0 : key(b);
            return reverse * ((a > b) - (b > a));
        };
    },
})