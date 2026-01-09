import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { get } from 'svelte/store';
import { toast, toasts } from './toast';

describe('toast store', () => {
	beforeEach(() => {
		vi.useFakeTimers();
		// Clear any existing toasts
		const currentToasts = get(toasts);
		currentToasts.forEach((t) => toast.dismiss(t.id));
	});

	afterEach(() => {
		vi.useRealTimers();
	});

	it('adds a success toast', () => {
		toast.success('Operation successful');

		const current = get(toasts);
		expect(current).toHaveLength(1);
		expect(current[0].type).toBe('success');
		expect(current[0].message).toBe('Operation successful');
	});

	it('adds an error toast', () => {
		toast.error('Something went wrong');

		const current = get(toasts);
		expect(current).toHaveLength(1);
		expect(current[0].type).toBe('error');
		expect(current[0].message).toBe('Something went wrong');
	});

	it('adds an info toast', () => {
		toast.info('Here is some information');

		const current = get(toasts);
		expect(current).toHaveLength(1);
		expect(current[0].type).toBe('info');
		expect(current[0].message).toBe('Here is some information');
	});

	it('assigns unique ids to toasts', () => {
		toast.success('First');
		toast.success('Second');

		const current = get(toasts);
		expect(current).toHaveLength(2);
		expect(current[0].id).not.toBe(current[1].id);
	});

	it('dismisses a toast by id', () => {
		toast.success('To be dismissed');

		const current = get(toasts);
		expect(current).toHaveLength(1);

		const id = current[0].id;
		toast.dismiss(id);

		expect(get(toasts)).toHaveLength(0);
	});

	it('auto-dismisses after 5 seconds', () => {
		toast.success('Auto dismiss test');

		expect(get(toasts)).toHaveLength(1);

		// Advance time by 4.9 seconds
		vi.advanceTimersByTime(4900);
		expect(get(toasts)).toHaveLength(1);

		// Advance time past 5 seconds
		vi.advanceTimersByTime(200);
		expect(get(toasts)).toHaveLength(0);
	});

	it('can have multiple toasts at once', () => {
		toast.success('Success');
		toast.error('Error');
		toast.info('Info');

		expect(get(toasts)).toHaveLength(3);
	});

	it('removes only the specified toast', () => {
		toast.success('First');
		toast.success('Second');

		const current = get(toasts);
		expect(current).toHaveLength(2);

		toast.dismiss(current[0].id);

		const afterDismiss = get(toasts);
		expect(afterDismiss).toHaveLength(1);
		expect(afterDismiss[0].message).toBe('Second');
	});
});
