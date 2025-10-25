'use strict';

// CloudFront를 통한 API 호출 설정 (Same-Origin 요청으로 CORS 문제 해결)
// CloudFront가 /api/* 경로를 API Gateway로 프록시하므로 상대 경로 사용
var API_BASE_URL = '';  // 빈 문자열로 설정하여 상대 경로 사용

angular.module('infrastructure', [])
    .constant('API_BASE_URL', API_BASE_URL);
