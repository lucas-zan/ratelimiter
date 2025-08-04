#!/bin/bash

# Swagger Documentation Management Script

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

# Check if swag is installed
check_swag() {
    if ! command -v swag &> /dev/null; then
        print_error "swag command not found"
        print_info "To install swag, run: go install github.com/swaggo/swag/cmd/swag@latest"
        return 1
    fi
    return 0
}

# Generate Swagger documentation
generate_docs() {
    print_info "Generating Swagger documentation..."
    
    if ! check_swag; then
        return 1
    fi
    
    if swag init; then
        print_success "Swagger documentation generated successfully"
        print_info "Generated files:"
        echo "  - docs/docs.go"
        echo "  - docs/swagger.json"
        echo "  - docs/swagger.yaml"
        return 0
    else
        print_error "Failed to generate Swagger documentation"
        return 1
    fi
}

# Clean Swagger documentation
clean_docs() {
    print_info "Cleaning Swagger documentation..."
    
    if [ -d "docs" ]; then
        rm -rf docs
        print_success "Swagger documentation cleaned"
    else
        print_warning "docs directory does not exist"
    fi
}

# Show Swagger documentation status
show_status() {
    print_info "Swagger documentation status:"
    
    if [ -d "docs" ]; then
        print_success "docs directory exists"
        
        if [ -f "docs/docs.go" ]; then
            print_success "docs.go exists"
        else
            print_warning "docs.go missing"
        fi
        
        if [ -f "docs/swagger.json" ]; then
            print_success "swagger.json exists"
        else
            print_warning "swagger.json missing"
        fi
        
        if [ -f "docs/swagger.yaml" ]; then
            print_success "swagger.yaml exists"
        else
            print_warning "swagger.yaml missing"
        fi
    else
        print_warning "docs directory does not exist"
    fi
    
    # Check if swag is installed
    if check_swag; then
        print_success "swag command is available"
    fi
}

# Show help information
show_help() {
    echo "Usage: $0 {generate|clean|status|help}"
    echo ""
    echo "Commands:"
    echo "  generate - Generate Swagger documentation"
    echo "  clean    - Clean Swagger documentation files"
    echo "  status   - Show Swagger documentation status"
    echo "  help     - Show this help information"
    echo ""
    echo "Examples:"
    echo "  $0 generate  # Generate Swagger docs"
    echo "  $0 clean     # Clean Swagger docs"
    echo "  $0 status    # Check status"
}

# Main function
main() {
    case "${1:-help}" in
        generate|gen)
            generate_docs
            ;;
        clean)
            clean_docs
            ;;
        status)
            show_status
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