# Lesson 12: Infrastructure as Code & DevOps

**Duration:** 4 hours  
**Level:** Advanced  
**Prerequisites:** Completion of Phases 1-3, Basic AWS knowledge

## Learning Objectives

By the end of this lesson, you will be able to:
- Implement comprehensive Infrastructure as Code (IaC) with Terraform
- Set up CI/CD pipelines for both iOS and backend deployments
- Implement automated testing and deployment strategies
- Configure multi-environment deployments (dev, staging, production)
- Set up monitoring and alerting for infrastructure
- Implement security best practices in DevOps workflows

## 1. Advanced Terraform Infrastructure

### 1.1 Multi-Environment Terraform Structure

Let's create a comprehensive multi-environment infrastructure setup:

```hcl
# terraform/environments/dev/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "your-terraform-state-dev"
    key            = "auth-app/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-dev"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "development"
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

# Local variables
locals {
  environment = "dev"
  domain_name = "dev-auth.yourcompany.com"
  
  common_tags = {
    Environment = local.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  environment    = local.environment
  project_name   = var.project_name
  cidr_block     = "10.0.0.0/16"
  
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  
  tags = local.common_tags
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  environment         = local.environment
  project_name        = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Security configurations
  enable_waf                = true
  enable_shield_advanced    = false
  enable_guardduty         = true
  enable_config            = true
  enable_cloudtrail        = true
  
  # Compliance settings
  compliance_mode          = "moderate"
  data_classification      = "internal"
  
  # KMS encryption
  enable_kms_encryption    = true
  kms_key_rotation_enabled = true
  
  tags = local.common_tags
}

# Database Module
module "database" {
  source = "../../modules/dynamodb"
  
  environment  = local.environment
  project_name = var.project_name
  
  # DynamoDB settings for development
  billing_mode     = "PAY_PER_REQUEST"
  backup_retention = 7
  point_in_time_recovery = false
  
  kms_key_arn = module.security.kms_key_arn
  
  tables = {
    users = {
      hash_key = "user_id"
      attributes = [
        {
          name = "user_id"
          type = "S"
        },
        {
          name = "email"
          type = "S"
        }
      ]
      global_secondary_indexes = [
        {
          name     = "email-index"
          hash_key = "email"
        }
      ]
    }
    sessions = {
      hash_key = "session_id"
      range_key = "user_id"
      ttl_attribute = "expires_at"
      attributes = [
        {
          name = "session_id"
          type = "S"
        },
        {
          name = "user_id"
          type = "S"
        }
      ]
    }
    analytics = {
      hash_key = "event_type"
      range_key = "timestamp"
      attributes = [
        {
          name = "event_type"
          type = "S"
        },
        {
          name = "timestamp"
          type = "S"
        }
      ]
    }
  }
  
  tags = local.common_tags
}

# Lambda Module
module "lambda" {
  source = "../../modules/lambda"
  
  environment  = local.environment
  project_name = var.project_name
  
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.security.lambda_security_group_id]
  
  # Lambda configurations
  runtime     = "nodejs18.x"
  memory_size = 256
  timeout     = 30
  
  # Environment variables
  environment_variables = {
    ENVIRONMENT       = local.environment
    USERS_TABLE      = module.database.table_names["users"]
    SESSIONS_TABLE   = module.database.table_names["sessions"]
    ANALYTICS_TABLE  = module.database.table_names["analytics"]
    KMS_KEY_ID       = module.security.kms_key_id
    LOG_LEVEL        = "INFO"
  }
  
  # IAM permissions
  dynamodb_table_arns = module.database.table_arns
  kms_key_arn        = module.security.kms_key_arn
  
  tags = local.common_tags
}

# API Gateway Module
module "api_gateway" {
  source = "../../modules/api-gateway"
  
  environment  = local.environment
  project_name = var.project_name
  
  domain_name = local.domain_name
  
  # Lambda integration
  lambda_function_arn = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
  
  # WAF integration
  web_acl_arn = module.security.waf_web_acl_arn
  
  # API Gateway settings
  throttle_burst_limit = 1000
  throttle_rate_limit  = 500
  
  # CORS settings
  cors_configuration = {
    allow_credentials = true
    allow_headers    = ["authorization", "content-type", "x-amz-date", "x-api-key", "x-amz-security-token"]
    allow_methods    = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins    = ["https://dev-app.yourcompany.com"]
    expose_headers   = ["x-amz-request-id"]
    max_age         = 300
  }
  
  tags = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  environment  = local.environment
  project_name = var.project_name
  
  # Resource ARNs for monitoring
  lambda_function_name = module.lambda.function_name
  api_gateway_name     = module.api_gateway.api_name
  dynamodb_table_names = module.database.table_names
  
  # Alert settings
  alert_email = var.alert_email
  
  # Monitoring configuration
  enable_detailed_monitoring = true
  log_retention_days        = 14
  
  tags = local.common_tags
}
```

