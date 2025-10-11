 #!/usr/bin/env python3
"""
Terraform 통합 테스트 실행기
기존 integration-test.sh를 Python으로 재구현하여 더 정교한 테스트 수행
"""

import boto3
import json
import logging
import os
import sys
import time
import yaml
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class TestResult:
    """테스트 결과를 저장하는 데이터 클래스"""
    name: str
    status: str  # PASS, FAIL, SKIP, ERROR
    duration: float
    message: str
    details: Optional[Dict[str, Any]] = None
    timestamp: str = ""
    
    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()

class IntegrationTestRunner:
    """통합 테스트 실행기"""
    
    def __init__(self, config_file: str, environment: str, region: str = "ap-northeast-1"):
        self.config = self._load_config(config_file)
        self.environment = environment
        self.region = region
        self.aws_session = boto3.Session(region_name=region)
        self.results: List[TestResult] = []
        self.start_time = datetime.utcnow()
        
        # AWS 클라이언트 초기화
        self.ec2 = self.aws_session.client('ec2')
        self.ecs = self.aws_session.client('ecs')
        self.rds = self.aws_session.client('rds')
        self.elbv2 = self.aws_session.client('elbv2')
        self.apigateway = self.aws_session.client('apigateway')
        self.lambda_client = self.aws_session.client('lambda')
    
    def _load_config(self, config_file: str) -> Dict:
        """설정 파일 로드"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except Exception as e:
            logger.error(f"Failed to load config file {config_file}: {e}")
            sys.exit(1)
    
    def run_all_tests(self) -> List[TestResult]:
        """모든 테스트 스위트 실행"""
        logger.info(f"🚀 Starting integration tests for environment: {self.environment}")
        
        for suite in self.config.get('test_suites', []):
            logger.info(f"📋 Running test suite: {suite['name']}")
            self._run_test_suite(suite)
        
        # 실행 시간 계산
        duration = (datetime.utcnow() - self.start_time).total_seconds()
        logger.info(f"✅ Integration tests completed in {duration:.2f} seconds")
        
        return self.results    

    def _run_test_suite(self, suite: Dict):
        """개별 테스트 스위트 실행"""
        suite_name = suite['name']
        tests = suite.get('tests', [])
        
        # 병렬 실행 설정
        max_workers = min(len(tests), 5)  # 최대 5개 병렬 실행
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            future_to_test = {
                executor.submit(self._run_single_test, test, suite_name): test 
                for test in tests
            }
            
            for future in as_completed(future_to_test):
                test = future_to_test[future]
                try:
                    result = future.result()
                    self.results.append(result)
                except Exception as e:
                    error_result = TestResult(
                        name=f"{suite_name}.{test['name']}",
                        status='ERROR',
                        duration=0.0,
                        message=f"Test execution failed: {str(e)}",
                        details={'test': test, 'exception': str(e)}
                    )
                    self.results.append(error_result)
                    logger.error(f"❌ Test {test['name']} failed with exception: {e}")
    
    def _run_single_test(self, test: Dict, suite_name: str) -> TestResult:
        """개별 테스트 실행"""
        test_name = f"{suite_name}.{test['name']}"
        start_time = time.time()
        
        try:
            logger.info(f"🧪 Running test: {test_name}")
            
            test_type = test['type']
            success = False
            message = ""
            details = {}
            
            if test_type == 'network':
                success, message, details = self._test_network(test)
            elif test_type == 'service':
                success, message, details = self._test_service(test)
            elif test_type == 'database':
                success, message, details = self._test_database(test)
            elif test_type == 'security':
                success, message, details = self._test_security(test)
            elif test_type == 'http':
                success, message, details = self._test_http(test)
            else:
                raise ValueError(f"Unknown test type: {test_type}")
            
            duration = time.time() - start_time
            status = 'PASS' if success else 'FAIL'
            
            if success:
                logger.info(f"✅ {test_name}: {message}")
            else:
                logger.error(f"❌ {test_name}: {message}")
            
            return TestResult(
                name=test_name,
                status=status,
                duration=duration,
                message=message,
                details=details
            )
            
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"💥 {test_name} crashed: {str(e)}")
            
            return TestResult(
                name=test_name,
                status='ERROR',
                duration=duration,
                message=f"Test crashed: {str(e)}",
                details={'exception': str(e), 'test_config': test}
            )
    
    def _test_network(self, test: Dict) -> tuple[bool, str, Dict]:
        """네트워크 연결성 테스트"""
        target = test['target']
        expected = test['expected']
        
        try:
            if target == 'public_subnets':
                return self._test_public_subnet_connectivity()
            elif target == 'private_subnets':
                return self._test_private_subnet_isolation()
            elif target == 'vpc_endpoints':
                return self._test_vpc_endpoints()
            else:
                return False, f"Unknown network target: {target}", {}
                
        except Exception as e:
            return False, f"Network test failed: {str(e)}", {'exception': str(e)}
    
    def _test_public_subnet_connectivity(self) -> tuple[bool, str, Dict]:
        """퍼블릭 서브넷 인터넷 연결성 테스트"""
        try:
            # VPC 찾기
            vpcs = self.ec2.describe_vpcs(
                Filters=[
                    {'Name': 'tag:Environment', 'Values': [self.environment]},
                    {'Name': 'tag:Name', 'Values': [f'*petclinic*']}
                ]
            )
            
            if not vpcs['Vpcs']:
                return False, "No VPC found for environment", {}
            
            vpc_id = vpcs['Vpcs'][0]['VpcId']
            
            # 퍼블릭 서브넷 찾기
            subnets = self.ec2.describe_subnets(
                Filters=[
                    {'Name': 'vpc-id', 'Values': [vpc_id]},
                    {'Name': 'tag:Type', 'Values': ['public']}
                ]
            )
            
            if not subnets['Subnets']:
                return False, "No public subnets found", {'vpc_id': vpc_id}
            
            # 각 퍼블릭 서브넷의 라우팅 테이블 확인
            igw_routes = 0
            for subnet in subnets['Subnets']:
                subnet_id = subnet['SubnetId']
                
                # 서브넷의 라우팅 테이블 찾기
                route_tables = self.ec2.describe_route_tables(
                    Filters=[
                        {'Name': 'association.subnet-id', 'Values': [subnet_id]}
                    ]
                )
                
                # 메인 라우팅 테이블도 확인
                if not route_tables['RouteTables']:
                    route_tables = self.ec2.describe_route_tables(
                        Filters=[
                            {'Name': 'vpc-id', 'Values': [vpc_id]},
                            {'Name': 'association.main', 'Values': ['true']}
                        ]
                    )
                
                # IGW로의 라우트 확인
                for rt in route_tables['RouteTables']:
                    for route in rt['Routes']:
                        if (route.get('DestinationCidrBlock') == '0.0.0.0/0' and 
                            route.get('GatewayId', '').startswith('igw-')):
                            igw_routes += 1
                            break
            
            if igw_routes > 0:
                return True, f"Found {igw_routes} public subnets with IGW routes", {
                    'vpc_id': vpc_id,
                    'public_subnets': len(subnets['Subnets']),
                    'igw_routes': igw_routes
                }
            else:
                return False, "No IGW routes found in public subnets", {
                    'vpc_id': vpc_id,
                    'public_subnets': len(subnets['Subnets'])
                }
                
        except Exception as e:
            return False, f"Public subnet test failed: {str(e)}", {'exception': str(e)} 
   
    def _test_service(self, test: Dict) -> tuple[bool, str, Dict]:
        """서비스 상태 테스트"""
        target = test['target']
        
        try:
            if target == 'ecs_cluster':
                return self._test_ecs_cluster()
            elif target == 'lambda_functions':
                return self._test_lambda_functions()
            else:
                return False, f"Unknown service target: {target}", {}
                
        except Exception as e:
            return False, f"Service test failed: {str(e)}", {'exception': str(e)}
    
    def _test_ecs_cluster(self) -> tuple[bool, str, Dict]:
        """ECS 클러스터 및 서비스 상태 테스트"""
        try:
            cluster_name = f"petclinic-cluster-{self.environment}"
            
            # 클러스터 상태 확인
            clusters = self.ecs.describe_clusters(clusters=[cluster_name])
            
            if not clusters['clusters']:
                return False, f"ECS cluster {cluster_name} not found", {}
            
            cluster = clusters['clusters'][0]
            if cluster['status'] != 'ACTIVE':
                return False, f"ECS cluster is not active: {cluster['status']}", {
                    'cluster_name': cluster_name,
                    'status': cluster['status']
                }
            
            # 서비스 목록 가져오기
            services_response = self.ecs.list_services(cluster=cluster['clusterArn'])
            service_arns = services_response['serviceArns']
            
            if not service_arns:
                return False, "No services found in cluster", {
                    'cluster_name': cluster_name
                }
            
            # 각 서비스 상태 확인
            services_detail = self.ecs.describe_services(
                cluster=cluster['clusterArn'],
                services=service_arns
            )
            
            healthy_services = 0
            total_services = len(services_detail['services'])
            service_details = {}
            
            for service in services_detail['services']:
                service_name = service['serviceName']
                running_count = service['runningCount']
                desired_count = service['desiredCount']
                status = service['status']
                
                service_details[service_name] = {
                    'status': status,
                    'running_count': running_count,
                    'desired_count': desired_count,
                    'healthy': status == 'ACTIVE' and running_count == desired_count
                }
                
                if status == 'ACTIVE' and running_count == desired_count:
                    healthy_services += 1
            
            if healthy_services == total_services:
                return True, f"All {total_services} services are healthy", {
                    'cluster_name': cluster_name,
                    'total_services': total_services,
                    'healthy_services': healthy_services,
                    'services': service_details
                }
            else:
                return False, f"Only {healthy_services}/{total_services} services are healthy", {
                    'cluster_name': cluster_name,
                    'total_services': total_services,
                    'healthy_services': healthy_services,
                    'services': service_details
                }
                
        except Exception as e:
            return False, f"ECS cluster test failed: {str(e)}", {'exception': str(e)}
    
    def _test_database(self, test: Dict) -> tuple[bool, str, Dict]:
        """데이터베이스 상태 테스트"""
        target = test['target']
        
        try:
            if target == 'aurora_cluster':
                return self._test_aurora_cluster()
            else:
                return False, f"Unknown database target: {target}", {}
                
        except Exception as e:
            return False, f"Database test failed: {str(e)}", {'exception': str(e)}
    
    def _test_aurora_cluster(self) -> tuple[bool, str, Dict]:
        """Aurora 클러스터 상태 테스트"""
        try:
            cluster_id = f"petclinic-aurora-{self.environment}"
            
            # 클러스터 상태 확인
            clusters = self.rds.describe_db_clusters(
                DBClusterIdentifier=cluster_id
            )
            
            if not clusters['DBClusters']:
                return False, f"Aurora cluster {cluster_id} not found", {}
            
            cluster = clusters['DBClusters'][0]
            status = cluster['Status']
            
            if status != 'available':
                return False, f"Aurora cluster is not available: {status}", {
                    'cluster_id': cluster_id,
                    'status': status
                }
            
            # 클러스터 멤버 확인
            members = cluster.get('DBClusterMembers', [])
            writer_count = sum(1 for member in members if member['IsClusterWriter'])
            reader_count = len(members) - writer_count
            
            cluster_details = {
                'cluster_id': cluster_id,
                'status': status,
                'engine': cluster['Engine'],
                'engine_version': cluster['EngineVersion'],
                'writer_count': writer_count,
                'reader_count': reader_count,
                'total_members': len(members)
            }
            
            if writer_count >= 1:
                return True, f"Aurora cluster is healthy with {writer_count} writer(s) and {reader_count} reader(s)", cluster_details
            else:
                return False, f"Aurora cluster has no writer instances", cluster_details
                
        except Exception as e:
            return False, f"Aurora cluster test failed: {str(e)}", {'exception': str(e)}
    
    def _test_http(self, test: Dict) -> tuple[bool, str, Dict]:
        """HTTP 엔드포인트 테스트"""
        target = test['target']
        
        try:
            if target == 'application_load_balancer':
                return self._test_alb_endpoints()
            elif target == 'api_gateway':
                return self._test_api_gateway_endpoints()
            else:
                return False, f"Unknown HTTP target: {target}", {}
                
        except Exception as e:
            return False, f"HTTP test failed: {str(e)}", {'exception': str(e)}
    
    def _test_alb_endpoints(self) -> tuple[bool, str, Dict]:
        """ALB 엔드포인트 테스트"""
        try:
            # ALB 찾기
            load_balancers = self.elbv2.describe_load_balancers()
            
            petclinic_albs = [
                lb for lb in load_balancers['LoadBalancers']
                if self.environment in lb['LoadBalancerName'] and 'petclinic' in lb['LoadBalancerName']
            ]
            
            if not petclinic_albs:
                return False, f"No ALB found for environment {self.environment}", {}
            
            alb = petclinic_albs[0]
            dns_name = alb['DNSName']
            
            if alb['State']['Code'] != 'active':
                return False, f"ALB is not active: {alb['State']['Code']}", {
                    'alb_name': alb['LoadBalancerName'],
                    'state': alb['State']['Code']
                }
            
            # 헬스체크 엔드포인트 테스트
            test_endpoints = [
                '/actuator/health',
                '/api/customers/actuator/health',
                '/api/vets/actuator/health',
                '/api/visits/actuator/health'
            ]
            
            successful_endpoints = 0
            endpoint_results = {}
            
            for endpoint in test_endpoints:
                try:
                    url = f"http://{dns_name}{endpoint}"
                    response = requests.get(url, timeout=10)
                    
                    endpoint_results[endpoint] = {
                        'status_code': response.status_code,
                        'response_time': response.elapsed.total_seconds(),
                        'success': response.status_code == 200
                    }
                    
                    if response.status_code == 200:
                        successful_endpoints += 1
                        
                except requests.RequestException as e:
                    endpoint_results[endpoint] = {
                        'status_code': 0,
                        'error': str(e),
                        'success': False
                    }
            
            details = {
                'alb_name': alb['LoadBalancerName'],
                'dns_name': dns_name,
                'total_endpoints': len(test_endpoints),
                'successful_endpoints': successful_endpoints,
                'endpoints': endpoint_results
            }
            
            if successful_endpoints > 0:
                return True, f"ALB responding: {successful_endpoints}/{len(test_endpoints)} endpoints healthy", details
            else:
                return False, "ALB not responding to any health check endpoints", details
                
        except Exception as e:
            return False, f"ALB endpoint test failed: {str(e)}", {'exception': str(e)} 
   
    def generate_report(self) -> Dict:
        """테스트 결과 리포트 생성"""
        total_tests = len(self.results)
        passed_tests = len([r for r in self.results if r.status == 'PASS'])
        failed_tests = len([r for r in self.results if r.status == 'FAIL'])
        error_tests = len([r for r in self.results if r.status == 'ERROR'])
        skipped_tests = len([r for r in self.results if r.status == 'SKIP'])
        
        total_duration = sum(r.duration for r in self.results)
        end_time = datetime.utcnow()
        
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        
        return {
            'summary': {
                'start_time': self.start_time.isoformat(),
                'end_time': end_time.isoformat(),
                'total_duration_seconds': total_duration,
                'environment': self.environment,
                'region': self.region,
                'total_tests': total_tests,
                'passed': passed_tests,
                'failed': failed_tests,
                'errors': error_tests,
                'skipped': skipped_tests,
                'success_rate': f"{success_rate:.1f}%",
                'overall_status': 'PASS' if failed_tests == 0 and error_tests == 0 else 'FAIL'
            },
            'results': [asdict(result) for result in self.results],
            'metadata': {
                'runner_version': '2.0.0',
                'aws_region': self.region,
                'timestamp': datetime.utcnow().isoformat()
            }
        }
    
    def save_report(self, output_file: str):
        """리포트를 파일로 저장"""
        report = self.generate_report()
        
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(report, f, indent=2, ensure_ascii=False)
            logger.info(f"📄 Test report saved to: {output_file}")
        except Exception as e:
            logger.error(f"Failed to save report to {output_file}: {e}")
    
    def print_summary(self):
        """테스트 결과 요약 출력"""
        report = self.generate_report()
        summary = report['summary']
        
        print("\n" + "="*60)
        print("🧪 INTEGRATION TEST RESULTS SUMMARY")
        print("="*60)
        print(f"Environment: {summary['environment']}")
        print(f"Region: {summary['region']}")
        print(f"Duration: {summary['total_duration_seconds']:.2f} seconds")
        print(f"Start Time: {summary['start_time']}")
        print(f"End Time: {summary['end_time']}")
        print()
        print(f"Total Tests: {summary['total_tests']}")
        print(f"✅ Passed: {summary['passed']}")
        print(f"❌ Failed: {summary['failed']}")
        print(f"💥 Errors: {summary['errors']}")
        print(f"⏭️  Skipped: {summary['skipped']}")
        print(f"📊 Success Rate: {summary['success_rate']}")
        print()
        
        # 실패한 테스트 상세 정보
        failed_results = [r for r in self.results if r.status in ['FAIL', 'ERROR']]
        if failed_results:
            print("❌ FAILED TESTS:")
            print("-" * 40)
            for result in failed_results:
                print(f"• {result.name}: {result.message}")
            print()
        
        # 성공한 테스트 요약
        passed_results = [r for r in self.results if r.status == 'PASS']
        if passed_results:
            print("✅ PASSED TESTS:")
            print("-" * 40)
            for result in passed_results:
                print(f"• {result.name}: {result.message}")
            print()
        
        print("="*60)
        
        if summary['overall_status'] == 'PASS':
            print("🎉 ALL TESTS PASSED!")
        else:
            print("❌ SOME TESTS FAILED!")
        print("="*60)


def main():
    """메인 실행 함수"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Terraform Integration Test Runner')
    parser.add_argument('config_file', help='Test configuration YAML file')
    parser.add_argument('environment', help='Target environment (dev, staging, prod)')
    parser.add_argument('--region', default='ap-northeast-1', help='AWS region')
    parser.add_argument('--output', '-o', help='Output file for test results (JSON)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # 설정 파일 존재 확인
    if not os.path.exists(args.config_file):
        logger.error(f"Configuration file not found: {args.config_file}")
        sys.exit(1)
    
    # 테스트 실행
    runner = IntegrationTestRunner(args.config_file, args.environment, args.region)
    
    try:
        results = runner.run_all_tests()
        
        # 결과 출력
        runner.print_summary()
        
        # 파일로 저장 (지정된 경우)
        if args.output:
            runner.save_report(args.output)
        
        # 종료 코드 결정
        report = runner.generate_report()
        if report['summary']['overall_status'] == 'PASS':
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("🛑 Test execution interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"💥 Test execution failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()