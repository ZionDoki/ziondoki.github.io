// @ts-check
import mdx from '@astrojs/mdx';
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
	site: process.env.PUBLIC_SITE_URL || 'https://ziang.site',
	output: 'static',
	trailingSlash: 'always',
	integrations: [mdx()],
	vite: {
		plugins: [tailwindcss()],
	},
});
