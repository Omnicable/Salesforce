({
    doInit : function(cmp, event, helper) {
        helper.localGetRecord(cmp);
    },
    recall: function(cmp, event, helper){
        helper.recall(cmp);
    },
    close : function(cmp, event, helper){
        helper.close();
    }
})