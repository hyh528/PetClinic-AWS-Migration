'use strict';

angular.module('ownerForm')
    .controller('OwnerFormController', ["$http", '$state', '$stateParams', 'API_BASE_URL', function ($http, $state, $stateParams, API_BASE_URL) {
        var self = this;

        var ownerId = $stateParams.ownerId || 0;

        if (!ownerId) {
            self.owner = {};
        } else {
            $http.get(API_BASE_URL + "/customer/owners/" + ownerId).then(function (resp) {
                self.owner = resp.data;
            });
        }

        self.submitOwnerForm = function () {
            var id = self.owner.id;

            if (id) {
                $http.put(API_BASE_URL + '/customer/owners/' + id, self.owner).then(function () {
                    $state.go('ownerDetails', {ownerId: ownerId});
                });
            } else {
                $http.post(API_BASE_URL + '/customer/owners', self.owner).then(function () {
                    $state.go('owners');
                });
            }
        };
    }]);
