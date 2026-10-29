({
    doInit: function (cmp) {
        cmp.set('v.loading', true);
        var action = cmp.get('c.getHomePageData');
        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let results = response.getReturnValue();
                cmp.set('v.recentReleases', results.releases.records);
                cmp.set('v.carouselImages', results.carouselImages);
            } else {
                let errorMessage = response.getError()[0].message;
                cmp.find('notifLib').showToast({
                    "title": 'Error getting home page data',
                    "message": errorMessage,
                    "variant": 'error',
                    "mode": "pester"
                });
            }

        });

        $A.enqueueAction(action);

    }
})