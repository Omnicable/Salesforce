({
    setColumns: function (cmp) {
        cmp.set('v.columns', [
            { label: 'Lot#', fieldName: 'Lot_Number__c', type: 'text' },
            { label: 'Reel', fieldName: 'Putup__c', type: 'text' },
        ]);
    }
})