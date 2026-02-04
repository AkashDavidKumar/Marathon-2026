#!/bin/bash

# Multi-Server Deployment Script
# Deploys application to Master + 3 Worker servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_PATH="/var/www/debug-marathon"
SSH_KEY="${SSH_KEY:-deploy_key.pem}"
SSH_USER="${SSH_USER:-ubuntu}"

# Server IPs (override with environment variables or pass as arguments)
MASTER_IP="${MASTER_IP:-}"
WORKER1_IP="${WORKER1_IP:-}"
WORKER2_IP="${WORKER2_IP:-}"
WORKER3_IP="${WORKER3_IP:-}"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if [ ! -f "$SSH_KEY" ]; then
        print_error "SSH key not found: $SSH_KEY"
        exit 1
    fi
    
    if [ -z "$MASTER_IP" ] || [ -z "$WORKER1_IP" ] || [ -z "$WORKER2_IP" ] || [ -z "$WORKER3_IP" ]; then
        print_error "Server IPs not configured. Set environment variables or edit this script."
        print_info "Required: MASTER_IP, WORKER1_IP, WORKER2_IP, WORKER3_IP"
        exit 1
    fi
    
    chmod 600 "$SSH_KEY"
    print_info "Prerequisites check passed"
}

# Function to create deployment package
create_package() {
    print_info "Creating deployment package..."
    
    rm -rf deploy_package app.tar.gz
    mkdir -p deploy_package
    
    # Copy application files
    cp -r backend deploy_package/
    cp -r frontend deploy_package/
    
    # Create tarball
    tar -czf app.tar.gz -C deploy_package .
    
    SIZE=$(du -h app.tar.gz | cut -f1)
    print_info "Package created: $SIZE"
}

# Function to deploy to a single server
deploy_to_server() {
    local SERVER_NAME=$1
    local SERVER_IP=$2
    
    print_info "Deploying to $SERVER_NAME ($SERVER_IP)..."
    
    # Upload package
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no app.tar.gz ${SSH_USER}@${SERVER_IP}:/tmp/ || {
        print_error "Failed to upload package to $SERVER_NAME"
        return 1
    }
    
    # Deploy and restart service
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ${SSH_USER}@${SERVER_IP} << 'ENDSSH'
        set -e
        
        # Extract package
        sudo mkdir -p /var/www/debug-marathon
        sudo tar -xzf /tmp/app.tar.gz -C /var/www/debug-marathon
        
        # Install Python dependencies
        cd /var/www/debug-marathon/backend
        if [ -f requirements.txt ]; then
            sudo pip3 install -r requirements.txt --quiet || true
        fi
        
        # Restart service (adjust service name as needed)
        sudo systemctl restart debug-marathon 2>/dev/null || \
        sudo systemctl restart gunicorn 2>/dev/null || \
        sudo systemctl restart nginx || true
        
        # Cleanup
        rm /tmp/app.tar.gz
        
        echo "Deployment completed on $(hostname)"
ENDSSH
    
    if [ $? -eq 0 ]; then
        print_info "$SERVER_NAME deployment completed ✓"
    else
        print_error "$SERVER_NAME deployment failed ✗"
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    local SERVER_NAME=$1
    local SERVER_IP=$2
    
    print_info "Verifying $SERVER_NAME..."
    
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ${SSH_USER}@${SERVER_IP} << 'ENDSSH'
        if [ -d /var/www/debug-marathon/backend ]; then
            echo "✓ Application directory exists"
        else
            echo "✗ Application directory not found"
            exit 1
        fi
        
        # Check service status
        sudo systemctl is-active debug-marathon 2>/dev/null || \
        sudo systemctl is-active gunicorn 2>/dev/null || \
        echo "Service status unknown"
ENDSSH
}

# Main deployment process
main() {
    print_info "=== Multi-Server Deployment Started ==="
    print_info "Time: $(date)"
    
    # Check prerequisites
    check_prerequisites
    
    # Create deployment package
    create_package
    
    # Deploy to all servers
    FAILED_SERVERS=()
    
    deploy_to_server "Master" "$MASTER_IP" || FAILED_SERVERS+=("Master")
    deploy_to_server "Worker-1" "$WORKER1_IP" || FAILED_SERVERS+=("Worker-1")
    deploy_to_server "Worker-2" "$WORKER2_IP" || FAILED_SERVERS+=("Worker-2")
    deploy_to_server "Worker-3" "$WORKER3_IP" || FAILED_SERVERS+=("Worker-3")
    
    # Verify deployments
    print_info "=== Verification Phase ==="
    verify_deployment "Master" "$MASTER_IP"
    verify_deployment "Worker-1" "$WORKER1_IP"
    verify_deployment "Worker-2" "$WORKER2_IP"
    verify_deployment "Worker-3" "$WORKER3_IP"
    
    # Summary
    print_info "=== Deployment Summary ==="
    if [ ${#FAILED_SERVERS[@]} -eq 0 ]; then
        print_info "✅ All servers deployed successfully!"
    else
        print_error "❌ Failed servers: ${FAILED_SERVERS[*]}"
        exit 1
    fi
    
    # Cleanup
    rm -rf deploy_package app.tar.gz
    
    print_info "=== Deployment Completed ==="
}

# Run main function
main
