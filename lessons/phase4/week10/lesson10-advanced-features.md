# Lesson 13: Advanced Security & Compliance

## Learning Objectives
By the end of this lesson, you will be able to:
- Implement advanced security measures and compliance standards
- Set up comprehensive security monitoring and threat detection
- Configure data protection and privacy compliance (GDPR, CCPA)
- Build security incident response and audit logging
- Implement advanced authentication security patterns
- Set up vulnerability scanning and security testing automation

## Overview
This lesson covers enterprise-grade security implementation, compliance frameworks, and advanced security monitoring for production iOS authentication systems.

## 1. Advanced Security Architecture

### 1.1 Zero Trust Security Model

```hcl
# terraform/modules/security/zero-trust.tf
resource "aws_wafv2_web_acl" "zero_trust_acl" {
  name  = "${var.environment}-zero-trust-acl"
  scope = "CLOUDFRONT"

  default_action {
    block {}
  }

  # Geo-blocking rule
  rule {
    name     = "GeoBlockRule"
    priority = 1

    action {
      allow {}
    }

    statement {
      geo_match_statement {
        country_codes = var.allowed_countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockRule"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            positional_constraint = "CONTAINS"
            search_string         = "/api/auth"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # SQL injection protection
  rule {
    name     = "SQLInjectionRule"
    priority = 3

    action {
      block {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        excluded_rule {
          name = "GenericRFI_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionRule"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Environment = var.environment
    Purpose     = "ZeroTrustSecurity"
  }
}

# CloudTrail for comprehensive audit logging
resource "aws_cloudtrail" "security_audit_trail" {
  name                          = "${var.environment}-security-audit-trail"
  s3_bucket_name               = aws_s3_bucket.audit_logs.bucket
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.audit_logs.arn}/*"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["*"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = {
    Environment = var.environment
    Purpose     = "SecurityAudit"
  }
}

# GuardDuty for threat detection
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Environment = var.environment
    Purpose     = "ThreatDetection"
  }
}

# Security Hub for centralized security findings
resource "aws_securityhub_account" "main" {
  enable_default_standards = true
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/cis-aws-foundations-benchmark/v/1.2.0"
}
```

### 1.2 Advanced Encryption and Key Management

```hcl
# terraform/modules/security/encryption.tf
resource "aws_kms_key" "application_key" {
  description             = "KMS key for application encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Purpose     = "ApplicationEncryption"
  }
}

resource "aws_kms_alias" "application_key_alias" {
  name          = "alias/${var.environment}-application-key"
  target_key_id = aws_kms_key.application_key.key_id
}

# Secrets Manager for sensitive configuration
resource "aws_secretsmanager_secret" "database_credentials" {
  name                    = "${var.environment}-database-credentials"
  description             = "Database credentials for authentication system"
  recovery_window_in_days = 30
  kms_key_id             = aws_kms_key.application_key.arn

  replica {
    region = "us-west-2"
  }

  tags = {
    Environment = var.environment
    Purpose     = "DatabaseCredentials"
  }
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  secret_id = aws_secretsmanager_secret.database_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    port     = var.db_port
  })
}

# Parameter Store for application configuration
resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${var.environment}/auth/jwt-secret"
  type  = "SecureString"
  value = var.jwt_secret
  key_id = aws_kms_key.application_key.arn

  tags = {
    Environment = var.environment
    Purpose     = "JWTSecret"
  }
}

resource "aws_ssm_parameter" "firebase_config" {
  name  = "/${var.environment}/auth/firebase-config"
  type  = "SecureString"
  value = var.firebase_config
  key_id = aws_kms_key.application_key.arn

  tags = {
    Environment = var.environment
    Purpose     = "FirebaseConfig"
  }
}
```

## 2. Compliance Framework Implementation

### 2.1 GDPR Compliance

