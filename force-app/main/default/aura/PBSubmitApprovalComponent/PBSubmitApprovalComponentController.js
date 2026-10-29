({
    doInit : function(cmp, event, helper) {
        helper.localGetRecord(cmp);
    },
    submit: function(cmp, event, helper){
        helper.submit(cmp);
    },
    close : function(cmp, event, helper){
        helper.close();
    }
})