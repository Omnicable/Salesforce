({
    doInit: function (cmp, event, helper) {
        helper.getData(cmp, null);
        helper.setColumns(cmp);
    },
    addToRelease: function (cmp, event, helper) {
        helper.addToRelease(cmp);
    },
    clear: function (cmp, event, helper) {
        helper.clear(cmp);
    },
    updateSelectedText: function (cmp, event) {
        var newRows = event.getParam('selectedRows');
        var selectedIds = cmp.get('v.selectedIds');
        var selectedRows = cmp.get('v.selectedRows');
        var config = event.getParam('config');

        if (config.selection == 'rowDeselect') {
            selectedIds = selectedIds.filter(id => id != config.value);
            selectedRows = selectedRows.filter(row => row.Id != config.value);
        } else if (config.selection == 'deselectAllRows') {
            selectedIds = [];
            selectedRows = [];
        } else if (config.selection == 'selectAllRows') {

        }


        newRows.forEach(row => {
            if (!selectedIds.includes(row.Id)) {
                selectedIds.push(row.Id);
                selectedRows.push(row);
            }
        });

        cmp.set('v.selectedRows', selectedRows);
        cmp.set('v.selectedIds', selectedIds);
    },
    handleKeyUp: function (cmp, evt, helper) {
        var isEnterKey = evt.keyCode === 13;
        if (isEnterKey) {

            cmp.set('v.page', 1);
            cmp.set('v.offset', 0);

            var queryTerm = cmp.find('enter-search').get('v.value');
            helper.onSearchInventory(cmp, queryTerm);
        }
    },
    onClear: function (cmp, evt, helper) {
        var queryTerm = cmp.find('enter-search').get('v.value');
        if (queryTerm == null || queryTerm == '') {
            helper.onSearchInventory(cmp, queryTerm);
        }
    },
    handleRowAction: function (cmp, event, helper) {
        var action = event.getParam('action');
        var row = event.getParam('row');
        switch (action.name) {
            case 'view_details':
                helper.showRowDetails(cmp, row);
                break;
            case 'add_item':
                helper.addItem(cmp, row);
                break;
            case 'remove_items':
                helper.clearItems(cmp, row);
                break;
            default:
                helper.showRowDetails(row);
                break;
        }
    },
    onPaginationChange: function (cmp, event, helper) {
        let offset = event.getParam('offset');
        let tabName = event.getParam('tabName');
        let page = event.getParam('page');
        cmp.set('v.page', page);
        cmp.set('v.offset', offset);

        var queryTerm = cmp.find('enter-search').get('v.value');
        helper.getData(cmp, queryTerm);
        // if (tabName == 'my') {
        //     helper.getMyReleasesLocal(cmp, offset, page, tabName);
        // } else {
        //     helper.getOtherReleasesLocal(cmp, offset, page, tabName);
        // }
    },
})