```python
# lambda/compliance/gdpr_handler.py
import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional

logger = logging.getLogger()
logger.setLevel(logging.INFO)

class GDPRComplianceHandler:
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.s3 = boto3.client('s3')
        self.ses = boto3.client('ses')
        
    def handle_data_subject_request(self, event: Dict) -> Dict:
        """Handle GDPR data subject requests"""
        try:
            request_type = event.get('request_type')
            user_id = event.get('user_id')
            email = event.get('email')
            
            if request_type == 'ACCESS':
                return self.handle_access_request(user_id, email)
            elif request_type == 'PORTABILITY':
                return self.handle_portability_request(user_id, email)
            elif request_type == 'ERASURE':
                return self.handle_erasure_request(user_id, email)
            elif request_type == 'RECTIFICATION':
                return self.handle_rectification_request(user_id, event.get('corrections'))
            else:
                raise ValueError(f"Unknown request type: {request_type}")
                
        except Exception as e:
            logger.error(f"Error handling GDPR request: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Internal server error'})
            }
    
    def handle_access_request(self, user_id: str, email: str) -> Dict:
        """Handle data access requests (Article 15)"""
        try:
            # Collect all user data
            user_data = self.collect_user_data(user_id)
            
            # Create data export
            export_data = {
                'personal_data': user_data,
                'processing_purposes': self.get_processing_purposes(),
                'data_categories': self.get_data_categories(),
                'recipients': self.get_data_recipients(),
                'retention_period': self.get_retention_period(),
                'rights_information': self.get_rights_information(),
                'export_timestamp': datetime.utcnow().isoformat()
            }
            
            # Upload to S3 with encryption
            bucket_name = f"gdpr-exports-{os.environ['ENVIRONMENT']}"
            file_key = f"exports/{user_id}/{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
            
            self.s3.put_object(
                Bucket=bucket_name,
                Key=file_key,
                Body=json.dumps(export_data, indent=2),
                ServerSideEncryption='aws:kms',
                SSEKMSKeyId=os.environ['KMS_KEY_ID']
            )
            
            # Generate presigned URL for download
            download_url = self.s3.generate_presigned_url(
                'get_object',
                Params={'Bucket': bucket_name, 'Key': file_key},
                ExpiresIn=3600  # 1 hour
            )
            
            # Send notification email
            self.send_access_notification(email, download_url)
            
            # Log compliance action
            self.log_compliance_action(user_id, 'ACCESS_REQUEST_FULFILLED')
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Data access request fulfilled',
                    'download_url': download_url,
                    'expires_at': (datetime.utcnow() + timedelta(hours=1)).isoformat()
                })
            }
            
        except Exception as e:
            logger.error(f"Error handling access request: {str(e)}")
            raise
    
    def handle_erasure_request(self, user_id: str, email: str) -> Dict:
        """Handle right to erasure requests (Article 17)"""
        try:
            # Check if erasure is legally required
            if not self.can_erase_data(user_id):
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'error': 'Data cannot be erased due to legal obligations'
                    })
                }
            
            # Anonymize user data
            self.anonymize_user_data(user_id)
            
            # Remove from search indexes
            self.remove_from_search_indexes(user_id)
            
            # Update audit trail
            self.log_compliance_action(user_id, 'ERASURE_REQUEST_FULFILLED')
            
            # Send confirmation email
            self.send_erasure_confirmation(email)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Data erasure request fulfilled'
                })
            }
            
        except Exception as e:
            logger.error(f"Error handling erasure request: {str(e)}")
            raise
    
    def collect_user_data(self, user_id: str) -> Dict:
        """Collect all user data across systems"""
        user_data = {}
        
        # DynamoDB tables
        tables = ['users', 'user_sessions', 'user_preferences', 'audit_logs']
        
        for table_name in tables:
            try:
                table = self.dynamodb.Table(f"{os.environ['ENVIRONMENT']}-{table_name}")
                response = table.query(
                    KeyConditionExpression=boto3.dynamodb.conditions.Key('user_id').eq(user_id)
                )
                user_data[table_name] = response.get('Items', [])
            except Exception as e:
                logger.warning(f"Could not retrieve data from {table_name}: {str(e)}")
        
        return user_data
    
    def anonymize_user_data(self, user_id: str):
        """Anonymize user data while preserving analytics"""
        # Generate anonymous ID
        anonymous_id = f"anon_{hash(user_id + datetime.utcnow().isoformat())}"
        
        # Update user record
        users_table = self.dynamodb.Table(f"{os.environ['ENVIRONMENT']}-users")
        users_table.update_item(
            Key={'user_id': user_id},
            UpdateExpression='''
                SET email = :anon_email,
                    first_name = :anon_name,
                    last_name = :anon_name,
                    phone_number = :anon_phone,
                    anonymized = :anonymized,
                    anonymized_at = :timestamp
            ''',
            ExpressionAttributeValues={
                ':anon_email': f"{anonymous_id}@anonymized.local",
                ':anon_name': 'Anonymized',
                ':anon_phone': 'Anonymized',
                ':anonymized': True,
                ':timestamp': datetime.utcnow().isoformat()
            }
        )
    
    def log_compliance_action(self, user_id: str, action: str):
        """Log compliance actions for audit purposes"""
        audit_table = self.dynamodb.Table(f"{os.environ['ENVIRONMENT']}-compliance_audit")
        
        audit_table.put_item(
            Item={
                'audit_id': f"{user_id}_{datetime.utcnow().isoformat()}",
                'user_id': user_id,
                'action': action,
                'timestamp': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow() + timedelta(days=2555)).timestamp())  # 7 years
            }
        )

def lambda_handler(event, context):
    """Lambda handler for GDPR compliance requests"""
    handler = GDPRComplianceHandler()
    return handler.handle_data_subject_request(event)
```

