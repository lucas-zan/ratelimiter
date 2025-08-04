# Rate Limiter Service

A rate limiting service based on Go and Redis, supporting token bucket algorithm with flexible rate limiting rule configuration and monitoring capabilities.

## Features

1. **Dynamic Rate Limiting Rule Management**: Support dynamic rate limiting rule updates via API
2. **Token Bucket Algorithm**: Efficient token bucket rate limiting using Redis Lua scripts
3. **Configuration Management**: Support YAML configuration files and environment variables
4. **Monitoring and Statistics**: Complete rate limiting statistics and monitoring interfaces
5. **High Availability**: Support Redis connection pooling and error retry mechanisms
6. **Structured Logging**: Complete logging and log rotation functionality

## API Endpoints

### 1. Check Rate Limit Status
```http
POST /v1/check_rate_limit
Content-Type: application/json

{
  "key": "your_api_key:gpt-4"
}
```

Response:
```json
{
  "allowed": true,
  "message": "",
  "remain": 45
}
```

**Field Descriptions:**
- `key`: Rate limiting key (user-defined format, e.g., "api_key:model", "user_id:feature", "ip:endpoint")
- `allowed`: Whether the request is allowed
- `message`: Error message (if any)
- `remain`: Number of remaining tokens in the bucket

**Key Format Examples:**
The service supports flexible key formats to accommodate various use cases:

- `api_key:model` - API key and model combination (e.g., "sk-123:gpt-4")
- `user_id:feature` - User and feature combination (e.g., "user123:chat", "user123:upload")
- `ip_address:endpoint` - IP-based rate limiting (e.g., "192.168.1.1:/api/chat")
- `tenant_id:service` - Multi-tenant rate limiting (e.g., "tenant1:api", "tenant2:api")
- `project_id:api` - Project-based rate limiting (e.g., "proj123:chat", "proj123:completion")
- `session_id:action` - Session-based rate limiting (e.g., "sess456:login", "sess456:search")

Users can design their own key format based on their specific business requirements.

### 2. Update Rate Limiting Rule
```http
POST /v1/update_rule
Content-Type: application/json

{
  "key": "your_api_key:gpt-4",
  "rate_limit": 10,
  "burst": 50
}
```

Response:
```json
{
  "status": "success",
  "message": "Rate limit rule updated successfully"
}
```

### 3. Get Monitoring Statistics
```http
GET /v1/stats
```

Response:
```json
{
  "rules": {
    "your_api_key:gpt-4": {
      "rate": "10",
      "burst": "50",
      "updated_at": "1640995200"
    }
  },
  "stats": {
    "your_api_key:gpt-4": {
      "current_tokens": "45",
      "rate": 10,
      "burst": 50
    }
  }
}
```

**Field Descriptions:**
- `current_tokens`: Current number of remaining tokens in the token bucket, updated each time `/v1/check_rate_limit` endpoint is called
- `rate`: Token generation rate per second
- `burst`: Maximum token bucket capacity

### 4. Get Specific Rule Statistics
```http
GET /v1/rule_stats?key=your_api_key:gpt-4
```

Response:
```json
{
  "key": "your_api_key:gpt-4",
  "stats": {
    "current_tokens": "45",
    "rate": 10,
    "burst": 50
  }
}
```

### 5. Health Check
```http
GET /health
```

### 6. Swagger API Documentation
```http
GET /swagger/index.html
```

Access the interactive Swagger UI to explore and test all API endpoints.

## Installation and Running

### 1. Install Dependencies
```bash
go mod tidy
```

### 2. Configure Redis
Ensure Redis service is running, default connection address is `localhost:6379`

### 3. Configuration File
Create `config.yaml` file:
```yaml
server:
  port: ":8080"

redis:
  addr: "localhost:6379"
  password: ""
  db: 0
  pool_size: 10
  min_idle_conns: 5
  dial_timeout: "5s"
  read_timeout: "3s"
  write_timeout: "3s"

limiter:
  default_rate: 10   # Default token generation rate per second
  default_burst: 50  # Default bucket capacity

log:
  level: "info"        # Log level: debug, info, warn, error
  format: "json"       # Log format: json, console
  output: "file"       # Output location: stdout, file
  file_path: "logs"    # Log file path
  max_size: 100        # Maximum size of single log file (MB)
  max_backups: 10      # Maximum number of backup files
  max_age: 30          # Log file retention days
  compress: true       # Whether to compress old log files
```

