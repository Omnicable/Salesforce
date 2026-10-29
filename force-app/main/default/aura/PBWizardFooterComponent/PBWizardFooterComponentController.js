({
    previous : function(cmp, event, helper) {
        cmp.get('v.parent').previous();
    },
    next : function(cmp, event, helper) {
        cmp.get('v.parent').next();
    },
    save : function(cmp, event, helper) {
        cmp.get('v.parent').save();
    }
})