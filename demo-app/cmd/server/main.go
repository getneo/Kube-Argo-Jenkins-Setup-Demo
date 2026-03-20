package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"demo-app/internal/config"
	"demo-app/internal/handlers"
	"demo-app/internal/middleware"
	"demo-app/pkg/health"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.uber.org/zap"
)

func main() {
	// Initialize logger
	logger, err := zap.NewProduction()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize logger: %v\n", err)
		os.Exit(1)
	}
	defer logger.Sync()

	// Load configuration
	cfg := config.Load()
	logger.Info("Configuration loaded",
		zap.String("app_name", cfg.AppName),
		zap.String("version", cfg.Version),
		zap.String("environment", cfg.Environment),
		zap.Int("port", cfg.Port),
	)

	// Initialize health checker
	healthChecker := health.NewChecker(logger)

	// Create router
	router := mux.NewRouter()

	// Apply middleware
	router.Use(middleware.RequestLogger(logger))
	router.Use(middleware.RequestID)
	router.Use(middleware.Recovery(logger))
	router.Use(middleware.CORS)

	// Initialize handlers
	appHandler := handlers.NewAppHandler(logger, cfg)

	// Register routes
	// Health endpoints
	router.HandleFunc("/health", healthChecker.Health).Methods("GET")
	router.HandleFunc("/health/ready", healthChecker.Ready).Methods("GET")
	router.HandleFunc("/health/live", healthChecker.Live).Methods("GET")

	// Metrics endpoint
	router.Handle("/metrics", promhttp.Handler()).Methods("GET")

	// Application endpoints
	router.HandleFunc("/", appHandler.Home).Methods("GET")
	router.HandleFunc("/api/info", appHandler.Info).Methods("GET")
	router.HandleFunc("/api/echo", appHandler.Echo).Methods("POST")
	router.HandleFunc("/api/version", appHandler.Version).Methods("GET")

	// Create HTTP server
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		logger.Info("Starting HTTP server",
			zap.String("address", srv.Addr),
		)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Failed to start server", zap.Error(err))
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown", zap.Error(err))
	}

	logger.Info("Server exited gracefully")
}

// Made with Bob
