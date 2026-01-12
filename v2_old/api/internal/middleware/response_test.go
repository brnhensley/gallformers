package middleware

import (
	"encoding/json"
	"net/http/httptest"
	"testing"
)

func TestRespondJSON(t *testing.T) {
	rec := httptest.NewRecorder()
	data := map[string]string{"status": "ok"}

	RespondJSON(rec, 200, data)

	if rec.Code != 200 {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
	if rec.Header().Get("Content-Type") != "application/json" {
		t.Errorf("expected Content-Type application/json, got %s", rec.Header().Get("Content-Type"))
	}

	var result map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&result); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if result["status"] != "ok" {
		t.Errorf("expected status ok, got %s", result["status"])
	}
}

func TestRespondJSON_NilData(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondJSON(rec, 204, nil)

	if rec.Code != 204 {
		t.Errorf("expected status 204, got %d", rec.Code)
	}
}

func TestRespondError(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondError(rec, 404, "NOT_FOUND", "Resource not found")

	if rec.Code != 404 {
		t.Errorf("expected status 404, got %d", rec.Code)
	}

	var result ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&result); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if result.Error.Code != "NOT_FOUND" {
		t.Errorf("expected code NOT_FOUND, got %s", result.Error.Code)
	}
	if result.Error.Message != "Resource not found" {
		t.Errorf("expected message 'Resource not found', got %s", result.Error.Message)
	}
}

func TestRespondNotFound(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondNotFound(rec, "Gall not found")

	if rec.Code != 404 {
		t.Errorf("expected status 404, got %d", rec.Code)
	}

	var result ErrorResponse
	json.NewDecoder(rec.Body).Decode(&result)
	if result.Error.Code != "NOT_FOUND" {
		t.Errorf("expected code NOT_FOUND, got %s", result.Error.Code)
	}
}

func TestRespondBadRequest(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondBadRequest(rec, "Invalid input")

	if rec.Code != 400 {
		t.Errorf("expected status 400, got %d", rec.Code)
	}

	var result ErrorResponse
	json.NewDecoder(rec.Body).Decode(&result)
	if result.Error.Code != "BAD_REQUEST" {
		t.Errorf("expected code BAD_REQUEST, got %s", result.Error.Code)
	}
}

func TestRespondUnauthorized(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondUnauthorized(rec, "No token provided")

	if rec.Code != 401 {
		t.Errorf("expected status 401, got %d", rec.Code)
	}

	var result ErrorResponse
	json.NewDecoder(rec.Body).Decode(&result)
	if result.Error.Code != "UNAUTHORIZED" {
		t.Errorf("expected code UNAUTHORIZED, got %s", result.Error.Code)
	}
}

func TestRespondForbidden(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondForbidden(rec, "Admin access required")

	if rec.Code != 403 {
		t.Errorf("expected status 403, got %d", rec.Code)
	}

	var result ErrorResponse
	json.NewDecoder(rec.Body).Decode(&result)
	if result.Error.Code != "FORBIDDEN" {
		t.Errorf("expected code FORBIDDEN, got %s", result.Error.Code)
	}
}

func TestRespondInternalError(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondInternalError(rec, "Something went wrong")

	if rec.Code != 500 {
		t.Errorf("expected status 500, got %d", rec.Code)
	}

	var result ErrorResponse
	json.NewDecoder(rec.Body).Decode(&result)
	if result.Error.Code != "INTERNAL_ERROR" {
		t.Errorf("expected code INTERNAL_ERROR, got %s", result.Error.Code)
	}
}

func TestRespondServiceUnavailable(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondServiceUnavailable(rec, "Database is busy")

	if rec.Code != 503 {
		t.Errorf("expected status 503, got %d", rec.Code)
	}

	var result ErrorResponse
	json.NewDecoder(rec.Body).Decode(&result)
	if result.Error.Code != "SERVICE_UNAVAILABLE" {
		t.Errorf("expected code SERVICE_UNAVAILABLE, got %s", result.Error.Code)
	}
}

func TestRespondCreated(t *testing.T) {
	rec := httptest.NewRecorder()
	data := map[string]int{"id": 123}

	RespondCreated(rec, data)

	if rec.Code != 201 {
		t.Errorf("expected status 201, got %d", rec.Code)
	}

	var result map[string]int
	json.NewDecoder(rec.Body).Decode(&result)
	if result["id"] != 123 {
		t.Errorf("expected id 123, got %d", result["id"])
	}
}

func TestRespondOK(t *testing.T) {
	rec := httptest.NewRecorder()
	data := map[string]string{"message": "success"}

	RespondOK(rec, data)

	if rec.Code != 200 {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}

func TestRespondNoContent(t *testing.T) {
	rec := httptest.NewRecorder()

	RespondNoContent(rec)

	if rec.Code != 204 {
		t.Errorf("expected status 204, got %d", rec.Code)
	}
	if rec.Body.Len() != 0 {
		t.Error("expected empty body")
	}
}
