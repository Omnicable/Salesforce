({
    doInit: function (cmp, event, helper) {
        let records = event.getParam("value");
        cmp.set('v.showBorder', records.length > 0);
        cmp.set('v.loading', false);
        //TODO: FIX helper.buildQuote(records, []);

    },
    toggle: function (cmp, event, helper) {
        let target = event.currentTarget.dataset.bsTarget;
        $A.util.toggleClass(event.currentTarget, "open-active");

        let targComp = document.getElementById(target);
        $A.util.toggleClass(targComp, "show");
    },
    receiveRequest: function (cmp, event, helper) {
        let value = event.getSource().get("v.checked");
        let id = event.getSource().get("v.name");
        let message = value ? 'Are you sure you\'d like to mark this Release as received' : 'Are you sure you\'d like to mark this Release as NOT received';

        helper.LightningConfirm.open({
            message: message,
            theme: 'warning',
            label: 'Please Confirm',
        }).then(function (result) {
            if (result) {
                helper.receiveRequest(cmp, id, value);
            } else {
                event.getSource().set("v.checked", false);
            }
        });

    },
    openLink: function (cmp, event, helper) {
        var link = event.target.dataset.link;
        if (!link.includes('http')) {
            link = '//' + link;
        }
        window.open(link, '_blank');
    },
    showDeliveryInfo: function (cmp, event, helper) {
        let deliveryDate = event.target.dataset.date;
        let deliveryAddress = event.target.dataset.address;

        var modalBody;
        $A.createComponent("c:Portal_DeliveryInfoComponent", {
            recordId: deliveryAddress,
            deliveryDate: deliveryDate,
        },
            function (content, status) {
                if (status === "SUCCESS") {
                    modalBody = content;
                    cmp.find('overlayLib').showCustomModal({
                        header: "Delivery Information",
                        body: modalBody,
                        showCloseButton: true,
                        cssClass: "mymodal",
                    })
                }
            });


    }
})