package health

import (
	"encoding/json"
	"net/http"
	"sync/atomic"
	"time"

	"go.uber.org/zap"
)

// Checker provides health check endpoints
type Checker struct {
	logger    *zap.Logger
	startTime time.Time
	ready     atomic.Bool
}

// HealthResponse represents the health check response
type HealthResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
	Uptime    string    `json:"uptime,omitempty"`
	Version   string    `json:"version,omitempty"`
}

// NewChecker creates a new health checker
func NewChecker(logger *zap.Logger) *Checker {
	checker := &Checker{
		logger:    logger,
		startTime: time.Now(),
	}
	// Set ready to true by default
	checker.ready.Store(true)
	return checker
}

// Health returns the overall health status
func (c *Checker) Health(w http.ResponseWriter, r *http.Request) {
	uptime := time.Since(c.startTime)

	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now(),
		Uptime:    uptime.String(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// Ready returns readiness status (Kubernetes readiness probe)
func (c *Checker) Ready(w http.ResponseWriter, r *http.Request) {
	if !c.ready.Load() {
		response := HealthResponse{
			Status:    "not ready",
			Timestamp: time.Now(),
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(response)
		return
	}

	response := HealthResponse{
		Status:    "ready",
		Timestamp: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// Live returns liveness status (Kubernetes liveness probe)
func (c *Checker) Live(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:    "alive",
		Timestamp: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// SetReady sets the readiness status
func (c *Checker) SetReady(ready bool) {
	c.ready.Store(ready)
	c.logger.Info("Readiness status changed", zap.Bool("ready", ready))
}