### 4. Run Service
```bash
# Use default configuration file
go run main.go

# Specify configuration file
go run main.go -config=config.yaml

# Use Makefile
make dev
```

### 5. Environment Variable Configuration
You can also override configuration via environment variables:
```bash
export REDIS_ADDR=localhost:6379
export REDIS_PASSWORD=your_password
export DEFAULT_RATE=20
export DEFAULT_BURST=100
export SERVER_PORT=:8080
export LOG_LEVEL=debug
export LOG_OUTPUT=stdout
```

## Logging Features

### Log Configuration
The service supports complete logging functionality:

- **Log Levels**: debug, info, warn, error
- **Log Formats**: JSON format (recommended) or console format
- **Output Locations**: Standard output or file
- **Log Rotation**: Automatic file rotation with compression and cleanup

### Log Viewing
```bash
# View logs in real-time
make logs-view

# View log statistics
make logs-stats

# Clean log files
make logs-clean

# Use script to view logs
./scripts/view_logs.sh
```

### Log Example
```json
{
  "level": "INFO",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "caller": "main.go:45",
  "msg": "Starting Rate Limiter Service",
  "version": "1.0.0",
  "config_file": "config.yaml"
}
```

## Project Structure

```
.
├── main.go              # Main program entry
├── config.yaml          # Configuration file
├── go.mod              # Go module file
├── README.md           # Project documentation
├── config/             # Configuration management
│   ├── config.go       # Configuration structure definitions
│   └── loader.go       # Configuration loader
├── redis/              # Redis wrapper
│   └── redis.go        # Redis client and operations
├── limiter/            # Rate limiter
│   └── limiter.go      # Token bucket algorithm implementation
├── handler/            # HTTP handlers
│   └── handler.go      # API endpoint implementations
├── logger/             # Logging system
│   └── logger.go       # Logger
├── scripts/            # Script files
│   └── view_logs.sh    # Log viewing script
├── logs/               # Log file directory
│   └── rate-limiter.log # Log file
└── test/               # Test scripts
    └── test_api.sh     # API tests
```

## Technology Stack

- **Go 1.22+**: Primary development language
- **Gin**: HTTP web framework
- **Redis**: Data storage and token bucket implementation
- **YAML**: Configuration file format
- **Zap**: High-performance logging library
- **Lumberjack**: Log rotation library

## Rate Limiting Algorithm

Uses token bucket algorithm for rate limiting:

1. **Token Generation**: Generate tokens at configured rate
2. **Token Consumption**: Each request consumes one token
3. **Bucket Capacity**: Limit maximum token count (burst)
4. **Redis Storage**: Use Redis to store current token count and last update time

## Monitoring and Statistics

The service provides complete monitoring capabilities:

- Current token count
- Rate limiting rule configuration
- Request statistics
- Rule update timestamps
- Detailed logging

## Deployment Recommendations

1. **Redis Cluster**: Production environments should use Redis cluster for high availability
2. **Load Balancing**: Deploy multiple service instances with load balancer for request distribution
3. **Monitoring and Alerting**: Integrate Prometheus and Grafana for monitoring
4. **Logging**: Use structured logging for log aggregation and analysis
5. **Log Rotation**: Configure appropriate log rotation strategies to avoid disk space issues

## Development

### Adding New Features
1. Add functionality in appropriate packages
2. Add API endpoints in handler package
3. Update route configuration
4. Add test cases
5. Add appropriate logging

### Testing
```bash
# Run tests
go test ./...

# Run specific tests
go test ./limiter -v

# API testing
./test/test_api.sh
```

### Log Debugging
```bash
# Set debug level
export LOG_LEVEL=debug

# View real-time logs
make logs-view

# View error logs
grep '"level":"ERROR"' logs/rate-limiter.log
```

## License

MIT License 