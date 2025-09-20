# Spring PetClinic MSA on AWS: 클라우드 마이그레이션 프로젝트

이 프로젝트는 널리 알려진 오픈소스 애플리케이션인 **Spring PetClinic Microservices**를 기존의 온프레미스 환경에서 **AWS 클라우드 네이티브 환경으로 성공적으로 이전(Migration)하는 과정을 담은 포트폴리오 프로젝트**입니다.

단순한 서버 이전(Lift & Shift)을 넘어, AWS의 관리형 서비스와 서버리스 기술을 적극적으로 활용하여 운영 효율성, 확장성, 보안성을 극대화하는 것을 목표로 합니다.

---

## 👥 팀원 및 역할 (Team & Roles)

| 역할 (Role) | 담당자 (Member) | 주요 기여 (Key Contributions) |
|---|---|---|
| **PM & Infra/Automation** | 영현 | 프로젝트 총괄, 인프라 설계(IaC), CI/CD 구축 |
| **Application & Deployment** | 석겸 | 애플리케이션 분석, 컨테이너화, ECS 배포 |
| **Data & Migration** | 준제 | 데이터베이스 마이그레이션, 설정 관리 이전 |
| **Security & Compliance** | 휘권 | 보안 아키텍처 설계, 모니터링 전략 수립 |

---

## 🚀 최종 목표 아키텍처 (To-Be Architecture)

![To-Be Architecture Diagram](docs/to-be-architecture.png)
*위 다이어그램은 1주차에 팀이 확정한 최종 목표 아키텍처 이미지로 교체될 예정입니다.*

### 아키텍처 흐름

1.  사용자의 요청은 **Amazon API Gateway**를 통해 수신됩니다.
2.  API Gateway는 요청을 **Application Load Balancer(ALB)** 로 전달합니다.
3.  ALB는 트래픽을 각 마이크로서비스가 실행 중인 **Amazon ECS (Fargate)** 컨테이너로 분산합니다.
4.  각 서비스는 **Amazon RDS**에 격리된 데이터베이스를 사용하며, 모든 설정 정보는 **AWS Systems Manager Parameter Store**를 통해 안전하게 관리됩니다.
5.  모든 인프라의 지표와 로그는 **Amazon CloudWatch**로 중앙에서 수집 및 모니터링됩니다.

---

## ✨ 프로젝트 핵심 특징 (Key Features)

### 1. Infrastructure as Code (IaC)
- 모든 AWS 인프라(VPC, ECS, RDS 등)는 **Terraform** 코드로 관리됩니다.
- 이를 통해 인프라를 언제든 동일한 구성으로, 빠르고 안정적으로 재생성할 수 있습니다.

### 2. CI/CD Automation
- **GitHub Actions**를 활용하여 빌드-테스트-배포 파이프라인을 완전 자동화했습니다.
- `develop` 브랜치에 코드가 Merge되면, 자동으로 Docker 이미지를 빌드하여 ECR에 Push하고, ECS 서비스에 무중단으로 배포합니다.

### 3. Cloud-Native & Serverless
- EC2 인스턴스를 직접 관리할 필요가 없는 서버리스 컨테이너 엔진 **AWS Fargate**를 사용하여 운영 부담을 최소화했습니다.
- 데이터베이스, 파라미터 관리 등에도 **AWS의 완전 관리형 서비스**를 적극 활용하여 핵심 비즈니스 로직에만 집중할 수 있는 환경을 구축했습니다.

### 4. Security & Monitoring
- **IAM**과 **Security Group**을 통해 '최소 권한의 원칙'에 입각한 접근 제어를 구현했습니다.
- **Amazon CloudWatch**를 통해 모든 서비스의 로그와 지표를 중앙에서 관리하여 시스템의 가시성을 확보하고, 이상 상황 발생 시 즉각적인 알림을 받을 수 있도록 구성했습니다.

---

## 🛠️ 기술 스택 (Tech Stack)

- **Cloud:** `AWS`
- **IaC:** `Terraform`
- **CI/CD:** `GitHub Actions`
- **Container:** `Docker`, `Amazon ECR`
- **Orchestration:** `Amazon ECS (Fargate)`
- **Database:** `Amazon RDS for MySQL`
- **Networking:** `Amazon VPC`, `API Gateway`, `Application Load Balancer`
- **Monitoring:** `Amazon CloudWatch`
- **Config Management:** `AWS Systems Manager Parameter Store`

---

## 🙏 원본 프로젝트 (Original Project)

본 프로젝트는 Spring 커뮤니티에서 제공하는 아래의 훌륭한 오픈소스 프로젝트를 기반으로 마이그레이션을 진행했습니다.

- **Original Repository:** [spring-petclinic/spring-petclinic-microservices](https://github.com/spring-petclinic/spring-petclinic-microservices)