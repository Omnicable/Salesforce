({
    doInit: function (cmp) {
        cmp.set('v.loading', true);
        var action = cmp.get('c.getAccount');
        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let data = response.getReturnValue();
                cmp.set('v.contact', data.contact);
                cmp.set('v.accountManager', data.accountManager);
                cmp.set('v.territorySalesManager', data.territorySalesManager);
                cmp.set('v.regionalManager', data.regionalManager);
                cmp.set('v.amEmail', data.amEmail);
                cmp.set('v.dsmEmail', data.dsmEmail);
                cmp.set('v.rmEmail', data.rmEmail);
                cmp.set('v.contactFileId', data.contactFileId);
            } else {

            }
        });

        $A.enqueueAction(action);
    },
    handleUploadFinished: function (cmp, uploadedFiles) {
        cmp.set('v.loading', true);
        var action = cmp.get('c.updatePicturePath');
        action.setParams({
            recId: cmp.get('v.contact').Id
        });
        action.setCallback(this, function (response) {
            var state = response.getState();
            cmp.set('v.loading', false);
            if (state === 'SUCCESS') {
                let data = response.getReturnValue();
                cmp.set('v.contactFileId', data);
                var resultToast = $A.get("e.force:showTest");
                resultToast.setParams({
                    "title": "Success!",
                    "message": "Contact Photo Updated"
                });
                resultToast.fire();;
            }
        });
        $A.enqueueAction(action);
    }
})