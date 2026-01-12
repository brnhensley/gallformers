import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect } from 'vitest';
import Select from './Select.svelte';

describe('Select', () => {
	const options = [
		{ id: 1, name: 'Option A' },
		{ id: 2, name: 'Option B' },
		{ id: 3, name: 'Option C' }
	];

	it('renders label and select', () => {
		render(Select, {
			props: { label: 'Category', options, optionLabel: 'name', optionValue: 'id' }
		});
		expect(screen.getByLabelText('Category')).toBeInTheDocument();
	});

	it('renders all options', () => {
		render(Select, {
			props: { label: 'Category', options, optionLabel: 'name', optionValue: 'id' }
		});
		expect(screen.getByText('Select...')).toBeInTheDocument();
		expect(screen.getByText('Option A')).toBeInTheDocument();
		expect(screen.getByText('Option B')).toBeInTheDocument();
		expect(screen.getByText('Option C')).toBeInTheDocument();
	});

	it('displays error message when error prop set', () => {
		render(Select, {
			props: { label: 'Category', options, optionLabel: 'name', optionValue: 'id', error: 'Required' }
		});
		expect(screen.getByText('Required')).toBeInTheDocument();
	});

	it('shows required indicator', () => {
		render(Select, {
			props: { label: 'Category', options, optionLabel: 'name', optionValue: 'id', required: true }
		});
		expect(screen.getByText('*')).toBeInTheDocument();
	});

	it('selects an option', async () => {
		const user = userEvent.setup();
		render(Select, {
			props: { label: 'Category', options, optionLabel: 'name', optionValue: 'id' }
		});

		const select = screen.getByLabelText('Category');
		await user.selectOptions(select, '2');

		expect(select).toHaveValue('2');
	});

	it('renders with disabled state', () => {
		render(Select, {
			props: { label: 'Category', options, optionLabel: 'name', optionValue: 'id', disabled: true }
		});
		expect(screen.getByLabelText('Category')).toBeDisabled();
	});
});
