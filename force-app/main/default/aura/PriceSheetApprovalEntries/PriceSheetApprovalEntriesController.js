({
    doInit : function(cmp, event, helper) {
        helper.initColumns(cmp);
        helper.getEntries(cmp);
    },
    eHandleSort : function(cmp, event, helper){
        helper.sortEntries(cmp, event);
    },
    aHandleSort : function(cmp, event, helper){
        helper.sortAccounts(cmp, event);
    }
})