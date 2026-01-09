import { render, screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { get } from 'svelte/store';
import ToastContainer from './ToastContainer.svelte';
import { toast, toasts } from './toast';

describe('ToastContainer', () => {
	beforeEach(() => {
		vi.useFakeTimers();
		// Clear any existing toasts
		const currentToasts = get(toasts);
		currentToasts.forEach((t) => toast.dismiss(t.id));
	});

	afterEach(() => {
		vi.useRealTimers();
	});

	it('renders toasts from the store', async () => {
		render(ToastContainer);

		toast.success('Test message');

		await waitFor(() => {
			expect(screen.getByText('Test message')).toBeInTheDocument();
		});
	});

	it('renders success toast with green background', async () => {
		const { container } = render(ToastContainer);

		toast.success('Success message');

		await waitFor(() => {
			const alert = container.querySelector('[role="alert"]');
			expect(alert).toHaveClass('bg-green-500');
		});
	});

	it('renders error toast with red background', async () => {
		const { container } = render(ToastContainer);

		toast.error('Error message');

		await waitFor(() => {
			const alert = container.querySelector('[role="alert"]');
			expect(alert).toHaveClass('bg-red-500');
		});
	});

	it('renders info toast with blue background', async () => {
		const { container } = render(ToastContainer);

		toast.info('Info message');

		await waitFor(() => {
			const alert = container.querySelector('[role="alert"]');
			expect(alert).toHaveClass('bg-blue-500');
		});
	});

	it('renders multiple toasts', async () => {
		render(ToastContainer);

		toast.success('First');
		toast.error('Second');
		toast.info('Third');

		await waitFor(() => {
			expect(screen.getByText('First')).toBeInTheDocument();
			expect(screen.getByText('Second')).toBeInTheDocument();
			expect(screen.getByText('Third')).toBeInTheDocument();
		});
	});

	it('auto-dismisses toast after 5 seconds', async () => {
		render(ToastContainer);

		toast.success('Auto dismiss');

		await waitFor(() => {
			expect(screen.getByText('Auto dismiss')).toBeInTheDocument();
		});

		// Advance time past 5 seconds
		vi.advanceTimersByTime(5100);

		await waitFor(() => {
			expect(screen.queryByText('Auto dismiss')).not.toBeInTheDocument();
		});
	});

	it('has dismiss button on each toast', async () => {
		render(ToastContainer);

		toast.success('Dismissable');

		await waitFor(() => {
			expect(screen.getByRole('button', { name: 'Dismiss' })).toBeInTheDocument();
		});
	});

	it('manual dismiss removes toast when close button clicked', async () => {
		const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
		render(ToastContainer);

		toast.success('Manual dismiss');

		await waitFor(() => {
			expect(screen.getByText('Manual dismiss')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: 'Dismiss' });
		await user.click(dismissButton);

		await waitFor(() => {
			expect(screen.queryByText('Manual dismiss')).not.toBeInTheDocument();
		});
	});

	it('has fixed positioning at bottom-right', () => {
		const { container } = render(ToastContainer);

		const wrapper = container.firstElementChild;
		expect(wrapper).toHaveClass('fixed', 'bottom-4', 'right-4', 'z-50');
	});

	it('toasts have alert role for accessibility', async () => {
		render(ToastContainer);

		toast.success('Accessible toast');

		await waitFor(() => {
			expect(screen.getByRole('alert')).toBeInTheDocument();
		});
	});
});
