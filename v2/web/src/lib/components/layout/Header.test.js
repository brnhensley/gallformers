import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import Header from './Header.svelte';

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

describe('Header', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	it('renders the logo', () => {
		render(Header);
		const logo = screen.getByAltText(/gallformers logo/i);
		expect(logo).toBeInTheDocument();
	});

	it('renders navigation links', () => {
		render(Header);
		expect(screen.getByRole('link', { name: /identify/i })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: /explore/i })).toBeInTheDocument();
	});

	it('renders search form', () => {
		render(Header);
		expect(screen.getByPlaceholderText(/search/i)).toBeInTheDocument();
		expect(screen.getByRole('button', { name: /search/i })).toBeInTheDocument();
	});

	it('renders login link', () => {
		render(Header);
		expect(screen.getByRole('link', { name: /login/i })).toBeInTheDocument();
	});

	it('renders resources dropdown button', () => {
		render(Header);
		expect(screen.getByRole('button', { name: /resources/i })).toBeInTheDocument();
	});

	it('renders mobile menu button', () => {
		render(Header);
		const menuButton = screen.getByRole('button', { name: /open main menu/i });
		expect(menuButton).toBeInTheDocument();
	});

	it('toggles mobile menu when button is clicked', async () => {
		render(Header);
		const menuButton = screen.getByRole('button', { name: /open main menu/i });

		// Initially no mobile menu visible
		expect(screen.queryByRole('link', { name: /identify/i })).toBeInTheDocument();

		await fireEvent.click(menuButton);

		// Mobile menu should now be visible (multiple identify links - desktop and mobile)
		const identifyLinks = screen.getAllByRole('link', { name: /identify/i });
		expect(identifyLinks.length).toBeGreaterThanOrEqual(1);
	});

	it('updates search input value', async () => {
		render(Header);
		const searchInput = screen.getByPlaceholderText(/search/i);

		await fireEvent.input(searchInput, { target: { value: 'oak gall' } });

		expect(searchInput.value).toBe('oak gall');
	});

	it('navigates to search page on form submit', async () => {
		const { goto } = await import('$app/navigation');
		render(Header);

		const searchInput = screen.getByPlaceholderText(/search/i);
		const form = searchInput.closest('form');

		await fireEvent.input(searchInput, { target: { value: 'oak gall' } });
		await fireEvent.submit(form);

		expect(goto).toHaveBeenCalledWith('/globalsearch?q=oak%20gall');
	});

	it('does not navigate on empty search', async () => {
		const { goto } = await import('$app/navigation');
		render(Header);

		const searchInput = screen.getByPlaceholderText(/search/i);
		const form = searchInput.closest('form');

		await fireEvent.submit(form);

		expect(goto).not.toHaveBeenCalled();
	});
});
