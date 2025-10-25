'use strict';

angular.module('ownerForm')
    .controller('OwnerFormController', ["$http", '$state', '$stateParams', 'API_BASE_URL', function ($http, $state, $stateParams, API_BASE_URL) {
        var self = this;

        var ownerId = $stateParams.ownerId || 0;

        if (!ownerId) {
            self.owner = {};
        } else {
            $http.get(API_BASE_URL + "/api/customers/owners/" + ownerId).then(function (resp) {
                self.owner = resp.data;
            }).catch(function (error) {
                console.error('Error loading owner:', error);
            });
        }

        self.submitOwnerForm = function () {
            var id = self.owner.id;

            if (id) {
                $http.put(API_BASE_URL + '/api/customers/owners/' + id, self.owner).then(function () {
                    $state.go('ownerDetails', {ownerId: ownerId});
                }).catch(function (error) {
                    console.error('Error updating owner:', error);
                });
            } else {
                $http.post(API_BASE_URL + '/api/customers', self.owner).then(function () {
                    $state.go('owners');
                }).catch(function (error) {
                    console.error('Error creating owner:', error);
                });
            }
        };
    }]);
