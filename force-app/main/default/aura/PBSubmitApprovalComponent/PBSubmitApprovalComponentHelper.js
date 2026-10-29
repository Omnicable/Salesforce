({
    submit: function (cmp) {
        cmp.set('v.isLoading', true);
        var pba = cmp.get('v.pba');
        var action = cmp.get("c.submitPriceBookApproval");
        action.setParams({ "recordId": pba.Id });
        action.setCallback(this, function (response) {
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                const results = response.getReturnValue();
                this.showToast(cmp, results.type, results.title, results.message);
                $A.get('e.force:refreshView').fire();
                this.close();
            } else {
                let error = response.getError()[0].message;
                this.showToast(cmp, 'error', 'Error Recalling Request', error);
            }
        });
        $A.enqueueAction(action);
    },
    close: function () {
        var dismissActionPanel = $A.get("e.force:closeQuickAction");
        dismissActionPanel.fire();
    }
})