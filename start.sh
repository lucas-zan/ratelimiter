#!/bin/bash

# Rate Limiter Service Startup Script
SERVICE_NAME="rate-limiter"
PID_FILE="./logs/rate-limiter.pid"
LOG_FILE="./logs/rate-limiter.log"
CONFIG_FILE="config.yaml"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
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

# Check if service is already running
check_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            return 0
        else
            # PID file exists but process doesn't, clean up PID file
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Create necessary directories
create_directories() {
    print_info "Creating necessary directories..."
    mkdir -p logs
    mkdir -p scripts
    print_success "Directories created successfully"
}

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed, please install Go first"
        exit 1
    fi
    
    # Check if Redis is connectable
    if ! command -v redis-cli &> /dev/null; then
        print_warning "redis-cli not found, skipping Redis connection check"
    else
        # Try to connect to Redis
        if redis-cli ping > /dev/null 2>&1; then
            print_success "Redis connection is normal"
        else
            print_warning "Redis connection failed, please ensure Redis service is running"
        fi
    fi
    
    print_success "Dependency check completed"
}

# Build application
build_app() {
    print_info "Building application..."
    
    # Generate Swagger documentation
    print_info "Generating Swagger documentation..."
    if command -v swag &> /dev/null; then
        if swag init; then
            print_success "Swagger documentation generated successfully"
        else
            print_warning "Failed to generate Swagger documentation, continuing with build..."
        fi
    else
        print_warning "swag command not found, skipping Swagger documentation generation"
        print_info "To install swag: go install github.com/swaggo/swag/cmd/swag@latest"
    fi
    
    # Build the application
    if go build -o rate-limiter main.go; then
        print_success "Application built successfully"
    else
        print_error "Application build failed"
        exit 1
    fi
}

# Start service
start_service() {
    print_info "Starting $SERVICE_NAME service..."
    
    # Check if already running
    if check_running; then
        print_warning "Service is already running (PID: $(cat $PID_FILE))"
        return 0
    fi
    
    # Create directories
    create_directories
    
    # Check dependencies
    check_dependencies
    
    # Build application
    build_app
    
    # Start service
    print_info "Starting service..."
    nohup ./rate-limiter > "$LOG_FILE" 2>&1 &
    PID=$!
    
    # Save PID
    echo $PID > "$PID_FILE"
    
    # Wait for service to start
    sleep 2
    
    # Check if service started successfully
    if ps -p $PID > /dev/null 2>&1; then
        print_success "Service started successfully (PID: $PID)"
        print_info "Log file: $LOG_FILE"
        print_info "PID file: $PID_FILE"
        print_info "Service address: http://localhost:8080"
        print_info "Health check: http://localhost:8080/health"
        print_info "Swagger docs: http://localhost:8080/swagger/index.html"
        
        # Display all API endpoints
        print_info "Available API endpoints:"
        echo "  POST /v1/check_rate_limit - Check if rate limit is exceeded"
        echo "  POST /v1/update_rule      - Update rate limiting rule"
        echo "  GET  /v1/stats            - Get all monitoring statistics"
        echo "  GET  /v1/rule_stats       - Get specific rule statistics"
        echo "  GET  /health              - Health check"
        echo "  GET  /swagger/index.html  - Swagger API documentation"
        echo "  GET  /                    - API documentation"
        
        print_info "Example API calls:"
        echo "  # Check rate limit (returns allowed status and remaining tokens)"
        echo "  curl -X POST http://localhost:8080/v1/check_rate_limit \\"
        echo "    -H 'Content-Type: application/json' \\"
        echo "    -d '{\"key\": \"test:gpt-4\"}'"
        echo "  # Response: {\"allowed\": true, \"message\": \"\", \"remain\": 45}"
        echo ""
        echo "  # Update rate limit rule"
        echo "  curl -X POST http://localhost:8080/v1/update_rule \\"
        echo "    -H 'Content-Type: application/json' \\"
        echo "    -d '{\"key\": \"test:gpt-4\", \"rate_limit\": 10, \"burst\": 50}'"
        echo ""
        echo "  # Get statistics"
        echo "  curl http://localhost:8080/v1/stats"
        echo ""
        echo "  # Get specific rule stats"
        echo "  curl 'http://localhost:8080/v1/rule_stats?key=test:gpt-4'"
        
    else
        print_error "Service failed to start"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Show service status
show_status() {
    print_info "Service status:"
    if check_running; then
        PID=$(cat "$PID_FILE")
        print_success "Service is running (PID: $PID)"
        print_info "Port: 8080"
        print_info "Log file: $LOG_FILE"
        
        # Show recent logs
        if [ -f "$LOG_FILE" ]; then
            print_info "Recent logs:"
            tail -5 "$LOG_FILE" | while read line; do
                echo "  $line"
            done
        fi
    else
        print_warning "Service is not running"
    fi
}

# Main function
main() {
    case "${1:-start}" in
        start)
            start_service
            ;;
        status)
            show_status
            ;;
        build)
            build_app
            ;;
        check)
            check_dependencies
            ;;
        *)
            echo "Usage: $0 {start|status|build|check}"
            echo ""
            echo "Commands:"
            echo "  start   - Start service"
            echo "  status  - Show service status"
            echo "  build   - Build application"
            echo "  check   - Check dependencies"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@" 