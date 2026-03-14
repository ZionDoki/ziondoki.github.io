import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const publications = defineCollection({
	loader: glob({ base: './src/content/publications', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		title: z.string(),
		authors: z.array(z.string()),
		venue: z.string(),
		year: z.union([z.number().int(), z.string()]),
		abstract: z.string(),
		tags: z.array(z.string()).default([]),
		links: z
			.object({
				paper: z.string().url().optional(),
				code: z.string().url().optional(),
				project: z.string().url().optional(),
			})
			.default({}),
		featured: z.boolean().default(false),
		citation: z.string(),
	}),
});

const projects = defineCollection({
	loader: glob({ base: './src/content/projects', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		name: z.string(),
		summary: z.string(),
		status: z.enum(['Active', 'Maintained', 'Research', 'Archived']),
		tags: z.array(z.string()).default([]),
		repo: z.string().url().optional(),
		demo: z.string().url().optional(),
		featured: z.boolean().default(false),
	}),
});

const posts = defineCollection({
	loader: glob({ base: './src/content/posts', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		title: z.string(),
		description: z.string(),
		date: z.coerce.date(),
		tags: z.array(z.string()).default([]),
		draft: z.boolean().default(false),
		featured: z.boolean().default(false),
	}),
});

const updates = defineCollection({
	loader: glob({ base: './src/content/updates', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		title: z.string(),
		date: z.coerce.date(),
		source: z.string(),
		url: z.string().url(),
		summary: z.string(),
		featured: z.boolean().default(false),
	}),
});

export const collections = {
	publications,
	projects,
	posts,
	updates,
};
