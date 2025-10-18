'use strict';

// API Gateway URL 설정 (CloudFront에서 /api/* 경로를 API Gateway로 라우팅하므로 /api 접두사 제거)
var API_GATEWAY_URL = window.location.origin;

angular.module('infrastructure', [])
    .constant('API_BASE_URL', API_GATEWAY_URL);
