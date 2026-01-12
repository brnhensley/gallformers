import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect } from 'vitest';
import Checkbox from './Checkbox.svelte';

describe('Checkbox', () => {
	it('renders label and checkbox', () => {
		render(Checkbox, { props: { label: 'Undescribed species?' } });
		expect(screen.getByLabelText('Undescribed species?')).toBeInTheDocument();
	});

	it('toggles checked state on click', async () => {
		const user = userEvent.setup();
		render(Checkbox, { props: { label: 'Undescribed species?' } });

		const checkbox = screen.getByLabelText('Undescribed species?');
		expect(checkbox).not.toBeChecked();

		await user.click(checkbox);
		expect(checkbox).toBeChecked();

		await user.click(checkbox);
		expect(checkbox).not.toBeChecked();
	});

	it('renders with checked state', () => {
		render(Checkbox, { props: { label: 'Undescribed species?', checked: true } });
		expect(screen.getByLabelText('Undescribed species?')).toBeChecked();
	});

	it('renders with disabled state', () => {
		render(Checkbox, { props: { label: 'Undescribed species?', disabled: true } });
		expect(screen.getByLabelText('Undescribed species?')).toBeDisabled();
	});

	it('does not toggle when disabled', async () => {
		const user = userEvent.setup();
		render(Checkbox, { props: { label: 'Undescribed species?', disabled: true } });

		const checkbox = screen.getByLabelText('Undescribed species?');
		await user.click(checkbox);

		expect(checkbox).not.toBeChecked();
	});
});
