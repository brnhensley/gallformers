import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { svelteTesting } from '@testing-library/svelte/vite';

export default defineConfig({
    plugins: [sveltekit(), svelteTesting()],
    server: {
        proxy: {
            '/api': {
                target: 'http://localhost:8080',
                changeOrigin: true,
            },
        },
    },
    test: {
        include: ['src/**/*.{test,spec}.js'],
        environment: 'jsdom',
        globals: true,
        setupFiles: ['./src/lib/components/vitest-setup.js'],
    },
});
