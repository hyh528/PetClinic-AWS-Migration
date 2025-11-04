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

import de.codecentric.boot.admin.server.domain.entities.Instance;
import de.codecentric.boot.admin.server.domain.entities.InstanceRepository;
import de.codecentric.boot.admin.server.domain.values.InstanceId;
import de.codecentric.boot.admin.server.domain.values.Registration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;

import java.util.HashMap;
import java.util.Map;

/**
 * Admin 서버 설정 클래스
 * ECS 환경에서 다른 서비스들을 수동으로 등록합니다.
 */
@Configuration
public class AdminServerConfig {

    @Autowired
    private InstanceRepository instanceRepository;

    @Autowired
    private Environment environment;

    /**
     * 애플리케이션 시작 후 서비스들을 자동으로 등록합니다.
     */
    @EventListener(ApplicationReadyEvent.class)
    public void registerServices() {
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

    /**
     * 재시도 로직을 포함한 서비스 등록
     */
    private void registerServiceWithRetry(String serviceName, String serviceUrl) {
        int maxRetries = 3;
        for (int i = 0; i < maxRetries; i++) {
            try {
                // 헬스체크 먼저 확인
                if (checkServiceHealth(serviceUrl + "/actuator/health")) {
                    registerService(serviceName, serviceUrl);
                    return;
                } else {
                    System.out.println("⚠️ " + serviceName + " 헬스체크 실패, 재시도 " + (i + 1) + "/" + maxRetries);
                    Thread.sleep(10000); // 10초 대기 후 재시도
                }
            } catch (Exception e) {
                System.err.println("❌ " + serviceName + " 등록 시도 " + (i + 1) + " 실패: " + e.getMessage());
                if (i < maxRetries - 1) {
                    try {
                        Thread.sleep(10000); // 10초 대기 후 재시도
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        break;
                    }
                }
            }
        }
        System.err.println("❌ " + serviceName + " 등록 최종 실패 (모든 재시도 소진)");
    }

    /**
     * 서비스 헬스체크 확인
     */
    private boolean checkServiceHealth(String healthUrl) {
        try {
            // 간단한 HTTP 요청으로 헬스체크 확인
            java.net.URL url = new java.net.URL(healthUrl);
            java.net.HttpURLConnection connection = (java.net.HttpURLConnection) url.openConnection();
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(5000);
            connection.setReadTimeout(5000);
            
            int responseCode = connection.getResponseCode();
            System.out.println("🔍 " + healthUrl + " 응답 코드: " + responseCode);
            return responseCode == 200;
        } catch (Exception e) {
            System.err.println("❌ 헬스체크 실패 " + healthUrl + ": " + e.getMessage());
            return false;
        }
    }

    /**
     * 개별 서비스를 Admin 서버에 등록합니다.
     */
    private void registerService(String serviceName, String serviceUrl) {
        try {
            Map<String, String> metadata = new HashMap<>();
            metadata.put("tags.environment", "aws");
            metadata.put("tags.version", "3.4.1");

            Registration registration = Registration.create(serviceName, serviceUrl + "/actuator/health")
                    .managementUrl(serviceUrl + "/actuator")
                    .serviceUrl(serviceUrl)
                    .metadata(metadata)
                    .build();

            instanceRepository.save(Instance.create(InstanceId.of(serviceName)).register(registration));
            System.out.println("✅ " + serviceName + " 서비스가 등록되었습니다: " + serviceUrl);
        } catch (Exception e) {
            System.err.println("❌ " + serviceName + " 등록 실패: " + e.getMessage());
            e.printStackTrace();
        }
    }
}