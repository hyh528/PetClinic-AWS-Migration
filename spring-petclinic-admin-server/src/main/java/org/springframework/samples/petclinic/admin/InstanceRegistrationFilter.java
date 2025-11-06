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

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * 잘못된 URL 패턴으로 등록 시도하는 인스턴스를 차단하는 필터
 */
@Component
public class InstanceRegistrationFilter extends OncePerRequestFilter {

    private static final Logger logger = LoggerFactory.getLogger(InstanceRegistrationFilter.class);
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        // /instances POST 요청만 검사
        if ("POST".equalsIgnoreCase(request.getMethod()) && 
            request.getRequestURI().endsWith("/instances")) {
            
            // Request body를 읽기 위한 wrapper
            CachedBodyHttpServletRequest cachedRequest = new CachedBodyHttpServletRequest(request);
            String body = cachedRequest.getReader().lines()
                    .reduce("", (accumulator, actual) -> accumulator + actual);

            try {
                JsonNode json = objectMapper.readTree(body);
                String healthUrl = json.path("healthUrl").asText();
                String serviceUrl = json.path("serviceUrl").asText();
                
                logger.info("Registration attempt - healthUrl: {}, serviceUrl: {}", healthUrl, serviceUrl);

                // 잘못된 패턴 검사
                if (isInvalidPattern(healthUrl, serviceUrl)) {
                    logger.warn("BLOCKED invalid registration attempt - healthUrl: {}, serviceUrl: {}", 
                               healthUrl, serviceUrl);
                    
                    response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
                    response.setContentType("application/json");
                    response.getWriter().write(
                        "{\"error\":\"Invalid URL pattern\",\"message\":\"healthUrl must contain /api/{service}/actuator pattern\"}"
                    );
                    return;
                }
            } catch (Exception e) {
                logger.error("Error parsing registration request: {}", e.getMessage());
            }

            // 정상 요청은 계속 진행
            filterChain.doFilter(cachedRequest, response);
        } else {
            filterChain.doFilter(request, response);
        }
    }

    /**
     * 잘못된 URL 패턴인지 검사
     */
    private boolean isInvalidPattern(String healthUrl, String serviceUrl) {
        if (healthUrl == null || healthUrl.isEmpty()) {
            return true;
        }

        // healthUrl이 /api/{service}/actuator/health 패턴을 따르는지 확인
        if (!healthUrl.matches(".*\\/api\\/[^\\/]+\\/actuator\\/health$")) {
            return true;
        }

        // serviceUrl이 슬래시로 끝나지 않으면 잘못된 것
        if (serviceUrl != null && !serviceUrl.endsWith("/")) {
            return true;
        }

        return false;
    }
}
