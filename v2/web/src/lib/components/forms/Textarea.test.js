import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect } from 'vitest';
import Textarea from './Textarea.svelte';

describe('Textarea', () => {
	it('renders label and textarea', () => {
		render(Textarea, { props: { label: 'Description', value: '' } });
		expect(screen.getByLabelText('Description')).toBeInTheDocument();
	});

	it('displays error message when error prop set', () => {
		render(Textarea, { props: { label: 'Description', value: '', error: 'Required' } });
		expect(screen.getByText('Required')).toBeInTheDocument();
	});

	it('shows required indicator', () => {
		render(Textarea, { props: { label: 'Description', value: '', required: true } });
		expect(screen.getByText('*')).toBeInTheDocument();
	});

	it('updates value on input', async () => {
		const user = userEvent.setup();
		render(Textarea, { props: { label: 'Description', value: '' } });

		const textarea = screen.getByLabelText('Description');
		await user.type(textarea, 'Test content');

		expect(textarea).toHaveValue('Test content');
	});

	it('renders with disabled state', () => {
		render(Textarea, { props: { label: 'Description', value: '', disabled: true } });
		expect(screen.getByLabelText('Description')).toBeDisabled();
	});

	it('renders with custom rows', () => {
		render(Textarea, { props: { label: 'Description', value: '', rows: 5 } });
		expect(screen.getByLabelText('Description')).toHaveAttribute('rows', '5');
	});
});
