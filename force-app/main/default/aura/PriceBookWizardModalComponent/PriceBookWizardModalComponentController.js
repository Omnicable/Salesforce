({
    doInit : function(cmp, event, helper) {
        helper.getCustomPriceBookData(cmp);
        helper.setEntryCols(cmp);
    },
    addDiscount : function(cmp, event, helper){
        let valid = true;
        let familyInput = cmp.find('newFamily');
        let type = cmp.get('v.currentType');
        let discountInput = cmp.find('newDiscount');
        let addCont = cmp.find('add-cont');
        let pFamily = familyInput.get('v.value');
        let discount = discountInput.get('v.value');
        let discounts = cmp.get('v.discounts') || [];
        var foundIndex = discounts.findIndex(x => x.Product_Family__c == pFamily || (x.Type__c == 'All' && type == 'All'));

        if(type != 'All'){
            if(pFamily == null || pFamily.trim() == '' || (foundIndex != -1 && discount.length > 0)){
                familyInput.setCustomValidity(foundIndex != -1 ? 'Discount already exist': type + ' Required');
                valid = false;
            }else{
                familyInput.setCustomValidity('');
            }
        }else{
            if (foundIndex != -1 && discount.length > 0){
                familyInput.setCustomValidity('Discount already exist');
                valid = false;
            }else{
                familyInput.setCustomValidity('');
            }
        }

        if(discount == null || discount.trim() == ''){
            discountInput.setCustomValidity('Discount % Required');
            valid = false;
        }else{
            discountInput.setCustomValidity('');
        }

        familyInput.reportValidity();
        discountInput.reportValidity();

        if(valid){
            discounts.push({"Type__c":type, "Percent_Discount__c":discount, "Product_Family__c":pFamily});
            cmp.set('v.discounts', discounts);
            familyInput.set('v.value', '');
            discountInput.set('v.value', '');
            $A.util.removeClass(addCont, "slds-align-middle");
            $A.util.addClass(addCont, "slds-align-bottom");
        }else{
            $A.util.addClass(addCont, "slds-align-middle");
            $A.util.removeClass(addCont, "slds-align-bottom");
        }
    },

    onValueChange : function(cmp, event, helper){
        let draftValues = event.getParam('draftValues');
        let entries = cmp.get('v.entries');

        for (let index = 0; index < draftValues.length; index++) {
            let entry = draftValues[index];
            var foundIndex = entries.findIndex(x => x.Id == entry.Id);

            if(foundIndex != -1){
                for (const key in entry) {
                    if (Object.hasOwnProperty.call(entry, key) && key != 'Id') {
                        const element = entry[key];
                        entries[foundIndex][key] = parseFloat(entry[key] || 0);
                        entries[foundIndex] = helper.calculateMargin(entries[foundIndex]);
                    }
                }
            }
        }

        cmp.set('v.entries', entries);
    },

    applyDiscountsOverrides :  function(cmp, event, helper){
        helper.applyDiscountsOverrides(cmp);
    },
    removeDiscount : function(cmp, event, helper){
        let index = event.getSource().get("v.value");
        let discounts = cmp.get('v.discounts');
        discounts.splice(index, 1);
        cmp.set('v.discounts', discounts);
    },
    previous : function(cmp, event, helper){
        cmp.set('v.enableInfiniteLoading', true);
        helper.previous(cmp);
    },
    next : function(cmp, event, helper){
        helper.next(cmp);
    },
    save : function(cmp, event, helper){
        helper.save(cmp);
    },
    handleSort: function(cmp, event, helper) {
        helper.handleSort(cmp, event);
    },
    loadMoreData : function(cmp, event, helper){
        let offset = cmp.get('v.loadOffset');
        let filteredEntries = cmp.get('v.filteredEntries');
        let currentCount = filteredEntries.length;
        let entries = cmp.get('v.entries');
        let enableInfiniteLoading = entries.length != filteredEntries.length;
        let remaining = entries.length - currentCount;
        let loadStatus = enableInfiniteLoading == false ? 'No more data to load' : 'Load more (' + remaining + ' remaining)';
        cmp.set('v.loadMoreStatus', loadStatus);
        cmp.set('v.enableInfiniteLoading', enableInfiniteLoading);
        cmp.set('v.isLoading', true);
        setTimeout(() => {
            cmp.set('v.filteredEntries', entries.slice(0, Math.min(currentCount + offset, entries.length)));
            cmp.set('v.isLoading', false);
        }, 500);

    }

})