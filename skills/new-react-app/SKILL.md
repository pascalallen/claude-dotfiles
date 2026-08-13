---
name: new-react-app
description: Scaffold a React 19 + TypeScript frontend on the production carline stack — Webpack 5, Yarn, TanStack Query, React Router v7, Bootstrap 5 + react-bootstrap + @pascalallen/react-form-components, SCSS, ESLint 9 flat config + Prettier. Use when adding a web frontend to a Go service (default, served by the Go binary) or standing up a standalone React app.
---

# New React App

Scaffold a React + TypeScript frontend on Pascal Allen's production stack. The
ground truth is **carline's `web/app/`** (`~/code/carline/web/app`) — copy and
adapt its config rather than generating configs from memory or reaching for
Vite/CRA.

**Read `references/config-notes.md` before writing code** — it lists the exact
stack, path aliases, directory conventions, and the deltas to adjust per app.

## Two modes

1. **Frontend inside a Go service** (default — the carline/pascalallen.com
   pattern): the app lives at `web/app/`, Webpack emits into `web/static/`, and
   the Go binary serves `web/template/` with runtime config injected into the
   page as base64-encoded JSON. One deployable artifact, no NGINX sidecar, and
   the bundle stays environment-agnostic.
2. **Standalone SPA**: same toolchain at the repo root; only choose this when
   there is no Go backend in the same repo.

## Process

Ask the user:
1. **App name** (kebab-case) — package name (and Docker image name if standalone).
2. **Go service repo?** — determines mode 1 vs mode 2.
3. **API base URL / auth** — whether the JWT auth store + axios interceptor
   setup is needed from day one.

## Scaffold: copy the living config

```bash
mkdir -p web/app && cd web/app   # mode 1 (repo root for mode 2)

# Copy carline's frontend toolchain — these files ARE the convention:
cp ~/code/carline/web/app/package.json .          # then edit name/description/repository
cp ~/code/carline/web/app/webpack.config.js .
cp ~/code/carline/web/app/tsconfig.json .
cp ~/code/carline/web/app/eslint.config.js .
cp ~/code/carline/web/app/postcss.config.js .

# Trim dependencies the new app doesn't need yet (Stripe-ish extras, moment,
# lodash) but KEEP the core: react/react-dom 19, typescript, webpack 5 chain,
# @tanstack/react-query, react-router-dom 7, axios, bootstrap + react-bootstrap,
# @pascalallen/react-form-components, sass, eslint 9 flat + prettier.

yarn install
mkdir -p src/{assets,components,domain,hooks,pages,routes,services,stores,types,utilities}
```

Then build out `src/` following the structure and conventions in
`references/config-notes.md` (entry `src/app.tsx`, `@`-prefixed path aliases,
TanStack Query for server state, observable store for auth — no Redux).

## Verify

```bash
yarn lint        # ESLint 9 flat config + Prettier — MUST pass
yarn build       # production webpack build — MUST pass
yarn watch       # dev loop (mode 1: bin/up runs the Go server serving web/static)
```

Mode 1: confirm the Go template serves the built bundle and the runtime config
injection works (`window` config decoded from base64 JSON — see
`references/config-notes.md`). CI runs `yarn ci` (`--frozen-lockfile`) + lint +
build alongside the Go checks.
