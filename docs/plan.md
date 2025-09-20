# Spring PetClinic MSA 프로젝트 AWS 마이그레이션 로드맵

## 멘토의 한마디

반갑습니다, 미래의 클라우드 전문가 여러분. 지금부터 7주간 여러분은 온프레미스 환경의 애플리케이션을 AWS 클라우드로 성공적으로 이전하는 여정을 시작합니다. 이 프로젝트는 단순히 기술을 배우는 것을 넘어, 실제 현업에서 마주할 문제들을 해결하고, 동료와 협업하며, 결과물을 명확하게 문서화하고 발표하는 종합적인 실무 경험을 제공할 것입니다. 각자 역할을 맡되, 항상 동료의 작업을 궁금해하고 서로 도우며 함께 성장하시기 바랍니다. 이 7주가 여러분의 커리어에 단단한 초석이 될 것이라 확신합니다.

---

## 1. 전체 로드맵 개요

**프로젝트 목표:** GitHub의 `spring-petclinic-microservices`를 온프레미스 환경에서 AWS 클라우드로 이전, 운영 및 최적화한다.

**핵심 전략:**
- **Re-platform/Re-architect:** 단순한 'Lift & Shift'를 넘어, 각 마이크로서비스의 특성에 맞게 컨테이너화하고, AWS의 관리형 서비스(Managed Service)를 적극 활용하여 클라우드 네이티브 아키텍처로 전환한다.
- **Infrastructure as Code (IaC):** 모든 인프라 구성을 코드로 관리(Terraform 사용)하여 재현성과 확장성을 확보한다.
- **CI/CD 자동화:** GitHub Actions를 활용하여 소스 코드 변경 시 자동으로 빌드, 테스트, 배포가 이루어지는 파이프라인을 구축한다.
- **Well-Architected Framework:** AWS의 6가지 원칙(운영 우수성, 보안, 안정성, 성능 효율성, 비용 최적화, 지속 가능성)을 프로젝트 전반에 걸쳐 적용한다.

