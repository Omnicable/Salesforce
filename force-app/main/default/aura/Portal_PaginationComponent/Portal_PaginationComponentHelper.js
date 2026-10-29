({
    notifyPaginationChange: function (cmp) {
        var offset = cmp.get('v.offset');
        var page = cmp.get('v.selected');
        var itemsPerPage = cmp.get('v.itemsPerPage');
        var total = cmp.get('v.total');


        var offset = (page * itemsPerPage) - itemsPerPage;

        if (total > offset) {
            var compEvent = cmp.getEvent("paginationChange");
            compEvent.setParams({
                "offset": offset,
                "page": page,
                "tabName": cmp.get('v.tab')
            });
            compEvent.fire();
        }


    }
})