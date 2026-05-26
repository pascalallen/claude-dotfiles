---
name: new-react-app
description: Scaffold a React + TypeScript app with Vite, Axios, ESLint/Prettier, and Docker/NGINX production serving
---

# New React App

Scaffold a production-ready React + TypeScript frontend. Serves via NGINX in Docker for production.

## Process

Ask the user:
1. **App name** (kebab-case, e.g. `admin-ui`) — used for package name and Docker image name
2. **API base URL** (e.g. `http://localhost:8080/api/v1`) — used in the Axios client config
3. **Styling approach**: CSS Modules (default) or Tailwind

Substitute `<app>` with the app name and `<api-base-url>` with the API base URL throughout all templates before writing files.

Note: When substituting `<app>` inside JSX (e.g. `<h1>`), write the app name as a plain string — not as an HTML/JSX tag.

## Directory Structure to Generate

```
src/
  components/
    ExampleCard.tsx
    ExampleCard.module.css  (CSS Modules) or omit (Tailwind)
  hooks/
    useExample.ts
  services/
    api.ts
  types/
    index.ts
  App.tsx
  main.tsx
public/
  vite.svg
Dockerfile
nginx.conf
index.html
vite.config.ts
tsconfig.json
tsconfig.node.json
package.json
postcss.config.js  (Tailwind only)
tailwind.config.js  (Tailwind only)
.eslintrc.cjs
.prettierrc
.gitignore
CLAUDE.md
.github/
  workflows/
    npm.yml
```

## File Templates

### `package.json`
```json
{
  "name": "<app>",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "lint": "eslint src --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "axios": "^1.7.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "eslint": "^8.57.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.0",
    "prettier": "^3.3.0",
    "typescript": "^5.4.0",
    "vite": "^5.3.0"
  }
}
```

If Tailwind was chosen, also add to devDependencies:
```json
"tailwindcss": "^3.4.0",
"postcss": "^8.4.0",
"autoprefixer": "^10.4.0"
```

### Tailwind config files (Tailwind variant only)

**`postcss.config.js`:**
```js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

**`tailwind.config.js`:**
```js
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

### `vite.config.ts`
```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
  },
})
```

### `tsconfig.json`
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

### `tsconfig.node.json`
```json
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
```

### `src/types/index.ts`
```ts
export interface ApiError {
  message: string
  status: number
}
```

### `src/services/api.ts`
```ts
import axios from 'axios'

const api = axios.create({
  baseURL: '<api-base-url>',
  headers: {
    'Content-Type': 'application/json',
  },
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    return Promise.reject(error)
  }
)

export default api
```

### `src/hooks/useExample.ts`
```ts
import { useState, useEffect } from 'react'
import api from '../services/api'

interface ExampleData {
  id: string
}

export function useExample(id: string) {
  const [data, setData] = useState<ExampleData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    api.get<ExampleData>(`/examples/${id}`)
      .then((res) => setData(res.data))
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false))
  }, [id])

  return { data, loading, error }
}
```

### `src/components/ExampleCard.tsx` (CSS Modules variant)
```tsx
import styles from './ExampleCard.module.css'

interface Props {
  id: string
  label: string
}

export function ExampleCard({ id, label }: Props) {
  return (
    <div className={styles.card}>
      <span className={styles.id}>{id}</span>
      <span className={styles.label}>{label}</span>
    </div>
  )
}
```

### `src/components/ExampleCard.module.css` (CSS Modules variant)
```css
.card {
  display: flex;
  gap: 0.5rem;
  padding: 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
}

.id {
  font-size: 0.75rem;
  color: #94a3b8;
}

.label {
  font-weight: 500;
}
```

### `src/components/ExampleCard.tsx` (Tailwind variant)
```tsx
interface Props {
  id: string
  label: string
}

export function ExampleCard({ id, label }: Props) {
  return (
    <div className="flex gap-2 p-4 border border-slate-200 rounded-lg">
      <span className="text-xs text-slate-400">{id}</span>
      <span className="font-medium">{label}</span>
    </div>
  )
}
```

### `src/App.tsx`
```tsx
function App() {
  return (
    <main>
      <h1><app></h1>
    </main>
  )
}

export default App
```

### `src/main.tsx`
```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

### `index.html`
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><app></title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

### `Dockerfile`
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

### `nginx.conf`
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;
}
```

### `.eslintrc.cjs`
```js
module.exports = {
  root: true,
  env: { browser: true, es2020: true },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react-hooks/recommended',
  ],
  ignorePatterns: ['dist', '.eslintrc.cjs'],
  parser: '@typescript-eslint/parser',
  plugins: ['react-refresh'],
  rules: {
    'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
  },
}
```

### `.prettierrc`
```json
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5"
}
```

### `CLAUDE.md` (project-level)
```markdown
# CLAUDE.md

## Overview

`<app>` is a React + TypeScript frontend built with Vite. Production-served via NGINX in Docker.

## Commands

```bash
npm run dev     # Start dev server (port 3000)
npm run build   # Type-check + build to dist/
npm run lint    # Run ESLint
```

## Structure

```
src/
  components/   — UI components (with props interfaces)
  hooks/        — custom React hooks (data fetching, state)
  services/     — Axios HTTP client + API calls
  types/        — shared TypeScript interfaces
```

## Key Patterns

- All API calls go through `src/services/api.ts` — never call axios directly in components
- Hooks own data fetching — components receive data as props or via hooks
- Strict TypeScript — no `any`, explicit interfaces for all API responses
```

### `.gitignore`
```
node_modules/
dist/
.env
.env.local
.env.*.local
```

### `.github/workflows/npm.yml`
```yaml
name: NPM

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm run lint
      - run: npm run build
```
