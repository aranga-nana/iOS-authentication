# 🛠 Lesson 3: Development Environment Setup

> **Phase 1, Week 2 - Development Environment and Tools**  
> **Duration**: 6 hours | **Level**: All Levels  
> **Prerequisites**: Completed Lessons 1-2

## 🎯 Learning Objectives

By the end of this lesson, you will:
- Set up a complete iOS development environment
- Configure Firebase and AWS development tools
- Establish version control and project structure
- Create accounts for all required services
- Understand development environment best practices

---

## 📚 Part 1: Xcode and iOS Development Setup (1.5 hours)

### 1.1 Xcode Advanced Configuration

**Verify Xcode Installation:**
```bash
# Check Xcode installation
xcode-select --print-path
# Expected output: /Applications/Xcode.app/Contents/Developer

# Install command line tools if needed
xcode-select --install

# Accept Xcode license
sudo xcodebuild -license accept
```

**Configure Xcode Preferences:**
1. **Locations Tab:**
   - Command Line Tools: Latest Xcode version
   - Archives: Default location or custom path

2. **Text Editing Tab:**
   - Enable line numbers
   - Code completion: Show completions immediately
   - Enable syntax highlighting

3. **Source Control Tab:**
   - Configure Git author name and email
   - Enable source control navigation

**Install iOS Simulator:**
```bash
# List available simulators
xcrun simctl list devices

# Install additional iOS versions if needed
# Open Xcode → Preferences → Components → iOS Simulators
```

### 1.2 Essential Xcode Extensions

**Recommended Extensions:**
1. **SF Symbols** - Apple's icon library
2. **SwiftLint** - Code style enforcement
3. **Sourcery** - Code generation
4. **Periphery** - Dead code detection

**Install SwiftLint:**
```bash
# Using Homebrew
brew install swiftlint

# Verify installation
swiftlint version
```

**🏃‍♂️ Practice Exercise 1.1:**
Create a new iOS project and configure SwiftLint:

```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace
  - line_length
opt_in_rules:
  - empty_count
  - force_unwrapping
included:
  - Sources
excluded:
  - Carthage
  - Pods
  - .build
```

---

## 📚 Part 2: Firebase Development Environment (1.5 hours)

### 2.1 Firebase CLI Setup

**Install Firebase CLI:**
```bash
# Using npm (requires Node.js)
npm install -g firebase-tools

# Using standalone binary (macOS)
curl -sL https://firebase.tools | bash

# Verify installation
firebase --version
```

**Login to Firebase:**
```bash
# Login to your Google account
firebase login

# List your Firebase projects
firebase projects:list

# Set default project (if you have one)
firebase use --add
```

### 2.2 Firebase Project Creation

**Create Firebase Project:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project"
3. Enter project name: `ios-auth-tutorial`
4. Choose whether to enable Google Analytics
5. Select Analytics location (if enabled)

