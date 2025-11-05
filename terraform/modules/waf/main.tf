resource "aws_wafv2_web_acl" "this" {
    name        = "${var.name_prefix}-${var.environment}-web-acl-v2" # 이름 변경
    description = "Web ACL for ${var.name_prefix} ${var.environment} environment"
    scope       = var.scope # CLOUDFRONT or REGIONAL
  
    default_action {
      allow {}
    }
  
    # AWS Managed Rule Group for SQL Injection
    rule {
      name     = "AWS-AWSManagedRulesSQLiRuleSet"
      priority = 10
  
      override_action {
        none {}
      }
  
      statement {
        managed_rule_group_statement {
          name    = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"
        }
      }
  
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesSQLiRuleSet"
        sampled_requests_enabled   = true
      }
    }
  
    # AWS Managed Rule Group for XSS
    rule {
      name     = "AWS-AWSManagedRulesCommonRuleSet" # Common Rule Set includes XSS protection
      priority = 20
  
      override_action {
        none {}
      }
  
      statement {
        managed_rule_group_statement {
          name    = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }
  
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesCommonRuleSet"
        sampled_requests_enabled   = true
      }
    }

    # Rate-Based Rule for throttling
    dynamic "rule" {
      for_each = var.enable_rate_limiting ? [1] : []
      content {
        name     = "RateBasedRule"
        priority = 30

        action {
          block {}
        }

        statement {
          rate_based_statement {
            limit              = var.rate_limit_threshold
            aggregate_key_type = "IP"
          }
        }

        visibility_config {
          cloudwatch_metrics_enabled = true
          metric_name                = "RateBasedRule"
          sampled_requests_enabled   = true
        }
      }
    }
  
    # Logging configuration
    # WAF logs to S3 bucket
    tags = {
      Project     = var.name_prefix
      Environment = var.environment
    }
  
    # 최상위 visibility_config 블록 추가
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-${var.environment}-web-acl-v2" # 이름 변경에 맞춰 metric_name도 변경
      sampled_requests_enabled   = true
    }
}

# WAF logs S3 bucket
resource "aws_s3_bucket" "waf_logs" {
  bucket = "aws-waf-logs-${var.name_prefix}-${var.environment}-v2"
}

resource "aws_s3_bucket_ownership_controls" "waf_logs_ownership" {
  bucket = aws_s3_bucket.waf_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "waf_logs_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.waf_logs_ownership]
  bucket = aws_s3_bucket.waf_logs.id
  acl    = "log-delivery-write"
}

# WAF logging configuration
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  log_destination_configs = [aws_s3_bucket.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn
}

# S3 bucket policy for WAF logging
resource "aws_s3_bucket_policy" "waf_logs_policy" {
  bucket = aws_s3_bucket.waf_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSLogDeliveryWrite",
        Effect    = "Allow",
        Principal = { Service = "delivery.logs.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.waf_logs.arn}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck",
        Effect = "Allow",
        Principal = { Service = "delivery.logs.amazonaws.com" },
        Action = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.waf_logs.arn
      }
    ]
  })
}
# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = var.api_gateway_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}