---
paths:
  - "web/app/**"
---

# Frontend conventions

- Path aliases (`@assets @components @domain @hooks @pages @routes @services
  @stores @types @utilities`) and their import order are enforced by
  `eslint-plugin-import` in `eslint.config.js` — don't add ad hoc relative
  imports (`../../services/X`) where an alias exists; `yarn lint` will flag
  the ordering even if the import itself works.
- **`request.ts`/`ApiService` façade rule**: nothing outside `src/services/`
  touches `ApiService` (or axios) directly. Components and hooks call a
  `src/services/*Service.ts` function; that function is the only thing that
  imports `ApiService`.
- Server state lives in TanStack Query hooks under `src/hooks/queries/`
  (`useQuery`/`useMutation` wrapping a service function) — don't fetch data
  with a bare `useEffect`.
- Runtime config is read through `src/utilities/env.ts`, never a build-time
  `process.env` reference — the bundle is environment-agnostic and reads its
  config from the injected `#script_config` payload at request time. See the
  `new-react-app` skill's `references/config-notes.md` for the full mechanism.
- Prettier owns formatting, not ESLint style rules — run `yarn lint:fix`
  rather than hand-formatting; the `prettier` PostToolUse hook auto-formats
  `.ts`/`.tsx`/`.scss` on save as a backstop, but don't rely on it instead of
  running the gate yourself.
- Tests mock the service layer (`jest.mock('@services/XService')`), never
  axios directly. Tests live beside the code they cover as `*.test.tsx` /
  `*.test.ts`, not in a parallel `__tests__/` tree.
- Full gate, in order: `yarn lint && yarn typecheck && yarn test && yarn build`.
  All four must pass before frontend work is done.
