# A UX framework and web apps on top of the platform

Draft plan for a new repo that holds the club's shared UI components and its web apps. The apps run on
the platform: Directus in [cyc-seattle/platform](https://github.com/cyc-seattle/platform) is the
backend, and the planning engine is `@cyc-seattle/platform/planning`. Over time the repo replaces
the portal's look. Nothing here is built yet.

## Where things stand

Line references are to platform `main` at 779f3151 and isthmia `main` at the commit checked out on
2026-11-01.

- **The backend.** Directus 12.3.1 runs at `https://directus.<domain>` from platform's `backend`
  stack. Sign-in goes through Authentik in session mode (`stacks/backend/workloads.ts:44-55`).
  `CORS_ORIGIN` and `AUTH_AUTHENTIK_REDIRECT_ALLOW_LIST` name only the portal's origin, `https://<domain>`.
- **Who sees what.** Three roles (Community, Crew, Admin) plus groups that give policies
  ([cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6) decision 19). What a
  user sees is the same in the Data Studio, over MCP, and in any app (decision 20). Apps add no
  security of their own; Directus decides.
- **MCP.** Directus serves MCP at `/mcp` for every signed-in user (decision 16). It's the agent
  surface. People build task-specific views with their own agents over it.
- **The engine.** `computePlan` is pure TypeScript. Nothing under `src/planning/` imports Node or
  Pulumi, so it runs in a browser. The package declares `@pulumi/*` as required peer dependencies,
  though, so an app that installs it pulls in Pulumi too. Decision 17 says apps calculate a P&L
  when they need one, and store nothing.
- **Community reads.** Phase 3 of workplace#6 moves Community users off the item API onto a
  community endpoint extension (`/community/roster`, `/community/me`, step 17), and the portal
  roster moves to it (step 18). Any app a parent or coach uses calls that endpoint, not
  `/items`.
- **No schedule tool yet** (decision 24). Planners fill in offerings and activities through their
  agent over MCP. So the first planning screen people need is one that shows a plan, not one that
  edits it.

### The portal today

`isthmia/packages/portal` serves `cycsail.team`:

- A static link page from `src/links.ts`, rendered as a Caddy template. Staff-only sections check
  Authentik's `staff` group in the `X-Authentik-Groups` header (`src/render.ts:40-50`).
- Caddy puts Authentik's `forward_auth` in front of every page but `/welcome` (`Caddyfile`).
- One dynamic part, the roster ("My Teams"). It's plain TypeScript with no framework or bundler. It
  calls Directus from the browser with `credentials: "include"`. Directus's session cookie is
  host-only and `SameSite=Lax`, and `directus.<host>` is the same site as the page, so the cookie
  goes along and no token reaches the script (`src/roster/browser.ts:1-10`).
- If there's no session, it redirects to `directus.<host>/auth/login/authentik?redirect=<page>`,
  with a two-minute guard against redirect loops (`src/roster/auth.ts`). That pattern carries over
  as is.
- Its look is one inline stylesheet: system font, one blue accent, light and dark, cards on a white
  page. It works, but it has no type scale, no components, and nothing to share.

What to replace: the page chrome, the link list, and the roster UI. What to keep: the auth pattern,
the pure model/render split, and its tests.

### Earlier thinking

[research/2026-10-19-erp-and-frontend.md](2026-10-19-erp-and-frontend.md) planned a Next.js staff app
in isthmia with `packages/ui`, the server forwarding the Directus cookie, and server actions for
writes. workplace#6 then put staff screens aside in favor of MCP (its Alternatives). Two of that
plan's ideas still hold: shadcn on Base UI with Tailwind v4, and taking project-two's generic pieces
as patterns. Its server half doesn't: with every rule in Directus and a browser that already holds a
Directus session, an app server adds a thing to run and patch and protects nothing (isthmia#241
makes the same point).

## What makes project-two look good

project-two is a volunteer's staff-only Next.js app. It's private, so this describes its style in
general terms, to carry over the ideas, not the code.

- **Type.** One geometric sans, self-hosted, used for everything, headings included. A short scale:
  page titles at 2xl semibold with tight tracking, card titles at base medium, body and tables at
  sm, hints at xs muted. Weight and color do the work that size does elsewhere.
- **Color.** Neutral grays in OKLCH for nearly everything; black is the primary button. The page
  background is a faint cool wash, so white cards stand off it without heavy borders. Color is kept
  for meaning: success, warning, info and destructive are tuned to the same lightness and chroma, so
  no status pill shouts louder than another. Profit and loss color only the amount, never the row's
  label. Program colors are one shared map in code, never hex values at call sites. Full dark mode.
- **Density.** Desktop-dense but calm. Cards use a 16px inset (12px for small nested cards). Form
  fields flow in a grid that goes from 1 to 5 columns as the screen widens, rather than one long
  column. Tables are text-sm with fixed cell padding and a muted header wash.
- **Components.** shadcn's base-nova style on Base UI, lucide icons, sonner toasts. On top of that, a
  small set of pieces that make every page read the same: page header with a back link above the
  title, summary tiles with one big number each, a card shell with title, description, and actions,
  icon-only row actions with a named tooltip and one fixed icon per action, confirm and content
  dialogs, a sticky notice, and an info popover for "how is this calculated".
- **Layout rules, written down.** This is the main reason it stays consistent. A design skill for
  agents lists hard rules, and a live style-guide page shows every token and component:
  - actions on the right (easier on a phone)
  - inline "Add {thing}" rows at the top of a list, never below it
  - one way to save: explicit Save and Discard, with a warning before leaving unsaved changes
  - numbers right-aligned in tabular figures, with totals in a table footer
  - underline tabs for named sections, pill toggles only for a two-way view switch
  - ask before adding a new variant or component

  Agents write most of its code, and these rules are what keep them from inventing a fourth button
  style.

- **Charts.** Hand-drawn SVG in React components, with a shared tooltip and a chart card header
  whose explanation sits behind an info icon.

What not to carry over: the 1,000-plus-line client components, its own auth and service-role data
access, and charts hand-drawn in SVG (a library does this better, and accessibly).

## Recommendation

**Vite + React single-page apps, with TanStack Router and TanStack Query, on shadcn/ui (Base UI) and
Tailwind v4, served as static files from a small Caddy container on the club's GKE cluster. The
browser talks to Directus directly with its session cookie, and runs the planning engine itself.**

Why:

- **Nothing to secure in the app.** Every rule lives in Directus (decision 20). A static bundle has
  no secrets, no server to patch, and no session handling of its own. That's the portal roster's
  model, which already works in prod.
- **Cheapest to run.** A static Caddy pod needs a few millicores. The dev namespace's quota is tight.
  A Node server per app would need about 250m CPU and 512Mi each.
- **What agents write best.** Plain React, Vite, TanStack Query and Tailwind are the most common code
  in the training data. The newest server features (Next 16's Cache Components, TanStack Start 1.0,
  SvelteKit 3) are where agents go wrong most. shadcn components are source in the repo, so an agent
  reads and edits them rather than guessing at a library's API. shadcn and Storybook both ship MCP
  servers for agents.
- **Accessible by default.** Base UI is made by the people behind Radix, Floating UI and MUI, and
  has been stable since 1.0. It handles focus, keyboard, and ARIA for every overlay and control.
  shadcn made it the default in July 2026, and project-two already uses it, so its patterns transfer.
- **Phones.** Coaches and parents use phones on the dock. A static SPA loads once, and TanStack
  Query caches data, so going back is instant even on a weak signal. Server rendering would help
  only the first paint, and for a signed-in tool that's a small gain.
- **One design system, many apps.** Tailwind v4 tokens are plain CSS variables (`@theme`), so a
  shared `tokens.css` themes every app. The shared components live in one workspace package.

### Runner-up: React Router 8 in SPA mode

React Router 8 in framework mode with `ssr: false` builds to the same static files and serves the
same way. Its routing and data loading are conventions agents know well from Remix. It can turn on
server rendering later without a rewrite, if a public page ever needs it. It loses on two counts.
Its `clientLoader` split adds one more concept than TanStack Router with Query. Its yearly major
releases (v8 shipped in June 2026) mean a migration each year. Pick it if TanStack Router's type-heavy
generated route tree turns out to confuse agents in the first app.

### Rejected

- **Next.js 16** (project-two's choice). Its strengths are server components and server actions,
  which this design doesn't use. It means a Node server to patch: it's had critical React Server
  Components advisories, and monthly security releases since July 2026. Static export can't do
  dynamic routes without listing them at build time.
- **TanStack Start.** Stable only since 2026-10-13, with a security advisory already. Revisit in
  a year if an app needs a server.
- **SvelteKit, Nuxt.** Fine frameworks, but a new language for agents and the team, and project-two's
  patterns are React. Directus's own Data Studio being Vue doesn't help: apps don't extend it.
- **Astro.** Made for content sites with islands of interactivity. These are apps.
- **Mantine, Chakra.** Complete kits, but not Tailwind and not source in the repo. Agents fight a
  library's theme API more than they fight their own components.

## The stack

| Concern         | Choice                                                                              | Version on 2026-11-01 |
| --------------- | ----------------------------------------------------------------------------------- | --------------------- |
| Build           | Vite                                                                                | 8.3                   |
| UI              | React                                                                               | 19.2                  |
| Routing         | TanStack Router (file-based)                                                        | 1.170                 |
| Data            | TanStack Query over `@directus/sdk` (REST, session mode)                            | 5.105 / 27.1          |
| Components      | shadcn/ui on Base UI (`@base-ui/react`), lucide icons, sonner toasts                | CLI 4.23 / 1.9        |
| Styling         | Tailwind v4, tokens as CSS variables                                                | 4.3                   |
| Tables          | TanStack Table, only for big sortable tables. Plain shadcn `Table` for the rest     | 9.3                   |
| Forms           | react-hook-form with zod (what shadcn's form examples use)                          | 7.91                  |
| Charts          | shadcn charts, which are Recharts 3 with `accessibilityLayer` on                    | 3.10                  |
| Unit tests      | Vitest                                                                              | 5.0                   |
| Component tests | Storybook 10 with `addon-vitest` and the a11y addon, in Vitest browser mode         | 10.6                  |
| Journeys        | Playwright with `playwright-bdd` and `@axe-core/playwright`, against the dev deploy | 1.64                  |
| API mocks       | MSW                                                                                 | 3.0                   |
| Serving         | Caddy                                                                               |                       |

Sources: each package's npm registry entry on 2026-11-01, and
[shadcn's changelog](https://ui.shadcn.com/docs/changelog) for the Base UI default,
[InfoQ on Base UI 1.0](https://infoq.com/news/2026/02/baseui-v1-accessible/),
[Tailwind's `@theme`](https://tailwindcss.com/docs/theme),
[the Directus SDK guide](https://directus.com/docs/raw/guides/connect/sdk.md),
[Directus seamless SSO](https://directus.com/docs/raw/guides/auth/sso/seamless.md),
[TanStack Start 1.0](https://tanstack.com/blog/tanstack-start-1-0),
[React Router v8](https://remix.run/blog/react-router-v8),
[React Router SPA mode](https://reactrouter.com/how-to/spa),
[Next.js static export limits](https://nextjs.org/docs/app/guides/static-exports),
[Next.js blog (security releases)](https://nextjs.org/blog),
[Recharts API](https://recharts.github.io/en-US/api/),
[ECharts accessibility](https://echarts.apache.org/handbook/en/best-practices/aria),
[Vitest 4 browser mode](https://voidzero.dev/posts/announcing-vitest-4),
[Storybook blog](https://storybook.js.org/blog),
[DTCG 2025.10](https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/).

**Charts.** Most of a P&L is a table, and the table is the accessible view. Charts are a summary
above it: revenue against cost per offering, a waterfall from revenue to net, cost by account.
Recharts 3 covers these and is keyboard-navigable by default; it has a known VoiceOver gap
([recharts#4662](https://github.com/recharts/recharts/discussions/4662)), which is one more reason
every chart sits beside its table. ECharts is the fallback if a chart gets dense, since its
`aria.decal` patterns stop series depending on color alone.

**Tokens without a pipeline.** The DTCG token format reached its first stable version (2025.10), and
Style Dictionary 5 reads it. A tiny team doesn't need that yet: one hand-written `tokens.css` is the
source, in OKLCH, the same shape shadcn uses. Add Style Dictionary only if a second output appears
(email, a native app, a Figma file).

## Repo name

1. **`clubhouse`** (recommended). Plain, what a staffer would call the place they go to get things
   done, and it reads well as the package scope: `@cyc-seattle/clubhouse-ui`.
2. **`chartroom`**. Where a crew plans a passage. Fits planning and charts, but it's a sailing
   in-joke a new volunteer may not get.
3. **`apps`**. Says exactly what it is, and nothing more.

## Repo layout

A pnpm workspace, ESM, on `@cyc-seattle/ts-config`, like the other repos.

```text
clubhouse/
  apps/
    plans/              the first app: plan P&Ls (Plan Reader)
      src/routes/       TanStack Router file routes
      src/features/     page components, by feature
      src/model/        pure functions with Vitest tests, no React, no fetch
    team/               the second app: the portal's replacement (everyone)
  packages/
    ui/                 @cyc-seattle/clubhouse-ui
      src/tokens.css    every token, light and dark
      src/components/   shadcn components as adapted here
      src/patterns/     page header, summary tiles, row actions, P&L table...
      src/charts/       chart card and the chart wrappers
      .storybook/
    directus/           @cyc-seattle/clubhouse-directus
      src/client.ts     one client per app, session mode
      src/session.ts    sign-in redirect and its loop guard, from the portal
      src/schema.ts     the Directus schema's types
      src/community.ts  the community endpoint's client
      src/queries/      query options for TanStack Query, by collection
  features/             Gherkin journeys, steps in test/features/
  stacks/apps/          Pulumi: one WebService per app
  Dockerfile            builds every app; one Caddy image per app
  Caddyfile
  .agents/skills/design/SKILL.md   the design rules for agents
  docs/design.md        the same rules for people
```

- **Packages are private to the workspace** at first, and the apps import them from source. Publish
  `clubhouse-ui` only if an app outside this repo needs it.
- **One app per sign-in audience.** Staff tools that need the same policies go in one app with a
  nav; a new app is for a new audience or a new device (desk vs phone).
- **`src/model/` is the rule from project-two that works:** business logic in pure modules with
  tests, and components that only render.

## How apps sign in and call the backend

Every app follows the portal roster's pattern.

1. **Hosts.** Each app gets its own subdomain: `plans.<domain>`, `team.<domain>`. The Gateway already
   holds a wildcard certificate and DNS for `*.<domain>` (`platform/stacks/infra/gateway.ts:48-65`).
   So no new DNS or certificates are needed, and every app is the same site as `directus.<domain>`.
2. **Sign-in.** On load, the app asks Directus for `/users/me` with `credentials: "include"`. With no
   session, it sends the browser to
   `https://directus.<domain>/auth/login/authentik?redirect=<the page>`. Authentik signs them in
   (silently if they're already signed in), and Directus sets its session cookie and sends them back.
   The portal's two-minute loop guard moves into `packages/directus/src/session.ts`.
3. **The cookie.** Directus's session cookie stays host-only on `directus.<domain>` and `SameSite=Lax`.
   A fetch from `plans.<domain>` is same-site, so the browser sends it. JavaScript never sees a token.
   Directus's guide sets `SameSite=None` and a cookie domain for cross-site apps; same-site
   subdomains don't need either.
4. **Platform's part.** `CORS_ORIGIN` and `AUTH_AUTHENTIK_REDIRECT_ALLOW_LIST` become lists: the portal
   plus each app's origin. A `backend:appHosts` config in platform holds the names, so platform never
   reads this repo's outputs.
5. **Reads and writes.** `@directus/sdk` with `authentication("session", { credentials: "include" })` and
   `rest({ credentials: "include" })`, wrapped in TanStack Query. Writes go to the same item API as
   the user. A 403 shows a plain "you don't have access to this" page, never a blank screen.
6. **Community data.** Pages for parents, coaches and Parent Coordinators call the community endpoint
   (`/community/roster`, `/community/me`) once workplace#6 step 17 lands. They never read `/items` for
   CRM data. Until then, the `team` app's roster keeps the portal's current item reads.
7. **The engine.** The `plans` app loads a plan version's rows, the saved Operations Plan version it
   names, the catalog, and the organization through the SDK. Then it calls `computePlan` in the
   browser, in a Web Worker if a big plan makes the page stutter. It stores nothing (decision 17).
8. **MCP.** Apps don't call MCP. MCP is for people's agents; apps are for screens the club wants to
   keep. Both read Directus with the same user's access. An agent-built view that people keep using
   is a candidate to become a page here, and the agent that built it can port it, following the
   design skill.
9. **Types.** Directus has no official type generator. Generate `schema.ts` from platform's
   `schemas/*.yaml`, which are the source of truth, rather than from a live instance. See the open
   questions for where that generator lives.

**Local development.** `localhost` isn't the same site as `directus.dev.<domain>`, so the cookie won't
go along. Two modes:

- `pnpm dev` with MSW fixtures, for most UI work and for agents. Fixtures are synthetic, never prod
  data.
- `pnpm dev:remote`: Vite's dev server proxies `/directus` to dev Directus and adds the developer's
  own static token from a git-ignored `.env.local`. The token stays in the proxy and never reaches
  the bundle.

Every PR also deploys to dev, so the real sign-in is tested there.

## Design tokens

One `tokens.css`, OKLCH, light and dark. It starts from project-two's set, which is shadcn's, and
adds what the club's apps need.

- **Surfaces:** `background` (a faint cool wash), `card`, `popover`, `muted`, `accent`, `sidebar`.
- **Text:** `foreground`, `muted-foreground`, and a `*-foreground` for each filled surface.
- **Actions:** `primary`, `secondary`, `destructive`, `ring`, `border`, `input`.
- **Status:** `success`, `warning`, `info`, `destructive`, all at the same lightness and chroma.
- **Money:** `money-positive`, `money-negative`, `money-zero`, used only on amounts.
- **Brand:** `brand`, `brand-foreground`: the club's color, for the app bar and links. Neutral
  primary buttons stay neutral.
- **Charts:** `chart-1` to `chart-6`, checked for color-blind safety, plus program colors from data,
  never hard-coded.
- **Type:** `font-sans` (one self-hosted face with tabular figures), `font-mono`. Sizes are
  Tailwind's `xs` to `2xl`.
- **Shape and space:** `radius` with sm to xl derived from it, `card-spacing` (16px, 12px small).
- **Touch:** `tap-target`, a 44px minimum for anything a phone user taps (WCAG 2.5.5), used by every
  control in phone-first apps.
- **Density:** a `data-density="compact"` attribute on desk apps tightens table and form spacing.
  Phone apps keep the default.

## Components

From shadcn, adapted once in `packages/ui`:

- **Controls:** Button, Input, Textarea, Label, Select, Combobox, Checkbox, Radio Group, Switch,
  Toggle Group (the pill toggle)
- **Layout:** Card (with Title, Description, Action, Footer), Separator
- **Overlays:** Dialog, Sheet (the phone-friendly side panel), Popover, Tooltip, Dropdown Menu
- **Navigation:** Tabs (underline), Breadcrumb
- **Data:** Table (with numeric head and cell, footer)
- **Feedback:** Badge, Alert, Progress, Skeleton, Toaster

Patterns, the club's own, from project-two's ideas:

- **Page frame:** App Shell (top bar on desks, bottom bar on phones, with the user menu and sign-out),
  Page Header (title, description, back link, actions), Back Link
- **Numbers:** Summary Tiles and Metric Value, Money (cents shown as dollars, signed and colored)
- **Tables:** Row Actions (icon-only, from one fixed table of actions and icons, with a named
  tooltip), Empty State (one muted line)
- **Dialogs and notices:** Confirm Dialog, Content Dialog, Sticky Notice, Info Popover ("how is this
  calculated")
- **Forms:** Form Field Grid (1 to 5 columns), Save Bar (Save and Discard on the right, with the
  unsaved-changes warning)
- **Charts:** Chart Card (title, info icon, chart, and its table)
- **States:** No Access (a plain 403 page), Signed Out, Error Boundary
- **Links:** External Link

Domain components, built when the apps need them:

- **Plans:** P&L Table (accounts as rows, by offering or product, with per day and per sailor-day),
  Engine Warnings (the engine's `warnings`, in words a planner understands), Version Badge (draft,
  saved, active)
- **Team:** Roster List and Person Card (tap to call, text, or email, shown only when the person shared
  their contact information), Program Filter

Every component has a Storybook story, with light and dark, a phone width, and an axe check. The
stories are the style-guide page. The design skill points agents at them, and lists the hard rules
from project-two that still apply: actions on the right, explicit Save, numbers right-aligned in
tabular figures, ask before a new variant.

## Deployment

- **Image.** One Dockerfile builds every app, then copies each app's `dist/` into its own Caddy image.
  Caddy serves the files, falls back to `index.html` for routes, caches hashed assets for a year and
  `index.html` never, and sets security headers. The content security policy's `connect-src` allows
  only `self` and `directus.<domain>`.
- **No forward-auth.** The bundle holds nothing private (the repo is public anyway), and every piece of
  data comes from Directus as the user. So Caddy doesn't put Authentik in front, unlike the portal.
- **Pulumi.** `stacks/apps` declares one `WebService` per app from `@cyc-seattle/platform`, with
  requests around 10m CPU and 32Mi. Prod runs two replicas, spread across zones.
- **CI and deploys.** The same as isthmia: `.github`'s `ci.yml`, and `deploy.yml` for dev on every PR
  and prod after approval. Dev runs the image built for the commit, and prod runs that same image.
- **Elsewhere?** Static files could go on a bucket behind a CDN for even less. That means a second way
  of serving things, outside the Gateway and its certificate. The cluster already runs the portal the
  same way, so stay there.

## The first two apps

1. **`plans`: see a plan's P&L.** Planners plan 2027 now, through their agents over MCP (decisions 1
   and 24). What they lack is a steady place to see the result: pick a plan and a version, then see
   each offering's and product's P&L for the year, per day and per sailor-day, the shared costs, and
   the engine's warnings. Draft against saved, and later scenarios. It's read-only at first, for
   Plan Readers and Writers on a desk, so it's the cheapest way to prove the stack, the engine in the
   browser, and the auth. Editing comes after, one table at a time, once planners say which edits
   they'd rather do on a screen than through their agent.
2. **`team`: the portal, redone.** The link page and the roster in the new design, at `team.<domain>`,
   phone-first, for every signed-in user. It proves the phone side of the design system and replaces
   the portal's look. Its roster switches to the community endpoint once workplace#6 step 17 ships.
   When it's done, `cycsail.team` redirects to it, and isthmia's portal package retires.

## Steps

Each step is one PR or one maintainer action. A **features** PR is reviewed before the code that turns
it green.

**Phase 0, agreement.**

- [ ] 0. **[maintainer]** Pick the repo's name and settle the open questions. Post this plan as an
      issue in the new repo once it exists.
- [ ] 1. **platform PR, then [maintainer]**: the new repo in `stacks/bootstrap/github.ts`. Apply with
      `mise run deploy-bootstrap`. Add it to the workplace's `place.toml` (a workplace commit).

**Phase 1, the foundation.** Ships: an empty app shell on dev, signed in as yourself.

- [ ] 2. **platform PR**: mark the `@pulumi/*` peers optional (`peerDependenciesMeta`), so an app can
      install `@cyc-seattle/platform` for `planning` without Pulumi (`fix:`, which releases).
- [ ] 3. **platform PR**: `backend:appHosts`, which adds each app's origin to `CORS_ORIGIN` and
      `AUTH_AUTHENTIK_REDIRECT_ALLOW_LIST`, in dev and prod. Start with `plans` and `team`.
- [ ] 4. **repo PR**: the scaffold. pnpm workspace, mise, ts-config, eslint, Vitest, lefthook,
      renovate, `ci.yml`, AGENTS.md.
- [ ] 5. **repo PR**: `packages/ui`. Tokens, the shadcn components, Storybook with the a11y and Vitest
      addons, the design skill, and `docs/design.md`.
- [ ] 6. **repo PR**: `packages/directus`. The client, the sign-in redirect and loop guard (ported
      from the portal with its tests), the schema types, and MSW fixtures.
- [ ] 7. **repo PR (features)**: signing in to an app, and a user without access seeing a plain
      "no access" page, on `playwright-bdd` against dev.
- [ ] 8. **repo PR**: the `plans` app shell, the Dockerfile and Caddyfile, `stacks/apps`, and
      `pull-request.yml`. Deploys to dev and turns step 7 green.

**Phase 2, plans.** Ships: planners see any plan's P&L in prod.

- [ ] 9. **repo PR (features)**: a Plan Reader picks a plan and sees its P&L; someone without a Plan
      policy can't.
- [ ] 10. **repo PR**: the patterns the page needs (Page Header, Summary Tiles, Money, Chart Card, P&L
      Table, Engine Warnings), with stories.
- [ ] 11. **repo PR**: the plan list, version picker, and P&L page, with the engine running in the
      browser.
- [ ] 12. **[maintainer]** Deploy to prod. Add a link on the portal (isthmia PR).

**Phase 3, team.** Ships: the portal's replacement. The roster's last step waits for workplace#6
step 17.

- [ ] 13. **repo PR (features)**: the link page and the roster, on a phone-sized viewport.
- [ ] 14. **repo PR**: the `team` app: App Shell's phone layout, the link list, and the roster on today's
      item reads.
- [ ] 15. **repo PR**: the roster on the community endpoint, once it ships.
- [ ] 16. **isthmia PR, then [maintainer]**: `cycsail.team` redirects to `team.<domain>`. Retire the
      portal package, and drop the portal's origin from platform's lists (platform PR).

## Open questions

Each has a recommendation.

1. **The name.** Recommend `clubhouse`.
2. **One host per app, or one host with a path per app** (`apps.<domain>/plans`)? Recommend one
   host per app. Each deploys and rolls back alone, and the wildcard certificate already covers it.
   The cost is one line per app in platform's allow lists.
3. **Who generates the schema types?** Recommend platform. It publishes them as a
   `@cyc-seattle/platform/schema` subpath, generated from `schemas/*.yaml` in its build, so the
   syncs and the apps share one set. Until then, `packages/directus` generates its own from the
   same YAML files.
4. **Which engine version calculates a saved version?** A saved version records the platform version
   that calculated it. Recommend the app always calculates with the version it bundles, and shows a
   notice when a saved version's recorded version differs. Loading old engines side by side (npm
   aliases) only if planners ask to see old numbers exactly as they were.
5. **The club's color and typeface.** project-two's geometric sans and neutral palette work. Recommend
   keeping the neutral palette, adding one brand color from the club's existing logo, and choosing a
   self-hosted face that has tabular figures (check that the chosen face supports `tnum` before
   committing to it).
6. **Storybook, or a style-guide page in each app?** Recommend Storybook. It doubles as the component
   tests (Vitest browser mode with axe), and its MCP server lets agents look up components. project-two's
   in-app page is simpler, but its demos aren't tests.
7. **Dark mode.** Recommend yes, following the device's setting, as the portal does today. The tokens
   make it cheap, and coaches use phones in bright sun and at dusk.
8. **Does the `team` app keep Authentik's forward-auth in front?** Recommend no. Nothing in the bundle
   is private, and Directus's sign-in redirect already handles anyone not signed in. The portal's
   `staff`-group sections become sections shown by Directus role or policy, read from
   `/users/me` and `/permissions/me` as the roster already does. That's a display choice, not a
   security one, because the data behind each link is guarded where it lives.
9. **Where the plan for this lives.** The new repo owns the outcome, so the issue goes there once step
   1 makes it. Recommend opening it in the workplace repo first only if step 1 waits more than a week.