**최종 목표 아키텍처 (To-Be):**
![Target Architecture](https://user-images.githubusercontent.com/12345678/123456789-abcdef.png)  *<-- 이 부분은 1주차에 팀원들이 직접 그릴 아키텍처 다이어그램 이미지 링크로 대체될 것입니다.*

---

## 2. 7주 주차별 상세 계획

### 역할 분담 (4인 기준)

**핵심 원칙:** 아래와 같이 주도적인 리드 역할을 나누되, 모든 팀원은 AWS 기본 인프라 구성(VPC, IAM 등)과 전체 마이그레이션 과정에 함께 참여하며 학습합니다. 각 리드는 자신의 담당 분야에 대한 학습과 실행을 주도하고, 그 내용을 팀원들에게 공유할 의무를 가집니다.

| 역할 (담당자) | 주요 책임 및 활동 (Key Responsibilities & Activities) |
|---|---|
| **PM & Infra/Automation Lead** <br> (영현) | - **프로젝트 총괄 관리:** 전체 일정, 작업 분배, 팀 협업 리딩<br>- **인프라 설계 및 구축 주도:** VPC, Subnet, ECS, ALB 등 핵심 인프라 설계 및 Terraform 코드 작성 주도<br>- **자동화 설계 및 구축 주도:** CI/CD 파이프라인(GitHub Actions), Docker 이미지 빌드 및 배포 자동화<br>- **협업 환경 지원:** GitHub 브랜치/템플릿 설정, 코드리뷰/Merge 정책 수립 및 가이드 |
| **Application & Deployment Lead** <br> (석겸) | - **애플리케이션 분석 주도:** PetClinic 소스코드 구조, 서비스 간 의존성 및 API 흐름 분석<br>- **컨테이너화 및 배포 주도:** 각 서비스의 Dockerfile 작성, ECS Task Definition 정의<br>- **배포 후 최적화:** 서비스 배포 후 성능 모니터링 및 리소스 최적화 방안 제시 |
| **Data & Migration Lead** <br> (준제) | - **데이터 마이그레이션 주도:** RDS 인스턴스 생성, 스키마 이전 및 데이터 마이그레이션 실행<br>- **설정 정보 관리 주도:** `Config Server`를 AWS Parameter Store/Secrets Manager로 전환하는 작업 리딩<br>- **마이그레이션 검증:** 클라우드 환경으로 이전된 애플리케이션의 기능이 정상 동작하는지 검증 및 테스트 |
| **Security & Compliance Lead** <br> (휘권) | - **보안 아키텍처 설계 주도:** IAM 정책, Security Group, 네트워크 접근 제어(NACL) 등 보안 규칙 수립<br>- **거버넌스 및 컴플라이언스:** AWS 모범 사례(Well-Architected) 준수 여부 점검 및 개선<br>- **모니터링 및 로깅 전략 수립:** CloudWatch를 활용한 중앙 집중식 로깅 및 이상 행위 탐지 전략 수립 |

**참고:** 석겸님과 준제님의 역할은 애플리케이션과 데이터라는 밀접한 영역을 다루므로, 프로젝트 진행 상황에 따라 서로의 작업을 적극적으로 돕고 유연하게 협력하여 시너지를 낼 수 있습니다.
### 주차별 계획

#### **1주차: 분석 및 설계 (As-Is & To-Be)**
- **목표:** 현재 애플리케이션 구조를 분석하고, 목표 AWS 아키텍처를 설계한다.
- **실습 작업:**
    1. `spring-petclinic-microservices`를 로컬/온프레미스 환경에서 직접 실행 및 테스트.
    2. 각 서비스(customers, vets, visits 등)의 역할과 서비스 간 통신 방식(API Gateway, Discovery Server) 파악.
    3. 현재 아키텍처(As-Is) 다이어그램 작성.
    4. AWS 클라우드 환경에 최적화된 목표 아키텍처(To-Be) 설계 및 다이어그램 작성.
- **AWS 서비스:** 없음 (분석 및 설계 단계)
- **역할 분담:** 전원 참여 (팀 전체가 동일한 이해도를 갖는 것이 중요)
- **산출물:**
    - As-Is 아키텍처 다이어그램
    - To-Be 아키텍처 다이어그램 (각 서비스가 어떤 AWS 서비스로 대체될지 명시)
    - 기술 스택 선정 및 근거 자료

#### **2주차: 핵심 인프라 구축 (IaC)**
- **목표:** Terraform을 사용하여 AWS의 기본 네트워크 및 보안 환경을 코드로 구축한다.
- **실습 작업:**
    1. Terraform 학습 및 개발 환경 설정.
    2. 가용 영역(AZ) 2개 이상을 사용하는 고가용성 VPC 설계 및 구축 (Public/Private Subnets, NAT Gateway, Internet Gateway).
    3. 프로젝트 팀원 및 각 AWS 서비스가 사용할 IAM 역할(Role) 및 정책(Policy) 정의 및 생성.
- **AWS 서비스:** `VPC`, `IAM`, `EC2` (Bastion Host용)
- **역할 분담:**
    - **Infra Lead:** VPC 및 네트워크 구성 주도.
    - **Security Lead:** IAM 역할 및 정책 설계 주도.
    - **전원:** Terraform 코드 리뷰 및 페어 프로그래밍 참여.
- **산출물:**
    - Terraform 코드 (`.tf` 파일)
    - 구축된 VPC 네트워크 구성도

#### **3주차: 데이터 및 설정 정보 마이그레이션**
- **목표:** 애플리케이션의 데이터베이스와 설정 정보를 AWS 관리형 서비스로 이전한다.
- **실습 작업:**
    1. 각 마이크로서비스용 `RDS for MySQL` 인스턴스 생성. (Private Subnet에 배치)
    2. 기존 DB 스키마 마이그레이션 및 초기 데이터 적재.
    3. `Config Server`를 `AWS Systems Manager Parameter Store` 또는 `Secrets Manager`로 대체.
    4. 애플리케이션 코드 수정 (DB 접속 정보, 설정 값 등을 Parameter Store에서 읽어오도록 변경).
- **AWS 서비스:** `RDS`, `Systems Manager Parameter Store`, `Secrets Manager`
- **역할 분담:**
    - **Data Lead:** RDS 생성 및 데이터 마이그레이션 주도.
    - **DevOps Lead:** 애플리케이션 코드 수정 지원.
- **산출물:**
    - 생성된 RDS 인스턴스 정보 및 접속 방법 문서.
    - Parameter Store에 저장된 설정 값 목록.
    - 수정된 애플리케이션 소스 코드 (Git Commit).

#### **4주차: 컨테이너화 및 이미지 저장**
- **목표:** 각 마이크로서비스를 Docker 컨테이너로 패키징하고, ECR에 저장한다.
- **실습 작업:**
    1. 각 서비스별 `Dockerfile` 작성.
    2. 로컬에서 Docker 이미지를 빌드하고, 컨테이너가 정상 실행되는지 테스트.
    3. `AWS ECR`(Elastic Container Registry)에 Private Repository 생성.
    4. 빌드된 Docker 이미지를 ECR에 Push.
- **AWS 서비스:** `ECR`
- **역할 분담:**
    - **DevOps Lead:** Dockerfile 작성 및 ECR 관리 주도.
    - **전원:** 각자 담당하는 서비스의 Dockerfile 작성 및 테스트 참여.
- **산출물:**
    - 각 서비스의 `Dockerfile`.
    - ECR에 Push된 Docker 이미지 목록.

#### **5주차: 서비스 배포 (ECS Fargate & API Gateway)**
- **목표:** 컨테이너화된 애플리케이션을 서버리스 환경에 배포하고 외부와 통신하도록 구성한다.
- **실습 작업:**
    1. `ECS Cluster` 생성.
    2. `Application Load Balancer`(ALB) 생성.
    3. 각 서비스에 대한 `Task Definition` 및 `ECS Service` 생성 (Fargate 시작 유형 사용).
        - `Discovery Server`를 `ECS Service Discovery`로 대체.
    4. `API Gateway`를 생성하여 외부 요청을 내부 ALB로 라우팅하도록 구성.
- **AWS 서비스:** `ECS (Fargate)`, `Application Load Balancer`, `API Gateway`, `Cloud Map`
- **역할 분담:**
    - **DevOps Lead:** ECS 클러스터, Task Definition, Service 구성 주도.
    - **Infra Lead:** ALB 및 API Gateway 구성 주도.
- **산출물:**
    - ECS 서비스 구성 Terraform 코드.
    - API Gateway 엔드포인트 URL.
    - 배포된 애플리케이션 정상 동작 확인 결과.

#### **6주차: CI/CD 자동화 및 모니터링**
- **목표:** 코드 변경부터 배포까지의 과정을 자동화하고, 서비스 상태를 모니터링한다.
- **실습 작업:**
    1. `GitHub Actions` 워크플로우 수정.
        - `main` 브랜치에 Push 시, Docker 이미지 빌드 -> ECR Push -> ECS 서비스 업데이트가 순차적으로 실행되도록 구성.
    2. `CloudWatch`를 사용하여 CPU/Memory 사용률, ALB 요청 수 등 핵심 지표 모니터링.
    3. 주요 지표에 대한 `CloudWatch Alarm` 설정 (예: CPU 80% 이상 시 알림).
    4. `CloudWatch Logs`를 통해 각 서비스의 로그를 중앙에서 확인.
- **AWS 서비스:** `CloudWatch` (Logs, Metrics, Alarms), `GitHub Actions`
- **역할 분담:**
    - **DevOps Lead:** GitHub Actions CI/CD 파이프라인 구축 주도.
    - **Monitoring Lead:** CloudWatch 대시보드 및 알람 설정 주도.
- **산출물:**
    - `github/workflows` 내의 CI/CD 워크플로우 `.yml` 파일.
    - CloudWatch 모니터링 대시보드 스크린샷.
    - 자동 배포 시연 영상 또는 로그.

#### **7주차: 최적화, 문서화 및 발표 준비**
- **목표:** 비용 및 보안을 최적화하고, 프로젝트 전체를 문서화하며 최종 발표를 준비한다.
- **실습 작업:**
    1. **비용 최적화:** `AWS Cost Explorer`를 통해 비용 분석, Fargate/RDS 인스턴스 Right-sizing 검토.
    2. **보안 강화:** `Security Group` Inbound/Outbound 규칙 최소화, `IAM` 정책 최소 권한 원칙 준수 여부 검토.
    3. **부하 테스트 (선택):** `JMeter` 등을 사용하여 API Gateway에 부하를 주어 ECS Auto Scaling 동작 확인.
    4. 최종 프로젝트 산출물 정리 및 문서화 (GitHub README, Wiki 등).
    5. 최종 발표 자료(PPT) 제작 및 리허설.
- **AWS 서비스:** `Cost Explorer`, `Trusted Advisor`
- **역할 분담:** 전원 참여. 각자 리딩했던 부분을 중심으로 문서화 및 발표 자료 작성.
- **산출물:**
    - 비용 최적화 분석 보고서.
    - 보안 강화 조치 내역.
    - 최종 프로젝트 발표 자료 (PPT).
    - 잘 정리된 GitHub Repository (README, 아키텍처 다이어그램, IaC 코드 등).

---

## 3. 프로젝트 중 반드시 고려해야 할 AWS 베스트 프랙티스

- **보안 (Security):**
    - **최소 권한의 원칙:** IAM 사용자, 역할, 정책은 꼭 필요한 권한만 부여합니다.
    - **네트워크 분리:** Security Group과 NACL을 사용하여 인스턴스와 서브넷 레벨에서 접근을 제어합니다. DB는 Private Subnet에 배치하고 Bastion Host나 내부 서비스를 통해서만 접근하도록 합니다.
    - **데이터 암호화:** RDS, S3 등 데이터를 저장하는 모든 서비스에서 암호화 옵션을 활성화합니다.

- **비용 (Cost Optimization):**
    - **관리형 서비스 활용:** 직접 EC2에 설치하는 것보다 RDS, Fargate, API Gateway 등 관리형 서비스를 사용해 운영 비용을 절감합니다.
    - **서버리스 우선 고려:** 사용량이 적거나 예측 불가능한 워크로드에는 EC2보다 Fargate나 Lambda를 우선적으로 고려합니다.
    - **Billing Alarm 설정:** 예산을 초과하는 비용이 발생하지 않도록 AWS Budgets에서 결제 알람을 설정합니다.

- **운영 자동화 (Operational Excellence):**
    - **Infrastructure as Code (IaC):** 모든 인프라를 Terraform 코드로 관리하여 수동 작업을 없애고 일관성을 유지합니다.
    - **CI/CD:** 배포 파이프라인을 자동화하여 사람의 실수를 줄이고 배포 속도를 높입니다.
    - **중앙 집중식 로깅:** CloudWatch Logs를 사용하여 모든 서비스의 로그를 한 곳에서 검색하고 분석할 수 있도록 합니다.

- **확장성 및 성능 (Performance Efficiency):**
    - **Auto Scaling:** ECS 서비스에 Auto Scaling을 적용하여 트래픽에 따라 컨테이너 수를 자동으로 조절하도록 합니다.
    - **Load Balancing:** Application Load Balancer를 사용하여 여러 컨테이너에 트래픽을 분산시킵니다.
    - **글로벌 서비스 활용:** API Gateway, CloudFront(선택) 등 리전 단위로 제공되는 확장성 높은 서비스를 활용합니다.

---

## 4. 프로젝트 종료 후 포트폴리오에 포함해야 할 최종 결과물 목록

1.  **GitHub Repository:**
    - **README.md:** 프로젝트 개요, 최종 아키텍처 다이어그램, 사용된 기술 스택, 배포 및 실행 방법, 팀원별 역할 소개 등을 상세히 기술.
    - **IaC 코드:** `terraform/` 디렉터리에 모든 인프라 구성 코드를 포함.
    - **CI/CD 파이프라인 코드:** `.github/workflows/` 디렉터리에 배포 자동화 워크플로우 코드를 포함.
    - **애플리케이션 소스 코드:** AWS 서비스 연동을 위해 수정된 `spring-petclinic-microservices` 코드.

2.  **프로젝트 최종 발표 자료 (PPT):**
    - 프로젝트 목표 및 배경.
    - As-Is 및 To-Be 아키텍처 비교 분석.
    - 마이그레이션 과정에서 발생한 문제 및 해결 과정 (Troubleshooting 경험).
    - AWS Well-Architected Framework 관점에서의 성과 (비용 절감 효과, 보안 강화 내역 등).
    - 서비스 동작 시연 영상.
    - 프로젝트를 통해 배운 점 및 개인별 소감.

3.  **기술 블로그 포스팅 (권장):**
    - 팀원 각자가 담당했던 파트(예: "Terraform으로 VPC 구축하기", "GitHub Actions와 ECS Fargate로 CI/CD 구축하기")에 대해 상세한 기술 블로그를 작성하여 프로젝트 경험을 공유하고 깊이를 더합니다.

---

## 5. 팀 협업 및 발표 전략

- **효과적인 협업 방식:**
    - **일일 스크럼 (Daily Scrum):** 매일 짧게 진행 상황, 문제점, 계획을 공유합니다. (어제 한 일, 오늘 할 일, 어려운 점)
    - **Git-flow 전략:** `main`, `develop`, `feature` 브랜치를 활용하여 체계적으로 코드를 관리합니다. 모든 코드는 동료의 코드 리뷰(Pull Request)를 거친 후 `develop` 브랜치에 병합합니다.
    - **지식 공유 세션:** 각자 리딩한 기술(Terraform, ECS 등)에 대해 다른 팀원들에게 설명하는 세션을 주기적으로 갖습니다.
    - **문서화:** 모든 논의 과정과 결정 사항은 GitHub Wiki나 이슈 트래커에 기록하여 투명하게 관리합니다.

- **성공적인 발표 준비:**
    - **스토리텔링:** "우리는 이런 문제에 직면했고, 이런 기술을 사용해 이렇게 해결했으며, 그 결과 이런 성과를 얻었다"는 명확한 스토리라인을 만듭니다.
    - **역할 분담:** 각자 가장 자신 있는, 직접 리딩했던 부분을 발표합니다.
    - **데모 준비:** 라이브 데모는 위험 부담이 크므로, 안정적인 동작을 녹화한 영상을 준비하는 것을 추천합니다.
    - **예상 질문 대비:** 면접관의 입장에서 궁금해할 만한 질문(예: "왜 EKS가 아닌 ECS를 선택했나요?", "비용을 더 줄일 방법은 없었나요?") 목록을 만들고 답변을 미리 준비합니다.

이 로드맵을 충실히 따라온다면, 여러분은 단순한 '수료생'이 아닌 '실무 경험을 갖춘 주니어 클라우드 엔지니어'로 거듭날 것입니다. 성공적인 프로젝트 완수를 응원합니다!