### 1.2 Environment-Specific Variables

```hcl
# terraform/environments/dev/variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "auth-app"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "development-team"
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = "alerts-dev@yourcompany.com"
}

# terraform/environments/dev/terraform.tfvars
aws_region    = "us-east-1"
project_name  = "auth-app"
owner         = "development-team"
alert_email   = "alerts-dev@yourcompany.com"
```

### 1.3 Production Environment Configuration

```hcl
# terraform/environments/prod/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "your-terraform-state-prod"
    key            = "auth-app/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-prod"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

# Production-specific configurations
locals {
  environment = "prod"
  domain_name = "auth.yourcompany.com"
  
  common_tags = {
    Environment = local.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
    Compliance  = "required"
  }
}

# Enhanced security for production
module "security" {
  source = "../../modules/security"
  
  environment         = local.environment
  project_name        = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Enhanced security for production
  enable_waf                = true
  enable_shield_advanced    = true
  enable_guardduty         = true
  enable_config            = true
  enable_cloudtrail        = true
  enable_inspector         = true
  
  # Strict compliance mode
  compliance_mode          = "strict"
  data_classification      = "sensitive"
  
  # Enhanced encryption
  enable_kms_encryption    = true
  kms_key_rotation_enabled = true
  
  # Backup and recovery
  backup_retention_days    = 90
  cross_region_backup      = true
  
  tags = local.common_tags
}

# Production database with provisioned capacity
module "database" {
  source = "../../modules/dynamodb"
  
  environment  = local.environment
  project_name = var.project_name
  
  # Production DynamoDB settings
  billing_mode           = "PROVISIONED"
  read_capacity         = 20
  write_capacity        = 20
  backup_retention      = 30
  point_in_time_recovery = true
  deletion_protection   = true
  
  # Auto-scaling configuration
  enable_autoscaling = true
  autoscaling_read_target  = 70
  autoscaling_write_target = 70
  autoscaling_read_min     = 5
  autoscaling_read_max     = 100
  autoscaling_write_min    = 5
  autoscaling_write_max    = 100
  
  kms_key_arn = module.security.kms_key_arn
  
  # Same table structure as dev but with production settings
  tables = {
    users = {
      hash_key = "user_id"
      attributes = [
        {
          name = "user_id"
          type = "S"
        },
        {
          name = "email"
          type = "S"
        }
      ]
      global_secondary_indexes = [
        {
          name               = "email-index"
          hash_key          = "email"
          read_capacity     = 10
          write_capacity    = 10
        }
      ]
    }
    # ... other tables
  }
  
  tags = local.common_tags
}

# Production Lambda with reserved concurrency
module "lambda" {
  source = "../../modules/lambda"
  
  environment  = local.environment
  project_name = var.project_name
  
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.security.lambda_security_group_id]
  
  # Production Lambda settings
  runtime               = "nodejs18.x"
  memory_size          = 512
  timeout              = 30
  reserved_concurrency = 100
  
  # Enhanced monitoring
  enable_xray_tracing = true
  
  # Production environment variables
  environment_variables = {
    ENVIRONMENT       = local.environment
    USERS_TABLE      = module.database.table_names["users"]
    SESSIONS_TABLE   = module.database.table_names["sessions"]
    ANALYTICS_TABLE  = module.database.table_names["analytics"]
    KMS_KEY_ID       = module.security.kms_key_id
    LOG_LEVEL        = "WARN"
    ENABLE_METRICS   = "true"
  }
  
  tags = local.common_tags
}
```

## 2. CI/CD Pipeline Setup

### 2.1 GitHub Actions for Backend Deployment

