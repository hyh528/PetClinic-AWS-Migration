'use strict';

angular.module('ownerList')
    .controller('OwnerListController', ['$http', 'API_BASE_URL', function ($http, API_BASE_URL) {
        var self = this;

        $http.get(API_BASE_URL + '/customer/owners').then(function (resp) {
            self.owners = resp.data;
        });
    }]);
