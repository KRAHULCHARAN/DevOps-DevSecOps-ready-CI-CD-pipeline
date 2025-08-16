#!/bin/bash

# DevOps CI/CD Pipeline Application Deployment Script
# This script deploys the application to Kubernetes with monitoring and security

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command_exists kubectl; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        print_status "Please ensure your cluster is running and kubectl is configured"
        exit 1
    fi
}

# Function to check if Docker is available
check_docker() {
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Cannot connect to Docker daemon"
        print_status "Please ensure Docker is running"
        exit 1
    fi
}

# Function to build and push Docker image
build_and_push_image() {
    local image_tag="$1"
    local registry="$2"
    local image_name="$3"
    
    print_status "Building Docker image..."
    cd "$(dirname "$0")/../src/app"
    
    # Build the image
    docker build -t "${registry}/${image_name}:${image_tag}" .
    docker tag "${registry}/${image_name}:${image_tag}" "${registry}/${image_name}:latest"
    
    # Push to registry if specified
    if [[ -n "$registry" && "$registry" != "local" ]]; then
        print_status "Pushing image to registry..."
        docker push "${registry}/${image_name}:${image_tag}"
        docker push "${registry}/${image_name}:latest"
    fi
    
    cd - > /dev/null
}

# Function to deploy to Kubernetes
deploy_to_kubernetes() {
    local environment="$1"
    local image_tag="$2"
    local registry="$3"
    local image_name="$4"
    
    print_status "Deploying to Kubernetes environment: $environment"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$environment" --dry-run=client -o yaml | kubectl apply -f -
    
    # Update the deployment YAML with the correct image
    local deployment_file="$(dirname "$0")/../infrastructure/kubernetes/deployment.yaml"
    local temp_file="/tmp/deployment-${environment}.yaml"
    
    # Create environment-specific deployment
    cat "$deployment_file" | sed "s|your-registry.com|${registry}|g" > "$temp_file"
    
    # Apply the deployment
    kubectl apply -f "$temp_file" -n "$environment"
    
    # Wait for deployment to be ready
    print_status "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/devops-cicd-app -n "$environment"
    
    # Clean up temp file
    rm "$temp_file"
    
    print_success "Application deployed successfully to $environment environment"
}

# Function to run security scans
run_security_scans() {
    print_status "Running security scans..."
    
    # Run Trivy container scan
    if command_exists trivy; then
        print_status "Running Trivy container scan..."
        local image_tag="$1"
        local registry="$2"
        local image_name="$3"
        
        trivy image --severity HIGH,CRITICAL "${registry}/${image_name}:${image_tag}"
        
        if [ $? -ne 0 ]; then
            print_warning "Trivy found high/critical vulnerabilities in the container image"
            read -p "Continue with deployment? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Deployment aborted due to security concerns"
                exit 1
            fi
        fi
    fi
    
    # Run Gitleaks scan
    if command_exists gitleaks; then
        print_status "Running Gitleaks scan..."
        cd "$(dirname "$0")/.."
        gitleaks detect --source . --verbose
        
        if [ $? -ne 0 ]; then
            print_error "Gitleaks found secrets in the codebase!"
            exit 1
        fi
        cd - > /dev/null
    fi
}

# Function to run tests
run_tests() {
    print_status "Running application tests..."
    cd "$(dirname "$0")/../src/app"
    
    # Install dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        npm install
    fi
    
    # Run tests
    npm test
    
    if [ $? -ne 0 ]; then
        print_error "Tests failed! Aborting deployment."
        exit 1
    fi
    
    cd - > /dev/null
    print_success "All tests passed"
}

# Function to check application health
check_application_health() {
    local environment="$1"
    local max_attempts=30
    local attempt=1
    
    print_status "Checking application health..."
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl get pods -n "$environment" -l app=devops-cicd-app | grep -q "Running"; then
            # Get the service URL
            local service_url=""
            if command_exists minikube; then
                local minikube_ip=$(minikube ip)
                service_url="http://${minikube_ip}:$(kubectl get svc -n "$environment" devops-cicd-app-service -o jsonpath='{.spec.ports[0].nodePort}')"
            else
                service_url="http://localhost:$(kubectl get svc -n "$environment" devops-cicd-app-service -o jsonpath='{.spec.ports[0].nodePort}')"
            fi
            
            # Test health endpoint
            if curl -f "${service_url}/health" >/dev/null 2>&1; then
                print_success "Application is healthy and responding"
                print_status "Service URL: $service_url"
                return 0
            fi
        fi
        
        print_status "Waiting for application to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_error "Application health check failed after $max_attempts attempts"
    return 1
}