### 2.2 Data Classification and Retention

```python
# lambda/compliance/data_retention.py
import json
import boto3
from datetime import datetime, timedelta
from typing import Dict, List

class DataRetentionManager:
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.s3 = boto3.client('s3')
        
    def apply_retention_policies(self, event: Dict) -> Dict:
        """Apply data retention policies"""
        try:
            # Define retention policies
            retention_policies = {
                'user_sessions': timedelta(days=30),
                'audit_logs': timedelta(days=2555),  # 7 years
                'user_activity': timedelta(days=365),
                'support_tickets': timedelta(days=1095),  # 3 years
                'payment_data': timedelta(days=2555)  # 7 years
            }
            
            results = {}
            
            for table_name, retention_period in retention_policies.items():
                expired_items = self.find_expired_items(table_name, retention_period)
                archived_count = self.archive_expired_items(table_name, expired_items)
                deleted_count = self.delete_expired_items(table_name, expired_items)
                
                results[table_name] = {
                    'archived': archived_count,
                    'deleted': deleted_count
                }
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Retention policies applied successfully',
                    'results': results
                })
            }
            
        except Exception as e:
            logger.error(f"Error applying retention policies: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Internal server error'})
            }
    
    def find_expired_items(self, table_name: str, retention_period: timedelta) -> List[Dict]:
        """Find items that have exceeded retention period"""
        table = self.dynamodb.Table(f"{os.environ['ENVIRONMENT']}-{table_name}")
        cutoff_date = datetime.utcnow() - retention_period
        
        # Scan for expired items
        response = table.scan(
            FilterExpression=boto3.dynamodb.conditions.Attr('created_at').lt(cutoff_date.isoformat())
        )
        
        return response.get('Items', [])
    
    def archive_expired_items(self, table_name: str, items: List[Dict]) -> int:
        """Archive expired items to S3"""
        if not items:
            return 0
        
        bucket_name = f"data-archive-{os.environ['ENVIRONMENT']}"
        archive_key = f"archived/{table_name}/{datetime.utcnow().strftime('%Y/%m/%d')}/archive.json"
        
        self.s3.put_object(
            Bucket=bucket_name,
            Key=archive_key,
            Body=json.dumps(items, indent=2),
            ServerSideEncryption='aws:kms',
            SSEKMSKeyId=os.environ['KMS_KEY_ID']
        )
        
        return len(items)
```

## 3. Security Monitoring and Incident Response

### 3.1 Advanced Threat Detection

