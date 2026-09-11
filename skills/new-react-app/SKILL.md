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
3. **Auth?** — if the Go service has JWT auth, scaffold `ApiService` with the
   full auth store + refresh/retry interceptor. If it has **no auth**
   (`portfolio-agent`-shaped service), use the **no-auth variant**: strip
   `ApiService` of the auth store, the 401 refresh/retry interceptor, `moment`,
   and `jwt-decode`; its `Options` shrink to `{ contentType?, timeoutMs? }`.
   Reference implementation: `pascalallen/portfolio-agent`
   `web/app/src/services/ApiService.ts`.

## Scaffold: copy the living config

```bash
mkdir -p web/app && cd web/app   # mode 1 (repo root for mode 2)

# Copy carline's frontend toolchain — these files ARE the convention:
cp ~/code/carline/web/app/package.json .          # then edit name/description/repository
cp ~/code/carline/web/app/webpack.config.js .
cp ~/code/carline/web/app/tsconfig.json .
cp ~/code/carline/web/app/eslint.config.js .
cp ~/code/carline/web/app/postcss.config.js .
cp ~/code/carline/web/app/.prettierrc.json .

# Trim dependencies the new app doesn't need yet (Stripe-ish extras, moment,
# lodash) but KEEP the core: react/react-dom 19, typescript, webpack 5 chain,
# @tanstack/react-query, react-router-dom 7, axios, bootstrap + react-bootstrap,
# @pascalallen/react-form-components, sass, eslint 9 flat + prettier.

yarn install
mkdir -p src/{assets,components,domain,hooks/queries,pages,routes,services,stores,types,utilities}
```

Then build out `src/` following the structure and conventions in
`references/config-notes.md` (entry `src/app.tsx`, `@`-prefixed path aliases,
TanStack Query for server state, observable store for auth — no Redux). Add the
Jest + Testing Library toolchain from `references/config-notes.md` § Frontend
tests — it is the default, not opt-in.

## Go side (mode 1)

- `web/template/index.tmpl` — flat template dir, loaded with
  `LoadHTMLGlob("web/template/*")`.
- `routes/file_server.go` — `engine.Static("/static", "./web/static")`.
- `NoRoute` → `action.HandleDefault()` (serves the SPA shell; see
  `references/config-notes.md` § Go serving gotchas for what it must NOT catch).
- Route group registration order matters: `Config → domain routes → Swagger (if
  any) → Fileserver → Default`.

## Docker

`bin/yarn` runs Yarn inside a `node:lts` container with cwd `web/app` (mirrors
`bin/exec` for the Go side). `bin/up` runs `bin/yarn build` before bringing the
stack up, so the served bundle is always current. In the Dockerfile, stage 1
builds the frontend bundle (Node image, `yarn install --frozen-lockfile && yarn
build`) and a later stage copies the built `web/static/` into the final image
alongside the Go binary.

## Verify

```bash
yarn lint        # ESLint 9 flat config + Prettier — MUST pass
yarn typecheck   # tsc --noEmit — MUST pass
yarn test        # Jest — MUST pass
yarn build       # production webpack build — MUST pass
yarn watch       # dev loop (mode 1: bin/up runs the Go server serving web/static)
```

Mode 1: confirm the Go template serves the built bundle and the runtime config
injection works (`window` config decoded from base64 JSON — see
`references/config-notes.md`). CI runs, in order: install (`--frozen-lockfile`)
→ lint → typecheck → test → build, alongside the Go checks.
