({
    doInit: function (cmp, event, helper) {
        let type = cmp.get('v.type');
        if (type == 'Order') {
            helper.getOrders(cmp, '');
        } else {
            helper.getReleases(cmp, '');
        }

    },

    onPaginationChange: function (cmp, event, helper) {
        let offset = event.getParam('offset');
        let tabName = event.getParam('tabName');
        let page = event.getParam('page');

        if (tabName == 'my') {
            helper.getMyReleasesLocal(cmp, offset, page, tabName);
        } else {
            helper.getOtherReleasesLocal(cmp, offset, page, tabName);
        }
    },
    handleKeyUp: function (cmp, evt, helper) {
        let type = cmp.get('v.type');
        var isEnterKey = evt.keyCode === 13;
        if (isEnterKey) {
            var queryTerm = cmp.find('enter-search').get('v.value');
            cmp.set('v.searchTerm', queryTerm);
            cmp.set('v.issearching', true);
            if (type == 'Order') {
                helper.getOrders(cmp, queryTerm);
            } else {
                helper.getReleases(cmp, queryTerm);
            }
        }
    },
    onClear: function (cmp, evt, helper) {
        debugger;

        let myPagination = cmp.find('my');
        let otherPagination = cmp.find('other')
        if (myPagination != null) {
            myPagination.clear();
        }

        if (otherPagination != null) {
            otherPagination.clear();
        }

        let type = cmp.get('v.type');
        var queryTerm = cmp.find('enter-search').get('v.value');
        cmp.set('v.searchTerm', queryTerm);
        if (queryTerm == null || queryTerm == '') {
            if (type == 'Order') {
                helper.getOrders(cmp, queryTerm);
            } else {
                helper.getReleases(cmp, queryTerm);
            }
        }
    }
})