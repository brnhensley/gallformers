import { writable } from 'svelte/store';

interface Toast {
	id: string;
	type: 'success' | 'error' | 'info';
	message: string;
}

const { subscribe, update } = writable<Toast[]>([]);

export const toasts = { subscribe };

function addToast(type: Toast['type'], message: string) {
	const id = crypto.randomUUID();
	update((t) => [...t, { id, type, message }]);
	setTimeout(() => removeToast(id), 5000);
}

function removeToast(id: string) {
	update((t) => t.filter((toast) => toast.id !== id));
}

export const toast = {
	success: (message: string) => addToast('success', message),
	error: (message: string) => addToast('error', message),
	info: (message: string) => addToast('info', message),
	dismiss: (id: string) => removeToast(id)
};
