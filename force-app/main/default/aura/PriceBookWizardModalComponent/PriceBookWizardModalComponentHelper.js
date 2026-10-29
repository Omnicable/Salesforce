({
    getCustomPriceBookData: function (cmp) {
        cmp.set('v.isLoading', true);
        var action = cmp.get("c.getCustomPriceBookData");
        let pba = cmp.get('v.pba');
        action.setParams({ "priceBookId": pba.Price_Book__c });
        action.setCallback(this, function (response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                let data = response.getReturnValue();
                if (data.priceBook.Type__c != 'Custom') {
                    data.priceBook.Name = data.priceBook.Name + ' Custom';
                }
                let shouldSave = data.priceBook.Type__c != 'Custom' ? false : true;
                cmp.set('v.shouldSave', shouldSave);
                cmp.set('v.priceBook', data.priceBook);
                cmp.set('v.discounts', data.discounts);
                let options = data.familyOptions.sort((this.sortBy('value', 1)));
                let categories = data.categories.sort((this.sortBy('value', 1)));
                cmp.set('v.familyOptions', options);
                cmp.set('v.categories', categories);

                cmp.set('v.entries', data.priceBook.PricebookEntries);

            } else {
                let message = response.getError()[0].message;
                this.showToast(cmp, 'error', 'Error retrieving data', message);
            }
        });
        $A.enqueueAction(action);
    },
    save: function (cmp) {
        cmp.set('v.isLoading', true);
        let entries = cmp.get('v.entries');
        let discounts = cmp.get('v.discounts');
        let pba = cmp.get('v.pba');
        let pb = cmp.get('v.priceBook');
        delete pb.PricebookEntries;
        delete pba.Price_Book_Links__r;
        let shouldSave = cmp.get('v.shouldSave');

        var action = cmp.get("c.saveCustomPriceBook");
        /** NOTE: Only way to prevent internal error was to stringify all params  */
        action.setParams({ "shouldSaveStr": JSON.stringify(shouldSave), "pbStr": JSON.stringify(pb), "entriesStr": JSON.stringify(entries), "discountsStr": JSON.stringify(discounts), "pbaStr": JSON.stringify(pba) });
        action.setCallback(this, function (response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                let data = response.getReturnValue();
                console.log(data);
                this.showToast(cmp, 'success', 'Saved', 'Custom Price Book Saved');
                cmp.find("modalOverlay").notifyClose();
            } else {
                let message = response.getError()[0].message;
                this.showToast(cmp, 'error', 'Error Saving Price Book', message);
            }
        });
        $A.enqueueAction(action);
    },
    setEntryCols: function (cmp) {
        this.getEntryColumns(cmp, 'v.columns', true);
    },
    setEntries: function (cmp, entries, offset) {

        if (entries != null && entries.length > 0) {
            var discounts = cmp.get('v.discounts');
            var discountObj = discounts.reduce((obj, item) => {
                if (item.Type__c == 'All') {
                    obj['All'] = item.Percent_Discount__c;
                } else {
                    obj[item.Product_Family__c] = item.Percent_Discount__c;
                }
                return obj
            }, {})

            entries.forEach(entry => {
                entry.Family = entry.Product2.Family;
                entry.Category = entry.Product2.Category__c;
                entry.Discount = discountObj[entry.Family] || discountObj[entry.Category] || discountObj.All || 0;
                entry.QuantityUnitOfMeasure = entry.Product2.QuantityUnitOfMeasure;
                if (entry.Discount != 0) {
                    entry.Discount_Price__c = entry.Base_Price__c - (entry.Base_Price__c * (entry.Discount / 100))
                    entry.Discount_Percent__c = entry.Discount;
                    entry.Discount = entry.Discount / 100;
                } else {
                    entry.Discount_Price__c = null;
                    entry.Discount_Percent__c = null;
                    entry.Discount = null;
                }


                entry = this.calculateMargin(entry);
            });
            cmp.set('v.filteredEntries', entries.slice(0, offset));
            cmp.set('v.entries', entries);
        } else {
            this.showToast(cmp, 'warning', 'Problem with this price book', 'This price book doesn\'t have any entries');

        }

        cmp.set('v.isLoading', false);
    },
    calculateMargin: function (entry) {
        let priceArrays = [entry.Price_Override__c, entry.Discount_Price__c, entry.Base_Price__c, entry.UnitPrice];
        // entry.Base_Price__c = entry.Base_Price__c != null ? entry.Base_Price__c : entry.UnitPrice;
        entry.UnitPrice = priceArrays.find(el => el !== undefined && el !== 0 && el !== null);
        entry.UnitPrice = entry.Product2.QuantityUnitOfMeasure != 'EA' ? Math.round(entry.UnitPrice) : entry.UnitPrice;

        let grossProfit = entry.UnitPrice - entry.Unit_Cost__c;
        let margin = (grossProfit == 0 || entry.UnitPrice == 0) ? 0 : grossProfit / entry.UnitPrice;
        entry.Margin__c = margin;
        entry.errorClass = entry.Margin__c < .2 ? 'slds-text-color_error' : '';
        return entry;
    },
    next: function (cmp) {
        let currentStep = parseInt(cmp.get('v.currentStep')) + 1;
        if (currentStep == 3) {
            cmp.set('v.isLoading', true);
            setTimeout(() => {
                this.setEntries(cmp, cmp.get('v.entries'), cmp.get('v.loadOffset'));
                cmp.set('v.currentStep', currentStep.toString());
            }, 500);

        } else {
            cmp.set('v.currentStep', currentStep.toString());
        }
    },
    previous: function (cmp, event, helper) {
        let currentStep = parseInt(cmp.get('v.currentStep')) - 1;
        cmp.set('v.currentStep', currentStep.toString());
    },
    handleSort: function (cmp, event) {
        var sortedBy = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');

        var cloneData = cmp.get('v.filteredEntries');
        cloneData.sort((this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1)));

        cmp.set('v.filteredEntries', cloneData);
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