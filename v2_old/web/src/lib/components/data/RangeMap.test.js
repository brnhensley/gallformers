import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import RangeMap from './RangeMap.svelte';

// Mock d3-geo to avoid complex SVG path calculations in tests
vi.mock('d3-geo', () => ({
	geoPath: () => () => 'M0,0L10,10Z',
	geoConicEqualArea: () => ({
		center: () => ({
			parallels: () => ({
				rotate: () => ({
					scale: () => ({
						translate: () => ({})
					})
				})
			})
		})
	})
}));

// Mock topojson-client
vi.mock('topojson-client', () => ({
	feature: () => ({
		features: [
			{
				type: 'Feature',
				properties: { name: 'California', postal: 'CA', iso_a2: 'US' },
				geometry: { type: 'Polygon', coordinates: [] }
			},
			{
				type: 'Feature',
				properties: { name: 'Texas', postal: 'TX', iso_a2: 'US' },
				geometry: { type: 'Polygon', coordinates: [] }
			},
			{
				type: 'Feature',
				properties: { name: 'Ontario', postal: 'ON', iso_a2: 'CA' },
				geometry: { type: 'Polygon', coordinates: [] }
			}
		]
	})
}));

// Mock fetch to return topology data
const mockTopology = { objects: { ne_10m_admin_1_states_provinces: {} } };

describe('RangeMap', () => {
	beforeEach(() => {
		vi.clearAllMocks();
		global.fetch = vi.fn(() =>
			Promise.resolve({
				ok: true,
				json: () => Promise.resolve(mockTopology)
			})
		);
	});

	// Helper to wait for loading to complete
	async function waitForMapLoad() {
		await waitFor(() => {
			expect(screen.queryByText('Loading map...')).not.toBeInTheDocument();
		});
	}

	it('shows loading state initially', () => {
		render(RangeMap, {
			props: {
				inRange: new Set()
			}
		});

		expect(screen.getByText('Loading map...')).toBeInTheDocument();
	});

	it('renders SVG with correct viewBox after loading', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set()
			}
		});

		await waitForMapLoad();

		const svg = container.querySelector('svg[role="img"]');
		expect(svg).toBeInTheDocument();
		expect(svg).toHaveAttribute('viewBox', '0 0 800 600');
	});

	it('renders path elements for each region', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set()
			}
		});

		await waitFor(() => {
			const paths = container.querySelectorAll('path');
			expect(paths.length).toBe(3); // CA, TX, ON from mock
		});
	});

	it('fills in-range regions with green', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(['CA'])
			}
		});

		await waitFor(() => {
			const paths = container.querySelectorAll('path');
			// Find CA path (first one in mock)
			const caPath = paths[0];
			expect(caPath).toHaveAttribute('fill', '#228B22'); // ForestGreen
		});
	});

	it('fills excluded regions with coral', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				excludedRange: new Set(['TX'])
			}
		});

		await waitFor(() => {
			const paths = container.querySelectorAll('path');
			// Find TX path (second one in mock)
			const txPath = paths[1];
			expect(txPath).toHaveAttribute('fill', '#F08080'); // LightCoral
		});
	});

	it('fills unselected regions with white', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set()
			}
		});

		await waitFor(() => {
			const paths = container.querySelectorAll('path');
			const onPath = paths[2]; // Ontario
			expect(onPath).toHaveAttribute('fill', '#FFFFFF');
		});
	});

	it('does not call onToggle when not editable (clicking opens modal instead)', async () => {
		const mockToggle = vi.fn();
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: false,
				onToggle: mockToggle
			}
		});

		await waitForMapLoad();

		await waitFor(() => {
			expect(container.querySelectorAll('path').length).toBe(3);
		});

		// Clicking the map opens the modal, not toggle
		expect(mockToggle).not.toHaveBeenCalled();
	});

	it('opens modal when clicking on non-editable map', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(['CA']),
				editable: false
			}
		});

		await waitForMapLoad();

		await waitFor(() => {
			expect(container.querySelectorAll('path').length).toBe(3);
		});

		// Click the map container to open modal
		const mapContainer = container.querySelector('[role="button"]');
		await fireEvent.click(mapContainer);

		// Modal should now be visible
		expect(screen.getByRole('dialog')).toBeInTheDocument();
		expect(screen.getByText('Drag to pan, scroll to zoom')).toBeInTheDocument();
	});

	it('closes modal when clicking close button', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(['CA']),
				editable: false
			}
		});

		await waitForMapLoad();

		await waitFor(() => {
			expect(container.querySelectorAll('path').length).toBe(3);
		});

		// Open modal
		const mapContainer = container.querySelector('[role="button"]');
		await fireEvent.click(mapContainer);

		expect(screen.getByRole('dialog')).toBeInTheDocument();

		// Click close button
		const closeButton = screen.getByLabelText('Close modal');
		await fireEvent.click(closeButton);

		// Modal should be closed
		expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
	});

	it('shows "Click to expand" hint on non-editable maps', async () => {
		render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: false
			}
		});

		await waitFor(() => {
			expect(screen.getByText('Click to expand')).toBeInTheDocument();
		});
	});

	it('does not show "Click to expand" hint on editable maps', async () => {
		render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: true
			}
		});

		await waitFor(() => {
			expect(screen.queryByText('Click to expand')).not.toBeInTheDocument();
		});
	});

	it('calls onToggle with postal code when editable and clicked', async () => {
		const mockToggle = vi.fn();
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: true,
				onToggle: mockToggle
			}
		});

		await waitFor(() => {
			expect(container.querySelectorAll('path').length).toBe(3);
		});

		const paths = container.querySelectorAll('path');
		await fireEvent.click(paths[0]); // CA

		expect(mockToggle).toHaveBeenCalledWith('CA');
	});

	it('adds cursor-pointer class when editable', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: true
			}
		});

		await waitFor(() => {
			const paths = container.querySelectorAll('path');
			expect(paths.length).toBe(3);
			paths.forEach((path) => {
				expect(path).toHaveClass('cursor-pointer');
			});
		});
	});

	it('does not add cursor-pointer class when not editable', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: false
			}
		});

		await waitFor(() => {
			const paths = container.querySelectorAll('path');
			expect(paths.length).toBe(3);
			paths.forEach((path) => {
				expect(path).not.toHaveClass('cursor-pointer');
			});
		});
	});

	it('adds button role and tabindex when editable', async () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: true
			}
		});

		await waitFor(() => {
			const paths = container.querySelectorAll('path');
			expect(paths.length).toBe(3);
			paths.forEach((path) => {
				expect(path).toHaveAttribute('role', 'button');
				expect(path).toHaveAttribute('tabindex', '0');
			});
		});
	});

	it('responds to keyboard events when editable', async () => {
		const mockToggle = vi.fn();
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: true,
				onToggle: mockToggle
			}
		});

		await waitFor(() => {
			expect(container.querySelectorAll('path').length).toBe(3);
		});

		const paths = container.querySelectorAll('path');
		await fireEvent.keyDown(paths[0], { key: 'Enter' });

		expect(mockToggle).toHaveBeenCalledWith('CA');
	});
});