```python
# lambda/security/threat_detection.py
import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional

logger = logging.getLogger()
logger.setLevel(logging.INFO)

class ThreatDetectionSystem:
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.sns = boto3.client('sns')
        self.cloudwatch = boto3.client('cloudwatch')
        
    def analyze_authentication_patterns(self, event: Dict) -> Dict:
        """Analyze authentication patterns for anomalies"""
        try:
            user_id = event.get('user_id')
            ip_address = event.get('ip_address')
            user_agent = event.get('user_agent')
            timestamp = datetime.utcnow()
            
            # Analyze different threat vectors
            threats = []
            
            # 1. Brute force detection
            if self.detect_brute_force(user_id, ip_address):
                threats.append({
                    'type': 'BRUTE_FORCE',
                    'severity': 'HIGH',
                    'details': f'Multiple failed login attempts from {ip_address}'
                })
            
            # 2. Impossible travel detection
            if self.detect_impossible_travel(user_id, ip_address):
                threats.append({
                    'type': 'IMPOSSIBLE_TRAVEL',
                    'severity': 'CRITICAL',
                    'details': f'Login from geographically impossible location'
                })
            
            # 3. Device fingerprint anomaly
            if self.detect_device_anomaly(user_id, user_agent):
                threats.append({
                    'type': 'DEVICE_ANOMALY',
                    'severity': 'MEDIUM',
                    'details': f'Login from unrecognized device'
                })
            
            # 4. Time-based anomaly
            if self.detect_time_anomaly(user_id, timestamp):
                threats.append({
                    'type': 'TIME_ANOMALY',
                    'severity': 'LOW',
                    'details': f'Login at unusual time'
                })
            
            # Process threats
            if threats:
                self.process_security_threats(user_id, threats)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'threats_detected': len(threats),
                    'threats': threats
                })
            }
            
        except Exception as e:
            logger.error(f"Error in threat detection: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Internal server error'})
            }
    
    def detect_brute_force(self, user_id: str, ip_address: str) -> bool:
        """Detect brute force attacks"""
        # Check failed login attempts in last 5 minutes
        cutoff_time = datetime.utcnow() - timedelta(minutes=5)
        
        auth_logs_table = self.dynamodb.Table(f"{os.environ['ENVIRONMENT']}-auth_logs")
        
        response = auth_logs_table.query(
            IndexName='ip-timestamp-index',
            KeyConditionExpression=boto3.dynamodb.conditions.Key('ip_address').eq(ip_address),
            FilterExpression=boto3.dynamodb.conditions.Attr('timestamp').gte(cutoff_time.isoformat()) &
                           boto3.dynamodb.conditions.Attr('status').eq('FAILED')
        )
        
        failed_attempts = len(response.get('Items', []))
        return failed_attempts >= 5
    
    def detect_impossible_travel(self, user_id: str, current_ip: str) -> bool:
        """Detect impossible travel based on geolocation"""
        # Get last successful login location
        auth_logs_table = self.dynamodb.Table(f"{os.environ['ENVIRONMENT']}-auth_logs")
        
        response = auth_logs_table.query(
            KeyConditionExpression=boto3.dynamodb.conditions.Key('user_id').eq(user_id),
            FilterExpression=boto3.dynamodb.conditions.Attr('status').eq('SUCCESS'),
            ScanIndexForward=False,
            Limit=1
        )
        
        if not response.get('Items'):
            return False
        
        last_login = response['Items'][0]
        last_ip = last_login.get('ip_address')
        last_timestamp = datetime.fromisoformat(last_login.get('timestamp'))
        
        # Get geolocation data
        current_location = self.get_geolocation(current_ip)
        last_location = self.get_geolocation(last_ip)
        
        if not current_location or not last_location:
            return False
        
        # Calculate distance and time
        distance_km = self.calculate_distance(last_location, current_location)
        time_diff_hours = (datetime.utcnow() - last_timestamp).total_seconds() / 3600
        
        # Maximum reasonable travel speed (including flights)
        max_speed_kmh = 1000  # km/h
        
        return distance_km > (max_speed_kmh * time_diff_hours)
    
    def process_security_threats(self, user_id: str, threats: List[Dict]):
        """Process detected security threats"""
        for threat in threats:
            # Log security event
            self.log_security_event(user_id, threat)
            
            # Send alerts based on severity
            if threat['severity'] in ['HIGH', 'CRITICAL']:
                self.send_security_alert(user_id, threat)
            
            # Automatic response based on threat type
            if threat['type'] == 'BRUTE_FORCE':
                self.implement_rate_limiting(user_id)
            elif threat['type'] == 'IMPOSSIBLE_TRAVEL':
                self.require_additional_verification(user_id)
    
    def send_security_alert(self, user_id: str, threat: Dict):
        """Send security alert to operations team"""
        message = {
            'user_id': user_id,
            'threat_type': threat['type'],
            'severity': threat['severity'],
            'details': threat['details'],
            'timestamp': datetime.utcnow().isoformat()
        }
        
        self.sns.publish(
            TopicArn=os.environ['SECURITY_ALERTS_TOPIC'],
            Message=json.dumps(message),
            Subject=f"Security Alert: {threat['type']} - {threat['severity']}"
        )

def lambda_handler(event, context):
    """Lambda handler for threat detection"""
    detector = ThreatDetectionSystem()
    return detector.analyze_authentication_patterns(event)
```

### 3.2 Security Incident Response

