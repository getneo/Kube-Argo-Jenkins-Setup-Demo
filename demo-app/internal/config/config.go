package config

import (
	"os"
	"strconv"
)

// Config holds application configuration
type Config struct {
	AppName     string
	Version     string
	Environment string
	Port        int
	LogLevel    string
}

// Load reads configuration from environment variables with defaults
func Load() *Config {
	return &Config{
		AppName:     getEnv("APP_NAME", "demo-app"),
		Version:     getEnv("APP_VERSION", "1.0.0"),
		Environment: getEnv("ENVIRONMENT", "development"),
		Port:        getEnvAsInt("PORT", 8080),
		LogLevel:    getEnv("LOG_LEVEL", "info"),
	}
}

// getEnv reads an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvAsInt reads an environment variable as integer or returns a default value
func getEnvAsInt(key string, defaultValue int) int {
	valueStr := os.Getenv(key)
	if value, err := strconv.Atoi(valueStr); err == nil {
		return value
	}
	return defaultValue
}

// Made with Bob
