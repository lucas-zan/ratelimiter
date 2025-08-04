package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/your-org/rate-limiter/limiter"
	"github.com/your-org/rate-limiter/logger"
	"github.com/your-org/rate-limiter/redis"
)

// CheckReq represents the request for checking rate limit
type CheckReq struct {
	Key string `json:"key" binding:"required" example:"your_api_key:gpt-4"` // Rate limiting key (user-defined format)
}

// CheckResp represents the response for rate limit check
type CheckResp struct {
	Allowed bool   `json:"allowed" example:"true"`       // Whether the request is allowed
	Message string `json:"message,omitempty" example:""` // Error message (if any)
	Remain  int64  `json:"remain" example:"45"`          // Number of remaining tokens
}

// UpdateRuleReq represents the request for updating rate limiting rule
type UpdateRuleReq struct {
	Key       string `json:"key" binding:"required" example:"your_api_key:gpt-4"` // Rate limiting key (user-defined format)
	RateLimit int64  `json:"rate_limit" binding:"required" example:"10"`          // Tokens per second
	Burst     int64  `json:"burst" example:"50"`                                  // Bucket capacity, optional
}

// UpdateRuleResp represents the response for updating rate limiting rule
type UpdateRuleResp struct {
	Status  string `json:"status" example:"success"`                 // Status of the operation
	Message string `json:"message,omitempty" example:"Rule updated"` // Response message
}

// StatsResp represents the response for getting statistics
type StatsResp struct {
	Rules map[string]map[string]interface{} `json:"rules"` // Rate limiting rules
	Stats map[string]map[string]interface{} `json:"stats"` // Statistics for each rule
}

// CheckRateLimit checks if rate limit is exceeded
// @Summary Check rate limit status
// @Description Check if the current request is allowed based on rate limiting rules
// @Tags rate-limit
// @Accept json
// @Produce json
// @Param request body CheckReq true "Rate limit check request"
// @Success 200 {object} CheckResp
// @Failure 400 {object} map[string]interface{} "Invalid request parameters"
// @Failure 500 {object} map[string]interface{} "Internal server error"
// @Router /v1/check_rate_limit [post]
func CheckRateLimit(c *gin.Context) {
	startTime := time.Now()

	var req CheckReq
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Error("Invalid request parameters for rate limit check",
			logger.ErrorField(err),
			logger.String("key", req.Key),
		)
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request parameters",
			"details": err.Error(),
		})
		return
	}

	logger.Info("Rate limit check request",
		logger.String("key", req.Key),
		logger.String("client_ip", c.ClientIP()),
		logger.String("user_agent", c.GetHeader("User-Agent")),
	)

	// Get rule from Redis
	rule, err := limiter.GetRuleFromRedis(c.Request.Context(), req.Key)
	if err != nil {
		logger.Error("Failed to get rate limit rule",
			logger.String("key", req.Key),
			logger.ErrorField(err),
		)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get rate limit rule",
			"details": err.Error(),
		})
		return
	}

	// Check rate limit
	allowed, remain, err := limiter.AllowWithRemain(c.Request.Context(), rule)
	if err != nil {
		logger.Error("Rate limit check failed",
			logger.String("key", req.Key),
			logger.ErrorField(err),
		)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Rate limit check failed",
			"details": err.Error(),
		})
		return
	}

	resp := CheckResp{
		Allowed: allowed,
		Remain:  remain,
	}
	if !allowed {
		resp.Message = "Rate limit exceeded"
		logger.Warn("Rate limit exceeded",
			logger.String("key", req.Key),
		)
	}

	duration := time.Since(startTime)
	logger.Info("Rate limit check completed",
		logger.String("key", req.Key),
		logger.Bool("allowed", allowed),
		logger.Int64("remain", remain),
		logger.Duration("duration", duration),
	)

	c.JSON(http.StatusOK, resp)
}