```python
# lambda/security/incident_response.py
import json
import boto3
from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional

class IncidentSeverity(Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class SecurityIncidentHandler:
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.sns = boto3.client('sns')
        self.ses = boto3.client('ses')
        
    def handle_security_incident(self, event: Dict) -> Dict:
        """Handle security incident response"""
        try:
            incident_data = {
                'incident_id': self.generate_incident_id(),
                'type': event.get('incident_type'),
                'severity': event.get('severity', 'MEDIUM'),
                'description': event.get('description'),
                'affected_users': event.get('affected_users', []),
                'source_ip': event.get('source_ip'),
                'timestamp': datetime.utcnow().isoformat(),
                'status': 'OPEN'
            }
            
            # Log incident
            self.log_incident(incident_data)
            
            # Execute response plan
            self.execute_response_plan(incident_data)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Security incident handled',
                    'incident_id': incident_data['incident_id']
                })
            }
            
        except Exception as e:
            logger.error(f"Error handling security incident: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Internal server error'})
            }
    
    def execute_response_plan(self, incident: Dict):
        """Execute incident response plan based on severity"""
        severity = IncidentSeverity(incident['severity'])
        
        if severity == IncidentSeverity.CRITICAL:
            self.execute_critical_response(incident)
        elif severity == IncidentSeverity.HIGH:
            self.execute_high_response(incident)
        elif severity == IncidentSeverity.MEDIUM:
            self.execute_medium_response(incident)
        else:
            self.execute_low_response(incident)
    
    def execute_critical_response(self, incident: Dict):
        """Execute critical incident response"""
        # Immediate actions
        self.notify_incident_team(incident)
        self.notify_management(incident)
        
        # Containment actions
        if incident['type'] == 'DATA_BREACH':
            self.initiate_data_breach_protocol(incident)
        elif incident['type'] == 'SYSTEM_COMPROMISE':
            self.initiate_system_isolation(incident)
        
        # Start war room
        self.create_incident_war_room(incident)
    
    def initiate_data_breach_protocol(self, incident: Dict):
        """Initiate data breach response protocol"""
        # Immediate containment
        self.isolate_affected_systems(incident)
        
        # Evidence preservation
        self.preserve_evidence(incident)
        
        # Regulatory notification preparation
        self.prepare_regulatory_notifications(incident)
        
        # User notification preparation
        self.prepare_user_notifications(incident)
```

## 4. iOS Security Implementation

### 4.1 Advanced iOS Security Features

