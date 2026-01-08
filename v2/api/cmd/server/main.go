package main

import (
	"context"
	"database/sql"
	"embed"
	"encoding/json"
	"io/fs"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	"github.com/jeffdc/gallformers/v2/api/internal/handlers"
	mw "github.com/jeffdc/gallformers/v2/api/internal/middleware"
	_ "github.com/mattn/go-sqlite3"
)

//go:embed static/*
var staticFiles embed.FS

//go:embed api/openapi.yaml
var openapiSpec []byte

var (
	sqlDB   *sql.DB
	queries *db.Queries
)

func main() {
	// Initialize logger
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	// Initialize database connection
	dbPath := os.Getenv("DATABASE_PATH")
	if dbPath == "" {
		dbPath = "../prisma/gallformers.sqlite"
	}

	var err error
	sqlDB, err = sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_busy_timeout=5000")
	if err != nil {
		slog.Error("failed to open database", "error", err)
		os.Exit(1)
	}
	defer sqlDB.Close()

	// Initialize sqlc queries
	queries = db.New(sqlDB)

	// Test the connection
	if err := sqlDB.Ping(); err != nil {
		slog.Warn("database ping failed at startup", "error", err)
	}

	// Initialize Auth0
	if err := mw.InitAuth0(); err != nil {
		slog.Warn("Auth0 initialization failed - auth endpoints will not work", "error", err)
	}

	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.RequestID)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	// Health endpoint
	r.Get("/health", healthHandler)

	// OpenAPI documentation
	r.Get("/api/docs", swaggerUIHandler)
	r.Get("/api/docs/openapi.yaml", openapiSpecHandler)

	// API v2 routes
	r.Route("/api/v2", func(r chi.Router) {
		// Auth endpoints
		r.Route("/auth", func(r chi.Router) {
			r.Get("/callback", handlers.AuthCallbackHandler())
			r.Post("/refresh", handlers.RefreshHandler())
			r.Post("/logout", handlers.LogoutHandler())
		})

		// Current user endpoint (requires auth)
		r.With(mw.RequireAuth).Get("/me", handlers.MeHandler())

		// Species endpoints
		r.Route("/species", func(r chi.Router) {
			r.Get("/", handlers.ListSpecies(queries))
			r.Get("/{id}", handlers.GetSpecies(queries))
		})

		// Gall endpoints
		gallHandler := handlers.NewGallHandler(queries)
		gallHandler.RegisterRoutes(r)
	})

	// Static file serving from embedded filesystem
	staticFS, err := fs.Sub(staticFiles, "static")
	if err != nil {
		slog.Error("failed to create static filesystem", "error", err)
		os.Exit(1)
	}
	fileServer := http.FileServer(http.FS(staticFS))
	r.Handle("/*", fileServer)

	// Get port from env or default to 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	// Start server in goroutine
	go func() {
		slog.Info("starting server", "port", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	// Wait for shutdown signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	slog.Info("shutting down server...")

	// Graceful shutdown with 30s timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("server shutdown error", "error", err)
	}

	slog.Info("server stopped")
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Check database connectivity using sqlc-generated query
	_, err := queries.HealthCheck(r.Context())
	if err != nil {
		slog.Warn("health check: database unavailable", "error", err)
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status":   "degraded",
			"database": "unavailable",
		})
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":   "ok",
		"database": "connected",
	})
}

func openapiSpecHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/yaml")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.Write(openapiSpec)
}

func swaggerUIHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gallformers API Documentation</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">
    <style>
        body { margin: 0; padding: 0; }
        .swagger-ui .topbar { display: none; }
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script>
        window.onload = function() {
            SwaggerUIBundle({
                url: "/api/docs/openapi.yaml",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIBundle.SwaggerUIStandalonePreset
                ],
                layout: "BaseLayout"
            });
        };
    </script>
</body>
</html>`
	w.Write([]byte(html))
}
