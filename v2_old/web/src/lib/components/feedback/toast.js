import { writable } from 'svelte/store';

const { subscribe, update } = writable([]);

export const toasts = { subscribe };

function addToast(type, message) {
	const id = crypto.randomUUID();
	update((t) => [...t, { id, type, message }]);
	setTimeout(() => removeToast(id), 5000);
}

function removeToast(id) {
	update((t) => t.filter((toast) => toast.id !== id));
}

export const toast = {
	success: (message) => addToast('success', message),
	error: (message) => addToast('error', message),
	info: (message) => addToast('info', message),
	dismiss: (id) => removeToast(id)
};
