({
    doInit: function (cmp, event, helper) {
        debugger;
        var profUrl = $A.get('$Resource.OCC_StaticResources') + '/OCC_StaticResources/img/avatar.png';

        document.getElementsByClassName('profile-img').onerror = (event) => {
            console.log('logo img did not load');
            debugger;
        }

        helper.doInit(cmp);
    },
    handleSubmit: function (component, event, helper) {
        component.set('v.loading', true);
        event.preventDefault();
        const fields = event.getParam('fields');
        fields.ContactId = component.get("v.contact").Id;
        component.find('contactForm').submit(fields);
    },

    handleSuccess: function (component, event, helper) {
        component.set('v.loading', false);
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "Success",
            "message": "Contact Information Updated",
            "mode": 'dismissible',
            "duration": 3000,
            "type": "success"
        });
        toastEvent.fire();
    },
    handleError: function (component, event, helper) {
        component.set('v.loading', false);
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "Error",
            "message": "Error saving contact information, please try again",
            "mode": 'dismissible',
            "duration": 3000,
            "type": "error"
        });
        toastEvent.fire();
    },
    setDefaultImage: function (cmp, event, helper) {
        debugger;
        event.target.src = "https://default-image-link-goes-here";
        event.onerror = null
    },

    handleUploadFinished: function (component, event, helper) {
        debugger;
        // Get the list of uploaded files
        var uploadedFiles = event.getParam('files');
        helper.handleUploadFinished(component, uploadedFiles);
    }

})