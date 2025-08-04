package redis

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/your-org/rate-limiter/config"
	"github.com/your-org/rate-limiter/logger"
)

var Client redis.Cmdable

// Init initializes Redis connection (single node or cluster)
func Init(cfg *config.RedisConfig) error {
	// Check if cluster configuration is provided
	if cfg.Cluster != nil && len(cfg.Cluster.Nodes) > 0 {
		return initCluster(cfg)
	}
	return initSingleNode(cfg)
}

// initSingleNode initializes single node Redis connection
func initSingleNode(cfg *config.RedisConfig) error {
	logger.Info("Initializing single node Redis connection",
		logger.String("addr", cfg.Addr),
		logger.Int("db", cfg.DB),
		logger.Int("pool_size", cfg.PoolSize),
	)

	client := redis.NewClient(&redis.Options{
		Addr:         cfg.Addr,
		Password:     cfg.Password,
		DB:           cfg.DB,
		PoolSize:     cfg.PoolSize,
		MinIdleConns: cfg.MinIdleConns,
		DialTimeout:  cfg.DialTimeout,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		// Connection pool configuration
		MaxRetries:      3,
		MinRetryBackoff: 8 * time.Millisecond,
		MaxRetryBackoff: 512 * time.Millisecond,
	})

	Client = client

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		logger.Error("Failed to connect to Redis", logger.ErrorField(err))
		return fmt.Errorf("failed to connect to Redis: %w", err)
	}

	logger.Info("Single node Redis connection established successfully")
	return nil
}

// initCluster initializes Redis cluster connection
func initCluster(cfg *config.RedisConfig) error {
	logger.Info("Initializing Redis cluster connection",
		logger.Any("nodes", cfg.Cluster.Nodes),
		logger.Int("pool_size", cfg.PoolSize),
	)

	client := redis.NewClusterClient(&redis.ClusterOptions{
		Addrs:        cfg.Cluster.Nodes,
		Password:     cfg.Password,
		PoolSize:     cfg.PoolSize,
		MinIdleConns: cfg.MinIdleConns,
		DialTimeout:  cfg.DialTimeout,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		// Connection pool configuration
		MaxRetries:      3,
		MinRetryBackoff: 8 * time.Millisecond,
		MaxRetryBackoff: 512 * time.Millisecond,
	})

	Client = client

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		logger.Error("Failed to connect to Redis cluster", logger.ErrorField(err))
		return fmt.Errorf("failed to connect to Redis cluster: %w", err)
	}

	logger.Info("Redis cluster connection established successfully")
	return nil
}

// Close closes Redis connection
func Close() error {
	if Client != nil {
		logger.Info("Closing Redis connection")
		switch client := Client.(type) {
		case *redis.Client:
			return client.Close()
		case *redis.ClusterClient:
			return client.Close()
		}
	}
	return nil
}

// SetRule sets rate limiting rule
func SetRule(ctx context.Context, key string, rate, burst int64) error {
	ruleKey := fmt.Sprintf("rule:%s", key)

	logger.Info("Setting rate limit rule",
		logger.String("key", key),
		logger.Int64("rate", rate),
		logger.Int64("burst", burst),
	)

	err := Client.HMSet(ctx, ruleKey, map[string]interface{}{
		"rate":       rate,
		"burst":      burst,
		"updated_at": time.Now().Unix(),
	}).Err()

	if err != nil {
		logger.Error("Failed to set rate limit rule",
			logger.String("key", key),
			logger.ErrorField(err),
		)
	} else {
		logger.Info("Rate limit rule set successfully", logger.String("key", key))
	}

	return err
}

// GetRule gets rate limiting rule
func GetRule(ctx context.Context, key string) (rate, burst int64, err error) {
	ruleKey := fmt.Sprintf("rule:%s", key)

	logger.Debug("Getting rate limit rule", logger.String("key", key))

	result, err := Client.HMGet(ctx, ruleKey, "rate", "burst").Result()
	if err != nil {
		logger.Error("Failed to get rate limit rule",
			logger.String("key", key),
			logger.ErrorField(err),
		)
		return 0, 0, err
	}

	if result[0] == nil || result[1] == nil {
		logger.Debug("Rate limit rule not found, using defaults", logger.String("key", key))
		return 0, 0, fmt.Errorf("rule not found")
	}

	rate, err = strconv.ParseInt(result[0].(string), 10, 64)
	if err != nil {
		logger.Error("Invalid rate value in rule",
			logger.String("key", key),
			logger.ErrorField(err),
		)
		return 0, 0, fmt.Errorf("invalid rate value: %w", err)
	}

	burst, err = strconv.ParseInt(result[1].(string), 10, 64)
	if err != nil {
		logger.Error("Invalid burst value in rule",
			logger.String("key", key),
			logger.ErrorField(err),
		)
		return 0, 0, fmt.Errorf("invalid burst value: %w", err)
	}

	logger.Debug("Retrieved rate limit rule",
		logger.String("key", key),
		logger.Int64("rate", rate),
		logger.Int64("burst", burst),
	)

	return rate, burst, nil
}

// GetAllRules gets all rate limiting rules
func GetAllRules(ctx context.Context) (map[string]map[string]interface{}, error) {
	pattern := "rule:*"

	logger.Debug("Getting all rate limit rules")

	keys, err := Client.Keys(ctx, pattern).Result()
	if err != nil {
		logger.Error("Failed to get rule keys", logger.ErrorField(err))
		return nil, err
	}

	logger.Info("Found rate limit rules", logger.Int("count", len(keys)))

	rules := make(map[string]map[string]interface{})
	for _, key := range keys {
		ruleKey := key[5:] // Remove "rule:" prefix
		result, err := Client.HGetAll(ctx, key).Result()
		if err != nil {
			logger.Warn("Failed to get rule data",
				logger.String("key", key),
				logger.ErrorField(err),
			)
			continue
		}
		// Convert map[string]string to map[string]interface{}
		ruleData := make(map[string]interface{})
		for k, v := range result {
			ruleData[k] = v
		}
		rules[ruleKey] = ruleData
	}

	return rules, nil
}

// GetStats gets rate limiting statistics
func GetStats(ctx context.Context, key string) (map[string]interface{}, error) {
	logger.Debug("Getting stats for key", logger.String("key", key))

	stats := make(map[string]interface{})

	// Get rule information
	rate, burst, err := GetRule(ctx, key)
	if err != nil {
		stats["rate"] = "unknown"
		stats["burst"] = "unknown"
		stats["current_tokens"] = "unknown"
		logger.Debug("Using unknown rate/burst for stats", logger.String("key", key))
		return stats, nil
	}

	// Get current token count - Fix: use key directly, no need for tokens: prefix
	tokens, err := Client.Get(ctx, key).Result()
	if err != nil && err != redis.Nil {
		logger.Error("Failed to get current tokens",
			logger.String("key", key),
			logger.ErrorField(err),
		)
		return nil, err
	}
	if err == redis.Nil {
		// If token data doesn't exist, it means no rate limit check has been performed yet, return initial bucket capacity
		stats["current_tokens"] = burst
		logger.Debug("No token data found, using initial burst capacity",
			logger.String("key", key),
			logger.Int64("burst", burst))
	} else {
		stats["current_tokens"] = tokens
		logger.Debug("Retrieved current tokens",
			logger.String("key", key),
			logger.String("tokens", tokens),
		)
	}

	stats["rate"] = rate
	stats["burst"] = burst
	logger.Debug("Retrieved rate/burst for stats",
		logger.String("key", key),
		logger.Int64("rate", rate),
		logger.Int64("burst", burst),
	)

	return stats, nil
}
