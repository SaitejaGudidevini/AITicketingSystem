#!/bin/bash

# UVDesk v1.1.7 Docker Deployment Script for EC2
# This script automates the deployment of UVDesk on AWS EC2

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} UVDesk v1.1.7 Deployment Script${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        OS="Red Hat Enterprise Linux"
        VER=$(cat /etc/redhat-release | awk '{print $3}')
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

# Function to install Docker
install_docker() {
    print_status "Installing Docker..."
    
    if [[ "$OS" == *"Amazon Linux"* ]]; then
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker ec2-user
    elif [[ "$OS" == *"Ubuntu"* ]]; then
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker ubuntu
    elif [[ "$OS" == *"CentOS"* ]]; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker $(whoami)
    else
        print_error "Unsupported OS. Please install Docker manually."
        exit 1
    fi
    
    print_status "Docker installed successfully!"
}

# Function to install Docker Compose
install_docker_compose() {
    print_status "Installing Docker Compose..."
    
    # Get latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    # Download and install
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    print_status "Docker Compose installed successfully!"
}

# Function to create environment file
create_env_file() {
    print_status "Creating environment configuration..."
    
    # Generate secure passwords
    MYSQL_ROOT_PASSWORD=$(generate_password)
    MYSQL_PASSWORD=$(generate_password)
    APP_SECRET=$(generate_password)$(generate_password)
    REDIS_PASSWORD=$(generate_password)
    
    # Create .env file
    cat > .env << EOF
# UVDesk Docker Compose Environment Configuration
# Generated on $(date)

# Database Configuration
MYSQL_DATABASE=uvdesk
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_USER=uvdesk
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Application Configuration
APP_ENV=prod
APP_DEBUG=false
APP_SECRET=${APP_SECRET}

# UVDesk Configuration
UVDESK_ENV=prod
UVDESK_PORT=8080

# Mailer Configuration (Update with your settings)
MAILER_DSN=smtp://localhost:25

# Redis Configuration
REDIS_PASSWORD=${REDIS_PASSWORD}

# PHP Configuration
PHP_MEMORY_LIMIT=512M
PHP_MAX_EXECUTION_TIME=300
PHP_UPLOAD_MAX_FILESIZE=64M
PHP_POST_MAX_SIZE=64M

# Timezone
TZ=UTC

# Optional Services
PHPMYADMIN_PORT=8081

# Docker Compose Configuration
COMPOSE_PROJECT_NAME=uvdesk
EOF
    
    print_status "Environment file created with secure passwords!"
    print_warning "Please update the MAILER_DSN in .env file with your email settings"
}

# Function to start services
start_services() {
    print_status "Starting UVDesk services..."
    
    # Build and start containers
    docker-compose up -d --build
    
    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 30
    
    # Check service status
    print_status "Checking service status..."
    docker-compose ps
}

# Function to display final information
display_final_info() {
    print_header
    print_status "UVDesk deployment completed successfully!"
    echo ""
    echo "Access Information:"
    echo "=================="
    echo "🌐 Main Application: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "your-server-ip"):8080"
    echo "🗄️  PhpMyAdmin: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "your-server-ip"):8081"
    echo ""
    echo "Credentials:"
    echo "============"
    echo "📧 Admin Email: admin@example.com (change this during setup)"
    echo "🔒 Database passwords are stored in .env file"
    echo ""
    echo "Useful Commands:"
    echo "==============="
    echo "• View logs: docker-compose logs -f"
    echo "• Check status: docker-compose ps"
    echo "• Stop services: docker-compose down"
    echo "• Restart services: docker-compose restart"
    echo ""
    echo "Next Steps:"
    echo "==========="
    echo "1. Update email settings in .env file"
    echo "2. Configure SSL/TLS for production"
    echo "3. Set up regular backups"
    echo "4. Configure monitoring"
    echo ""
    print_warning "Remember to secure your server and change default passwords!"
}

# Main deployment function
main() {
    print_header
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for security reasons"
        exit 1
    fi
    
    # Detect OS
    detect_os
    print_status "Detected OS: $OS"
    
    # Check if Docker is installed
    if ! command_exists docker; then
        install_docker
        print_warning "Docker has been installed. Please log out and log back in, then run this script again."
        exit 0
    else
        print_status "Docker is already installed"
    fi
    
    # Check if Docker Compose is installed
    if ! command_exists docker-compose; then
        install_docker_compose
    else
        print_status "Docker Compose is already installed"
    fi
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        create_env_file
    else
        print_warning ".env file already exists, skipping creation"
    fi
    
    # Start services
    start_services
    
    # Display final information
    display_final_info
}

# Run main function
main "$@" 