#!/bin/bash
#docker push ${REPOSITORY_PREFIX}/spring-petclinic-config-server:${VERSION}
#docker push ${REPOSITORY_PREFIX}/spring-petclinic-discovery-server:${VERSION}
#docker push ${REPOSITORY_PREFIX}/spring-petclinic-api-gateway:${VERSION}
docker build -t admin-server:latest ./spring-petclinic-admin-server
docker build -t customers-service:latest ./spring-petclinic-customers-service
docker build -t vets-service:latest ./spring-petclinic-vets-service
docker build -t visits-service:latest ./spring-petclinic-visits-service
