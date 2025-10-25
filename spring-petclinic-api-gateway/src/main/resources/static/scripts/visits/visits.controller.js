'use strict';

angular.module('visits')
    .controller('VisitsController', ['$http', '$state', '$stateParams', '$filter', 'API_BASE_URL', function ($http, $state, $stateParams, $filter, API_BASE_URL) {
        var self = this;
        var petId = $stateParams.petId || 0;
        var url = API_BASE_URL + "/api/visits";
        self.date = new Date();
        self.desc = "";

        $http.get(url).then(function (resp) {
            self.visits = resp.data;
        });

        self.submit = function () {
            var data = {
                date: $filter('date')(self.date, "yyyy-MM-dd"),
                description: self.desc
            };

            var postUrl = API_BASE_URL + "/api/visits/owners/*/pets/" + petId + "/visits";
            $http.post(postUrl, data).then(function () {
                $state.go('ownerDetails', { ownerId: $stateParams.ownerId });
            });
        };
    }]);