```swift
// iOS-Auth-App/Services/AdvancedSecurityManager.swift
import Foundation
import Security
import CryptoKit
import LocalAuthentication
import DeviceCheck

class AdvancedSecurityManager: ObservableObject {
    static let shared = AdvancedSecurityManager()
    
    private let keychain = KeychainManager()
    private let deviceCheck = DCDevice.current
    
    // MARK: - Certificate Pinning
    
    func validateCertificate(for challenge: URLAuthenticationChallenge) -> Bool {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return false
        }
        
        // Get the server certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }
        
        // Get the server certificate data
        let serverCertData = SecCertificateCopyData(serverCertificate)
        let serverCertDataRef = CFDataGetBytePtr(serverCertData)
        let serverCertDataLength = CFDataGetLength(serverCertData)
        
        // Load pinned certificates
        guard let pinnedCertData = loadPinnedCertificate() else {
            return false
        }
        
        // Compare certificates
        return pinnedCertData.withUnsafeBytes { pinnedBytes in
            return memcmp(serverCertDataRef, pinnedBytes.bindMemory(to: UInt8.self).baseAddress, min(serverCertDataLength, pinnedCertData.count)) == 0
        }
    }
    
    private func loadPinnedCertificate() -> Data? {
        guard let path = Bundle.main.path(forResource: "api-certificate", ofType: "cer"),
              let certData = NSData(contentsOfFile: path) as Data? else {
            return nil
        }
        return certData
    }
    
    // MARK: - Runtime Application Self-Protection (RASP)
    
    func performSecurityChecks() -> SecurityCheckResult {
        var issues: [SecurityIssue] = []
        
        // 1. Jailbreak detection
        if isJailbroken() {
            issues.append(.jailbreakDetected)
        }
        
        // 2. Debugger detection
        if isDebuggerAttached() {
            issues.append(.debuggerDetected)
        }
        
        // 3. Reverse engineering protection
        if isReverseEngineeringDetected() {
            issues.append(.reverseEngineeringDetected)
        }
        
        // 4. App integrity check
        if !isAppIntegrityValid() {
            issues.append(.appIntegrityCompromised)
        }
        
        // 5. Device attestation
        performDeviceAttestation { result in
            if case .failure = result {
                issues.append(.deviceAttestationFailed)
            }
        }
        
        return SecurityCheckResult(issues: issues)
    }
    
    private func isJailbroken() -> Bool {
        // Check for common jailbreak files
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if we can write to system directories
        let testString = "jailbreak test"
        do {
            try testString.write(toFile: "/private/test.txt", atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: "/private/test.txt")
            return true
        } catch {
            // This is expected on non-jailbroken devices
        }
        
        return false
    }
    
    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        
        if result != 0 {
            return false
        }
        
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    private func isReverseEngineeringDetected() -> Bool {
        // Check for common reverse engineering tools
        let suspiciousLibraries = [
            "FridaGadget",
            "frida",
            "cynject",
            "libcycript"
        ]
        
        for library in suspiciousLibraries {
            if dlopen(library, RTLD_NOW) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func isAppIntegrityValid() -> Bool {
        // Verify app signature
        guard let path = Bundle.main.executablePath else {
            return false
        }
        
        let url = URL(fileURLWithPath: path)
        var staticCode: SecStaticCode?
        
        let status = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        
        if status != errSecSuccess {
            return false
        }
        
        guard let code = staticCode else {
            return false
        }
        
        let validateStatus = SecStaticCodeCheckValidity(code, [], nil)
        return validateStatus == errSecSuccess
    }
    
    // MARK: - Device Attestation
    
    func performDeviceAttestation(completion: @escaping (Result<Data, Error>) -> Void) {
        guard deviceCheck.isSupported else {
            completion(.failure(SecurityError.deviceAttestationNotSupported))
            return
        }
        
        // Generate challenge data
        let challengeData = generateChallengeData()
        
        deviceCheck.generateToken { token, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let token = token else {
                completion(.failure(SecurityError.deviceAttestationFailed))
                return
            }
            
            // Send token to server for validation
            self.validateDeviceToken(token, challenge: challengeData) { result in
                completion(result)
            }
        }
    }
    
    private func generateChallengeData() -> Data {
        let challenge = UUID().uuidString + String(Date().timeIntervalSince1970)
        return challenge.data(using: .utf8) ?? Data()
    }
    
    private func validateDeviceToken(_ token: Data, challenge: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        let request = DeviceAttestationRequest(
            token: token.base64EncodedString(),
            challenge: challenge.base64EncodedString(),
            bundleId: Bundle.main.bundleIdentifier ?? "",
            timestamp: Date().timeIntervalSince1970
        )
        
        NetworkManager.shared.performDeviceAttestation(request) { result in
            completion(result)
        }
    }
    
    // MARK: - Secure Communication
    
    func createSecureChannel() -> SecureChannel {
        return SecureChannel()
    }
}

// MARK: - Supporting Types

enum SecurityIssue {
    case jailbreakDetected
    case debuggerDetected
    case reverseEngineeringDetected
    case appIntegrityCompromised
    case deviceAttestationFailed
}

struct SecurityCheckResult {
    let issues: [SecurityIssue]
    
    var isSecure: Bool {
        return issues.isEmpty
    }
    
    var riskLevel: RiskLevel {
        if issues.contains(.jailbreakDetected) || issues.contains(.reverseEngineeringDetected) {
            return .high
        } else if issues.contains(.debuggerDetected) || issues.contains(.appIntegrityCompromised) {
            return .medium
        } else if !issues.isEmpty {
            return .low
        } else {
            return .none
        }
    }
}

enum RiskLevel {
    case none, low, medium, high
}

enum SecurityError: Error {
    case deviceAttestationNotSupported
    case deviceAttestationFailed
    case certificatePinningFailed
    case integrityCheckFailed
}

struct DeviceAttestationRequest: Codable {
    let token: String
    let challenge: String
    let bundleId: String
    let timestamp: TimeInterval
}

class SecureChannel {
    private let symmetricKey: SymmetricKey
    
    init() {
        // Generate a new symmetric key for this session
        self.symmetricKey = SymmetricKey(size: .bits256)
    }
    
    func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        return sealedBox.combined!
    }
    
    func decrypt(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }
}
```

### 4.2 Biometric Security Enhancement

