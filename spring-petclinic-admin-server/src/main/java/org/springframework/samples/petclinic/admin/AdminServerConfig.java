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

// Auto-registration imports removed - no longer needed
// import de.codecentric.boot.admin.server.domain.entities.Instance;
// import de.codecentric.boot.admin.server.domain.entities.InstanceRepository;
// import de.codecentric.boot.admin.server.domain.values.InstanceId;
// import de.codecentric.boot.admin.server.domain.values.Registration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
// import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
// import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.http.client.reactive.ClientHttpConnector;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;
// import java.util.HashMap;
// import java.util.Map;

/**
 * Admin 서버 설정 클래스
 * ECS 환경에서 다른 서비스들을 수동으로 등록합니다.
 */
@Configuration
public class AdminServerConfig {

    // InstanceRepository removed - auto-registration disabled
    // @Autowired
    // private InstanceRepository instanceRepository;

    @Autowired
    private Environment environment;

    /**
     * Spring Boot Admin이 사용하는 WebClient를 커스터마이즈합니다.
     * WAF 우회를 위한 헤더 및 타임아웃 설정을 추가합니다.
     */
    @Bean
    public WebClient.Builder webClientBuilder() {
        // HTTP 클라이언트 타임아웃 설정
        HttpClient httpClient = HttpClient.create()
            .responseTimeout(Duration.ofSeconds(30))
            .followRedirect(true);
        
        ClientHttpConnector connector = new ReactorClientHttpConnector(httpClient);
        
        return WebClient.builder()
            .clientConnector(connector)
            .defaultHeader("User-Agent", "SpringBootAdmin/3.4.1")
            .defaultHeader("Accept", "application/json, application/*+json")
            .defaultHeader("X-Admin-Request", "true");
    }

    /**
     * 애플리케이션 시작 후 서비스들을 자동으로 등록합니다.
     * 
     * NOTE: 자동 등록 기능은 완전히 비활성화되었습니다.
     * 수동 등록 스크립트(register-services-to-admin.sh)를 사용하세요.
     * 
     * DISABLED: This method is intentionally disabled to prevent automatic registration
     * with incorrect URLs. Use manual registration script instead.
     */
    /* DISABLED - DO NOT ENABLE
    @EventListener(ApplicationReadyEvent.class)
    public void registerServices_DISABLED() {
        // 5초 후에 등록 시도 (서비스들이 완전히 시작될 시간을 줌)
        new Thread(() -> {
            try {
                Thread.sleep(5000); // 5초 대기
                
                // ALB를 통한 서비스 등록
                String albDnsName = environment.getProperty("petclinic.alb.dns-name",
                        "petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com");
                System.out.println("🔍 사용할 ALB DNS 이름: " + albDnsName);

                // 각 서비스 등록 시도
                registerServiceWithRetry("customers-service", "http://" + albDnsName + "/api/customers");
                registerServiceWithRetry("vets-service", "http://" + albDnsName + "/api/vets");
                registerServiceWithRetry("visits-service", "http://" + albDnsName + "/api/visits");

                System.out.println("✅ Admin 서버에 모든 서비스 등록 시도가 완료되었습니다.");
            } catch (Exception e) {
                System.err.println("❌ 서비스 등록 중 오류 발생: " + e.getMessage());
                e.printStackTrace();
            }
        }).start();
    }
    DISABLED - END */

    /* DISABLED - Auto-registration methods removed
     * Use manual registration script: scripts/register-services-to-admin.sh
     * 
     * These methods were causing issues with incorrect URL generation:
     * - Missing trailing slashes in service URLs
     * - Automatic registration conflicting with manual registration
     */
}