#!/bin/bash

# DevOps CI/CD Pipeline Setup Script
# This script sets up the complete development environment

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

# Function to check OS
get_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*)   echo "windows";;
        MINGW*)    echo "windows";;
        *)         echo "unknown";;
    esac
}

OS=$(get_os)

print_status "Setting up DevOps CI/CD Pipeline environment on $OS..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Create necessary directories
print_status "Creating project directories..."
mkdir -p ~/.devops-cicd/{bin,config,logs}
mkdir -p ~/.kube
mkdir -p ~/.terraform.d

# Install Homebrew (macOS) or update package manager
if [[ "$OS" == "macos" ]]; then
    if ! command_exists brew; then
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        print_status "Updating Homebrew..."
        brew update
    fi
elif [[ "$OS" == "linux" ]]; then
    if command_exists apt-get; then
        print_status "Updating package manager..."
        sudo apt-get update
    elif command_exists yum; then
        print_status "Updating package manager..."
        sudo yum update -y
    fi
fi

# Install Docker
if ! command_exists docker; then
    print_status "Installing Docker..."
    if [[ "$OS" == "macos" ]]; then
        print_warning "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
        print_status "After installation, make sure Docker is running and you can run 'docker --version'"
    elif [[ "$OS" == "linux" ]]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        print_warning "Please log out and log back in for Docker group changes to take effect"
    fi
else
    print_success "Docker is already installed"
fi

# Install kubectl
if ! command_exists kubectl; then
    print_status "Installing kubectl..."
    if [[ "$OS" == "macos" ]]; then
        brew install kubectl
    elif [[ "$OS" == "linux" ]]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi
else
    print_success "kubectl is already installed"
fi

# Install Minikube
if ! command_exists minikube; then
    print_status "Installing Minikube..."
    if [[ "$OS" == "macos" ]]; then
        brew install minikube
    elif [[ "$OS" == "linux" ]]; then
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
    fi
else
    print_success "Minikube is already installed"
fi

# Install Terraform
if ! command_exists terraform; then
    print_status "Installing Terraform..."
    if [[ "$OS" == "macos" ]]; then
        brew install terraform
    elif [[ "$OS" == "linux" ]]; then
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
        sudo apt-get update && sudo apt-get install terraform
    fi
else
    print_success "Terraform is already installed"
fi

# Install Ansible
if ! command_exists ansible; then
    print_status "Installing Ansible..."
    if [[ "$OS" == "macos" ]]; then
        brew install ansible
    elif [[ "$OS" == "linux" ]]; then
        sudo apt-get install -y ansible
    fi
else
    print_success "Ansible is already installed"
fi

