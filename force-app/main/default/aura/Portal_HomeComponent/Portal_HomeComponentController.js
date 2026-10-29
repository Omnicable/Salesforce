({
    doInit: function (cmp, event, helper) {
        helper.doInit(cmp);
    },
    onImageClick: function (cmp, event, helper) {
        var url = event.getSource().get("v.id");
        window.open(url, '_blank');
    },
    openRelease: function (cmp, event, helper) {
        window.location.href = '../s/releases';
    }
})