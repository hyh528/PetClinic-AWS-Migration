---
name: "❓ 질문/도움 요청"
about: 개발 중 막히는 부분이나 도움이 필요할 때 사용합니다.
title: "[Help] "
labels: 'question'
assignees: ''

---

## 겪고 있는 문제 (Problem)
<!-- 현재 어떤 문제에 부딪혔는지 최대한 상세하게 설명해주세요. -->
<!-- 예: `docker-compose up` 명령어로 로컬에서 MSA 환경을 실행하려 하지만, `discovery-server`가 정상적으로 실행되지 않고 바로 종료됩니다. -->


## 💻 시도해본 것들 (Troubleshooting History)
<!-- 이 문제를 해결하기 위해 어떤 시도들을 해봤는지 순서대로 작성해주세요. 동료가 같은 실수를 반복하지 않게 도와줍니다. -->
1. `docker-compose.yml` 파일의 `discovery-server` 포트 번호를 8761에서 8762로 변경해보았으나 동일한 증상 발생.
2. `mvnw clean install` 명령어로 전체 프로젝트를 다시 빌드한 후 시도했으나 실패.
3. 구글에 "spring eureka server immediately shutdown" 키워드로 검색하여 관련 스택오버플로우 글들을 확인해봄.


## ⛔️ 에러 메시지 (Error Message)
<!-- 발생한 에러 메시지 전체를 복사해서 붙여넣어 주세요. (```로 감싸면 보기 좋습니다) -->
```
(여기에 에러 메시지 붙여넣기)
```


## ⚙️ 개발 환경 (Environment)
<!-- 자신의 개발 환경 정보를 알려주세요. -->
- **OS:** (예: Windows 11, macOS Sonoma)
- **Docker version:** 
- **Java version:** 
