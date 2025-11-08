'use strict';

angular.module('ownerList')
    .controller('OwnerListController', ['$http', 'API_BASE_URL', function ($http, API_BASE_URL) {
        var self = this;

        $http.get(API_BASE_URL + '/api/customers/owners').then(function (resp) {
            self.owners = resp.data;
        }).catch(function (error) {
            console.error('Error loading owners:', error);
        });
    }]);
