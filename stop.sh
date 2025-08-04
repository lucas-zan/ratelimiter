#!/bin/bash

# Rate Limiter Service Stop Script
SERVICE_NAME="rate-limiter"
PID_FILE="./logs/rate-limiter.pid"
LOG_FILE="./logs/rate-limiter.log"

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

# Check if service is running
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

# Stop service
stop_service() {
    print_info "Stopping $SERVICE_NAME service..."
    
    if ! check_running; then
        print_warning "Service is not running"
        return 0
    fi
    
    PID=$(cat "$PID_FILE")
    print_info "Stopping process (PID: $PID)..."
    
    # Try graceful stop
    kill $PID
    
    # Wait for process to end
    local count=0
    while ps -p $PID > /dev/null 2>&1 && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
        print_info "Waiting for process to end... ($count/10)"
    done
    
    # Check if process is still running
    if ps -p $PID > /dev/null 2>&1; then
        print_warning "Process not responding, force killing..."
        kill -9 $PID
        sleep 1
    fi
    
    # Final check
    if ps -p $PID > /dev/null 2>&1; then
        print_error "Unable to stop process (PID: $PID)"
        return 1
    else
        print_success "Service stopped"
        rm -f "$PID_FILE"
        return 0
    fi
}

# Restart service
restart_service() {
    print_info "Restarting $SERVICE_NAME service..."
    
    # Stop service first
    if check_running; then
        stop_service
        sleep 2
    fi
    
    # Start service
    if [ -f "./scripts/start.sh" ]; then
        ./scripts/start.sh start
    else
        print_error "Start script not found: ./scripts/start.sh"
        return 1
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
        
        # Show process information
        print_info "Process information:"
        ps -p $PID -o pid,ppid,cmd,etime 2>/dev/null || print_warning "Unable to get process information"
        
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
        print_warning "Service is not running"
    fi
}

# Clean logs
clean_logs() {
    print_info "Cleaning log files..."
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        print_success "Log file cleaned"
    else
        print_warning "Log file does not exist"
    fi
    
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
        print_success "PID file cleaned"
    fi
}

# Show help information
show_help() {
    echo "Usage: $0 {stop|restart|status|clean|help}"
    echo ""
    echo "Commands:"
    echo "  stop     - Stop service"
    echo "  restart  - Restart service"
    echo "  status   - Show service status"
    echo "  clean    - Clean log files"
    echo "  help     - Show this help information"
    echo ""
    echo "Examples:"
    echo "  $0 stop      # Stop service"
    echo "  $0 restart   # Restart service"
    echo "  $0 status    # Check status"
}

# Main function
main() {
    case "${1:-stop}" in
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            show_status
            ;;
        clean)
            clean_logs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@" 