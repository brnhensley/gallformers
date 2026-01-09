/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {
			colors: {
				'gf-maroon': {
					DEFAULT: '#800000',
					dark: '#660000',
					light: '#a64d4d'
				}
			}
		}
	},
	plugins: []
};
