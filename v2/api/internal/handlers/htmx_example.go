package handlers

import (
	"math/rand"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jeffdc/gallformers/v2/api/internal/views/pages"
)

// HTMXExampleHandler demonstrates HTMX patterns for server-rendered pages.
// This serves as a reference implementation for converting pages to HTMX.
type HTMXExampleHandler struct{}

// NewHTMXExampleHandler creates a new HTMX example handler.
func NewHTMXExampleHandler() *HTMXExampleHandler {
	return &HTMXExampleHandler{}
}

// RegisterRoutes registers the HTMX example routes.
// These routes are separate from the API routes and serve HTML.
func (h *HTMXExampleHandler) RegisterRoutes(r chi.Router) {
	r.Route("/htmx/example", func(r chi.Router) {
		r.Get("/", h.Page)
		r.Get("/refresh", h.RefreshItems)
	})
}

// Page renders the example page.
// If this is an HTMX request (partial update), it returns just the content.
// Otherwise, it returns the full page with layout.
func (h *HTMXExampleHandler) Page(w http.ResponseWriter, r *http.Request) {
	data := pages.ExampleData{
		Title:   "HTMX Example",
		Message: "This page demonstrates HTMX patterns for gallformers.",
		Items:   generateItems(),
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")

	// Check if this is an HTMX request
	if isHTMXRequest(r) {
		// Return just the content for partial updates
		pages.ExampleContent(data).Render(r.Context(), w)
	} else {
		// Return full page with layout
		pages.ExamplePage(data).Render(r.Context(), w)
	}
}

// RefreshItems returns just the items list for partial HTMX update.
// This demonstrates how to create endpoints for specific partial updates.
func (h *HTMXExampleHandler) RefreshItems(w http.ResponseWriter, r *http.Request) {
	items := generateItems()

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	pages.ItemsList(items).Render(r.Context(), w)
}

// isHTMXRequest checks if the request is an HTMX request by looking for
// the HX-Request header that HTMX sends with every request.
func isHTMXRequest(r *http.Request) bool {
	return r.Header.Get("HX-Request") == "true"
}

// isHTMXBoosted checks if the request is from an hx-boost link.
// Boosted requests may want different handling than regular HTMX requests.
func isHTMXBoosted(r *http.Request) bool {
	return r.Header.Get("HX-Boosted") == "true"
}

// getHTMXTrigger returns the ID of the element that triggered the request.
func getHTMXTrigger(r *http.Request) string {
	return r.Header.Get("HX-Trigger")
}

// getHTMXTarget returns the ID of the target element for the response.
func getHTMXTarget(r *http.Request) string {
	return r.Header.Get("HX-Target")
}

// setHTMXPushURL sets the URL to push to the browser history.
func setHTMXPushURL(w http.ResponseWriter, url string) {
	w.Header().Set("HX-Push-Url", url)
}

// setHTMXRedirect tells HTMX to do a client-side redirect.
func setHTMXRedirect(w http.ResponseWriter, url string) {
	w.Header().Set("HX-Redirect", url)
}

// setHTMXRefresh tells HTMX to refresh the page.
func setHTMXRefresh(w http.ResponseWriter) {
	w.Header().Set("HX-Refresh", "true")
}

// setHTMXRetarget changes the target element for the response.
func setHTMXRetarget(w http.ResponseWriter, target string) {
	w.Header().Set("HX-Retarget", target)
}

// setHTMXReswap changes the swap method for the response.
func setHTMXReswap(w http.ResponseWriter, swap string) {
	w.Header().Set("HX-Reswap", swap)
}

// generateItems creates a random list of items for demonstration.
func generateItems() []string {
	allItems := []string{
		"Oak Apple Gall",
		"Jumping Oak Gall",
		"Hedgehog Gall",
		"Wool Sower Gall",
		"Horned Oak Gall",
		"Bullet Gall",
		"Spiny Rose Gall",
		"Goldenrod Ball Gall",
		"Willow Pine Cone Gall",
	}

	// Shuffle and take a random subset
	rand.Shuffle(len(allItems), func(i, j int) {
		allItems[i], allItems[j] = allItems[j], allItems[i]
	})

	count := rand.Intn(5) + 3 // 3-7 items
	return allItems[:count]
}
