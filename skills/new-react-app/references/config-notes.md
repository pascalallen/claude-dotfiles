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
  single quotes; `eslint-plugin-import` with TS resolver
- Custom **observable stores** (e.g. `AuthStore`) in `src/stores/` — subscribe/
  notify pattern, no Redux
- `jwt-decode`, `http-status-codes` as supporting libs

## Directory + alias conventions

```
src/
  app.tsx          entry — mounts router + providers
  assets/          images, scss
  components/      shared UI components
  domain/          TS domain types/models (mirror backend JSON)
  hooks/           custom hooks (data fetching wraps TanStack Query)
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

## Runtime config injection (mode 1 — no rebuilt-per-env bundles)

The bundle is environment-agnostic. The Go action serving the page marshals an
env map and injects it base64-encoded into the template:

```go
// application/http/action/default.go
var env = map[string]string{
	"APP_BASE_URL":    os.Getenv("APP_BASE_URL"),
	"APP_BASE_URL_WS": os.Getenv("APP_BASE_URL_WS"),
	"APP_ENV":         os.Getenv("APP_ENV"),
}
envBytes, _ := json.Marshal(env)
// template var: base64.StdEncoding.EncodeToString(envBytes) → <input id="script_config" value="...">
```

The frontend decodes it in `src/utilities/env.ts`:

```ts
const scriptConfig = JSON.parse(atob(`${document.getElementById('script_config')?.getAttribute('value')}`));

export enum EnvKey {
  APP_BASE_URL = 'APP_BASE_URL',
  APP_BASE_URL_WS = 'APP_BASE_URL_WS',
  APP_ENV = 'APP_ENV'
}

const env = (key: EnvKey): Json => scriptConfig[key];
export default env;
```

Add new runtime config by extending BOTH the Go env map and `EnvKey` — never by
baking values into the bundle at build time.

## Deltas to adjust per app

- `package.json`: `name`, `description`, `repository`; prune unused deps
  (moment/lodash/bootstrap-icons are carline legacy — omit unless needed).
- `webpack.config.js` output path: `../static/assets` in mode 1; `dist/` if
  standalone (then add `HtmlWebpackPlugin` + a static server or Docker/NGINX
  stage — only standalone apps need NGINX).
- `EnvKey` entries and the Go env map for the app's real config surface.
- Bootstrap theming: SCSS overrides in `src/assets`; keep `data-bs-theme`
  attribute switching.

## Conventions for new code

- Server state → TanStack Query hooks in `src/hooks/` (`useQuery`/`useMutation`
  wrapping `ApiService`); client/auth state → observable store.
- Route guards read the auth store; JWT lives with the store, refresh handled in
  the ApiService interceptor (single retry with `_retry` flag).
- Strict TS: explicit interfaces in `src/domain/` for every API payload; no `any`.
- Prettier owns formatting (120 cols, single quotes) — run `yarn lint:fix`.
- There are currently no frontend tests in the reference app; if the user wants
  tests, propose the toolchain rather than assuming one.
