# React App Config Notes (carline stack)

Ground truth: `~/code/carline/web/app`. Copy its configs; this file records what
they encode and what to change per app.

## Stack (keep these exact choices)

- **React 19 + react-dom 19**, TypeScript 5 (strict via `@tsconfig/recommended`
  base + `noImplicitAny`, `alwaysStrict`, `isolatedModules`)
- **Webpack 5** + ts-loader + sass-loader/postcss-loader/css-loader +
  MiniCssExtractPlugin. Entry `src/app.tsx`; output `app.js`/`app.css` into
  `../static/assets` (mode 1). NOT Vite, NOT CRA.
- **Yarn** (`yarn ci` = `yarn install --frozen-lockfile`)
- **@tanstack/react-query v5** for server state; **axios** behind a single
  `ApiService` class (JSend-aware, JWT refresh-retry interceptor) — components
  never call axios directly
- **react-router-dom v7** with `createBrowserRouter` under `src/routes/`
- **Bootstrap 5.3 + react-bootstrap + @pascalallen/react-form-components** (his
  own form library), SCSS, `data-bs-theme="dark"`; icons via Font Awesome kit
- **ESLint 9 flat config (`eslint.config.js`) + Prettier** — 120 print width,
  single quotes; `eslint-plugin-import` with TS resolver. `eslint.config.js`
  imports `globals` directly, so it must be an explicit devDependency (not a
  transitive one) or the flat config throws at lint time.
- **`.prettierrc.json`**: `arrowParens: "avoid"`, `printWidth: 120`,
  `singleQuote: true`, `trailingComma: "none"`, `bracketSameLine: true`,
  `tabWidth: 2`, `semi: true`.
- Custom **observable stores** (e.g. `AuthStore`) in `src/stores/` — subscribe/
  notify pattern, no Redux
- `jwt-decode`, `http-status-codes` as supporting libs (`jwt-decode` only when
  the app has auth — see § Deltas)

## Directory + alias conventions

```
src/
  app.tsx          entry — mounts router + providers
  assets/          images, scss
  components/      shared UI components
  domain/          TS domain types/models (mirror backend JSON)
  hooks/queries/   TanStack Query hooks (useQuery/useMutation wrapping a service)
  pages/           route-level components
  routes/          createBrowserRouter config, route guards
  services/        ApiService (axios), WebSocket service
  stores/          observable stores (AuthStore, ...)
  types/           → alias to domain/types
  utilities/       env.ts, helpers
```

Path aliases — defined in BOTH `tsconfig.json` (`baseUrl: ./src`, `paths`) and
`webpack.config.js` (`resolve.alias`), keep them in sync:
`@assets @components @domain @hooks @pages @routes @services @stores @types @utilities`

## Frontend tests (default: Jest + Testing Library)

Jest is the default test runner — **not Vitest**, which drags in a Vite
toolchain this stack deliberately avoids.

DevDeps: `jest`, `jest-environment-jsdom`, `ts-jest`, `@types/jest`,
`@testing-library/react`, `@testing-library/dom`, `@testing-library/jest-dom`,
`@testing-library/user-event`, `identity-obj-proxy`.

`package.json` scripts: `"test": "jest"`, `"typecheck": "tsc --noEmit"`.

`jest.config.js` shape:
- `testEnvironment: 'jsdom'`
- `ts-jest` transform for `.ts`/`.tsx`
- `setupFilesAfterEnv: ['<rootDir>/src/test/jest.setup.ts']` — imports
  `@testing-library/jest-dom` and injects a `#script_config` input carrying a
  base64-encoded test config, so `utilities/env.ts` never throws under test.
- `moduleNameMapper` — MUST mirror every `tsconfig.json` path alias one-for-one
  (drift here is a silent "Cannot find module" per new alias), plus:
  - `\.(css|scss)$` → `identity-obj-proxy`
  - a static image stub (`__mocks__/fileMock.ts`) for image imports
  - ESM-only packages that break under `ts-jest` (`react-markdown`,
    `remark-gfm`) stubbed via `src/__mocks__/<package>.ts`
  - `axios` mapped to its CJS build (`axios/dist/node/axios.cjs`) if jsdom picks
    up the ESM browser export instead

`src/test/renderWithProviders.tsx` — a shared render helper: fresh
`QueryClient` per test with `retry: false` (no retry storms slowing failing
tests), wrapped in `MemoryRouter`.

**Rule: tests mock the service layer, never axios.** `jest.mock('@services/XService')`
— never `jest.mock('axios')` or a live HTTP call. Page-level tests cover
render, submit, pending, fail (JSend `fail`), and error (JSend `error`) states.

## Runtime config injection (mode 1 — no rebuilt-per-env bundles)

The bundle is environment-agnostic. The Go action serving the page marshals an
env map and injects it base64-encoded into the template. **Build the map inside
the handler, at registration time** — not as a package-level `var`:

```go
// application/http/action/default.go
func HandleDefault() gin.HandlerFunc {
	env := map[string]string{
		"APP_ENV":               os.Getenv("APP_ENV"),
		"AGENT_TIMEOUT_SECONDS": os.Getenv("AGENT_TIMEOUT_SECONDS"),
	}
	envBytes, _ := json.Marshal(env)
	encoded := base64.StdEncoding.EncodeToString(envBytes)

	return func(c *gin.Context) {
		c.HTML(http.StatusOK, "index.tmpl", gin.H{"ScriptConfig": encoded})
	}
}
```

