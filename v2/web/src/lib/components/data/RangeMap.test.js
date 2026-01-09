import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import RangeMap from './RangeMap.svelte';

// Mock d3-geo to avoid complex SVG path calculations in tests
vi.mock('d3-geo', () => ({
	geoPath: () => () => 'M0,0L10,10Z',
	geoAlbers: () => ({
		center: () => ({
			rotate: () => ({
				parallels: () => ({
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

describe('RangeMap', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	it('renders SVG with correct viewBox', () => {
		render(RangeMap, {
			props: {
				inRange: new Set()
			}
		});

		const svg = screen.getByRole('img', { name: 'Range map of North America' });
		expect(svg).toBeInTheDocument();
		expect(svg).toHaveAttribute('viewBox', '0 0 975 700');
	});

	it('renders path elements for each region', () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set()
			}
		});

		const paths = container.querySelectorAll('path');
		expect(paths.length).toBe(3); // CA, TX, ON from mock
	});

	it('fills in-range regions with green', () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(['CA'])
			}
		});

		const paths = container.querySelectorAll('path');
		// Find CA path (first one in mock)
		const caPath = paths[0];
		expect(caPath).toHaveAttribute('fill', '#228B22'); // ForestGreen
	});

	it('fills excluded regions with coral', () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				excludedRange: new Set(['TX'])
			}
		});

		const paths = container.querySelectorAll('path');
		// Find TX path (second one in mock)
		const txPath = paths[1];
		expect(txPath).toHaveAttribute('fill', '#F08080'); // LightCoral
	});

	it('fills unselected regions with white', () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set()
			}
		});

		const paths = container.querySelectorAll('path');
		const onPath = paths[2]; // Ontario
		expect(onPath).toHaveAttribute('fill', '#FFFFFF');
	});

	it('does not call onToggle when not editable', async () => {
		const mockToggle = vi.fn();
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: false,
				onToggle: mockToggle
			}
		});

		const paths = container.querySelectorAll('path');
		await fireEvent.click(paths[0]);

		expect(mockToggle).not.toHaveBeenCalled();
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

		const paths = container.querySelectorAll('path');
		await fireEvent.click(paths[0]); // CA

		expect(mockToggle).toHaveBeenCalledWith('CA');
	});

	it('adds cursor-pointer class when editable', () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: true
			}
		});

		const paths = container.querySelectorAll('path');
		paths.forEach((path) => {
			expect(path).toHaveClass('cursor-pointer');
		});
	});

	it('does not add cursor-pointer class when not editable', () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: false
			}
		});

		const paths = container.querySelectorAll('path');
		paths.forEach((path) => {
			expect(path).not.toHaveClass('cursor-pointer');
		});
	});

	it('adds button role and tabindex when editable', () => {
		const { container } = render(RangeMap, {
			props: {
				inRange: new Set(),
				editable: true
			}
		});

		const paths = container.querySelectorAll('path');
		paths.forEach((path) => {
			expect(path).toHaveAttribute('role', 'button');
			expect(path).toHaveAttribute('tabindex', '0');
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

		const paths = container.querySelectorAll('path');
		await fireEvent.keyDown(paths[0], { key: 'Enter' });

		expect(mockToggle).toHaveBeenCalledWith('CA');
	});
});
