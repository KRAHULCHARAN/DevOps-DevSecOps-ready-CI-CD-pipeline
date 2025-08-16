#!/bin/bash

# Local Deployment Script for DevOps CI/CD Pipeline
# This script deploys the application locally using Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Function to run security scans
run_security_scans() {
    print_status "Running security scans..."
    
    # Run Gitleaks scan
    if command -v gitleaks >/dev/null 2>&1; then
        print_status "Running Gitleaks scan..."
        cd "$(dirname "$0")/.."
        gitleaks detect --source . --verbose
        
        if [ $? -ne 0 ]; then
            print_error "Gitleaks found secrets in the codebase!"
            exit 1
        fi
        print_success "Gitleaks scan passed"
    else
        print_warning "Gitleaks not found, skipping secrets scan"
    fi
    
    # Run Trivy filesystem scan
    if command -v trivy >/dev/null 2>&1; then
        print_status "Running Trivy filesystem scan..."
        cd "$(dirname "$0")/.."
        trivy fs --severity HIGH,CRITICAL .
        
        if [ $? -ne 0 ]; then
            print_warning "Trivy found high/critical vulnerabilities"
            read -p "Continue with deployment? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Deployment aborted due to security concerns"
                exit 1
            fi
        fi
        print_success "Trivy scan completed"
    else
        print_warning "Trivy not found, skipping vulnerability scan"
    fi
}

# Function to run tests
run_tests() {
    print_status "Running application tests..."
    cd "$(dirname "$0")/../src/app"
    
    # Install dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        print_status "Installing dependencies..."
        npm install
    fi
    
    # Run tests
    print_status "Running tests..."
    npm test
    
    if [ $? -ne 0 ]; then
        print_error "Tests failed! Aborting deployment."
        exit 1
    fi
    
    print_success "All tests passed"
    cd - > /dev/null
}

# Function to build Docker image
build_docker_image() {
    print_status "Building Docker image..."
    cd "$(dirname "$0")/../src/app"
    
    # Build the image
    docker build -t devops-cicd-app:latest .
    
    if [ $? -ne 0 ]; then
        print_error "Docker build failed!"
        exit 1
    fi
    
    print_success "Docker image built successfully"
    cd - > /dev/null
}

# Function to run container security scan
scan_container() {
    print_status "Scanning container for vulnerabilities..."
    
    if command -v trivy >/dev/null 2>&1; then
        trivy image --severity HIGH,CRITICAL devops-cicd-app:latest
        
        if [ $? -ne 0 ]; then
            print_warning "Container contains high/critical vulnerabilities"
            read -p "Continue with deployment? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Deployment aborted due to container security concerns"
                exit 1
            fi
        fi
        print_success "Container security scan completed"
    else
        print_warning "Trivy not found, skipping container scan"
    fi
}

# Function to start application
start_application() {
    print_status "Starting application..."
    
    # Stop existing container if running
    docker stop devops-cicd-app 2>/dev/null || true
    docker rm devops-cicd-app 2>/dev/null || true
    
    # Start new container
    docker run -d \
        --name devops-cicd-app \
        -p 3000:3000 \
        --restart unless-stopped \
        devops-cicd-app:latest
    
    if [ $? -ne 0 ]; then
        print_error "Failed to start application container"
        exit 1
    fi
    
    print_success "Application container started"
}

# Function to check application health
check_application_health() {
    print_status "Checking application health..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            print_success "Application is healthy and responding"
            return 0
        fi
        
        print_status "Waiting for application to be ready... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "Application health check failed after $max_attempts attempts"
    return 1
}

# Function to show application status
show_application_status() {
    print_status "Application Status:"
    echo "====================="
    
    # Show container status
    echo "Container Status:"
    docker ps -a --filter name=devops-cicd-app
    
    echo
    echo "Container Logs (last 10 lines):"
    docker logs --tail 10 devops-cicd-app
    
    echo
    echo "Application Endpoints:"
    echo "- Health Check: http://localhost:3000/health"
    echo "- API Status: http://localhost:3000/api/v1/status"
    echo "- API Info: http://localhost:3000/api/v1/info"
    echo "- Metrics: http://localhost:3000/metrics"
}

# Main function
main() {
    print_status "Starting local deployment of DevOps CI/CD Pipeline..."
    
    # Check Docker
    check_docker
    
    # Run security scans
    run_security_scans
    
    # Run tests
    run_tests
    
    # Build Docker image
    build_docker_image
    
    # Scan container
    scan_container
    
    # Start application
    start_application
    
    # Check health
    if check_application_health; then
        print_success "Local deployment completed successfully!"
        
        # Show status
        show_application_status
        
        echo
        echo "🎉 Your DevOps CI/CD Pipeline application is now running locally!"
        echo "Open your browser and visit: http://localhost:3000"
        echo
        echo "Next steps:"
        echo "1. Test the application endpoints"
        echo "2. Once Docker Desktop is fully ready, run: ./scripts/deploy-app.sh -e staging"
        echo "3. Set up Kubernetes cluster with: minikube start"
        
    else
        print_error "Local deployment failed health check"
        exit 1
    fi
}

# Run main function
main
