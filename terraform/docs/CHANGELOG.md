# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2025-01-10

### Added - Phase 1: 공유 시스템 구축 완료
- **업계 표준 Backend 관리 시스템 구현**
  - backend.hcl 템플릿 방식 적용 (DRY 원칙 준수)
  - 레이어별 상태 분리 (dev/01-network/terraform.tfstate 형식)
  - 도쿄 리전 전용 S3 버킷 및 DynamoDB 테이블 생성
- **공유 변수 시스템 구축**
  - shared-variables.tf 중앙 집중식 변수 관리
  - 모든 공통 변수 통합 (name_prefix, environment, aws_region, tags)
  - 변수 타입 및 description 명확히 정의
- **자동화 스크립트 개선**
  - init-layer.ps1 스크립트 업계 표준 방식으로 재작성
  - 색상 출력 및 에러 처리 개선
  - Backend 템플릿 자동 복사 기능 추가

### Changed - 아키텍처 표준화
- **Backend 설정 표준화**
  - 중앙 집중식 backend.tf에서 backend.hcl 템플릿 방식으로 변경
  - 모든 레이어에서 동일한 backend.tf 템플릿 사용
  - required_providers 중복 제거 (providers.tf에서만 정의)
- **상태 관리 개선**
  - 개인 경로 제거 (dev/yeonghyeon/network → dev/01-network/terraform.tfstate)
  - 표준화된 상태 키 형식 적용
  - 레이어별 독립적 상태 관리로 변경 범위 최소화

### Removed - 불필요한 복잡성 제거
- **11-state-management 레이어 완전 제거**
  - 순환 의존성 문제 해결
  - 복잡한 템플릿 시스템 제거
  - Bootstrap 디렉토리로 상태 관리 이동
- **모든 참조 정리**
  - 스크립트, 문서, CI/CD 파일에서 state-management 참조 제거
  - 레이어 실행 순서 문서 업데이트

### Infrastructure - 도쿄 리전 테스트 환경
- **새로운 AWS 리소스 생성**
  - S3 버킷: `petclinic-yeonghyeon-test` (ap-northeast-1)
  - DynamoDB 테이블: `petclinic-yeonghyeon-test-locks` (ap-northeast-1)
  - 버전닝 및 암호화 설정 완료
- **검증 완료**
  - 01-network, 02-security 레이어 초기화 성공
  - 원격 상태 관리 정상 작동 확인

### Technical Debt Resolved
- **DRY 원칙 적용**: 중복 코드 제거, 공유 변수 사용
- **SRP 원칙 적용**: 각 레이어가 단일 책임만 담당
- **업계 표준 준수**: terraform init -backend-config 방식 적용
- **상태 분리**: 변경 범위 최소화 및 병렬 작업 가능

## [1.0.0] - 2025-10-09

### Added
- 초기 Terraform IaC 프로젝트 설정
- 기본 네트워크, 보안, 데이터베이스, 애플리케이션 모듈 구현
- AWS 프로바이더 및 백엔드 설정