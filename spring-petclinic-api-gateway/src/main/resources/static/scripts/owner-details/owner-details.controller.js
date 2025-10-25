'use strict';

angular.module('ownerDetails')
    .controller('OwnerDetailsController', ['$http', '$stateParams', 'API_BASE_URL', function ($http, $stateParams, API_BASE_URL) {
        var self = this;

        $http.get(API_BASE_URL + '/api/customers/owners/' + $stateParams.ownerId).then(function (resp) {
            self.owner = resp.data;

            // 각 반려동물의 방문 기록을 불러옵니다
            if (self.owner.pets) {
                self.owner.pets.forEach(function(pet) {
                    $http.get(API_BASE_URL + '/api/visits/owners/*/pets/' + pet.id + '/visits').then(function (visitResp) {
                        pet.visits = visitResp.data;
                    }).catch(function (error) {
                        console.error('Error loading visits for pet ' + pet.id + ':', error);
                        pet.visits = [];
                    });
                });
            }
        }).catch(function (error) {
            console.error('Error loading owner details:', error);
        });
    }]);
