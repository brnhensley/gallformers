import { render, screen } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import Typeahead from './Typeahead.svelte';

describe('Typeahead', () => {
	const mockSearchFn = vi.fn(async (query) => {
		return [
			{ id: 1, name: 'Apple' },
			{ id: 2, name: 'Banana' },
			{ id: 3, name: 'Cherry' }
		].filter((item) => item.name.toLowerCase().includes(query.toLowerCase()));
	});

	it('renders label', () => {
		render(Typeahead, {
			props: {
				label: 'Select Fruit',
				searchFn: mockSearchFn
			}
		});

		expect(screen.getByText('Select Fruit')).toBeInTheDocument();
	});

	it('shows required indicator when required', () => {
		render(Typeahead, {
			props: {
				label: 'Select Fruit',
				searchFn: mockSearchFn,
				required: true
			}
		});

		expect(screen.getByText('*')).toBeInTheDocument();
	});

	it('displays error message when error prop set', () => {
		render(Typeahead, {
			props: {
				label: 'Select Fruit',
				searchFn: mockSearchFn,
				error: 'Please select a fruit'
			}
		});

		expect(screen.getByText('Please select a fruit')).toBeInTheDocument();
	});

	it('renders without error message when no error', () => {
		render(Typeahead, {
			props: {
				label: 'Select Fruit',
				searchFn: mockSearchFn
			}
		});

		expect(screen.queryByText('Please select a fruit')).not.toBeInTheDocument();
	});

	it('generates unique label ID for accessibility', () => {
		const { container } = render(Typeahead, {
			props: {
				label: 'Select Fruit',
				searchFn: mockSearchFn
			}
		});

		const labelSpan = container.querySelector('span[id^="typeahead-label-"]');
		expect(labelSpan).toBeInTheDocument();
	});
});
