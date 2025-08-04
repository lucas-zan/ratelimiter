# Rate Limiter Service

A high-performance rate limiting service built with Go and Redis, implementing the token bucket algorithm with dynamic rule management and comprehensive monitoring capabilities.

## Features

- **Token Bucket Algorithm**: Efficient rate limiting using Redis Lua scripts
- **Dynamic Rule Management**: Update rate limiting rules via REST API
- **Flexible Key Format**: Support custom key patterns for various use cases
- **Real-time Monitoring**: Complete statistics and monitoring interfaces
- **High Availability**: Redis connection pooling with retry mechanisms
- **Structured Logging**: JSON logging with rotation and compression
- **Swagger Documentation**: Interactive API documentation
- **Docker Support**: Containerized deployment with Docker Compose

## Quick Start

### Option 1: Using start.sh Script (Recommended for Development)

```bash
# Make script executable
chmod +x start.sh

# Start the service
./start.sh start

# Check service status
./start.sh status

# Build application only
./start.sh build

# Check dependencies
./start.sh check
```

### Option 2: Using Docker Compose (Recommended for Production)

```bash
# Start all services (Redis + Rate Limiter)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Rebuild and start
docker-compose up --build -d
```

### Option 3: Manual Setup

```bash
# Install dependencies
go mod tidy

# Build application
go build -o rate-limiter main.go

# Start Redis (if not running)
redis-server

# Run service
./rate-limiter
```

## API Endpoints

### Check Rate Limit
```http
POST /v1/check_rate_limit
Content-Type: application/json

{
  "key": "api_key:model"
}
```

**Response:**
```json
{
  "allowed": true,
  "message": "",
  "remain": 45
}
```

### Update Rate Limiting Rule
```http
POST /v1/update_rule
Content-Type: application/json

{
  "key": "api_key:model",
  "rate_limit": 10,
  "burst": 50
}
```

### Get Statistics
```http
GET /v1/stats
GET /v1/rule_stats?key=api_key:model
```

### Health Check
```http
GET /health
```

### API Documentation
```http
GET /swagger/index.html
```

## Configuration

### Environment Variables
```bash
export REDIS_ADDR=localhost:6379
export REDIS_PASSWORD=your_password
export DEFAULT_RATE=10
export DEFAULT_BURST=50
export SERVER_PORT=:8080
export LOG_LEVEL=info
```

### Configuration File (config.yaml)
```yaml
server:
  port: ":8080"

redis:
  addr: "localhost:6379"
  password: ""
  db: 0
  pool_size: 10
  min_idle_conns: 5

limiter:
  default_rate: 10
  default_burst: 50

log:
  level: "info"
  format: "json"
  output: "file"
  file_path: "logs"
  max_size: 100
  max_backups: 10
  max_age: 30
  compress: true
```

## Key Format Examples

The service supports flexible key formats:

- `api_key:model` - API key and model combination
- `user_id:feature` - User and feature combination  
- `ip_address:endpoint` - IP-based rate limiting
- `tenant_id:service` - Multi-tenant rate limiting
- `project_id:api` - Project-based rate limiting
- `session_id:action` - Session-based rate limiting

## Project Structure

```
.
├── main.go              # Application entry point
├── config.yaml          # Configuration file
├── start.sh             # Startup script
├── docker-compose.yml   # Docker Compose configuration
├── Dockerfile           # Docker image definition
├── config/              # Configuration management
├── redis/               # Redis client wrapper
├── limiter/             # Rate limiter implementation
├── handler/             # HTTP handlers
├── logger/              # Logging system
├── scripts/             # Utility scripts
├── logs/                # Log files
└── test/                # Test scripts
```

## Technology Stack

- **Go 1.23+**: Primary language
- **Gin**: HTTP web framework
- **Redis**: Data storage and token bucket
- **Zap**: High-performance logging
- **Lumberjack**: Log rotation
- **Swagger**: API documentation

## Development

### Prerequisites
- Go 1.23+
- Redis 6.0+
- Docker & Docker Compose (optional)

### Testing
```bash
# Run tests
go test ./...

# API testing
./test/test_api.sh
```

### Logging
```bash
# View real-time logs
tail -f logs/rate-limiter.log

# View logs with script
./scripts/view_logs.sh
```

## Deployment

### Production Recommendations
- Use Redis cluster for high availability
- Deploy multiple service instances with load balancer
- Configure monitoring with Prometheus/Grafana
- Use structured logging for log aggregation
- Set appropriate log rotation policies

### Docker Deployment
```bash
# Build and push image
docker build -t your-registry/rate-limiter:latest .
docker push your-registry/rate-limiter:latest

# Deploy with custom configuration
docker-compose -f docker-compose.prod.yml up -d
```

## License

MIT License 