A package-level `var env = map[string]string{...}` reads `os.Getenv` at Go
package-init time, which races `godotenv/autoload`'s own package init — carline
gets away with it only because of import-path ordering luck, not a guarantee.
Building the map inside `HandleDefault()` instead means the read happens when
`HandleDefault()` is *called* — i.e. at route registration in `main.go`, which
runs after `godotenv.Load()` has definitely completed. It is not deferred all
the way to request time: the closure returned by `HandleDefault()` captures
`encoded` once and reuses it for every request; only the wrapping call happens
after `.env` is loaded, not per-request.

Keys are **per app**, not a fixed set: carline uses `APP_BASE_URL`,
`APP_BASE_URL_WS`, `APP_ENV`; `portfolio-agent` uses `APP_ENV`,
`AGENT_TIMEOUT_SECONDS`. Derive the key set from the app's actual runtime
config surface.

The frontend decodes it in `src/utilities/env.ts`, **lazily and memoised** —
reading `#script_config` eagerly at module scope makes every module that
imports `env.ts` throw in a Jest/jsdom test that hasn't rendered the shell yet:

```ts
let scriptConfig: Json | undefined;

const readScriptConfig = (): Json => {
  if (!scriptConfig) {
    const raw = document.getElementById('script_config')?.getAttribute('value') ?? '';
    scriptConfig = JSON.parse(atob(raw));
  }
  return scriptConfig;
};

export enum EnvKey {
  APP_ENV = 'APP_ENV',
  AGENT_TIMEOUT_SECONDS = 'AGENT_TIMEOUT_SECONDS'
}

const env = (key: EnvKey): Json => readScriptConfig()[key];
export default env;
```

Add new runtime config by extending BOTH the Go env map and `EnvKey` — never by
baking values into the bundle at build time.

## Go serving gotchas

- `NoRoute` should serve the SPA shell (`c.HTML(200, "index.tmpl", ...)`) only
  for `GET`/`HEAD` requests whose path is **not** under `/api/` or `/static/`.
  API clients must keep getting the JSend 404 they expect, not an HTML shell.
- Gin's static handler (`engine.Static`) falls through to `NoRoute` on a
  missing static file — and it has already lazily written a 404 status to the
  response by the time it falls through. If `NoRoute` then calls
  `c.HTML(200, ...)` unconditionally, Gin logs a superseded-status warning and
  the client gets a 200 shell for a 404'd asset; check the path prefix before
  writing.
- `GIN_MODE` in `.env` is a no-op: gin reads `GIN_MODE` from the OS environment
  in a package `init()`, which runs before `godotenv/autoload` has loaded
  `.env`. Call `gin.SetMode(gin.ReleaseMode)` explicitly in `main.go` when
  `APP_ENV == "production"` instead of relying on `.env`.
- Test the router with `httptest` in `package routes`, using `t.Chdir("../../../..")`
  (or the correct relative depth) so `web/template` and `web/static` resolve
  from the test's working directory. Subtests: shell served at `/`; shell
  served for a deep client-side link; JSend 404 for `/api/*` paths; JSend 404
  for non-`GET` methods; a real static asset is served; a missing static asset
  → JSend 404, not the shell; Swagger (if mounted) wins over the shell for its
  path.
- Add a **tracked** `web/go.mod` (module `<module>/web`, `go <version>`, no Go
  code — just a boundary marker with a comment explaining why it's there).
  Without it, `go build/vet/test/list ./...` run from the repo root descends
  into `web/app/node_modules`, which ships stray `.go` files from vendored
  dependencies; the separate module stops `./...` expansion at the `web/`
  boundary. `gofmt` doesn't respect module boundaries at all, so its gates
  still need to target `cmd internal` explicitly (never `gofmt -l .`)
  regardless of `web/go.mod`.

## JSend fail-data shape

`FailResponseBody.data` is a `{ [field: string]: string }` map in carline
(field-level validation errors), but a plain `string` in simpler backends with
one flat fail message. Type `FailResponseBody['data']` to match the actual
backend responder, and make the shared `formatError` helper handle both shapes
rather than assuming carline's.

## Deltas to adjust per app

- `package.json`: `name`, `description`, `repository`; prune unused deps
  (`bootstrap-icons`, `moment`, `lodash`, `uuid` are carline legacy — omit
  unless the app actually needs them).
- `webpack.config.js` output path: `../static/assets` in mode 1; `dist/` if
  standalone (then add `HtmlWebpackPlugin` + a static server or Docker/NGINX
  stage — only standalone apps need NGINX).
- `EnvKey` entries and the Go env map for the app's real config surface.
- Bootstrap theming: SCSS overrides in `src/assets`; keep `data-bs-theme`
  attribute switching.
- `react-helmet-async`: only add it when pages need per-route `<title>`/meta
  tags — not a default dependency.

## Conventions for new code

- Server state → TanStack Query hooks in `src/hooks/queries/` (`useQuery`/
  `useMutation` wrapping a service function); client/auth state → observable
  store.
- Route guards read the auth store; JWT lives with the store, refresh handled in
  the ApiService interceptor (single retry with `_retry` flag) — auth apps only.
- Strict TS: explicit interfaces in `src/domain/` for every API payload; no `any`.
- Prettier owns formatting (120 cols, single quotes) — run `yarn lint:fix`.
- Jest + Testing Library is the default test toolchain (see § Frontend tests
  above) — scaffold it for every new app, not only on request. Tests mock the
  service layer, never axios.