// UpdateRule updates rate limiting rule
// @Summary Update rate limiting rule
// @Description Update or create a new rate limiting rule for the specified API key and model
// @Tags rate-limit
// @Accept json
// @Produce json
// @Param request body UpdateRuleReq true "Rate limiting rule update request"
// @Success 200 {object} UpdateRuleResp
// @Failure 400 {object} map[string]interface{} "Invalid request parameters"
// @Failure 500 {object} map[string]interface{} "Internal server error"
// @Router /v1/update_rule [post]
func UpdateRule(c *gin.Context) {
	startTime := time.Now()

	var req UpdateRuleReq
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Error("Invalid request parameters for update rule",
			logger.ErrorField(err),
			logger.String("key", req.Key),
		)
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request parameters",
			"details": err.Error(),
		})
		return
	}

	// Use default value if burst is not set
	if req.Burst == 0 {
		req.Burst = 50 // Default bucket capacity
		logger.Debug("Using default burst value", logger.Int64("burst", req.Burst))
	}

	// Validate parameters
	if req.RateLimit <= 0 {
		logger.Warn("Invalid rate limit value",
			logger.String("key", req.Key),
			logger.Int64("rate", req.RateLimit),
		)
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Rate limit must be greater than 0",
		})
		return
	}
	if req.Burst <= 0 {
		logger.Warn("Invalid burst value",
			logger.String("key", req.Key),
			logger.Int64("burst", req.Burst),
		)
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Burst must be greater than 0",
		})
		return
	}

	logger.Info("Updating rate limit rule",
		logger.String("key", req.Key),
		logger.Int64("rate", req.RateLimit),
		logger.Int64("burst", req.Burst),
		logger.String("client_ip", c.ClientIP()),
	)

	// Update rule to Redis
	err := limiter.SetRuleToRedis(c.Request.Context(), req.Key, req.RateLimit, req.Burst)
	if err != nil {
		logger.Error("Failed to update rate limit rule",
			logger.String("key", req.Key),
			logger.ErrorField(err),
		)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to update rate limit rule",
			"details": err.Error(),
		})
		return
	}

	resp := UpdateRuleResp{
		Status:  "success",
		Message: "Rate limit rule updated successfully",
	}

	duration := time.Since(startTime)
	logger.Info("Rate limit rule updated successfully",
		logger.String("key", req.Key),
		logger.Int64("rate", req.RateLimit),
		logger.Int64("burst", req.Burst),
		logger.Duration("duration", duration),
	)

	c.JSON(http.StatusOK, resp)
}

// GetStats gets monitoring statistics
// @Summary Get all monitoring statistics
// @Description Get comprehensive monitoring statistics for all rate limiting rules
// @Tags monitoring
// @Accept json
// @Produce json
// @Success 200 {object} StatsResp
// @Failure 500 {object} map[string]interface{} "Internal server error"
// @Router /v1/stats [get]
func GetStats(c *gin.Context) {
	startTime := time.Now()

	logger.Info("Getting stats request",
		logger.String("client_ip", c.ClientIP()),
		logger.String("user_agent", c.GetHeader("User-Agent")),
	)

	ctx := c.Request.Context()

	// Get all rules
	rules, err := redis.GetAllRules(ctx)
	if err != nil {
		logger.Error("Failed to get rules", logger.ErrorField(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get rules",
			"details": err.Error(),
		})
		return
	}

	// Get statistics
	stats := make(map[string]map[string]interface{})
	for key := range rules {
		stat, err := limiter.GetStats(c.Request.Context(), key)
		if err != nil {
			// Skip this key if getting statistics fails
			logger.Warn("Failed to get stats for key",
				logger.String("key", key),
				logger.ErrorField(err),
			)
			continue
		}
		stats[key] = stat
	}

	resp := StatsResp{
		Rules: rules,
		Stats: stats,
	}

	duration := time.Since(startTime)
	logger.Info("Stats retrieved successfully",
		logger.Int("rules_count", len(rules)),
		logger.Int("stats_count", len(stats)),
		logger.Duration("duration", duration),
	)

	c.JSON(http.StatusOK, resp)
}

// GetRuleStats gets statistics for specific rule
// @Summary Get specific rule statistics
// @Description Get monitoring statistics for a specific rate limiting key
// @Tags monitoring
// @Accept json
// @Produce json
// @Param key query string true "Rate limiting key"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{} "Missing required parameters"
// @Failure 500 {object} map[string]interface{} "Internal server error"
// @Router /v1/rule_stats [get]
func GetRuleStats(c *gin.Context) {
	startTime := time.Now()

	key := c.Query("key")

	if key == "" {
		logger.Warn("Missing required parameter for rule stats",
			logger.String("key", key),
		)
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "key is required",
		})
		return
	}

	logger.Info("Getting rule stats",
		logger.String("key", key),
		logger.String("client_ip", c.ClientIP()),
	)

	stats, err := limiter.GetStats(c.Request.Context(), key)
	if err != nil {
		logger.Error("Failed to get stats",
			logger.String("key", key),
			logger.ErrorField(err),
		)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get stats",
			"details": err.Error(),
		})
		return
	}

	duration := time.Since(startTime)
	logger.Info("Rule stats retrieved successfully",
		logger.String("key", key),
		logger.Duration("duration", duration),
	)

	c.JSON(http.StatusOK, gin.H{
		"key":   key,
		"stats": stats,
	})
}
