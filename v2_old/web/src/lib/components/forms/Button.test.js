import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import Button from './Button.svelte';

// Helper component to test Button with children snippet
import { createRawSnippet } from 'svelte';

describe('Button', () => {
	const childrenSnippet = createRawSnippet(() => ({
		render: () => 'Click me',
		setup: () => {}
	}));

	it('renders button with children', () => {
		render(Button, { props: { children: childrenSnippet } });
		expect(screen.getByRole('button', { name: 'Click me' })).toBeInTheDocument();
	});

	it('renders primary variant by default', () => {
		render(Button, { props: { children: childrenSnippet } });
		const button = screen.getByRole('button');
		expect(button).toHaveClass('bg-gf-maroon');
	});

	it('renders secondary variant', () => {
		render(Button, { props: { children: childrenSnippet, variant: 'secondary' } });
		const button = screen.getByRole('button');
		expect(button).toHaveClass('bg-white');
		expect(button).toHaveClass('border-gray-300');
	});

	it('renders danger variant', () => {
		render(Button, { props: { children: childrenSnippet, variant: 'danger' } });
		const button = screen.getByRole('button');
		expect(button).toHaveClass('bg-red-600');
	});

	it('renders ghost variant', () => {
		render(Button, { props: { children: childrenSnippet, variant: 'ghost' } });
		const button = screen.getByRole('button');
		expect(button).toHaveClass('text-gf-maroon');
	});

	it('renders with disabled state', () => {
		render(Button, { props: { children: childrenSnippet, disabled: true } });
		expect(screen.getByRole('button')).toBeDisabled();
	});

	it('calls onclick when clicked', async () => {
		const user = userEvent.setup();
		const handleClick = vi.fn();
		render(Button, { props: { children: childrenSnippet, onclick: handleClick } });

		await user.click(screen.getByRole('button'));
		expect(handleClick).toHaveBeenCalledOnce();
	});

	it('does not call onclick when disabled', async () => {
		const user = userEvent.setup();
		const handleClick = vi.fn();
		render(Button, { props: { children: childrenSnippet, onclick: handleClick, disabled: true } });

		await user.click(screen.getByRole('button'));
		expect(handleClick).not.toHaveBeenCalled();
	});

	it('renders with submit type', () => {
		render(Button, { props: { children: childrenSnippet, type: 'submit' } });
		expect(screen.getByRole('button')).toHaveAttribute('type', 'submit');
	});

	it('focuses button when autofocus is true', async () => {
		render(Button, { props: { children: childrenSnippet, autofocus: true } });

		// Wait for the setTimeout in $effect to complete
		await new Promise((resolve) => setTimeout(resolve, 10));

		expect(screen.getByRole('button')).toHaveFocus();
	});
});
