const config = {
  stories: ['../src/**/*.mdx', '../src/**/*.stories.@(js|svelte)'],
  addons: [
    '@storybook/addon-svelte-csf',
    '@chromatic-com/storybook',
    '@storybook/addon-a11y',
    '@storybook/addon-docs',
  ],
  framework: '@storybook/sveltekit',
};
export default config;
