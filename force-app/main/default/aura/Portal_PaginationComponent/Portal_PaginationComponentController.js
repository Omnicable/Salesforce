({
    doInit: function (cmp, event, helper) {
        debugger;
        let total = cmp.get('v.total');
        let itemsPerPage = cmp.get('v.itemsPerPage');
        let totalPages = Math.ceil(total / itemsPerPage);
        let pages = Array.from({ length: totalPages }, (_, i) => i + 1)
        cmp.set('v.pages', pages);

    },
    paginationChange: function (cmp, event, helper) {
        let paginationData = cmp.get('v.paginationData');

    },
    pageSelected: function (cmp, event, helper) {
        let selected = event.getSource().get("v.label");
        let currentPage = cmp.get('v.selected');
        if (currentPage != selected) {
            cmp.set('v.selected', selected);
            helper.notifyPaginationChange(cmp);
        }
    },
    next: function (cmp, event, helper) {
        let currentPage = cmp.get('v.selected');
        cmp.set('v.selected', currentPage + 1);
        helper.notifyPaginationChange(cmp)


    },
    last: function (cmp, event, helper) {
        let pages = cmp.get('v.pages');
        cmp.set('v.selected', pages.length);
        helper.notifyPaginationChange(cmp)

    },
    previous: function (cmp, event, helper) {
        let currentPage = cmp.get('v.selected');
        cmp.set('v.selected', currentPage - 1);
        helper.notifyPaginationChange(cmp)

    },
    first: function (cmp, event, helper) {
        cmp.set('v.selected', 1);
        helper.notifyPaginationChange(cmp)
    },

    onClear: function (cmp, event, helper) {
        cmp.set('v.selected', 1);
    }

})