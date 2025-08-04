.PHONY: build run test clean docker-build docker-run help logs-view logs-clean service-start service-stop service-restart service-status

# 默认目标
.DEFAULT_GOAL := help

# 变量定义
BINARY_NAME=rate-limiter
DOCKER_IMAGE=rate-limiter:latest
LOG_DIR=logs

# 构建应用
build:
	@echo "Building $(BINARY_NAME)..."
	go build -o $(BINARY_NAME) main.go

# 运行应用
run: build
	@echo "Running $(BINARY_NAME)..."
	./$(BINARY_NAME)

# 开发模式运行
dev:
	@echo "Running in development mode..."
	go run main.go

# 测试
test:
	@echo "Running tests..."
	go test ./...

# 清理构建文件
clean:
	@echo "Cleaning build files..."
	rm -f $(BINARY_NAME)
	go clean

# 清理日志文件
logs-clean:
	@echo "Cleaning log files..."
	rm -rf $(LOG_DIR)/*

# 查看日志
logs-view:
	@echo "Viewing logs..."
	@if [ -f "$(LOG_DIR)/rate-limiter.log" ]; then \
		tail -f $(LOG_DIR)/rate-limiter.log; \
	else \
		echo "No log file found. Start the service first."; \
	fi

# 查看日志统计
logs-stats:
	@echo "Log statistics:"
	@if [ -f "$(LOG_DIR)/rate-limiter.log" ]; then \
		echo "Total lines: $$(wc -l < $(LOG_DIR)/rate-limiter.log)"; \
		echo "INFO logs: $$(grep -c '"level":"INFO"' $(LOG_DIR)/rate-limiter.log 2>/dev/null || echo 0)"; \
		echo "ERROR logs: $$(grep -c '"level":"ERROR"' $(LOG_DIR)/rate-limiter.log 2>/dev/null || echo 0)"; \
		echo "WARN logs: $$(grep -c '"level":"WARN"' $(LOG_DIR)/rate-limiter.log 2>/dev/null || echo 0)"; \
		echo "DEBUG logs: $$(grep -c '"level":"DEBUG"' $(LOG_DIR)/rate-limiter.log 2>/dev/null || echo 0)"; \
		echo "FATAL logs: $$(grep -c '"level":"FATAL"' $(LOG_DIR)/rate-limiter.log 2>/dev/null || echo 0)"; \
	else \
		echo "No log file found."; \
	fi

# 服务管理
service-start:
	@echo "Starting service..."
	@./scripts/service.sh start

service-stop:
	@echo "Stopping service..."
	@./scripts/service.sh stop

service-restart:
	@echo "Restarting service..."
	@./scripts/service.sh restart

service-status:
	@echo "Checking service status..."
	@./scripts/service.sh status

service-logs:
	@echo "Viewing service logs..."
	@./scripts/service.sh logs

service-clean:
	@echo "Cleaning service logs..."
	@./scripts/service.sh clean

# Docker构建
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE) .

# Docker运行
docker-run: docker-build
	@echo "Running with Docker..."
	docker run -p 8080:8080 --name $(BINARY_NAME) $(DOCKER_IMAGE)

# Docker Compose启动
docker-compose-up:
	@echo "Starting services with Docker Compose..."
	docker-compose up -d

# Docker Compose停止
docker-compose-down:
	@echo "Stopping services..."
	docker-compose down

# Docker Compose重启
docker-compose-restart:
	@echo "Restarting services..."
	docker-compose restart

# 查看日志
logs:
	@echo "Showing logs..."
	docker-compose logs -f

# 格式化代码
fmt:
	@echo "Formatting code..."
	go fmt ./...

# 代码检查
lint:
	@echo "Running linter..."
	golangci-lint run

# 安装依赖
deps:
	@echo "Installing dependencies..."
	go mod tidy
	go mod download

# 生成API文档
docs:
	@echo "Generating API documentation..."
	@echo "API文档已生成在README.md中"

# Swagger documentation
swagger-init:
	@echo "Generating Swagger documentation..."
	swag init
	@echo "Swagger documentation generated successfully"

swagger-serve:
	@echo "Starting Swagger documentation server..."
	swag serve

# Development with Swagger
dev-swagger: swagger-init
	@echo "Starting development server with Swagger..."
	go run main.go

# Build with Swagger
build-swagger: swagger-init
	@echo "Building application with Swagger..."
	go build -o rate-limiter main.go

# 帮助信息
help:
	@echo "Available commands:"
	@echo "  build              - 构建应用"
	@echo "  run                - 构建并运行应用"
	@echo "  dev                - 开发模式运行"
	@echo "  test               - 运行测试"
	@echo "  clean              - 清理构建文件"
	@echo ""
	@echo "日志管理:"
	@echo "  logs-clean         - 清理日志文件"
	@echo "  logs-view          - 实时查看日志"
	@echo "  logs-stats         - 查看日志统计"
	@echo ""
	@echo "服务管理:"
	@echo "  service-start      - 启动服务"
	@echo "  service-stop       - 停止服务"
	@echo "  service-restart    - 重启服务"
	@echo "  service-status     - 查看服务状态"
	@echo "  service-logs       - 查看服务日志"
	@echo "  service-clean      - 清理服务日志"
	@echo ""
	@echo "Docker管理:"
	@echo "  docker-build       - 构建Docker镜像"
	@echo "  docker-run         - 运行Docker容器"
	@echo "  docker-compose-up  - 启动所有服务"
	@echo "  docker-compose-down- 停止所有服务"
	@echo "  docker-compose-restart - 重启所有服务"
	@echo "  logs               - 查看Docker日志"
	@echo ""
	@echo "开发工具:"
	@echo "  fmt                - 格式化代码"
	@echo "  lint               - 代码检查"
	@echo "  deps               - 安装依赖"
	@echo "  docs               - 生成文档"
	@echo "  help               - 显示此帮助信息" 