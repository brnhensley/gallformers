/// <reference types="vitest/config" />
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { svelteTesting } from '@testing-library/svelte/vite';

export default defineConfig({
    plugins: [sveltekit(), svelteTesting()],
    test: {
        include: ['src/**/*.{test,spec}.{js,ts}'],
        environment: 'jsdom',
        globals: true,
        setupFiles: ['./src/lib/components/vitest-setup.ts'],
    },
});
