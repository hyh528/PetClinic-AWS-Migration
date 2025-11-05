/*
 * Copyright 2002-2021 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.springframework.samples.petclinic.admin;

import org.springframework.context.annotation.Configuration;

/**
 * Admin 서버 설정 클래스
 * Spring Boot Admin의 자동 디스커버리 기능을 사용합니다.
 * 수동 등록 로직은 제거되고, 클라이언트들이 직접 Admin Server에 등록합니다.
 */
@Configuration
public class AdminServerConfig {
    // Spring Boot Admin Server의 자동 디스커버리 기능만 사용
    // 클라이언트 서비스들은 spring.boot.admin.client.enabled=true로 설정되어
    // 직접 Admin Server에 등록됩니다.
}