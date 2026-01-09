import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect } from 'vitest';
import Input from './Input.svelte';

describe('Input', () => {
	it('renders label and input', () => {
		render(Input, { props: { label: 'Name', value: '' } });
		expect(screen.getByLabelText('Name')).toBeInTheDocument();
	});

	it('displays error message when error prop set', () => {
		render(Input, { props: { label: 'Name', value: '', error: 'Required' } });
		expect(screen.getByText('Required')).toBeInTheDocument();
	});

	it('shows required indicator', () => {
		render(Input, { props: { label: 'Name', value: '', required: true } });
		expect(screen.getByText('*')).toBeInTheDocument();
	});

	it('updates value on input', async () => {
		const user = userEvent.setup();
		render(Input, { props: { label: 'Name', value: '' } });

		const input = screen.getByLabelText('Name');
		await user.type(input, 'Test');

		expect(input).toHaveValue('Test');
	});

	it('renders with disabled state', () => {
		render(Input, { props: { label: 'Name', value: '', disabled: true } });
		expect(screen.getByLabelText('Name')).toBeDisabled();
	});

	it('renders with different input types', () => {
		render(Input, { props: { label: 'Email', value: '', type: 'email' } });
		expect(screen.getByLabelText('Email')).toHaveAttribute('type', 'email');
	});
});
