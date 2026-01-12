import { render, screen } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import Layout from './Layout.svelte';

// Mock SvelteKit modules
vi.mock('$app/stores', () => ({
	page: {
		subscribe: vi.fn((callback) => {
			callback({ url: new URL('http://localhost/') });
			return () => {};
		})
	}
}));

vi.mock('$app/navigation', () => ({
	goto: vi.fn()
}));

describe('Layout', () => {
	it('renders header', () => {
		render(Layout);
		// Header contains the logo
		const logo = screen.getByAltText(/gallformers logo/i);
		expect(logo).toBeInTheDocument();
	});

	it('renders footer', () => {
		render(Layout);
		// Footer contains the copyright notice (multiple elements due to desktop + mobile)
		const currentYear = new Date().getFullYear();
		const copyrightElements = screen.getAllByText(new RegExp(`${currentYear}.*gallformers`, 'i'));
		expect(copyrightElements.length).toBeGreaterThanOrEqual(1);
	});

	it('renders main content area', () => {
		render(Layout);
		const main = document.querySelector('main');
		expect(main).toBeInTheDocument();
	});

	it('has correct flex layout structure', () => {
		const { container } = render(Layout);
		const wrapper = container.querySelector('div');
		expect(wrapper).toHaveClass('flex', 'min-h-screen', 'flex-col');
	});
});
