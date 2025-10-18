# CloudFront Distribution Module
# S3 정적 웹사이트와 API Gateway를 통합하는 CloudFront 배포

# CloudFront 배포 생성
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name_prefix} Frontend Distribution"
  default_root_object = "index.html"
  price_class         = var.price_class

  # S3 오리진 (프론트엔드 정적 파일)
  origin {
    domain_name = var.s3_bucket_regional_domain_name
    origin_id   = "S3-${var.s3_bucket_name}"

    s3_origin_config {
      origin_access_identity = var.cloudfront_oai_path
    }
  }

  # API Gateway 오리진 (API 호출용)
  dynamic "origin" {
    for_each = var.enable_api_gateway_integration ? [1] : []

    content {
      domain_name = trimsuffix(replace(var.api_gateway_domain_name, "https://", ""), "/v1")
      origin_path = "/v1"
      origin_id   = "API-Gateway"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # 기본 캐시 동작 (S3 오리진용)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all" # 로컬 테스트용으로 HTTP 허용
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    # SPA 라우팅을 위한 에러 페이지 설정
    dynamic "function_association" {
      for_each = var.enable_spa_routing ? [1] : []

      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.spa_routing[0].arn
      }
    }
  }

  # API 경로용 캐시 동작 (API Gateway 오리진용)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_api_gateway_integration ? [1] : []

    content {
      path_pattern     = "/api/*"
      allowed_methods  = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "API-Gateway"

      forwarded_values {
        query_string = true
        headers      = ["Authorization", "Content-Type", "X-Api-Key"]
        cookies {
          forward = "all"
        }
      }

      viewer_protocol_policy = "allow-all" # 로컬 테스트용으로 HTTP 허용
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0

      # CORS 헤더 추가
      dynamic "lambda_function_association" {
        for_each = var.enable_cors_headers ? [1] : []

        content {
          event_type   = "origin-response"
          lambda_arn   = aws_lambda_function.cors_headers[0].qualified_arn
          include_body = false
        }
      }
    }
  }


  # 사용자 지정 에러 페이지 (SPA용)
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 300
  }

  # 지리적 제한 (선택사항)
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL/TLS 설정 (로컬 테스트용으로 HTTP 허용)
  viewer_certificate {
    cloudfront_default_certificate = var.use_default_certificate
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.ssl_support_method
    minimum_protocol_version       = var.minimum_protocol_version
  }

  # 로컬 테스트용 HTTP 허용 (선택사항)
  http_version = "http2"

  # 로깅 설정
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []

    content {
      include_cookies = false
      bucket          = var.log_bucket_domain_name
      prefix          = var.log_prefix
    }
  }

  # 태그
  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-cloudfront"
    Environment = var.environment
    Service     = "cloudfront"
    Purpose     = "frontend-cdn"
    ManagedBy   = "terraform"
  })

  # WAF 연결 (선택사항)
  web_acl_id = var.web_acl_arn
}

# SPA 라우팅을 위한 CloudFront 함수
resource "aws_cloudfront_function" "spa_routing" {
  count = var.enable_spa_routing ? 1 : 0

  name    = "${var.name_prefix}-spa-routing"
  runtime = "cloudfront-js-1.0"
  comment = "SPA routing function for handling client-side routing"
  publish = true
  code    = <<-EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Check whether the URI is missing a file name.
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    // Check whether the URI is missing a file extension.
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }

    return request;
}
EOF
}

# CORS 헤더 추가를 위한 Lambda@Edge 함수
resource "aws_lambda_function" "cors_headers" {
  count = var.enable_cors_headers ? 1 : 0

  filename         = data.archive_file.cors_lambda[0].output_path
  function_name    = "${var.name_prefix}-cors-headers"
  role            = aws_iam_role.lambda_edge[0].arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  publish         = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cors-lambda"
  })
}

# Lambda@Edge용 IAM 역할
resource "aws_iam_role" "lambda_edge" {
  count = var.enable_cors_headers ? 1 : 0

  name = "${var.name_prefix}-lambda-edge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lambda-edge-role"
  })
}

# Lambda@Edge IAM 정책
resource "aws_iam_role_policy" "lambda_edge" {
  count = var.enable_cors_headers ? 1 : 0

  name = "${var.name_prefix}-lambda-edge-policy"
  role = aws_iam_role.lambda_edge[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# CORS Lambda 함수용 ZIP 파일
data "archive_file" "cors_lambda" {
  count = var.enable_cors_headers ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/cors-lambda.zip"

  source {
    content  = <<-EOF
exports.handler = async (event) => {
    const response = event.Records[0].cf.response;
    const headers = response.headers;

    // CORS 헤더 추가
    headers['access-control-allow-origin'] = [{key: 'Access-Control-Allow-Origin', value: '*'}];
    headers['access-control-allow-methods'] = [{key: 'Access-Control-Allow-Methods', value: 'GET, POST, PUT, DELETE, OPTIONS'}];
    headers['access-control-allow-headers'] = [{key: 'Access-Control-Allow-Headers', value: 'Content-Type, Authorization, X-Amz-Date, X-Amz-Security-Token, X-Api-Key'}];
    headers['access-control-max-age'] = [{key: 'Access-Control-Max-Age', value: '86400'}];

    return response;
};
EOF
    filename = "index.js"
  }
}

# CloudWatch 알람 (CloudFront 메트릭용)
resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-cloudfront-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.error_4xx_threshold
  alarm_description   = "CloudFront 4XX 에러율이 임계값을 초과했습니다"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.frontend.id
    Region         = "Global"
  }

  alarm_actions = var.alarm_actions

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-4xx-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-cloudfront-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.error_5xx_threshold
  alarm_description   = "CloudFront 5XX 에러율이 임계값을 초과했습니다"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.frontend.id
    Region         = "Global"
  }

  alarm_actions = var.alarm_actions

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-5xx-alarm"
  })
}