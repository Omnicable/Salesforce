({
    getPBA : function(cmp){

        var recordId = cmp.get('v.recordId');
        let _cmp = cmp;
        let _this = this;
        let oldPBA = cmp.get('v.pba');

        _this.executeApexPromise(cmp, 'getPriceBookApprovalById', { "recordId": recordId })
            .then(function (result) {
                let data = result;
                
                if(oldPBA != null && oldPBA.Price_Book__c != null && data.Price_Book__c == null){
                    data.Price_Book__c = oldPBA.Price_Book__c;
                }

                if(data.Price_Book__r != null){
                    _cmp.set('v.selectedPriceBook', data.Price_Book__r);
                }

                _cmp.set('v.pba', data);
                _this.getPriceBooks(_cmp);
            }
        );

    },
    getPriceBooks : function(cmp){
        cmp.set('v.isLoading', true);
        var recordId = cmp.get('v.recordId');
        var action = cmp.get("c.getBasePriceBooks");
        action.setParams({"pbaId": recordId});
        action.setCallback(this,function(response) {
            
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                let priceBooks = response.getReturnValue();
                cmp.set('v.priceBooks', priceBooks);
                cmp.set('v.isSaved', true);
                this.setPriceBookOptions(cmp, priceBooks);
                this.setEntries(cmp, priceBooks);
                
            } else{

                this.showToast(cmp, 'error', 'error', 'something went wrong');
        
            }
        });
        $A.enqueueAction(action);
    },
    initColumns : function(cmp){
        this.getEntryColumns(cmp, 'v.columns', false);
    },
    setEntries : function(cmp, priceBooks){
    
        let pba = cmp.get('v.pba');
        var foundIndex = priceBooks.findIndex(x => x.Id == pba.Price_Book__c);
        if(foundIndex != -1){
            let entries = priceBooks[foundIndex].PricebookEntries || [];

            if(entries != null && entries.length > 0){
                entries.forEach(entry => {
                    entry.Family = entry.Product2.Family;
                    entry.Category = entry.Product2.Category__c;
                    entry.QuantityUnitOfMeasure = entry.Product2.QuantityUnitOfMeasure;
                    entry.errorClass = entry.Margin__c < .2 ? 'slds-text-color_error' : '';
                    entry.UnitPrice = entry.Product2.QuantityUnitOfMeasure == 'EA' ? entry.UnitPrice : Math.round(entry.UnitPrice);
                    if(entry.Discount_Percent__c != null){
                        entry.Discount =  entry.Discount_Percent__c / 100;
                    }
                });
                cmp.set('v.entries', entries);
            }else{
                this.showToast(cmp, 'warning', 'Problem with Price Book: ' + priceBooks[foundIndex].Name, 'This price book doesn\'t have any entries');
                let pba = cmp.get('v.pba');
                pba.Price_Book__c = null;
                cmp.set('v.pba', pba);
            } 
        }
    },
    setPriceBookOptions : function(cmp, priceBooks){
        var pbOptions = [];
        priceBooks.forEach(pb => {
            pbOptions.push({label:pb.Name, value:pb.Id})
        });

        cmp.set('v.priceBookOptions', pbOptions);

    },
    priceBookSet : function(cmp, pba){
        cmp.set('v.isLoading', true);
        var action = cmp.get("c.setPriceBook");
        action.setParams({ "pbaId" : pba.Id, "pbId" : pba.Price_Book__c });
        action.setCallback(this,function(response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                let data = JSON.parse(response.getReturnValue());
                this.showToast(cmp, 'success', 'Price Book Set', '');
                cmp.set('v.isSaved', true);
                $A.get('e.force:refreshView').fire();
            } else{
                this.showToast(cmp, 'error', 'error', 'something went wrong');
            }
        });
        $A.enqueueAction(action);

    },
    customizePriceBook : function(cmp){
        
        var _helper = this;
        var modalBody;
        var modalFooter;
        var pba = cmp.get('v.pba')
        $A.createComponents([
            ["c:PriceBookWizardModalComponent", {"pba":pba}],
            ["c:PBWizardFooterComponent", {}]
        ],
            function (components, status) {
                if (status === "SUCCESS") {

                    modalBody = components[0];
                    modalFooter = components[1];
                    modalFooter.set('v.parent', modalBody);
                    modalFooter.set('v.currentStep', modalBody.getReference('v.currentStep'));

                    cmp.find('modalOverlay').showCustomModal({
                        header: "Customize Price Book",
                        body: modalBody,
                        footer: modalFooter,
                        showCloseButton: true,
                        cssClass: "slds-modal_large",
                        closeCallback: function () {
                            $A.get('e.force:refreshView').fire();
                            _helper.getPBA(cmp);
                        }
                    })
                }
            });
    },
})