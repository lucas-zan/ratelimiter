package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"gopkg.in/yaml.v3"
)

var GlobalConfig *Config

// LoadConfig loads configuration file
func LoadConfig(configPath string) error {
	config := &Config{}

	// Set default values
	setDefaults(config)

	// Load configuration from file
	if configPath != "" {
		if err := loadFromFile(configPath, config); err != nil {
			return fmt.Errorf("failed to load config file: %w", err)
		}
	}

	// Override configuration from environment variables
	loadFromEnv(config)

	GlobalConfig = config
	return nil
}

func setDefaults(config *Config) {
	config.Server.Port = ":8080"
	config.Redis.Addr = "localhost:6379"
	config.Redis.DB = 0
	config.Redis.PoolSize = 10
	config.Redis.MinIdleConns = 5
	config.Redis.DialTimeout = 5 * time.Second
	config.Redis.ReadTimeout = 3 * time.Second
	config.Redis.WriteTimeout = 3 * time.Second
	config.Limiter.DefaultRate = 10
	config.Limiter.DefaultBurst = 50
	config.Log.Level = "info"
	config.Log.Format = "json"
	config.Log.Output = "stdout"
	config.Log.FilePath = "logs"
	config.Log.MaxSize = 100
	config.Log.MaxBackups = 10
	config.Log.MaxAge = 30
	config.Log.Compress = true
}

func loadFromFile(configPath string, config *Config) error {
	data, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}

	return yaml.Unmarshal(data, config)
}

func loadFromEnv(config *Config) {
	// Server configuration
	if port := os.Getenv("SERVER_PORT"); port != "" {
		config.Server.Port = port
	}

	// Redis configuration
	if addr := os.Getenv("REDIS_ADDR"); addr != "" {
		config.Redis.Addr = addr
	}
	if password := os.Getenv("REDIS_PASSWORD"); password != "" {
		config.Redis.Password = password
	}
	if db := os.Getenv("REDIS_DB"); db != "" {
		if dbInt, err := strconv.Atoi(db); err == nil {
			config.Redis.DB = dbInt
		}
	}
	if poolSize := os.Getenv("REDIS_POOL_SIZE"); poolSize != "" {
		if poolSizeInt, err := strconv.Atoi(poolSize); err == nil {
			config.Redis.PoolSize = poolSizeInt
		}
	}

	// Limiter configuration
	if rate := os.Getenv("DEFAULT_RATE"); rate != "" {
		if rateInt, err := strconv.ParseInt(rate, 10, 64); err == nil {
			config.Limiter.DefaultRate = rateInt
		}
	}
	if burst := os.Getenv("DEFAULT_BURST"); burst != "" {
		if burstInt, err := strconv.ParseInt(burst, 10, 64); err == nil {
			config.Limiter.DefaultBurst = burstInt
		}
	}

	// Log configuration
	if level := os.Getenv("LOG_LEVEL"); level != "" {
		config.Log.Level = level
	}
	if format := os.Getenv("LOG_FORMAT"); format != "" {
		config.Log.Format = format
	}
	if output := os.Getenv("LOG_OUTPUT"); output != "" {
		config.Log.Output = output
	}
	if filePath := os.Getenv("LOG_FILE_PATH"); filePath != "" {
		config.Log.FilePath = filePath
	}
	if maxSize := os.Getenv("LOG_MAX_SIZE"); maxSize != "" {
		if maxSizeInt, err := strconv.Atoi(maxSize); err == nil {
			config.Log.MaxSize = maxSizeInt
		}
	}
	if maxBackups := os.Getenv("LOG_MAX_BACKUPS"); maxBackups != "" {
		if maxBackupsInt, err := strconv.Atoi(maxBackups); err == nil {
			config.Log.MaxBackups = maxBackupsInt
		}
	}
	if maxAge := os.Getenv("LOG_MAX_AGE"); maxAge != "" {
		if maxAgeInt, err := strconv.Atoi(maxAge); err == nil {
			config.Log.MaxAge = maxAgeInt
		}
	}
	if compress := os.Getenv("LOG_COMPRESS"); compress != "" {
		if compressBool, err := strconv.ParseBool(compress); err == nil {
			config.Log.Compress = compressBool
		}
	}
}
