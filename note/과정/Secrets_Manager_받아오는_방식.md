# ECS에서 Secrets Manager 비밀번호를 받아오는 올바른 방식

이 문서는 Terraform을 사용하여 ECS Task Definition에 AWS Secrets Manager의 데이터베이스 비밀번호를 전달할 때, "비밀번호가 틀리다"는 오류가 발생하는 문제의 원인과 해결 방안을 설명합니다.

## 1. 문제 상황

Terraform의 `terraform_remote_state`를 사용해 동적으로 Secrets Manager의 ARN을 참조하도록 코드를 수정했더니, 애플리케이션 로그에 데이터베이스 비밀번호가 틀렸다는 오류가 발생했습니다.

- **수정 전 (하드코딩):** 정상 작동
  ```terraform
  "SPRING_DATASOURCE_PASSWORD" = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:rds!cluster-...-XXXXXX:password::"
  ```

- **수정 후 (동적 참조):** DB 비밀번호 오류 발생
  ```terraform
  "SPRING_DATASOURCE_PASSWORD" = data.terraform_remote_state.database.outputs.db_master_user_secret_arn
  ```

## 2. 근본 원인: Secrets Manager의 저장 방식

이 문제의 원인은 AWS Secrets Manager가 RDS 데이터베이스의 비밀번호를 저장하는 방식에 있습니다.

Secrets Manager는 비밀번호를 단순 텍스트가 아닌, 여러 정보를 포함한 **JSON 형식의 문자열**로 저장합니다.

**실제 Secrets Manager에 저장된 값 (예시):**
```json
{
  "username": "admin",
  "password": "the-real-password-is-here",
  "host": "your-rds-endpoint.rds.amazonaws.com",
  "port": 3306,
  "dbClusterIdentifier": "your-db-cluster"
}
```

`data.terraform_remote_state`를 통해 가져온 ARN(`db_master_user_secret_arn`)만 사용하면, ECS 컨테이너의 `SPRING_DATASOURCE_PASSWORD` 환경 변수에는 저 **JSON 문자열 전체가 값으로 들어가게 됩니다.**

결국, Spring 애플리케이션은 비밀번호로 실제 비밀번호(`the-real-password-is-here`)를 기대하는데, `{ "username": ... }`로 시작하는 거대한 JSON 덩어리를 받게 되므로 인증에 실패하는 것입니다.

## 3. 해결 방안: JSON 키 지정 문법 사용

이 문제를 해결하기 위해, ECS Task Definition의 `secrets` 블록은 특별한 문법을 제공합니다. 바로 ARN 뒤에 `:json-key::` 형식을 붙여주는 것입니다.

원래 하드코딩되어 있던 코드의 뒷부분인 **`:password::`** 가 바로 "가져온 Secret 값(JSON)에서 `password` 라는 키(key)의 값(value)만 추출해서 환경 변수에 넣어줘" 라는 특별한 지시어입니다.

따라서, 동적으로 가져온 ARN 값 뒤에 이 지시어를 다시 붙여주면 문제가 해결됩니다.

---

## 4. 최종 코드 수정 제안

**파일:** `terraform/envs/dev/application/ecs.tf`

`secrets_variables` 블록의 `SPRING_DATASOURCE_PASSWORD` 부분을 아래와 같이 `${...}` 문법을 사용해서 동적 ARN과 문자열을 합쳐주면 됩니다.

```terraform
# ... (상단 생략) ...

 secrets_variables = {
    # "나쁜 방식" (하드코딩)
    # "SPRING_DATASOURCE_PASSWORD" = "arn:aws:secretsmanager:ap-northeast-2:897722691159:secret:rds!cluster-0edf3242-4cb9-4b90-9896-52cc5068a5fb-XmjB9d:password::",
    
    # "좋은 방식" (동적 참조 + JSON 키 지정)
    "SPRING_DATASOURCE_PASSWORD" = "${data.terraform_remote_state.database.outputs.db_master_user_secret_arn}:password::",
    
    # URL과 Username도 동일한 원리가 적용될 수 있습니다.
    # 만약 해당 값들도 JSON 형식으로 저장되어 있다면 아래와 같이 수정할 수 있습니다.
    "SPRING_DATASOURCE_URL"      = "${data.terraform_remote_state.database.outputs.db_url_parameter_arn}:url::",
    "SPRING_DATASOURCE_USERNAME" = "${data.terraform_remote_state.database.outputs.db_username_parameter_arn}:username::"
  }

# ... (이하 생략) ...
```

### 결론

Terraform으로 ECS에 Secrets Manager의 RDS 비밀번호를 주입할 때는, `outputs`에서 가져온 **ARN 값 뒤에 반드시 `:password::` 와 같은 JSON 키 지정자를 붙여주어야** 애플리케이션이 정확한 비밀번호 값을 인식할 수 있습니다.
