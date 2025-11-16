'use strict';

angular.module('vetList')
    .controller('VetListController', ['$http', 'API_BASE_URL', function ($http, API_BASE_URL) {
        var self = this;

        $http.get(API_BASE_URL + '/api/vets/vets').then(function (resp) {
            self.vetList = resp.data;
        });
    }]);