```yaml
# .github/workflows/backend-deploy.yml
name: Backend Deployment

on:
  push:
    branches: [main, develop]
    paths: 
      - 'aws-lambda/**'
      - 'terraform/**'
      - '.github/workflows/backend-deploy.yml'
  pull_request:
    branches: [main]
    paths:
      - 'aws-lambda/**'
      - 'terraform/**'

env:
  AWS_REGION: us-east-1
  NODE_VERSION: '18'
  TERRAFORM_VERSION: '1.5.0'

jobs:
  # Code Quality and Testing
  quality-checks:
    name: Quality Checks
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: aws-lambda/package-lock.json

      - name: Install dependencies
        run: |
          cd aws-lambda
          npm ci

      - name: Run ESLint
        run: |
          cd aws-lambda
          npm run lint

      - name: Run Prettier
        run: |
          cd aws-lambda
          npm run format:check

      - name: Run unit tests
        run: |
          cd aws-lambda
          npm run test:unit

      - name: Run integration tests
        run: |
          cd aws-lambda
          npm run test:integration

      - name: Generate test coverage
        run: |
          cd aws-lambda
          npm run test:coverage

      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          file: aws-lambda/coverage/lcov.info
          flags: backend

  # Security Scanning
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run npm audit
        run: |
          cd aws-lambda
          npm audit --audit-level moderate

      - name: Run Snyk security scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=medium
          command: test

      - name: Run Semgrep security scan
        uses: returntocorp/semgrep-action@v1
        with:
          config: p/security-audit p/secrets p/owasp-top-ten

  # Terraform Planning
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    needs: [quality-checks, security-scan]
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        run: |
          cd terraform/environments/${{ matrix.environment }}
          terraform init

      - name: Terraform Validate
        run: |
          cd terraform/environments/${{ matrix.environment }}
          terraform validate

      - name: Terraform Plan
        run: |
          cd terraform/environments/${{ matrix.environment }}
          terraform plan -out=tfplan

      - name: Upload Terraform plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan-${{ matrix.environment }}
          path: terraform/environments/${{ matrix.environment }}/tfplan

  # Development Deployment
  deploy-dev:
    name: Deploy to Development
    runs-on: ubuntu-latest
    needs: [terraform-plan]
    if: github.ref == 'refs/heads/develop'
    environment: development
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_DEV }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_DEV }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Build Lambda package
        run: |
          cd aws-lambda
          npm ci --production
          zip -r ../lambda-package.zip .

      - name: Download Terraform plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan-dev
          path: terraform/environments/dev/

      - name: Terraform Apply
        run: |
          cd terraform/environments/dev
          terraform init
          terraform apply tfplan

      - name: Deploy Lambda function
        run: |
          aws lambda update-function-code \
            --function-name auth-app-dev-auth-handler \
            --zip-file fileb://lambda-package.zip

      - name: Run smoke tests
        run: |
          cd aws-lambda
          npm run test:smoke -- --environment=dev

  # Staging Deployment
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: [deploy-dev]
    if: github.ref == 'refs/heads/main'
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_STAGING }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_STAGING }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Build Lambda package
        run: |
          cd aws-lambda
          npm ci --production
          zip -r ../lambda-package.zip .

      - name: Download Terraform plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan-staging
          path: terraform/environments/staging/

      - name: Terraform Apply
        run: |
          cd terraform/environments/staging
          terraform init
          terraform apply tfplan

      - name: Deploy Lambda function
        run: |
          aws lambda update-function-code \
            --function-name auth-app-staging-auth-handler \
            --zip-file fileb://lambda-package.zip

      - name: Run end-to-end tests
        run: |
          cd aws-lambda
          npm run test:e2e -- --environment=staging

      - name: Performance testing
        run: |
          cd aws-lambda
          npm run test:performance -- --environment=staging

  # Production Deployment
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [deploy-staging]
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Build Lambda package
        run: |
          cd aws-lambda
          npm ci --production
          zip -r ../lambda-package.zip .

      - name: Download Terraform plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan-prod
          path: terraform/environments/prod/

      - name: Terraform Apply
        run: |
          cd terraform/environments/prod
          terraform init
          terraform apply tfplan

      - name: Deploy Lambda function with blue-green
        run: |
          # Create new version
          NEW_VERSION=$(aws lambda publish-version \
            --function-name auth-app-prod-auth-handler \
            --zip-file fileb://lambda-package.zip \
            --query 'Version' --output text)
          
          # Update alias to point to new version
          aws lambda update-alias \
            --function-name auth-app-prod-auth-handler \
            --name LIVE \
            --function-version $NEW_VERSION

      - name: Run production smoke tests
        run: |
          cd aws-lambda
          npm run test:smoke -- --environment=production

      - name: Notify deployment success
        uses: 8398a7/action-slack@v3
        with:
          status: success
          channel: '#deployments'
          text: 'Production deployment completed successfully!'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

  # Rollback job (manual trigger)
  rollback-production:
    name: Rollback Production
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch'
    environment: production
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Rollback Lambda function
        run: |
          # Get previous version
          PREVIOUS_VERSION=$(aws lambda list-versions-by-function \
            --function-name auth-app-prod-auth-handler \
            --query 'Versions[-2].Version' --output text)
          
          # Update alias to point to previous version
          aws lambda update-alias \
            --function-name auth-app-prod-auth-handler \
            --name LIVE \
            --function-version $PREVIOUS_VERSION

      - name: Notify rollback
        uses: 8398a7/action-slack@v3
        with:
          status: warning
          channel: '#deployments'
          text: 'Production rollback completed!'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 2.2 iOS App CI/CD Pipeline

```yaml
# .github/workflows/ios-deploy.yml
name: iOS App Deployment

