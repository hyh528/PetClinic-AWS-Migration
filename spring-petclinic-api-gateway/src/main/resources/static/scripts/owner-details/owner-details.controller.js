'use strict';

angular.module('ownerDetails')
    .controller('OwnerDetailsController', ['$http', '$stateParams', 'API_BASE_URL', function ($http, $stateParams, API_BASE_URL) {
        var self = this;

        $http.get(API_BASE_URL + '/gateway/owners/' + $stateParams.ownerId).then(function (resp) {
            self.owner = resp.data;
        });
    }]);
