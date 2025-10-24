#!/bin/bash
#docker push ${REPOSITORY_PREFIX}/spring-petclinic-config-server:${VERSION}
#docker push ${REPOSITORY_PREFIX}/spring-petclinic-discovery-server:${VERSION}
#docker push ${REPOSITORY_PREFIX}/spring-petclinic-api-gateway:${VERSION}
docker push 897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/admin-server:latest
docker push 897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/visits-service:latest
docker push 897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/vets-service:latest
docker push 897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/customers-service:latest
