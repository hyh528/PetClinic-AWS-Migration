# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 실무형 완전체 Terraform 구조로 재구성
- docs/ 디렉터리에 문서 파일들 정리
- scripts/ 디렉터리에 자동화 스크립트 추가
- ci-cd/ 디렉터리에 GitHub Actions 워크플로우 추가
- 환경별 계층 구조 (01-network, 02-security, etc.) 구현

### Changed
- 기존 폴더 구조를 실무형 구조로 변경
- 환경별 디렉터리 재배치

### Fixed
- 구조 변경으로 인한 경로 참조 수정

## [1.0.0] - 2025-10-09

### Added
- 초기 Terraform IaC 프로젝트 설정
- 기본 네트워크, 보안, 데이터베이스, 애플리케이션 모듈 구현
- AWS 프로바이더 및 백엔드 설정