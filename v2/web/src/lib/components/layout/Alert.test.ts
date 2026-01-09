import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Alert from './Alert.svelte';

describe('Alert', () => {
	it('renders with default info variant', () => {
		const { container } = render(Alert, {
			props: {}
		});

		const alert = container.querySelector('[role="alert"]');
		expect(alert).toHaveClass('bg-blue-50', 'text-blue-800', 'border-blue-200');
	});

	it('renders warning variant correctly', () => {
		const { container } = render(Alert, {
			props: { variant: 'warning' }
		});

		const alert = container.querySelector('[role="alert"]');
		expect(alert).toHaveClass('bg-yellow-50', 'text-yellow-800', 'border-yellow-200');
	});

	it('renders error variant correctly', () => {
		const { container } = render(Alert, {
			props: { variant: 'error' }
		});

		const alert = container.querySelector('[role="alert"]');
		expect(alert).toHaveClass('bg-red-50', 'text-red-800', 'border-red-200');
	});

	it('renders success variant correctly', () => {
		const { container } = render(Alert, {
			props: { variant: 'success' }
		});

		const alert = container.querySelector('[role="alert"]');
		expect(alert).toHaveClass('bg-green-50', 'text-green-800', 'border-green-200');
	});

	it('has correct base styling', () => {
		const { container } = render(Alert, {
			props: {}
		});

		const alert = container.querySelector('[role="alert"]');
		expect(alert).toHaveClass('p-4', 'rounded-md', 'border');
	});

	it('has alert role for accessibility', () => {
		render(Alert, {
			props: {}
		});

		expect(screen.getByRole('alert')).toBeInTheDocument();
	});
});
