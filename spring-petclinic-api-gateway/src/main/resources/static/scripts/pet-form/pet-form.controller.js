'use strict';

angular.module('petForm')
    .controller('PetFormController', ['$http', '$state', '$stateParams', 'API_BASE_URL', function ($http, $state, $stateParams, API_BASE_URL) {
        var self = this;
        var ownerId = $stateParams.ownerId || 0;

        $http.get(API_BASE_URL + '/api/customers/petTypes').then(function (resp) {
            self.types = resp.data;
        }).then(function () {

            var petId = $stateParams.petId || 0;

            if (petId) { // edit
                $http.get(API_BASE_URL + "/api/customers/owners/" + ownerId + "/pets/" + petId).then(function (resp) {
                    self.pet = resp.data;
                    self.pet.birthDate = new Date(self.pet.birthDate);
                    self.petTypeId = "" + self.pet.type.id;
                });
            } else {
                $http.get(API_BASE_URL + '/api/customers/owners/' + ownerId).then(function (resp) {
                    self.pet = {
                        owner: resp.data.firstName + " " + resp.data.lastName
                    };
                    self.petTypeId = "1";
                })

            }
        });

        self.submit = function () {
            var id = self.pet.id || 0;

            var data = {
                id: id,
                name: self.pet.name,
                birthDate: self.pet.birthDate,
                typeId: self.petTypeId
            };

            var req;
            if (id) {
                req = $http.put(API_BASE_URL + "/api/customers/owners/" + ownerId + "/pets/" + id, data);
            } else {
                req = $http.post(API_BASE_URL + "/api/customers/owners/" + ownerId + "/pets", data);
            }

            req.then(function () {
                $state.go('ownerDetails', {ownerId: ownerId});
            });
        };
    }]);
