'use strict';

// API Gateway URL 설정 (실제 API Gateway 엔드포인트 사용)
var API_GATEWAY_URL = 'https://u05w9zzu1h.execute-api.us-west-2.amazonaws.com/v1';

angular.module('infrastructure', [])
    .constant('API_BASE_URL', API_GATEWAY_URL);
