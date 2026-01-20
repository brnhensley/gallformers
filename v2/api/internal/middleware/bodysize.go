package middleware

import (
	"net/http"
)

// MaxBodySize is a middleware that limits the size of request bodies.
// The default limit is 1MB (1,048,576 bytes).
func MaxBodySize(next http.Handler) http.Handler {
	return MaxBodySizeWithLimit(1 << 20)(next) // 1MB
}

// MaxBodySizeWithLimit creates a MaxBodySize middleware with a custom limit.
// The limit is specified in bytes.
func MaxBodySizeWithLimit(limit int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			r.Body = http.MaxBytesReader(w, r.Body, limit)
			next.ServeHTTP(w, r)
		})
	}
}
