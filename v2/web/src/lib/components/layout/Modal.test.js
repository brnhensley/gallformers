import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import Modal from './Modal.svelte';

// Mock the dialog element methods
beforeEach(() => {
	HTMLDialogElement.prototype.showModal = vi.fn();
	HTMLDialogElement.prototype.close = vi.fn();
});

afterEach(() => {
	vi.restoreAllMocks();
});

describe('Modal', () => {
	it('renders title when open', async () => {
		const { container } = render(Modal, {
			props: {
				open: true,
				title: 'Test Modal'
			}
		});

		// jsdom doesn't properly handle dialog visibility, so query directly
		const heading = container.querySelector('h2');
		expect(heading).toBeInTheDocument();
		expect(heading).toHaveTextContent('Test Modal');
	});

	it('calls showModal when opened', async () => {
		render(Modal, {
			props: {
				open: true,
				title: 'Test Modal'
			}
		});

		expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
	});

	it('calls close when open is set to false', async () => {
		const { rerender } = render(Modal, {
			props: {
				open: true,
				title: 'Test Modal'
			}
		});

		await rerender({ open: false, title: 'Test Modal' });

		expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
	});

	it('closes on Escape key', async () => {
		let openValue = true;
		const { container } = render(Modal, {
			props: {
				open: openValue,
				title: 'Test Modal'
			}
		});

		const dialog = container.querySelector('dialog');
		expect(dialog).toBeInTheDocument();
		await fireEvent.keyDown(dialog, { key: 'Escape' });

		// The component calls the effect to close the dialog
		// Verify close was called (since open should have been set to false)
		expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
	});

	it('renders dialog element', async () => {
		const { container } = render(Modal, {
			props: {
				open: true,
				title: 'Test Modal'
			}
		});

		// The dialog element should be rendered (jsdom doesn't support dialog role properly)
		const dialog = container.querySelector('dialog');
		expect(dialog).toBeInTheDocument();
		expect(dialog).toHaveClass('rounded-lg', 'shadow-xl');
	});
});
