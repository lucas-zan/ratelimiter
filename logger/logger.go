package logger

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/your-org/rate-limiter/config"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"gopkg.in/natefinch/lumberjack.v2"
)

var Logger *zap.Logger

// InitLogger 初始化日志系统
func InitLogger(cfg *config.LogConfig) error {
	// 创建日志目录
	if cfg.Output == "file" {
		if err := os.MkdirAll(cfg.FilePath, 0755); err != nil {
			return fmt.Errorf("failed to create log directory: %w", err)
		}
	}

	// Set log level
	level, err := zapcore.ParseLevel(cfg.Level)
	if err != nil {
		return fmt.Errorf("invalid log level: %w", err)
	}

	// 创建编码器配置
	encoderConfig := zap.NewProductionEncoderConfig()
	encoderConfig.TimeKey = "timestamp"
	encoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	encoderConfig.EncodeLevel = zapcore.CapitalLevelEncoder
	encoderConfig.EncodeCaller = zapcore.ShortCallerEncoder

	// 选择编码器
	var encoder zapcore.Encoder
	if cfg.Format == "json" {
		encoder = zapcore.NewJSONEncoder(encoderConfig)
	} else {
		encoder = zapcore.NewConsoleEncoder(encoderConfig)
	}

	// 创建输出
	var writeSyncer zapcore.WriteSyncer
	if cfg.Output == "file" {
		// 文件输出，支持日志轮转
		writer := &lumberjack.Logger{
			Filename:   filepath.Join(cfg.FilePath, "rate-limiter.log"),
			MaxSize:    cfg.MaxSize, // MB
			MaxBackups: cfg.MaxBackups,
			MaxAge:     cfg.MaxAge, // days
			Compress:   cfg.Compress,
		}
		writeSyncer = zapcore.AddSync(writer)
	} else {
		// 标准输出
		writeSyncer = zapcore.AddSync(os.Stdout)
	}

	// 创建核心
	core := zapcore.NewCore(encoder, writeSyncer, level)

	// 创建日志器
	Logger = zap.New(core, zap.AddCaller(), zap.AddStacktrace(zapcore.ErrorLevel))

	return nil
}

// Sync 同步日志缓冲区
func Sync() {
	if Logger != nil {
		Logger.Sync()
	}
}

// 提供便捷的日志方法
func Debug(msg string, fields ...zap.Field) {
	if Logger != nil {
		Logger.Debug(msg, fields...)
	}
}

func Info(msg string, fields ...zap.Field) {
	if Logger != nil {
		Logger.Info(msg, fields...)
	}
}

func Warn(msg string, fields ...zap.Field) {
	if Logger != nil {
		Logger.Warn(msg, fields...)
	}
}

func Error(msg string, fields ...zap.Field) {
	if Logger != nil {
		Logger.Error(msg, fields...)
	}
}

func Fatal(msg string, fields ...zap.Field) {
	if Logger != nil {
		Logger.Fatal(msg, fields...)
	}
}

// 提供便捷的字段创建方法
func String(key, val string) zap.Field {
	return zap.String(key, val)
}

func Int(key string, val int) zap.Field {
	return zap.Int(key, val)
}

func Int64(key string, val int64) zap.Field {
	return zap.Int64(key, val)
}

func Bool(key string, val bool) zap.Field {
	return zap.Bool(key, val)
}

func Duration(key string, val time.Duration) zap.Field {
	return zap.Duration(key, val)
}

func ErrorField(err error) zap.Field {
	return zap.Error(err)
}

func Any(key string, val interface{}) zap.Field {
	return zap.Any(key, val)
}
