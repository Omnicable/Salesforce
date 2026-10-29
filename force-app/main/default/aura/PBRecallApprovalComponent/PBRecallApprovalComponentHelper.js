({
    recall: function (cmp) {
        cmp.set('v.isLoading', true);
        var pba = cmp.get('v.pba');
        var action = cmp.get("c.recallApproval");
        action.setParams({ "recordId": pba.Id });
        action.setCallback(this, function (response) {
            //TODO: Fix here they receive an error recalling request
            cmp.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                this.showToast(cmp, 'success', 'Recall Successful', 'The request has been recalled and the status has been set to Ready to Submit');
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