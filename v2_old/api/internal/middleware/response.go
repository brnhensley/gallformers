package middleware

import (
	"encoding/json"
	"net/http"
)

// ErrorResponse represents a standardized error response.
type ErrorResponse struct {
	Error ErrorDetail `json:"error"`
}

// ErrorDetail contains the error code and message.
type ErrorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// RespondJSON sends a JSON response with the given status code and data.
func RespondJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if data != nil {
		json.NewEncoder(w).Encode(data)
	}
}

// RespondError sends a standardized JSON error response.
func RespondError(w http.ResponseWriter, status int, code, message string) {
	RespondJSON(w, status, ErrorResponse{
		Error: ErrorDetail{
			Code:    code,
			Message: message,
		},
	})
}

// RespondNotFound sends a 404 Not Found error response.
func RespondNotFound(w http.ResponseWriter, message string) {
	RespondError(w, http.StatusNotFound, "NOT_FOUND", message)
}

// RespondBadRequest sends a 400 Bad Request error response.
func RespondBadRequest(w http.ResponseWriter, message string) {
	RespondError(w, http.StatusBadRequest, "BAD_REQUEST", message)
}

// RespondUnauthorized sends a 401 Unauthorized error response.
func RespondUnauthorized(w http.ResponseWriter, message string) {
	RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", message)
}

// RespondForbidden sends a 403 Forbidden error response.
func RespondForbidden(w http.ResponseWriter, message string) {
	RespondError(w, http.StatusForbidden, "FORBIDDEN", message)
}

// RespondInternalError sends a 500 Internal Server Error response.
func RespondInternalError(w http.ResponseWriter, message string) {
	RespondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", message)
}

// RespondServiceUnavailable sends a 503 Service Unavailable error response.
func RespondServiceUnavailable(w http.ResponseWriter, message string) {
	RespondError(w, http.StatusServiceUnavailable, "SERVICE_UNAVAILABLE", message)
}

// RespondCreated sends a 201 Created response with the given data.
func RespondCreated(w http.ResponseWriter, data any) {
	RespondJSON(w, http.StatusCreated, data)
}

// RespondOK sends a 200 OK response with the given data.
func RespondOK(w http.ResponseWriter, data any) {
	RespondJSON(w, http.StatusOK, data)
}

// RespondNoContent sends a 204 No Content response.
func RespondNoContent(w http.ResponseWriter) {
	w.WriteHeader(http.StatusNoContent)
}
