import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect } from 'vitest';
import MultiSelect from './MultiSelect.svelte';

describe('MultiSelect', () => {
	const options = [
		{ id: 1, field: 'Red' },
		{ id: 2, field: 'Green' },
		{ id: 3, field: 'Blue' }
	];

	it('renders label and options', () => {
		render(MultiSelect, {
			props: { label: 'Colors', options, labelKey: 'field', valueKey: 'id' }
		});
		expect(screen.getByText('Colors')).toBeInTheDocument();
		expect(screen.getByText('Red')).toBeInTheDocument();
		expect(screen.getByText('Green')).toBeInTheDocument();
		expect(screen.getByText('Blue')).toBeInTheDocument();
	});

	it('shows required indicator', () => {
		render(MultiSelect, {
			props: { label: 'Colors', options, labelKey: 'field', valueKey: 'id', required: true }
		});
		expect(screen.getByText('*')).toBeInTheDocument();
	});

	it('displays error message when error prop set', () => {
		render(MultiSelect, {
			props: { label: 'Colors', options, labelKey: 'field', valueKey: 'id', error: 'Select at least one' }
		});
		expect(screen.getByText('Select at least one')).toBeInTheDocument();
	});

	it('toggles selection on click', async () => {
		const user = userEvent.setup();
		render(MultiSelect, {
			props: { label: 'Colors', options, labelKey: 'field', valueKey: 'id' }
		});

		const redButton = screen.getByText('Red');

		// Initially not selected (check for white background class)
		expect(redButton).toHaveClass('bg-white');

		// Click to select
		await user.click(redButton);
		expect(redButton).toHaveClass('bg-gf-maroon');

		// Click again to deselect
		await user.click(redButton);
		expect(redButton).toHaveClass('bg-white');
	});

	it('allows multiple selections', async () => {
		const user = userEvent.setup();
		render(MultiSelect, {
			props: { label: 'Colors', options, labelKey: 'field', valueKey: 'id' }
		});

		const redButton = screen.getByText('Red');
		const blueButton = screen.getByText('Blue');

		await user.click(redButton);
		await user.click(blueButton);

		expect(redButton).toHaveClass('bg-gf-maroon');
		expect(blueButton).toHaveClass('bg-gf-maroon');
	});

	it('renders with pre-selected values', () => {
		render(MultiSelect, {
			props: {
				label: 'Colors',
				options,
				labelKey: 'field',
				valueKey: 'id',
				selected: [{ id: 2, field: 'Green' }]
			}
		});

		expect(screen.getByText('Green')).toHaveClass('bg-gf-maroon');
		expect(screen.getByText('Red')).toHaveClass('bg-white');
	});
});
