({
    doInit: function (cmp, event, helper) {
        let inventoryDetails = cmp.get('v.inventoryDetails');
        cmp.set('v.reels', inventoryDetails.Reels__r);
        helper.setColumns(cmp)
    }
})