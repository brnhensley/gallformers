import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Card from './Card.svelte';

describe('Card', () => {
	it('renders with title', () => {
		render(Card, {
			props: {
				title: 'Card Title'
			}
		});

		expect(screen.getByRole('heading', { name: 'Card Title' })).toBeInTheDocument();
	});

	it('renders without title', () => {
		render(Card, {
			props: {}
		});

		expect(screen.queryByRole('heading')).not.toBeInTheDocument();
	});

	it('has correct styling classes', () => {
		const { container } = render(Card, {
			props: {
				title: 'Test'
			}
		});

		const cardDiv = container.querySelector('div');
		expect(cardDiv).toHaveClass('bg-white', 'rounded-lg', 'shadow-sm', 'border', 'border-gray-200', 'p-6');
	});
});
