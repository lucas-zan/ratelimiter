package config

import (
	"time"
)

type Config struct {
	Server  ServerConfig  `yaml:"server"`
	Redis   RedisConfig   `yaml:"redis"`
	Limiter LimiterConfig `yaml:"limiter"`
	Log     LogConfig     `yaml:"log"`
}

type ServerConfig struct {
	Port string `yaml:"port" default:":8080"`
}

type RedisConfig struct {
	Addr         string        `yaml:"addr" default:"localhost:6379"`
	Password     string        `yaml:"password"`
	DB           int           `yaml:"db" default:"0"`
	PoolSize     int           `yaml:"pool_size" default:"10"`
	MinIdleConns int           `yaml:"min_idle_conns" default:"5"`
	DialTimeout  time.Duration `yaml:"dial_timeout" default:"5s"`
	ReadTimeout  time.Duration `yaml:"read_timeout" default:"3s"`
	WriteTimeout time.Duration `yaml:"write_timeout" default:"3s"`
}

type LimiterConfig struct {
	DefaultRate  int64 `yaml:"default_rate" default:"10"`  // 默认每秒令牌生成速率
	DefaultBurst int64 `yaml:"default_burst" default:"50"` // 默认桶容量
}

type LogConfig struct {
	Level      string `yaml:"level" default:"info"`     // 日志级别: debug, info, warn, error
	Format     string `yaml:"format" default:"json"`    // 日志格式: json, console
	Output     string `yaml:"output" default:"stdout"`  // 输出位置: stdout, file
	FilePath   string `yaml:"file_path" default:"logs"` // 日志文件路径
	MaxSize    int    `yaml:"max_size" default:"100"`   // 单个日志文件最大大小(MB)
	MaxBackups int    `yaml:"max_backups" default:"10"` // 最大备份文件数
	MaxAge     int    `yaml:"max_age" default:"30"`     // 日志文件保留天数
	Compress   bool   `yaml:"compress" default:"true"`  // 是否压缩旧日志文件
}
