({
    doInit: function (cmp, event, helper) {
        helper.initColumns(cmp);
        helper.getPBA(cmp);

        
    },
    handleChange: function (cmp, event, helper) {
        var selectedOptionValue = event.getParam("value");
        var options = cmp.get('v.priceBookOptions');
        var selectedLabel = options.find(opt => opt.value === selectedOptionValue).label;

        var pricebook = cmp.get('v.selectedPriceBook');
        pricebook.Name = selectedLabel;
        pricebook.Id = selectedOptionValue;
        cmp.set('v.selectedPriceBook', pricebook);


        //TODO: get price book by id and pass that into set entries
        let priceBooks = cmp.get('v.priceBooks');
        var foundIndex = priceBooks.findIndex(x => x.Id == pricebook.Id);
        let priceBook = priceBooks[foundIndex];

        let pba = cmp.get('v.pba');
        pba.Price_Book__c = pricebook.Id;
        cmp.set('v.pba', pba);
        helper.setEntries(cmp, [priceBook]);
    },
    priceBookSet: function (cmp, event, helper) {
        let pba = cmp.get('v.pba');
        let pb = cmp.get('v.selectedPriceBook');
        if (pb == null || pb.Id == null) {
            helper.showToast();
        } else {
            pba.Price_Book__c = pb.Id;
            helper.priceBookSet(cmp, pba);
        }

    },
    handleSectionToggle: function (cmp, event) {
        var openSections = event.getParam('openSections');

        if (openSections.length === 0) {
            cmp.set('v.activeSectionsMessage', "All sections are closed");
        } else {
            cmp.set('v.activeSectionsMessage', "Open sections: " + openSections.join(', '));
        }
    },
    customizePriceBook: function (cmp, event, helper) {
        helper.customizePriceBook(cmp);
    },
    handleSort: function(cmp, event, helper) {
        helper.handleSort(cmp, event, 'v.entries');
    },
})