```swift
// iOS-Auth-App/Services/EnhancedBiometricManager.swift
import LocalAuthentication
import CryptoKit
import Security

class EnhancedBiometricManager: ObservableObject {
    static let shared = EnhancedBiometricManager()
    
    private var context = LAContext()
    
    // MARK: - Advanced Biometric Authentication
    
    func authenticateWithBiometrics(reason: String, completion: @escaping (Result<BiometricAuthResult, Error>) -> Void) {
        let context = LAContext()
        
        // Check for biometric changes
        if hasBiometricDataChanged() {
            completion(.failure(BiometricError.biometricDataChanged))
            return
        }
        
        // Set up context with enhanced security
        context.localizedFallbackTitle = "Use Passcode"
        context.touchIDAuthenticationAllowableReuseDuration = 0 // Require fresh authentication
        
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(.failure(error ?? BiometricError.notAvailable))
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    let result = BiometricAuthResult(
                        success: true,
                        biometricType: self.getBiometricType(),
                        timestamp: Date()
                    )
                    
                    // Store authentication proof
                    self.storeAuthenticationProof(result)
                    
                    completion(.success(result))
                } else {
                    completion(.failure(error ?? BiometricError.authenticationFailed))
                }
            }
        }
    }
    
    private func hasBiometricDataChanged() -> Bool {
        let context = LAContext()
        let currentData = context.evaluatedPolicyDomainState
        
        // Compare with stored domain state
        if let storedData = KeychainManager.shared.getBiometricDomainState() {
            return !storedData.elementsEqual(currentData ?? Data())
        }
        
        // Store current state if not exists
        if let currentData = currentData {
            KeychainManager.shared.storeBiometricDomainState(currentData)
        }
        
        return false
    }
    
    private func getBiometricType() -> BiometricType {
        let context = LAContext()
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
    
    private func storeAuthenticationProof(_ result: BiometricAuthResult) {
        let proof = BiometricAuthProof(
            timestamp: result.timestamp,
            biometricType: result.biometricType,
            hash: generateAuthProofHash(result)
        )
        
        KeychainManager.shared.storeBiometricAuthProof(proof)
    }
    
    private func generateAuthProofHash(_ result: BiometricAuthResult) -> String {
        let data = "\(result.timestamp.timeIntervalSince1970)\(result.biometricType.rawValue)".data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Secure Biometric Enrollment
    
    func enrollBiometric(completion: @escaping (Result<Void, Error>) -> Void) {
        let context = LAContext()
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Enroll biometric authentication") { success, error in
            DispatchQueue.main.async {
                if success {
                    // Store enrollment data
                    self.storeBiometricEnrollment()
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? BiometricError.enrollmentFailed))
                }
            }
        }
    }
    
    private func storeBiometricEnrollment() {
        let enrollment = BiometricEnrollment(
            enrollmentDate: Date(),
            biometricType: getBiometricType(),
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? ""
        )
        
        KeychainManager.shared.storeBiometricEnrollment(enrollment)
    }
}

// MARK: - Supporting Types

struct BiometricAuthResult {
    let success: Bool
    let biometricType: BiometricType
    let timestamp: Date
}

enum BiometricType: String, CaseIterable {
    case none = "none"
    case touchID = "touchID"
    case faceID = "faceID"
}

enum BiometricError: Error {
    case notAvailable
    case authenticationFailed
    case biometricDataChanged
    case enrollmentFailed
}

struct BiometricAuthProof: Codable {
    let timestamp: Date
    let biometricType: BiometricType
    let hash: String
}

struct BiometricEnrollment: Codable {
    let enrollmentDate: Date
    let biometricType: BiometricType
    let deviceId: String
}
```

## 5. Practical Exercises

### Exercise 1: Implement GDPR Compliance Handler
Create a complete GDPR compliance system that handles data subject requests, including data access, portability, and erasure requests.

### Exercise 2: Build Threat Detection System
Implement a real-time threat detection system that monitors authentication patterns and automatically responds to security threats.

### Exercise 3: Advanced iOS Security Implementation
Enhance the iOS app with advanced security features including certificate pinning, jailbreak detection, and secure communication channels.

### Exercise 4: Security Incident Response
Create a comprehensive incident response system that automatically handles security incidents based on severity levels.

### Exercise 5: Compliance Audit System
Build an automated compliance audit system that regularly checks for compliance with various security standards and regulations.

## 6. Testing and Validation

### 6.1 Security Testing Framework