**Enable Authentication:**
1. Navigate to Authentication
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Email/Password"
5. Enable "Google" (we'll configure later)

**Configure iOS App:**
1. Click "Add app" → iOS
2. Enter iOS bundle ID: `com.yourname.iosauth`
3. Download `GoogleService-Info.plist`
4. Save file for later use

### 2.3 Firebase Local Development

**Initialize Firebase in Project Directory:**
```bash
# Create project directory
mkdir ios-auth-tutorial
cd ios-auth-tutorial

# Initialize Firebase
firebase init

# Select the following options:
# - Hosting (for web dashboard)
# - Functions (for backend logic)
# - Emulators (for local testing)
```

**Configure Firebase Emulators:**
```json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "functions": {
      "port": 5001
    },
    "hosting": {
      "port": 5000
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  }
}
```

**🏃‍♂️ Practice Exercise 2.1:**
Start Firebase emulators and explore the UI:

```bash
# Start emulators
firebase emulators:start

# Open http://localhost:4000 in browser
# Explore Authentication and other services
```

---

## 📚 Part 3: AWS Development Environment (2 hours)

### 3.1 AWS CLI Setup

**Install AWS CLI:**
```bash
# Using Homebrew
brew install awscli

# Verify installation
aws --version

# Install AWS SAM CLI (for serverless applications)
brew tap aws/tap
brew install aws-sam-cli

# Verify SAM installation
sam --version
```

**Configure AWS Credentials:**
```bash
# Configure AWS CLI
aws configure

# Enter the following when prompted:
# AWS Access Key ID: [Your access key]
# AWS Secret Access Key: [Your secret key]
# Default region name: us-east-1
# Default output format: json
```

**Create AWS IAM User for Development:**
1. Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Click "Users" → "Add user"
3. Username: `ios-auth-dev`
4. Access type: "Programmatic access"
5. Attach policies:
   - `AWSLambdaFullAccess`
   - `AmazonAPIGatewayAdministrator`
   - `AmazonDynamoDBFullAccess`
   - `CloudWatchFullAccess`
6. Save access keys securely

### 3.2 Terraform Setup (Optional but Recommended)

**Install Terraform:**
```bash
# Using Homebrew
brew install terraform

# Verify installation
terraform --version
```

**Create Basic Terraform Configuration:**
```hcl
# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "ios-auth-terraform-state-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
```

### 3.3 AWS Development Best Practices

**Environment Variables Setup:**
```bash
# Create .env file for development
echo "AWS_REGION=us-east-1" > .env
echo "AWS_PROFILE=default" >> .env
echo "ENVIRONMENT=development" >> .env

# Add to .gitignore
echo ".env" >> .gitignore
echo "terraform.tfstate*" >> .gitignore
echo "*.tfvars" >> .gitignore
```

**🏃‍♂️ Practice Exercise 3.1:**
Test AWS connectivity:

```bash
# List S3 buckets
aws s3 ls

# Get caller identity
aws sts get-caller-identity

# Initialize Terraform
terraform init
terraform plan
```

---

## 📚 Part 4: Project Structure and Version Control (1 hour)

### 4.1 Git Configuration

**Global Git Setup:**
```bash
# Configure Git user information
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Set default branch name
git config --global init.defaultBranch main

# Improve Git output
git config --global color.ui auto
git config --global core.editor "code --wait"
```

**Create Project Repository:**
```bash
# Create and navigate to project directory
mkdir ios-auth-system
cd ios-auth-system

# Initialize Git repository
git init

# Create initial project structure
mkdir -p {ios-app,backend,docs,terraform}

# Create .gitignore
cat > .gitignore << EOF
# iOS
*.xcworkspace
*.xcuserdata
DerivedData/
build/
Carthage/
.DS_Store

# AWS
.env
terraform.tfstate*
*.tfvars

# Node.js
node_modules/
npm-debug.log

# General
.vscode/
.idea/
*.swp
*.swo
EOF

# Initial commit
git add .
git commit -m "Initial project structure"
```

### 4.2 Recommended Project Structure

```
ios-auth-system/
├── ios-app/                    # iOS application
│   ├── AuthApp/
│   │   ├── App/               # App delegate, scene delegate
│   │   ├── Views/             # SwiftUI views
│   │   ├── ViewModels/        # MVVM view models
│   │   ├── Models/            # Data models
│   │   ├── Services/          # API and auth services
│   │   └── Utils/             # Utilities and extensions
│   ├── AuthAppTests/          # Unit tests
│   └── AuthApp.xcodeproj
├── backend/                   # AWS Lambda functions
│   ├── functions/
│   │   ├── auth-verify/       # Token verification
│   │   ├── user-profile/      # User management
│   │   └── shared/            # Shared utilities
│   ├── package.json
│   └── serverless.yml
├── terraform/                 # Infrastructure as Code
│   ├── modules/
│   │   ├── api-gateway/
│   │   ├── dynamodb/
│   │   └── lambda/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── main.tf
├── docs/                      # Documentation
│   ├── architecture.md
│   ├── api-reference.md
│   └── deployment-guide.md
├── scripts/                   # Build and deployment scripts
├── .github/                   # GitHub Actions workflows
├── README.md
└── .gitignore
```

### 4.3 Development Workflow Setup

**Create Development Branches:**
```bash
# Create and switch to development branch
git checkout -b develop

# Create feature branch structure
git checkout -b feature/ios-setup
git checkout -b feature/firebase-setup
git checkout -b feature/aws-setup

# Switch back to main
git checkout main
```

**Setup GitHub Repository (Optional):**
```bash
# Create repository on GitHub first, then:
git remote add origin https://github.com/yourusername/ios-auth-system.git
git branch -M main
git push -u origin main
```

**🏃‍♂️ Practice Exercise 4.1:**
Create the complete project structure and make your first commit.

---

## 📚 Part 5: Development Tools and IDE Configuration (30 minutes)

### 5.1 Essential Development Tools

**Package Managers:**
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install useful development tools
brew install jq          # JSON processor
brew install curl        # HTTP client
brew install git         # Version control
brew install tree        # Directory visualization
```

**Node.js and npm (for Firebase Functions):**
```bash
# Install Node.js using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc

# Install latest LTS Node.js
nvm install --lts
nvm use --lts

# Verify installation
node --version
npm --version
```

### 5.2 VS Code Configuration (Optional)

**Recommended VS Code Extensions:**
```json
{
  "recommendations": [
    "ms-vscode.vscode-json",
    "ms-python.python",
    "amazonwebservices.aws-toolkit-vscode",
    "toba.vsfire",
    "hashicorp.terraform",
    "ms-vscode.swift"
  ]
}
```

**VS Code Settings for iOS Development:**
```json
{
  "files.associations": {
    "*.swift": "swift"
  },
  "terraform.experimentalFeatures.validateOnSave": true,
  "aws.telemetry": false
}
```

### 5.3 Testing Your Environment

**Environment Health Check Script:**
```bash
#!/bin/bash
# save as check-environment.sh

echo "🔍 Checking Development Environment..."

# Check Xcode
if xcode-select -p &> /dev/null; then
    echo "✅ Xcode: $(xcodebuild -version | head -n1)"
else
    echo "❌ Xcode: Not found"
fi

# Check Firebase CLI
if command -v firebase &> /dev/null; then
    echo "✅ Firebase CLI: $(firebase --version)"
else
    echo "❌ Firebase CLI: Not found"
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI: $(aws --version)"
else
    echo "❌ AWS CLI: Not found"
fi

# Check Git
if command -v git &> /dev/null; then
    echo "✅ Git: $(git --version)"
else
    echo "❌ Git: Not found"
fi

# Check Node.js
if command -v node &> /dev/null; then
    echo "✅ Node.js: $(node --version)"
else
    echo "❌ Node.js: Not found"
fi

echo "🎉 Environment check complete!"
```

**🏃‍♂️ Practice Exercise 5.1:**
Run the environment health check and ensure all tools are properly installed.

---

## ✅ Lesson Completion Checklist

- [ ] Xcode installed and configured with preferences
- [ ] SwiftLint installed and configured
- [ ] Firebase CLI installed and authenticated
- [ ] Firebase project created with Authentication enabled
- [ ] AWS CLI installed and configured with development user
- [ ] Git configured with user information
- [ ] Project directory structure created
- [ ] Environment health check passes
- [ ] All required accounts created (Firebase, AWS, GitHub)
- [ ] Development workflow documented

---

## 📝 Assignment

**Set up your complete development environment:**

1. **Tool Installation**: Install all required tools (Xcode, Firebase CLI, AWS CLI, Git)
2. **Account Creation**: Create Firebase project and AWS account with proper permissions
3. **Project Structure**: Create the recommended project directory structure
4. **Version Control**: Initialize Git repository with proper .gitignore
5. **Documentation**: Create a README.md with environment setup instructions
6. **Health Check**: Run environment health check and fix any issues

**Submit**: Screenshots of successful tool installations and project structure.

---

## 🔗 Next Lesson

**Lesson 4: Cloud Services Introduction** - We'll explore Firebase and AWS services in detail and understand how they work together.

---

## 📚 Additional Resources

### Documentation
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [AWS CLI User Guide](https://docs.aws.amazon.com/cli/latest/userguide/)
- [Git Documentation](https://git-scm.com/doc)

### Video Tutorials
- Firebase CLI Setup and Usage
- AWS CLI Configuration Best Practices
- Xcode Tips and Tricks for Productivity

### Best Practices
- [iOS Project Structure Best Practices](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [Git Workflow Best Practices](https://www.atlassian.com/git/tutorials/comparing-workflows)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
