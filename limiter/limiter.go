package limiter

import (
	"context"
	"fmt"
	"time"

	"github.com/your-org/rate-limiter/config"
	"github.com/your-org/rate-limiter/logger"
	"github.com/your-org/rate-limiter/redis"
)

type Rule struct {
	Key   string // apikey:model
	Rate  int64  // tokens generated per second
	Burst int64  // bucket capacity
}

// Allow determines if the current request is allowed
// Uses the officially recommended token bucket Redis Lua script
func Allow(ctx context.Context, rule Rule) (bool, error) {
	// Use default values if no rule is specified
	if rule.Rate == 0 {
		rule.Rate = config.GlobalConfig.Limiter.DefaultRate
		logger.Debug("Using default rate", logger.Int64("rate", rule.Rate))
	}
	if rule.Burst == 0 {
		rule.Burst = config.GlobalConfig.Limiter.DefaultBurst
		logger.Debug("Using default burst", logger.Int64("burst", rule.Burst))
	}

	logger.Debug("Checking rate limit",
		logger.String("key", rule.Key),
		logger.Int64("rate", rule.Rate),
		logger.Int64("burst", rule.Burst),
	)

	const script = `
local key     = KEYS[1]
local rate    = tonumber(ARGV[1])
local burst   = tonumber(ARGV[2])
local now     = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

local fill_time = burst/rate
local ttl = math.floor(fill_time*2)

local last_tokens = tonumber(redis.call("get", key) or burst)
local last_refreshed = tonumber(redis.call("get", key .. ":last_refreshed") or now)

local delta = math.max(0, now-last_refreshed)
local filled_tokens = math.min(burst, last_tokens + (delta*rate))
local allowed = filled_tokens >= requested
local new_tokens = filled_tokens
if allowed then
    new_tokens = filled_tokens - requested
end

redis.call("setex", key, ttl, new_tokens)
redis.call("setex", key .. ":last_refreshed", ttl, now)
return allowed and 1 or 0
`
	keys := []string{rule.Key}
	args := []interface{}{
		rule.Rate,
		rule.Burst,
		time.Now().Unix(),
		1, // Each request consumes 1 token
	}

	result, err := redis.Client.Eval(ctx, script, keys, args...).Int()
	if err != nil {
		logger.Error("Rate limit check failed",
			logger.String("key", rule.Key),
			logger.ErrorField(err),
		)
		return false, fmt.Errorf("rate limit check failed: %w", err)
	}

	allowed := result == 1
	logger.Info("Rate limit check result",
		logger.String("key", rule.Key),
		logger.Bool("allowed", allowed),
		logger.Int64("rate", rule.Rate),
		logger.Int64("burst", rule.Burst),
	)

	return allowed, nil
}

// AllowWithRemain determines if the current request is allowed and returns remaining tokens
// Uses the officially recommended token bucket Redis Lua script
func AllowWithRemain(ctx context.Context, rule Rule) (bool, int64, error) {
	// Use default values if no rule is specified
	if rule.Rate == 0 {
		rule.Rate = config.GlobalConfig.Limiter.DefaultRate
		logger.Debug("Using default rate", logger.Int64("rate", rule.Rate))
	}
	if rule.Burst == 0 {
		rule.Burst = config.GlobalConfig.Limiter.DefaultBurst
		logger.Debug("Using default burst", logger.Int64("burst", rule.Burst))
	}

	logger.Debug("Checking rate limit",
		logger.String("key", rule.Key),
		logger.Int64("rate", rule.Rate),
		logger.Int64("burst", rule.Burst),
	)

	const script = `
local key     = KEYS[1]
local rate    = tonumber(ARGV[1])
local burst   = tonumber(ARGV[2])
local now     = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

local fill_time = burst/rate
local ttl = math.floor(fill_time*2)

local last_tokens = tonumber(redis.call("get", key) or burst)
local last_refreshed = tonumber(redis.call("get", key .. ":last_refreshed") or now)

local delta = math.max(0, now-last_refreshed)
local filled_tokens = math.min(burst, last_tokens + (delta*rate))
local allowed = filled_tokens >= requested
local new_tokens = filled_tokens
if allowed then
    new_tokens = filled_tokens - requested
end

redis.call("setex", key, ttl, new_tokens)
redis.call("setex", key .. ":last_refreshed", ttl, now)
return {allowed and 1 or 0, new_tokens}
`
	keys := []string{rule.Key}
	args := []interface{}{
		rule.Rate,
		rule.Burst,
		time.Now().Unix(),
		1, // Each request consumes 1 token
	}

	result, err := redis.Client.Eval(ctx, script, keys, args...).Result()
	if err != nil {
		logger.Error("Rate limit check failed",
			logger.String("key", rule.Key),
			logger.ErrorField(err),
		)
		return false, 0, fmt.Errorf("rate limit check failed: %w", err)
	}

	// Parse result array
	resultArray, ok := result.([]interface{})
	if !ok || len(resultArray) != 2 {
		logger.Error("Invalid result format from Lua script",
			logger.String("key", rule.Key),
			logger.Any("result", result),
		)
		return false, 0, fmt.Errorf("invalid result format from Lua script")
	}

	allowed := resultArray[0].(int64) == 1
	remain := resultArray[1].(int64)

	logger.Info("Rate limit check result",
		logger.String("key", rule.Key),
		logger.Bool("allowed", allowed),
		logger.Int64("remain", remain),
		logger.Int64("rate", rule.Rate),
		logger.Int64("burst", rule.Burst),
	)

	return allowed, remain, nil
}

// GetRuleFromRedis gets rate limiting rule from Redis
func GetRuleFromRedis(ctx context.Context, key string) (Rule, error) {
	logger.Debug("Getting rule from Redis",
		logger.String("key", key),
	)

	rate, burst, err := redis.GetRule(ctx, key)
	if err != nil {
		// If rule doesn't exist, return default rule
		logger.Info("Rule not found, using defaults",
			logger.String("key", key),
		)
		return Rule{
			Key:   key,
			Rate:  config.GlobalConfig.Limiter.DefaultRate,
			Burst: config.GlobalConfig.Limiter.DefaultBurst,
		}, nil
	}

	logger.Debug("Retrieved rule from Redis",
		logger.String("key", key),
		logger.Int64("rate", rate),
		logger.Int64("burst", burst),
	)

	return Rule{
		Key:   key,
		Rate:  rate,
		Burst: burst,
	}, nil
}

// SetRuleToRedis sets rate limiting rule to Redis
func SetRuleToRedis(ctx context.Context, key string, rate, burst int64) error {
	logger.Info("Setting rule to Redis",
		logger.String("key", key),
		logger.Int64("rate", rate),
		logger.Int64("burst", burst),
	)

	return redis.SetRule(ctx, key, rate, burst)
}

// GetStats gets rate limiting statistics
func GetStats(ctx context.Context, key string) (map[string]interface{}, error) {
	logger.Debug("Getting stats",
		logger.String("key", key),
	)

	return redis.GetStats(ctx, key)
}