on:
  push:
    branches: [main, develop]
    paths: 
      - 'ios-app/**'
      - '.github/workflows/ios-deploy.yml'
  pull_request:
    branches: [main]
    paths:
      - 'ios-app/**'

env:
  XCODE_VERSION: '15.0'
  IOS_SIMULATOR: 'iPhone 15 Pro'
  IOS_VERSION: '17.0'

jobs:
  # Code Quality and Testing
  ios-quality-checks:
    name: iOS Quality Checks
    runs-on: macos-13
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      - name: Show Xcode version
        run: xcodebuild -version

      - name: Install dependencies
        run: |
          cd ios-app
          pod install

      - name: SwiftLint
        run: |
          cd ios-app
          if which swiftlint >/dev/null; then
            swiftlint
          else
            echo "SwiftLint not installed"
          fi

      - name: Build for testing
        run: |
          cd ios-app
          xcodebuild -workspace iOS-Auth-App.xcworkspace \
            -scheme iOS-Auth-App \
            -destination "platform=iOS Simulator,name=${{ env.IOS_SIMULATOR }},OS=${{ env.IOS_VERSION }}" \
            -configuration Debug \
            build-for-testing

      - name: Run unit tests
        run: |
          cd ios-app
          xcodebuild -workspace iOS-Auth-App.xcworkspace \
            -scheme iOS-Auth-App \
            -destination "platform=iOS Simulator,name=${{ env.IOS_SIMULATOR }},OS=${{ env.IOS_VERSION }}" \
            -configuration Debug \
            test-without-building \
            -testPlan UnitTests

      - name: Run UI tests
        run: |
          cd ios-app
          xcodebuild -workspace iOS-Auth-App.xcworkspace \
            -scheme iOS-Auth-App \
            -destination "platform=iOS Simulator,name=${{ env.IOS_SIMULATOR }},OS=${{ env.IOS_VERSION }}" \
            -configuration Debug \
            test-without-building \
            -testPlan UITests

      - name: Generate test coverage
        run: |
          cd ios-app
          xcrun xccov view --report --json DerivedData/Build/Logs/Test/*.xcresult > coverage.json

      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: ios-test-results
          path: ios-app/DerivedData/Build/Logs/Test/

  # Security Scanning
  ios-security-scan:
    name: iOS Security Scan
    runs-on: macos-13
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      - name: Install dependencies
        run: |
          cd ios-app
          pod install

      - name: Static Analysis
        run: |
          cd ios-app
          xcodebuild -workspace iOS-Auth-App.xcworkspace \
            -scheme iOS-Auth-App \
            -destination generic/platform=iOS \
            -configuration Release \
            analyze

      - name: Check for hardcoded secrets
        run: |
          cd ios-app
          # Use grep to find potential hardcoded secrets
          ! grep -r "password\|secret\|key\|token" --include="*.swift" --include="*.m" --include="*.h" . || echo "Potential hardcoded secrets found"

  # TestFlight Deployment
  deploy-testflight:
    name: Deploy to TestFlight
    runs-on: macos-13
    needs: [ios-quality-checks, ios-security-scan]
    if: github.ref == 'refs/heads/main'
    environment: testflight
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      - name: Install Apple Certificate
        env:
          BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
          P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          # Create variables
          CERTIFICATE_PATH=$RUNNER_TEMP/build_certificate.p12
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db

          # Import certificate from secrets
          echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode --output $CERTIFICATE_PATH

          # Create temporary keychain
          security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

          # Import certificate to keychain
          security import $CERTIFICATE_PATH -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
          security list-keychain -d user -s $KEYCHAIN_PATH

      - name: Install Provisioning Profile
        env:
          PROVISIONING_PROFILE_BASE64: ${{ secrets.PROVISIONING_PROFILE_BASE64 }}
        run: |
          PP_PATH=$RUNNER_TEMP/build_pp.mobileprovision
          echo -n "$PROVISIONING_PROFILE_BASE64" | base64 --decode --output $PP_PATH
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          cp $PP_PATH ~/Library/MobileDevice/Provisioning\ Profiles

      - name: Install dependencies
        run: |
          cd ios-app
          pod install

      - name: Increment build number
        run: |
          cd ios-app
          # Get current build number from App Store Connect and increment
          BUILD_NUMBER=$(date +%Y%m%d%H%M%S)
          /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" iOS-Auth-App/Info.plist

      - name: Build and Archive
        run: |
          cd ios-app
          xcodebuild -workspace iOS-Auth-App.xcworkspace \
            -scheme iOS-Auth-App \
            -archivePath $RUNNER_TEMP/iOS-Auth-App.xcarchive \
            -configuration Release \
            -destination generic/platform=iOS \
            archive

      - name: Export Archive
        env:
          EXPORT_OPTIONS_PLIST: ${{ secrets.EXPORT_OPTIONS_PLIST }}
        run: |
          cd ios-app
          EXPORT_OPTS_PATH=$RUNNER_TEMP/ExportOptions.plist
          echo -n "$EXPORT_OPTIONS_PLIST" | base64 --decode --output $EXPORT_OPTS_PATH
          xcodebuild -exportArchive \
            -archivePath $RUNNER_TEMP/iOS-Auth-App.xcarchive \
            -exportOptionsPlist $EXPORT_OPTS_PATH \
            -exportPath $RUNNER_TEMP/build

      - name: Upload to TestFlight
        env:
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_KEY_IDENTIFIER: ${{ secrets.APP_STORE_CONNECT_KEY_IDENTIFIER }}
          APP_STORE_CONNECT_PRIVATE_KEY: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY }}
        run: |
          xcrun altool --upload-app \
            --type ios \
            --file "$RUNNER_TEMP/build/iOS-Auth-App.ipa" \
            --apiKey "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
            --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

      - name: Clean up keychain and provisioning profile
        if: always()
        run: |
          security delete-keychain $RUNNER_TEMP/app-signing.keychain-db
          rm ~/Library/MobileDevice/Provisioning\ Profiles/build_pp.mobileprovision

      - name: Notify TestFlight deployment
        uses: 8398a7/action-slack@v3
        with:
          status: success
          channel: '#ios-deployments'
          text: 'iOS app deployed to TestFlight successfully!'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

  # App Store Deployment (Manual approval required)
  deploy-app-store:
    name: Deploy to App Store
    runs-on: macos-13
    needs: [deploy-testflight]
    if: github.event_name == 'workflow_dispatch'
    environment: app-store
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to App Store
        env:
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_KEY_IDENTIFIER: ${{ secrets.APP_STORE_CONNECT_KEY_IDENTIFIER }}
          APP_STORE_CONNECT_PRIVATE_KEY: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY }}
        run: |
          # This would typically involve App Store Connect API calls
          # to submit the latest TestFlight build for review
          echo "App Store deployment would be configured here"

      - name: Notify App Store submission
        uses: 8398a7/action-slack@v3
        with:
          status: success
          channel: '#ios-deployments'
          text: 'iOS app submitted to App Store for review!'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## 3. Automated Testing Strategy

### 3.1 Backend Testing Pipeline

```javascript
// aws-lambda/tests/integration/auth.integration.test.js
const AWS = require('aws-sdk');
const { handler } = require('../../src/authHandler');

// Mock AWS services for integration testing
AWS.config.update({
  region: 'us-east-1',
  endpoint: 'http://localhost:8000', // DynamoDB Local
  accessKeyId: 'dummy',
  secretAccessKey: 'dummy'
});

describe('Authentication Integration Tests', () => {
  let dynamodb;
  
  beforeAll(async () => {
    dynamodb = new AWS.DynamoDB();
    
    // Create test tables
    await createTestTables();
  });
  
  afterAll(async () => {
    // Clean up test tables
    await cleanupTestTables();
  });
  
  beforeEach(async () => {
    // Clean test data
    await clearTestData();
  });

  describe('User Registration', () => {
    test('should register a new user successfully', async () => {
      const event = {
        httpMethod: 'POST',
        path: '/auth/register',
        body: JSON.stringify({
          email: 'test@example.com',
          password: 'SecurePassword123!',
          displayName: 'Test User'
        }),
        headers: {
          'Content-Type': 'application/json'
        }
      };

      const result = await handler(event);
      
      expect(result.statusCode).toBe(201);
      
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.user.email).toBe('test@example.com');
      expect(body.user.displayName).toBe('Test User');
      expect(body.accessToken).toBeDefined();
    });

    test('should reject duplicate email registration', async () => {
      // First registration
      await registerUser('test@example.com', 'SecurePassword123!');
      
      // Duplicate registration attempt
      const event = {
        httpMethod: 'POST',
        path: '/auth/register',
        body: JSON.stringify({
          email: 'test@example.com',
          password: 'AnotherPassword123!',
          displayName: 'Another User'
        }),
        headers: {
          'Content-Type': 'application/json'
        }
      };

      const result = await handler(event);
      
      expect(result.statusCode).toBe(409);
      
      const body = JSON.parse(result.body);
      expect(body.error).toBe(true);
      expect(body.message).toContain('already exists');
    });
  });

  describe('User Authentication', () => {
    beforeEach(async () => {
      await registerUser('test@example.com', 'SecurePassword123!');
    });

    test('should authenticate user with valid credentials', async () => {
      const event = {
        httpMethod: 'POST',
        path: '/auth/login',
        body: JSON.stringify({
          email: 'test@example.com',
          password: 'SecurePassword123!'
        }),
        headers: {
          'Content-Type': 'application/json'
        }
      };

      const result = await handler(event);
      
      expect(result.statusCode).toBe(200);
      
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.user.email).toBe('test@example.com');
      expect(body.accessToken).toBeDefined();
    });

    test('should reject invalid credentials', async () => {
      const event = {
        httpMethod: 'POST',
        path: '/auth/login',
        body: JSON.stringify({
          email: 'test@example.com',
          password: 'WrongPassword123!'
        }),
        headers: {
          'Content-Type': 'application/json'
        }
      };

      const result = await handler(event);
      
      expect(result.statusCode).toBe(401);
      
      const body = JSON.parse(result.body);
      expect(body.error).toBe(true);
      expect(body.message).toContain('Invalid credentials');
    });
  });

  // Helper functions
  async function createTestTables() {
    const tableParams = {
      TableName: 'auth-app-test-users',
      KeySchema: [
        { AttributeName: 'user_id', KeyType: 'HASH' }
      ],
      AttributeDefinitions: [
        { AttributeName: 'user_id', AttributeType: 'S' },
        { AttributeName: 'email', AttributeType: 'S' }
      ],
      BillingMode: 'PAY_PER_REQUEST',
      GlobalSecondaryIndexes: [
        {
          IndexName: 'email-index',
          KeySchema: [
            { AttributeName: 'email', KeyType: 'HASH' }
          ],
          Projection: { ProjectionType: 'ALL' }
        }
      ]
    };

    try {
      await dynamodb.createTable(tableParams).promise();
      // Wait for table to be active
      await dynamodb.waitFor('tableExists', { TableName: 'auth-app-test-users' }).promise();
    } catch (error) {
      if (error.code !== 'ResourceInUseException') {
        throw error;
      }
    }
  }

  async function cleanupTestTables() {
    try {
      await dynamodb.deleteTable({ TableName: 'auth-app-test-users' }).promise();
    } catch (error) {
      // Ignore if table doesn't exist
    }
  }

  async function clearTestData() {
    const docClient = new AWS.DynamoDB.DocumentClient();
    
    // Scan and delete all items
    const scanResult = await docClient.scan({
      TableName: 'auth-app-test-users'
    }).promise();

    for (const item of scanResult.Items) {
      await docClient.delete({
        TableName: 'auth-app-test-users',
        Key: { user_id: item.user_id }
      }).promise();
    }
  }

  async function registerUser(email, password) {
    const event = {
      httpMethod: 'POST',
      path: '/auth/register',
      body: JSON.stringify({
        email: email,
        password: password,
        displayName: 'Test User'
      }),
      headers: {
        'Content-Type': 'application/json'
      }
    };

    return await handler(event);
  }
});
```

### 3.2 Performance Testing

```javascript
// aws-lambda/tests/performance/load.test.js
const autocannon = require('autocannon');

describe('Performance Tests', () => {
  const apiBaseUrl = process.env.API_BASE_URL || 'https://api-dev.yourcompany.com';
  
  test('Authentication endpoint load test', async () => {
    const result = await autocannon({
      url: `${apiBaseUrl}/auth/login`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email: 'loadtest@example.com',
        password: 'LoadTestPassword123!'
      }),
      connections: 50,
      duration: 30, // 30 seconds
      pipelining: 1
    });

    expect(result.requests.average).toBeGreaterThan(100); // At least 100 req/sec
    expect(result.latency.p95).toBeLessThan(1000); // 95th percentile under 1 second
    expect(result.errors).toBe(0); // No errors
  });

  test('User registration load test', async () => {
    const result = await autocannon({
      url: `${apiBaseUrl}/auth/register`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email: 'newuser@example.com',
        password: 'NewUserPassword123!',
        displayName: 'New User'
      }),
      connections: 25,
      duration: 15,
      pipelining: 1
    });

    expect(result.requests.average).toBeGreaterThan(50); // At least 50 req/sec
    expect(result.latency.p95).toBeLessThan(2000); // 95th percentile under 2 seconds
  });
});
```

## 4. Monitoring and Alerting in DevOps

### 4.1 Infrastructure Monitoring with Terraform

```hcl
# terraform/modules/devops-monitoring/main.tf
resource "aws_cloudwatch_dashboard" "devops_dashboard" {
  dashboard_name = "${var.project_name}-devops-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# ${var.project_name} DevOps Dashboard\n\nReal-time monitoring of deployment pipelines, infrastructure health, and application performance."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-auth-handler"],
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-auth-handler"],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-auth-handler"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Performance"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "${var.project_name}-auth-api"],
            ["AWS/ApiGateway", "Latency", "ApiName", "${var.project_name}-auth-api"],
            ["AWS/ApiGateway", "4XXError", "ApiName", "${var.project_name}-auth-api"],
            ["AWS/ApiGateway", "5XXError", "ApiName", "${var.project_name}-auth-api"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "${var.project_name}-users"],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", "${var.project_name}-users"],
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", "${var.project_name}-users"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB Performance"
          period  = 300
        }
      }
    ]
  })
}

# Deployment Pipeline Monitoring
resource "aws_cloudwatch_metric_alarm" "deployment_failure_alarm" {
  alarm_name          = "${var.project_name}-deployment-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DeploymentFailures"
  namespace           = "${var.project_name}/CI-CD"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Deployment pipeline has failed"
  alarm_actions       = [aws_sns_topic.devops_alerts.arn]
  ok_actions          = [aws_sns_topic.devops_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate_alarm" {
  alarm_name          = "${var.project_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "High error rate detected in Lambda function"
  alarm_actions       = [aws_sns_topic.devops_alerts.arn]

  dimensions = {
    FunctionName = "${var.project_name}-auth-handler"
  }
}

# SNS Topics for DevOps Alerts
resource "aws_sns_topic" "devops_alerts" {
  name = "${var.project_name}-devops-alerts"
}

resource "aws_sns_topic_subscription" "devops_email_alerts" {
  topic_arn = aws_sns_topic.devops_alerts.arn
  protocol  = "email"
  endpoint  = var.devops_alert_email
}

resource "aws_sns_topic_subscription" "devops_slack_alerts" {
  topic_arn = aws_sns_topic.devops_alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# Log Groups with Retention
resource "aws_cloudwatch_log_group" "deployment_logs" {
  name              = "/aws/lambda/${var.project_name}-deployment"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Custom Metrics for CI/CD Pipeline
resource "aws_cloudwatch_log_metric_filter" "deployment_success" {
  name           = "${var.project_name}-deployment-success"
  log_group_name = aws_cloudwatch_log_group.deployment_logs.name
  pattern        = "[timestamp, request_id, \"DEPLOYMENT_SUCCESS\", ...]"

  metric_transformation {
    name      = "DeploymentSuccess"
    namespace = "${var.project_name}/CI-CD"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "deployment_failure" {
  name           = "${var.project_name}-deployment-failure"
  log_group_name = aws_cloudwatch_log_group.deployment_logs.name
  pattern        = "[timestamp, request_id, \"DEPLOYMENT_FAILURE\", ...]"

  metric_transformation {
    name      = "DeploymentFailures"
    namespace = "${var.project_name}/CI-CD"
    value     = "1"
  }
}
```

## 5. Practical Exercises

### Exercise 1: Multi-Environment Infrastructure
1. Set up development, staging, and production environments using Terraform
2. Configure environment-specific variables and settings
3. Deploy infrastructure to each environment
4. Verify environment isolation and security

### Exercise 2: CI/CD Pipeline Implementation
1. Set up GitHub Actions workflows for backend and iOS
2. Configure automated testing and quality checks
3. Implement deployment automation with proper approvals
4. Test the complete pipeline from code commit to production

### Exercise 3: Infrastructure Monitoring
1. Deploy comprehensive monitoring for all environments
2. Set up alerts for critical infrastructure metrics
3. Create custom dashboards for DevOps visibility
4. Test alert notifications and response procedures

### Exercise 4: Automated Testing Integration
1. Implement unit, integration, and performance tests
2. Configure test automation in CI/CD pipeline
3. Set up test environment provisioning
4. Create test reporting and coverage analysis

## 6. Security and Compliance in DevOps

### 6.1 Security Scanning Integration

```yaml
# .github/workflows/security-scan.yml
name: Security Scanning

on:
  schedule:
    - cron: '0 2 * * *' # Daily at 2 AM
  push:
    branches: [main, develop]

jobs:
  terraform-security-scan:
    name: Terraform Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform
          output_format: sarif
          output_file_path: checkov-results.sarif

      - name: Upload Checkov results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: checkov-results.sarif

      - name: Run Terrascan
        uses: accurics/terrascan-action@main
        with:
          iac_type: terraform
          iac_dir: terraform/
          policy_type: aws
          only_warn: false

  dependency-security-scan:
    name: Dependency Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run npm audit
        run: |
          cd aws-lambda
          npm audit --audit-level moderate

      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=medium

  secrets-scan:
    name: Secrets Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run GitLeaks
        uses: zricethezav/gitleaks-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 7. Disaster Recovery and Backup

### 7.1 Automated Backup Strategy

```hcl
# terraform/modules/backup/main.tf
resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = var.tags
}

resource "aws_backup_plan" "main" {
  name = "${var.project_name}-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * * *)" # Daily at 5 AM

    recovery_point_tags = var.tags

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.main.arn
      
      lifecycle {
        cold_storage_after = 30
        delete_after       = 365
      }
    }
  }

  rule {
    rule_name         = "weekly_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * SUN *)" # Weekly on Sunday

    recovery_point_tags = merge(var.tags, {
      "backup-type" = "weekly"
    })

    lifecycle {
      cold_storage_after = 90
      delete_after       = 2555 # 7 years
    }
  }

  tags = var.tags
}

# Backup selection for DynamoDB tables
resource "aws_backup_selection" "dynamodb" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project_name}-dynamodb-backup"
  plan_id      = aws_backup_plan.main.id

  resources = var.dynamodb_table_arns
}

# IAM role for AWS Backup
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
```

## Summary

In this lesson, we implemented comprehensive Infrastructure as Code and DevOps practices:

1. **Multi-Environment Infrastructure**: Terraform configurations for dev, staging, and production
2. **CI/CD Pipelines**: Automated testing and deployment for both backend and iOS
3. **Security Integration**: Automated security scanning and compliance checks
4. **Monitoring and Alerting**: Infrastructure monitoring with automated alerts
5. **Backup and Recovery**: Automated backup strategies for disaster recovery

**Key DevOps Principles Implemented:**
- Infrastructure as Code with Terraform
- Automated testing and quality gates
- Continuous integration and deployment
- Security scanning and compliance
- Monitoring and observability
- Disaster recovery planning

**Next Steps:**
- Implement blue-green deployments for zero-downtime releases
- Set up infrastructure drift detection
- Implement automated rollback procedures
- Enhance security scanning with custom policies
- Set up compliance reporting and auditing

**Continue to:** [Lesson 11: Advanced Security & Compliance](lesson11-advanced-security.md)
