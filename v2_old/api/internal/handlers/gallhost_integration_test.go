//go:build integration
// +build integration

package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// Integration tests for GallHost handlers using the real database.
// Run with: go test -tags=integration ./internal/handlers/...

func TestIntegration_ListGallHosts_ReturnsHostsForGall(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	// First, get a gall that has hosts
	gallHandler := NewGallHandler(queries)
	listReq := httptest.NewRequest(http.MethodGet, "/api/v2/galls?limit=1", nil)
	listRec := httptest.NewRecorder()
	gallHandler.List(listRec, listReq)

	var gallResponse GallListResponse
	json.NewDecoder(listRec.Body).Decode(&gallResponse)

	if len(gallResponse.Data) == 0 {
		t.Fatal("no galls in database")
	}

	gallID := gallResponse.Data[0].ID

	// Now test the gall-hosts endpoint
	handler := NewGallHostHandler(queries)
	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid="+int64ToStr(gallID), nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response GallHostListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Response should have valid structure
	if response.Total < 0 {
		t.Error("total should not be negative")
	}

	// Verify data array structure
	for _, host := range response.Data {
		if host.ID <= 0 {
			t.Error("expected positive host relation ID")
		}
		if host.GallSpeciesID != gallID {
			t.Errorf("expected gall_species_id %d, got %d", gallID, host.GallSpeciesID)
		}
		if host.HostSpeciesID <= 0 {
			t.Error("expected positive host_species_id")
		}
	}

	t.Logf("Gall %d has %d hosts", gallID, response.Total)
}

func TestIntegration_ListGallHosts_MissingGallID(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewGallHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestIntegration_ListGallHosts_InvalidGallID(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewGallHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid=invalid", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestIntegration_ListGallHosts_NonExistentGall(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewGallHostHandler(queries)

	// Use a gall ID that doesn't exist
	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid=999999999", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response GallHostListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Should return empty list
	if response.Total != 0 {
		t.Errorf("expected total 0 for non-existent gall, got %d", response.Total)
	}
	if len(response.Data) != 0 {
		t.Errorf("expected empty data for non-existent gall, got %d items", len(response.Data))
	}
}

func TestIntegration_GallHostResponseStructure(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	// Find a gall that has hosts
	gallHandler := NewGallHandler(queries)

	// Get galls that likely have hosts (common species)
	listReq := httptest.NewRequest(http.MethodGet, "/api/v2/galls?q=Andricus&limit=10", nil)
	listRec := httptest.NewRecorder()
	gallHandler.List(listRec, listReq)

	var gallResponse GallListResponse
	json.NewDecoder(listRec.Body).Decode(&gallResponse)

	if len(gallResponse.Data) == 0 {
		t.Skip("no Andricus galls found in database")
	}

	// Try each gall until we find one with hosts
	handler := NewGallHostHandler(queries)
	var foundHosts bool

	for _, gall := range gallResponse.Data {
		req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid="+int64ToStr(gall.ID), nil)
		rec := httptest.NewRecorder()
		handler.List(rec, req)

		var response GallHostListResponse
		json.NewDecoder(rec.Body).Decode(&response)

		if response.Total > 0 {
			foundHosts = true

			// Verify structure of first host
			host := response.Data[0]
			if host.ID <= 0 {
				t.Error("host relation ID should be positive")
			}
			if host.GallSpeciesID != gall.ID {
				t.Errorf("gall_species_id mismatch: expected %d, got %d", gall.ID, host.GallSpeciesID)
			}
			if host.HostSpeciesID <= 0 {
				t.Error("host_species_id should be positive")
			}
			if host.HostName == "" {
				t.Error("host_name should not be empty")
			}

			t.Logf("Found gall %d (%s) with %d hosts, first host: %s",
				gall.ID, gall.Name, response.Total, host.HostName)
			break
		}
	}

	if !foundHosts {
		t.Skip("no Andricus galls with hosts found")
	}
}
