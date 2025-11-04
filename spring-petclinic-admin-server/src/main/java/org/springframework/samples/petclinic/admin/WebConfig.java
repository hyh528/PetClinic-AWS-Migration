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
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web 설정 클래스
 * CORS 및 정적 리소스 설정을 담당합니다.
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns("*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // Spring Boot Admin UI 정적 리소스 핸들러
        registry.addResourceHandler("/admin/**")
                .addResourceLocations("classpath:/META-INF/resources/", 
                                    "classpath:/resources/", 
                                    "classpath:/static/", 
                                    "classpath:/public/")
                .setCachePeriod(0);
                
        // Admin UI의 내부 리소스 핸들러
        registry.addResourceHandler("/admin/assets/**")
                .addResourceLocations("classpath:/META-INF/resources/assets/")
                .setCachePeriod(3600);
                
        // Webjars 지원 (Spring Boot Admin이 사용하는 라이브러리들)
        registry.addResourceHandler("/admin/webjars/**")
                .addResourceLocations("classpath:/META-INF/resources/webjars/")
                .setCachePeriod(3600);
    }
}