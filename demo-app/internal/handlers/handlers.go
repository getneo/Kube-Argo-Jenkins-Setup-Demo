package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"runtime"
	"time"

	"demo-app/internal/config"

	"go.uber.org/zap"
)

// AppHandler handles application endpoints
type AppHandler struct {
	logger *zap.Logger
	config *config.Config
}

// NewAppHandler creates a new application handler
func NewAppHandler(logger *zap.Logger, cfg *config.Config) *AppHandler {
	return &AppHandler{
		logger: logger,
		config: cfg,
	}
}

// HomeResponse represents the home endpoint response
type HomeResponse struct {
	Message     string    `json:"message"`
	Application string    `json:"application"`
	Version     string    `json:"version"`
	Environment string    `json:"environment"`
	Timestamp   time.Time `json:"timestamp"`
}

// Home handles the root endpoint
func (h *AppHandler) Home(w http.ResponseWriter, r *http.Request) {
	response := HomeResponse{
		Message:     "Welcome to Demo Application",
		Application: h.config.AppName,
		Version:     h.config.Version,
		Environment: h.config.Environment,
		Timestamp:   time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// InfoResponse represents the info endpoint response
type InfoResponse struct {
	Application string            `json:"application"`
	Version     string            `json:"version"`
	Environment string            `json:"environment"`
	GoVersion   string            `json:"go_version"`
	Platform    string            `json:"platform"`
	Timestamp   time.Time         `json:"timestamp"`
	Endpoints   map[string]string `json:"endpoints"`
}

// Info returns application information
func (h *AppHandler) Info(w http.ResponseWriter, r *http.Request) {
	response := InfoResponse{
		Application: h.config.AppName,
		Version:     h.config.Version,
		Environment: h.config.Environment,
		GoVersion:   runtime.Version(),
		Platform:    fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH),
		Timestamp:   time.Now(),
		Endpoints: map[string]string{
			"health":  "/health",
			"ready":   "/health/ready",
			"live":    "/health/live",
			"metrics": "/metrics",
			"info":    "/api/info",
			"echo":    "/api/echo",
			"version": "/api/version",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// EchoRequest represents the echo endpoint request
type EchoRequest struct {
	Message string `json:"message"`
}

// EchoResponse represents the echo endpoint response
type EchoResponse struct {
	Echo      string    `json:"echo"`
	Timestamp time.Time `json:"timestamp"`
	RequestID string    `json:"request_id,omitempty"`
}

// Echo echoes back the received message
func (h *AppHandler) Echo(w http.ResponseWriter, r *http.Request) {
	var req EchoRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Error("Failed to decode request", zap.Error(err))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "Invalid request body",
		})
		return
	}

	requestID, _ := r.Context().Value("request_id").(string)

	response := EchoResponse{
		Echo:      req.Message,
		Timestamp: time.Now(),
		RequestID: requestID,
	}

	h.logger.Info("Echo request processed",
		zap.String("message", req.Message),
		zap.String("request_id", requestID),
	)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// VersionResponse represents the version endpoint response
type VersionResponse struct {
	Version   string    `json:"version"`
	BuildTime string    `json:"build_time,omitempty"`
	GitCommit string    `json:"git_commit,omitempty"`
	Timestamp time.Time `json:"timestamp"`
}

// Version returns the application version
func (h *AppHandler) Version(w http.ResponseWriter, r *http.Request) {
	response := VersionResponse{
		Version:   h.config.Version,
		BuildTime: "2024-01-01T00:00:00Z", // This would be set during build
		GitCommit: "abc123",               // This would be set during build
		Timestamp: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// Made with Bob
