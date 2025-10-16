'use strict';

// API Gateway URL 설정
var API_GATEWAY_URL = window.location.origin + '/api';

angular.module('infrastructure', [])
    .constant('API_BASE_URL', API_GATEWAY_URL);