# Function to show deployment status
show_deployment_status() {
    local environment="$1"
    
    print_status "Deployment Status for $environment environment:"
    echo "================================================"
    
    # Show pods
    echo "Pods:"
    kubectl get pods -n "$environment" -l app=devops-cicd-app
    
    echo
    echo "Services:"
    kubectl get svc -n "$environment"
    
    echo
    echo "Ingress:"
    kubectl get ingress -n "$environment" 2>/dev/null || echo "No ingress configured"
    
    echo
    echo "Events:"
    kubectl get events -n "$environment" --sort-by='.lastTimestamp' | tail -10
}

# Function to setup monitoring
setup_monitoring() {
    print_status "Setting up monitoring for the application..."
    
    # Create monitoring namespace if it doesn't exist
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply Prometheus configuration
    local prometheus_config="$(dirname "$0")/../monitoring/prometheus/prometheus-config.yaml"
    if [[ -f "$prometheus_config" ]]; then
        kubectl apply -f "$prometheus_config"
    fi
    
    # Apply Grafana dashboard
    local grafana_dashboard="$(dirname "$0")/../monitoring/grafana/dashboards/cicd-pipeline.json"
    if [[ -f "$grafana_dashboard" ]]; then
        print_status "Grafana dashboard configuration available at: $grafana_dashboard"
        print_status "Import this dashboard into Grafana manually or use the Grafana API"
    fi
    
    print_success "Monitoring setup completed"
}

# Main deployment function
main() {
    local environment="${1:-staging}"
    local image_tag="${2:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"
    local registry="${3:-local}"
    local image_name="${4:-devops-cicd-app}"
    local skip_tests="${5:-false}"
    local skip_scans="${6:-false}"
    
    print_status "Starting DevOps CI/CD Pipeline deployment..."
    print_status "Environment: $environment"
    print_status "Image Tag: $image_tag"
    print_status "Registry: $registry"
    print_status "Image Name: $image_name"
    
    # Validate environment
    if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Invalid environment: $environment. Must be dev, staging, or prod."
        exit 1
    fi
    
    # Check prerequisites
    check_kubectl
    check_docker
    
    # Run tests unless skipped
    if [[ "$skip_tests" != "true" ]]; then
        run_tests
    else
        print_warning "Skipping tests as requested"
    fi
    
    # Run security scans unless skipped
    if [[ "$skip_scans" != "true" ]]; then
        run_security_scans "$image_tag" "$registry" "$image_name"
    else
        print_warning "Skipping security scans as requested"
    fi
    
    # Build and push image
    build_and_push_image "$image_tag" "$registry" "$image_name"
    
    # Deploy to Kubernetes
    deploy_to_kubernetes "$environment" "$image_tag" "$registry" "$image_name"
    
    # Setup monitoring
    setup_monitoring
    
    # Check application health
    if check_application_health "$environment"; then
        print_success "Deployment completed successfully!"
        
        # Show deployment status
        show_deployment_status "$environment"
        
        # Print access information
        echo
        echo "Access Information:"
        echo "=================="
        if command_exists minikube; then
            local minikube_ip=$(minikube ip)
            echo "Application: http://${minikube_ip}:$(kubectl get svc -n "$environment" devops-cicd-app-service -o jsonpath='{.spec.ports[0].nodePort}')"
            echo "Grafana: http://${minikube_ip}:30000 (admin/admin)"
            echo "Prometheus: http://${minikube_ip}:30000"
        fi
        echo "Kubernetes Dashboard: kubectl proxy --address=0.0.0.0 --port=8001"
        
    else
        print_error "Deployment failed health check"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS="true"
            shift
            ;;
        --skip-scans)
            SKIP_SCANS="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -e, --environment ENV    Deployment environment (dev|staging|prod) [default: staging]"
            echo "  -t, --tag TAG           Docker image tag [default: git commit hash]"
            echo "  -r, --registry REG      Docker registry [default: local]"
            echo "  -i, --image NAME        Docker image name [default: devops-cicd-app]"
            echo "  --skip-tests            Skip running tests before deployment"
            echo "  --skip-scans            Skip security scans before deployment"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function with parsed arguments
main "${ENVIRONMENT:-staging}" "${IMAGE_TAG:-}" "${REGISTRY:-local}" "${IMAGE_NAME:-devops-cicd-app}" "${SKIP_TESTS:-false}" "${SKIP_SCANS:-false}"