# Install Node.js
if ! command_exists node; then
    print_status "Installing Node.js..."
    if [[ "$OS" == "macos" ]]; then
        brew install node
    elif [[ "$OS" == "linux" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
else
    print_success "Node.js is already installed"
fi

# Install Java
if ! command_exists java; then
    print_status "Installing Java..."
    if [[ "$OS" == "macos" ]]; then
        brew install openjdk@17
        sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
        echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
        echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"' >> ~/.zshrc
    elif [[ "$OS" == "linux" ]]; then
        sudo apt-get install -y openjdk-17-jdk
        echo 'export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"' >> ~/.bashrc
    fi
else
    print_success "Java is already installed"
fi

# Install Helm
if ! command_exists helm; then
    print_status "Installing Helm..."
    if [[ "$OS" == "macos" ]]; then
        brew install helm
    elif [[ "$OS" == "linux" ]]; then
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt-get update && sudo apt-get install helm
    fi
else
    print_success "Helm is already installed"
fi

# Install additional tools
print_status "Installing additional tools..."

# Install Trivy
if ! command_exists trivy; then
    if [[ "$OS" == "macos" ]]; then
        brew install trivy
    elif [[ "$OS" == "linux" ]]; then
        sudo apt-get install -y wget apt-transport-https gnupg lsb-release
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
        echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
        sudo apt-get update && sudo apt-get install trivy
    fi
fi

# Install Gitleaks
if ! command_exists gitleaks; then
    if [[ "$OS" == "macos" ]]; then
        brew install gitleaks
    elif [[ "$OS" == "linux" ]]; then
        curl -sSfL https://raw.githubusercontent.com/zricethezav/gitleaks/master/install.sh | sh -s -- -b /usr/local/bin
    fi
fi

# Install Kind (Kubernetes in Docker)
if ! command_exists kind; then
    if [[ "$OS" == "macos" ]]; then
        brew install kind
    elif [[ "$OS" == "linux" ]]; then
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
fi

# Install LocalStack (for local AWS development)
if ! command_exists localstack; then
    if [[ "$OS" == "macos" ]]; then
        brew install localstack
    elif [[ "$OS" == "linux" ]]; then
        pip3 install localstack
    fi
fi

# Create local Kubernetes cluster
print_status "Setting up local Kubernetes cluster..."
if command_exists minikube; then
    if ! minikube status --format='{{.Host}}' | grep -q "Running"; then
        print_status "Starting Minikube cluster..."
        minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g
        minikube addons enable ingress
        minikube addons enable metrics-server
    else
        print_success "Minikube cluster is already running"
    fi
    
    # Configure kubectl to use minikube
    minikube kubectl -- get nodes
    print_success "Minikube cluster is ready"
fi

# Install monitoring stack
print_status "Installing monitoring stack..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus using Helm
if command_exists helm; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install Prometheus with custom values
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.retention=7d \
        --set grafana.enabled=true \
        --set grafana.adminPassword=admin \
        --set grafana.service.type=NodePort \
        --set grafana.service.nodePort=30000
fi

# Install SonarQube
print_status "Installing SonarQube..."
kubectl create namespace sonarqube --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarqube
  namespace: sonarqube
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarqube
  template:
    metadata:
      labels:
        app: sonarqube
    spec:
      containers:
      - name: sonarqube
        image: sonarqube:community
        ports:
        - containerPort: 9000
        env:
        - name: SONAR_ES_BOOTSTRAP_CHECKS_DISABLE
          value: "true"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: sonarqube
  namespace: sonarqube
spec:
  type: NodePort
  ports:
  - port: 9000
    targetPort: 9000
    nodePort: 30001
  selector:
    app: sonarqube
EOF

# Install Jenkins
print_status "Installing Jenkins..."
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
        - containerPort: 50000
        env:
        - name: JAVA_OPTS
          value: "-Djenkins.install.runSetupWizard=false"
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: jenkins-home
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: jenkins
spec:
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30002
  selector:
    app: jenkins
EOF

# Wait for services to be ready
print_status "Waiting for services to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sonarqube -n sonarqube
kubectl wait --for=condition=available --timeout=300s deployment/jenkins -n jenkins

# Get Jenkins admin password
print_status "Getting Jenkins admin password..."
JENKINS_PASSWORD=$(kubectl exec -n jenkins deployment/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "admin")

# Create environment file
print_status "Creating environment configuration..."
cat > ~/.devops-cicd/config/env.sh <<EOF
#!/bin/bash

# DevOps CI/CD Pipeline Environment Variables
export PROJECT_ROOT="$(pwd)"
export KUBECONFIG="~/.kube/config"
export MINIKUBE_IP="\$(minikube ip)"
export JENKINS_URL="http://\$(minikube ip):30002"
export JENKINS_PASSWORD="$JENKINS_PASSWORD"
export SONARQUBE_URL="http://\$(minikube ip):30001"
export GRAFANA_URL="http://\$(minikube ip):30000"
export PROMETHEUS_URL="http://\$(minikube ip):30000"

# Docker registry
export DOCKER_REGISTRY="ghcr.io"
export IMAGE_NAME="devops-cicd-app"

# AWS (for production)
export AWS_REGION="us-west-2"
export AWS_PROFILE="default"

# GitHub
export GITHUB_TOKEN=""
export GITHUB_USERNAME=""

# Slack/Discord notifications
export SLACK_WEBHOOK=""
export DISCORD_WEBHOOK=""
EOF

# Make environment file executable
chmod +x ~/.devops-cicd/config/env.sh

# Create aliases
print_status "Setting up aliases..."
cat >> ~/.zshrc <<EOF

# DevOps CI/CD Pipeline Aliases
alias devops-env="source ~/.devops-cicd/config/env.sh"
alias k="kubectl"
alias kctx="kubectl config get-contexts"
alias kuse="kubectl config use-context"
alias klogs="kubectl logs -f"
alias kexec="kubectl exec -it"
alias kport="kubectl port-forward"
alias minikube-start="minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g"
alias minikube-stop="minikube stop"
alias minikube-delete="minikube delete"
alias terraform-init="cd infrastructure/terraform && terraform init"
alias terraform-plan="cd infrastructure/terraform && terraform plan"
alias terraform-apply="cd infrastructure/terraform && terraform apply"
alias terraform-destroy="cd infrastructure/terraform && terraform destroy"

EOF

# Create completion scripts
print_status "Setting up shell completions..."
if [[ "$OS" == "macos" ]]; then
    # kubectl completion
    kubectl completion zsh >> ~/.zshrc
    
    # helm completion
    helm completion zsh >> ~/.zshrc
    
    # terraform completion
    terraform -install-autocomplete
fi

# Install project dependencies
print_status "Installing project dependencies..."
cd "$(dirname "$0")/.."

if [[ -f "src/app/package.json" ]]; then
    print_status "Installing Node.js dependencies..."
    cd src/app
    npm install
    cd ../..
fi

# Create pre-commit hooks
print_status "Setting up pre-commit hooks..."
mkdir -p .git/hooks

cat > .git/hooks/pre-commit <<EOF
#!/bin/bash

# Pre-commit hook for security scanning
echo "Running pre-commit security checks..."

# Run Gitleaks
if command -v gitleaks >/dev/null 2>&1; then
    echo "Running Gitleaks scan..."
    gitleaks detect --source . --verbose
    if [ \$? -ne 0 ]; then
        echo "Gitleaks found secrets in the codebase!"
        exit 1
    fi
fi

# Run Trivy filesystem scan
if command -v trivy >/dev/null 2>&1; then
    echo "Running Trivy filesystem scan..."
    trivy fs --severity HIGH,CRITICAL .
    if [ \$? -ne 0 ]; then
        echo "Trivy found high/critical vulnerabilities!"
        exit 1
    fi
fi

echo "Pre-commit checks passed!"
exit 0
EOF

chmod +x .git/hooks/pre-commit

# Final setup
print_status "Finalizing setup..."

# Source environment variables
source ~/.devops-cicd/config/env.sh

# Print access information
print_success "Setup completed successfully!"
echo
echo "Access Information:"
echo "=================="
echo "Jenkins: $JENKINS_URL (admin/$JENKINS_PASSWORD)"
echo "SonarQube: $SONARQUBE_URL (admin/admin)"
echo "Grafana: $GRAFANA_URL (admin/admin)"
echo "Kubernetes Dashboard: kubectl proxy --address=0.0.0.0 --port=8001"
echo
echo "Next Steps:"
echo "==========="
echo "1. Source the environment: source ~/.devops-cicd/config/env.sh"
echo "2. Start the monitoring stack: ./scripts/start-monitoring.sh"
echo "3. Deploy the application: ./scripts/deploy-app.sh"
echo "4. Access the dashboards using the URLs above"
echo
echo "Useful Commands:"
echo "================"
echo "kubectl get pods -A          # List all pods"
echo "kubectl get services -A      # List all services"
echo "minikube dashboard           # Open Kubernetes dashboard"
echo "kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090  # Access Prometheus"
echo
print_success "DevOps CI/CD Pipeline environment is ready!"
