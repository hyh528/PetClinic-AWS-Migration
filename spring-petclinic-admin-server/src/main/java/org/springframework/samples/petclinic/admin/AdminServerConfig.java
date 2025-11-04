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
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;

import java.net.URI;
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
        try {
            // ALB를 통한 서비스 등록
            String albDnsName = environment.getProperty("petclinic.alb.dns-name", "petclinic-alb-1234567890.ap-northeast-2.elb.amazonaws.com");
            
            registerService("customers-service", "http://" + albDnsName + "/api/customers");
            registerService("vets-service", "http://" + albDnsName + "/api/vets");
            registerService("visits-service", "http://" + albDnsName + "/api/visits");
            
            System.out.println("✅ Admin 서버에 모든 서비스가 등록되었습니다.");
        } catch (Exception e) {
            System.err.println("❌ 서비스 등록 중 오류 발생: " + e.getMessage());
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
        }
    }
}