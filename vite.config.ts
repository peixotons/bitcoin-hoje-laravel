import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import laravel from 'laravel-vite-plugin';
import { resolve } from 'node:path';
import { defineConfig } from 'vite';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.tsx'],
            ssr: 'resources/js/ssr.tsx',
            refresh: true,
        }),
        react(),
        tailwindcss(),
    ],
    esbuild: {
        jsx: 'automatic',
    },
    resolve: {
        alias: {
            'ziggy-js': resolve('./vendor/tightenco/ziggy'),
            '@': resolve('./resources/js'),
        },
    },
    server: {
        host: '0.0.0.0',
        port: 5173,
        hmr: {
            port: 5173,
            host: 'localhost',
        },
        watch: {
            // Disable polling for better performance
            usePolling: false,
            // Ignore files that don't need watching
            ignored: [
                '**/node_modules/**',
                '**/vendor/**',
                '**/storage/**',
                '**/public/build/**',
                '**/.git/**',
            ]
        },
        cors: true,
    },
    build: {
        // Build optimizations
        target: 'es2020',
        minify: 'terser',
        terserOptions: {
            compress: {
                drop_console: true,
                drop_debugger: true,
            },
        },
        rollupOptions: {
            output: {
                manualChunks: {
                    'react-vendor': ['react', 'react-dom'],
                    'inertia-vendor': ['@inertiajs/react'],
                    'ui-vendor': ['@headlessui/react', '@radix-ui/react-slot'],
                },
            },
        },
        // Enable CSS code splitting
        cssCodeSplit: true,
        // Generate source maps only for development
        sourcemap: false,
        // Chunk size warnings
        chunkSizeWarningLimit: 1000,
    },
    optimizeDeps: {
        include: [
            'react',
            'react-dom',
            '@inertiajs/react',
            '@headlessui/react',
            'lucide-react',
        ],
        exclude: ['@tailwindcss/vite'],
    },
    clearScreen: false,
});
