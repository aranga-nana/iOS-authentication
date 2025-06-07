# Terraform Infrastructure for iOS Authentication System

This directory contains the Terraform configuration for deploying the supporting AWS infrastructure for the iOS authentication system. The core Lambda functions and API Gateway are deployed using AWS SAM (see `../aws-lambda/` directory), while this Terraform configuration manages the broader infrastructure components.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CloudFront    │───▶│   API Gateway    │───▶│   Lambda Fns    │ ← SAM Managed
└─────────────────┘    └──────────────────┘    └─────────────────┘
        ↑                        ↑                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│      WAF        │    │  Custom Domain   │    │   DynamoDB      │ ← SAM Managed
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                               ┌─────────────────────────┼─────────────────────────┐
                               │                         │                         │
                    ┌──────────▼──────────┐   ┌─────────▼─────────┐   ┌─────────▼─────────┐
                    │   Secrets Manager   │   │   CloudWatch      │   │      IAM          │
                    │  (Firebase Keys)    │   │   Enhanced        │   │   Additional      │
                    └─────────────────────┘   └───────────────────┘   └───────────────────┘
```

## Terraform vs SAM Division

### SAM Manages (../aws-lambda/)
- **Lambda Functions**: Authentication business logic
- **API Gateway**: Core REST API endpoints
- **DynamoDB**: User data tables with indexes
- **Basic CloudWatch**: Function logs and metrics
- **Basic IAM**: Function execution roles

### Terraform Manages (this directory)
- **CloudFront Distribution**: CDN and DDoS protection
- **WAF**: Web Application Firewall rules
- **Custom Domain**: API Gateway custom domain setup
- **Certificate Manager**: SSL/TLS certificates
- **Secrets Manager**: Secure Firebase credentials storage
- **Enhanced CloudWatch**: Custom dashboards and alarms
- **Cross-Environment Resources**: Shared infrastructure

## Integration with SAM

This Terraform configuration is designed to complement the SAM deployment:

1. **Deploy SAM Stack First**: The core Lambda/API infrastructure
2. **Deploy Terraform**: The supporting infrastructure that references SAM outputs

```bash
# 1. Deploy SAM stack
cd ../aws-lambda
sam deploy --config-env dev

# 2. Deploy Terraform (references SAM outputs)
cd ../terraform
terraform apply
```

## Components

### Security Features
- **WAF**: Web Application Firewall for API protection
- **CloudFront**: CDN with DDoS protection
- **Certificate Manager**: SSL/TLS certificates
- **Secrets Manager**: Secure storage for sensitive configuration

### Monitoring & Observability
- **CloudWatch Dashboards**: Real-time metrics visualization
- **CloudWatch Alarms**: Automated alerting for issues
- **X-Ray**: Distributed tracing for performance monitoring

## Environments

- **Development**: `dev` - Minimal resources for development
- **Staging**: `staging` - Production-like environment for testing
- **Production**: `prod` - Full-scale production deployment

## Prerequisites

1. **AWS CLI**: Configured with appropriate credentials
2. **Terraform**: Version 1.0+ installed
3. **Firebase Project**: Service account credentials
4. **Domain** (optional): For custom API domain

## Quick Start

1. **Configure Variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Plan Deployment**:
   ```bash
   terraform plan
   ```

4. **Deploy Infrastructure**:
   ```bash
   terraform apply
   ```

## Directory Structure

```
terraform/
├── main.tf                 # Main configuration
├── variables.tf            # Input variables
├── outputs.tf             # Output values
├── terraform.tfvars.example # Example variables
├── modules/               # Reusable modules
│   ├── api-gateway/       # API Gateway module
│   ├── lambda/            # Lambda functions module
│   ├── dynamodb/          # DynamoDB module
│   ├── monitoring/        # CloudWatch module
│   └── security/          # Security resources module
├── environments/          # Environment-specific configs
│   ├── dev/              # Development environment
│   ├── staging/          # Staging environment
│   └── prod/             # Production environment
└── scripts/              # Helper scripts
    ├── deploy.sh         # Deployment script
    └── cleanup.sh        # Cleanup script
```

## Resource Naming

All resources follow a consistent naming convention:
- Format: `{project}-{component}-{environment}`
- Example: `ios-auth-api-prod`, `ios-auth-users-dev`

This ensures clear identification and prevents conflicts across environments.

## Cost Optimization

### Development Environment
- Minimal DynamoDB provisioning
- Basic CloudWatch retention
- No redundancy features

### Production Environment
- Auto-scaling enabled
- Multi-AZ deployment
- Enhanced monitoring
- Backup and disaster recovery

## Security Configuration

### IAM Policies
- Principle of least privilege
- Resource-specific permissions
- Cross-service access controls

### Network Security
- VPC endpoints for private communication
- Security groups with minimal access
- WAF rules for common attack patterns

### Data Protection
- Encryption at rest and in transit
- Secure parameter storage
- Audit logging enabled

## Monitoring & Alerting

### CloudWatch Metrics
- Lambda execution metrics
- API Gateway performance
- DynamoDB consumption
- Error rates and latencies

### Alarms
- High error rates
- Unusual traffic patterns
- Resource utilization thresholds
- Failed authentication attempts

## Disaster Recovery

### Backup Strategy
- DynamoDB point-in-time recovery
- Lambda function versioning
- Infrastructure as Code for recreation

### Multi-Region Setup
- Primary region: `us-east-1`
- Backup region: `us-west-2` (configurable)
- Cross-region replication for critical data

## Maintenance

### Regular Tasks
- Review CloudWatch logs
- Update security policies
- Optimize resource usage
- Update Terraform modules

### Updates
- Terraform version updates
- AWS provider updates
- Security patch management

## Troubleshooting

### Common Issues
1. **Permission Denied**: Check IAM roles and policies
2. **Resource Conflicts**: Verify naming conventions
3. **Timeout Errors**: Check network connectivity and security groups
4. **Billing Alerts**: Review resource usage and scaling policies

### Debug Commands
```bash
# Check Terraform state
terraform show

# Validate configuration
terraform validate

# Check resource drift
terraform plan -detailed-exitcode

# Force resource recreation
terraform taint aws_lambda_function.example
```

## Contact & Support

For issues with the Terraform infrastructure:
1. Check the troubleshooting guide
2. Review CloudWatch logs
3. Validate AWS service status
4. Contact the development team

## Contributing

When modifying the infrastructure:
1. Test changes in development environment
2. Update documentation
3. Follow security best practices
4. Review with the team before production deployment