```python
# tests/security_tests.py
import unittest
import json
from unittest.mock import Mock, patch
from security.threat_detection import ThreatDetectionSystem
from compliance.gdpr_handler import GDPRComplianceHandler

class SecurityTestSuite(unittest.TestCase):
    
    def setUp(self):
        self.threat_detector = ThreatDetectionSystem()
        self.gdpr_handler = GDPRComplianceHandler()
    
    def test_brute_force_detection(self):
        """Test brute force attack detection"""
        # Simulate multiple failed login attempts
        events = [
            {'user_id': 'test_user', 'ip_address': '192.168.1.100', 'status': 'FAILED'}
            for _ in range(6)
        ]
        
        # Mock DynamoDB response
        with patch.object(self.threat_detector, 'detect_brute_force', return_value=True):
            result = self.threat_detector.analyze_authentication_patterns(events[-1])
            
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertGreater(response_body['threats_detected'], 0)
    
    def test_gdpr_access_request(self):
        """Test GDPR data access request handling"""
        event = {
            'request_type': 'ACCESS',
            'user_id': 'test_user',
            'email': 'test@example.com'
        }
        
        with patch.object(self.gdpr_handler, 'collect_user_data', return_value={}):
            with patch.object(self.gdpr_handler, 's3') as mock_s3:
                mock_s3.put_object.return_value = {}
                mock_s3.generate_presigned_url.return_value = 'https://example.com/download'
                
                result = self.gdpr_handler.handle_data_subject_request(event)
                
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertIn('download_url', response_body)
    
    def test_impossible_travel_detection(self):
        """Test impossible travel detection"""
        # Mock geolocation data
        with patch.object(self.threat_detector, 'get_geolocation') as mock_geo:
            mock_geo.side_effect = [
                {'lat': 40.7128, 'lon': -74.0060},  # New York
                {'lat': 35.6762, 'lon': 139.6503}   # Tokyo
            ]
            
            with patch.object(self.threat_detector, 'calculate_distance', return_value=10000):
                result = self.threat_detector.detect_impossible_travel('test_user', '192.168.1.100')
                
        self.assertTrue(result)

if __name__ == '__main__':
    unittest.main()
```

### 6.2 iOS Security Tests

```swift
// iOS-Auth-App/Tests/SecurityTests.swift
import XCTest
@testable import iOS_Auth_App

class SecurityTests: XCTestCase {
    
    var securityManager: AdvancedSecurityManager!
    
    override func setUp() {
        super.setUp()
        securityManager = AdvancedSecurityManager.shared
    }
    
    func testSecurityChecks() {
        let result = securityManager.performSecurityChecks()
        
        // In a test environment, we expect certain security checks to pass
        XCTAssertTrue(result.issues.isEmpty || result.riskLevel == .low)
    }
    
    func testCertificatePinning() {
        // Create a mock challenge
        let challenge = URLAuthenticationChallenge()
        
        // Test certificate validation
        let isValid = securityManager.validateCertificate(for: challenge)
        
        // This would typically be true in production with proper certificates
        XCTAssertTrue(isValid || Bundle.main.path(forResource: "api-certificate", ofType: "cer") == nil)
    }
    
    func testSecureChannelEncryption() {
        let secureChannel = securityManager.createSecureChannel()
        let testData = "Test data for encryption".data(using: .utf8)!
        
        do {
            let encryptedData = try secureChannel.encrypt(testData)
            let decryptedData = try secureChannel.decrypt(encryptedData)
            
            XCTAssertEqual(testData, decryptedData)
        } catch {
            XCTFail("Encryption/decryption failed: \(error)")
        }
    }
    
    func testBiometricSecurity() {
        let biometricManager = EnhancedBiometricManager.shared
        
        let expectation = XCTestExpectation(description: "Biometric authentication")
        
        biometricManager.authenticateWithBiometrics(reason: "Test authentication") { result in
            switch result {
            case .success(let authResult):
                XCTAssertTrue(authResult.success)
            case .failure(let error):
                // Biometric authentication might fail in simulator
                XCTAssertTrue(error is BiometricError)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
```

## Summary

This lesson covered:

1. **Zero Trust Security Architecture**: Implementing comprehensive security measures with geo-blocking, rate limiting, and SQL injection protection
2. **Advanced Encryption**: KMS key management, Secrets Manager integration, and comprehensive encryption strategies
3. **GDPR Compliance**: Complete implementation of data subject rights, data retention policies, and privacy compliance
4. **Threat Detection**: Real-time monitoring for brute force attacks, impossible travel, and device anomalies
5. **Incident Response**: Automated security incident handling with severity-based response plans
6. **iOS Security**: Advanced mobile security with certificate pinning, jailbreak detection, and secure communication
7. **Compliance Frameworks**: Implementation of regulatory compliance including audit logging and data protection

## Next Steps

In the next lesson, we'll complete the course with a comprehensive final project that integrates all the concepts learned throughout the program, including portfolio development and deployment strategies.

## Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/security/security-resources/)
- [OWASP Mobile Security Testing Guide](https://owasp.org/www-project-mobile-security-testing-guide/)
- [GDPR Compliance Guide](https://gdpr.eu/)
- [iOS Security Guide](https://www.apple.com/business/docs/site/iOS_Security_Guide.pdf)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
