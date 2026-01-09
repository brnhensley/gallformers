import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import ConfirmModal from './ConfirmModal.svelte';

// Mock the dialog element methods
beforeEach(() => {
	HTMLDialogElement.prototype.showModal = vi.fn();
	HTMLDialogElement.prototype.close = vi.fn();
});

afterEach(() => {
	vi.restoreAllMocks();
});

// Helper to get button in dialog (jsdom doesn't properly expose dialog content via role queries)
function getButtonByText(container, text) {
	const buttons = container.querySelectorAll('button');
	for (const btn of buttons) {
		if (btn.textContent?.trim() === text) {
			return btn;
		}
	}
	throw new Error(`Button with text "${text}" not found`);
}

describe('ConfirmModal', () => {
	it('renders title and message when open', async () => {
		const { container } = render(ConfirmModal, {
			props: {
				open: true,
				title: 'Delete Item',
				message: 'Are you sure you want to delete this item?',
				onConfirm: vi.fn(),
				onCancel: vi.fn()
			}
		});

		const heading = container.querySelector('h2');
		expect(heading).toBeInTheDocument();
		expect(heading).toHaveTextContent('Delete Item');
		expect(screen.getByText('Are you sure you want to delete this item?')).toBeInTheDocument();
	});

	it('renders default button labels', async () => {
		const { container } = render(ConfirmModal, {
			props: {
				open: true,
				title: 'Confirm Action',
				message: 'Are you sure?',
				onConfirm: vi.fn(),
				onCancel: vi.fn()
			}
		});

		// jsdom doesn't properly handle dialog visibility, so query buttons directly
		expect(getButtonByText(container, 'Cancel')).toBeInTheDocument();
		expect(getButtonByText(container, 'Confirm')).toBeInTheDocument();
	});

	it('renders custom button labels', async () => {
		const { container } = render(ConfirmModal, {
			props: {
				open: true,
				title: 'Delete Item',
				message: 'Are you sure?',
				confirmLabel: 'Delete',
				cancelLabel: 'Keep',
				onConfirm: vi.fn(),
				onCancel: vi.fn()
			}
		});

		expect(getButtonByText(container, 'Keep')).toBeInTheDocument();
		expect(getButtonByText(container, 'Delete')).toBeInTheDocument();
	});

	it('calls onConfirm when confirm button clicked', async () => {
		const onConfirm = vi.fn();
		const { container } = render(ConfirmModal, {
			props: {
				open: true,
				title: 'Confirm',
				message: 'Are you sure?',
				onConfirm,
				onCancel: vi.fn()
			}
		});

		const confirmBtn = getButtonByText(container, 'Confirm');
		await fireEvent.click(confirmBtn);

		expect(onConfirm).toHaveBeenCalled();
	});

	it('calls onCancel when cancel button clicked', async () => {
		const onCancel = vi.fn();
		const { container } = render(ConfirmModal, {
			props: {
				open: true,
				title: 'Confirm',
				message: 'Are you sure?',
				onConfirm: vi.fn(),
				onCancel
			}
		});

		const cancelBtn = getButtonByText(container, 'Cancel');
		await fireEvent.click(cancelBtn);

		expect(onCancel).toHaveBeenCalled();
	});

	it('cancel button is focused on open', async () => {
		const { container } = render(ConfirmModal, {
			props: {
				open: true,
				title: 'Delete Item',
				message: 'Are you sure?',
				onConfirm: vi.fn(),
				onCancel: vi.fn()
			}
		});

		const cancelBtn = getButtonByText(container, 'Cancel');

		// Wait for the autofocus effect (uses setTimeout)
		await waitFor(() => {
			expect(document.activeElement).toBe(cancelBtn);
		});
	});

	it('renders danger variant for confirm button by default', async () => {
		const { container } = render(ConfirmModal, {
			props: {
				open: true,
				title: 'Delete Item',
				message: 'Are you sure?',
				onConfirm: vi.fn(),
				onCancel: vi.fn()
			}
		});

		const confirmBtn = getButtonByText(container, 'Confirm');
		expect(confirmBtn).toHaveClass('bg-red-600');
	});

	it('renders warning variant when specified', async () => {
		const { container } = render(ConfirmModal, {
			props: {
				open: true,
				title: 'Warning',
				message: 'This action has consequences.',
				variant: 'warning',
				onConfirm: vi.fn(),
				onCancel: vi.fn()
			}
		});

		// Warning variant should render - Button component handles the variant styling
		const confirmBtn = getButtonByText(container, 'Confirm');
		expect(confirmBtn).toBeInTheDocument();
	});
});
