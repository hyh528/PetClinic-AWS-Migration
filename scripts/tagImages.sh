#!/bin/bash
#docker tag ${REPOSITORY_PREFIX}/spring-petclinic-config-server ${REPOSITORY_PREFIX}/spring-petclinic-config-server:${VERSION}
#docker tag ${REPOSITORY_PREFIX}/spring-petclinic-discovery-server ${REPOSITORY_PREFIX}/spring-petclinic-discovery-server:${VERSION}
docker tag admin-server 897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/admin-server:latest
docker tag visits-service 897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/visits-service:latest
docker tag vets-service 897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/vets-service:latest
docker tag customers-service 897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/customers-service:latest
#docker tag ${REPOSITORY_PREFIX}/spring-petclinic-admin-server ${REPOSITORY_PREFIX}/spring-petclinic-admin-server:${VERSION}
