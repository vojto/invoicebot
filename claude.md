# Claude Instructions

## Development Mode

This project is in active development. If necessary, you can wipe all data except for the `users` table, as everything else can be easily restored by syncing from Gmail.

## Dependencies

Ruby and Node versions are managed with [mise](https://mise.jdx.dev/). Run `mise trust` first, then `mise install` to install the correct versions. When updating language versions, edit `.mise.toml` (not `.ruby-version` or `.node-version`).

Do not set a local Bundler path (for example, do not run `bundle config set --local path vendor/bundle`). Use the default gem path from the active `mise` Ruby toolchain.

### Command Execution

Run Ruby/Bundler/Kamal commands through `mise exec -- ...` to avoid accidentally using system Ruby/Bundler.

## Testing

Use specs instead of tests for new coverage.

Keep all specs as simple as possible: focus on the core behavior, avoid over-mocking, and avoid unnecessary setup.

Use FactoryBot factories for test data instead of YAML fixtures.

## Git Workflow

After completing and verifying a task, automatically commit all working-tree changes and push the current branch. Run the commit and push in the background when possible, without waiting for a separate request. Report any failure to commit or push.

## Environment Variables

When adding new environment variables to `.env`, always update `.env.example` with the new variable using a placeholder value. This keeps the example file in sync so other developers know which variables are required.

Example:
```
# .env (gitignored, contains real values)
NEW_API_KEY=sk-real-secret-key

# .env.example (committed, contains placeholders)
NEW_API_KEY=your-api-key-here
```

## React Component Props

Use Zod schemas as the source of truth for props coming from Rails to React components. Define schemas in the same file as the component and infer TypeScript types from them.

Example:
```tsx
import { z } from "zod"

const PropsSchema = z.object({
  title: z.string(),
  count: z.number(),
  items: z.array(z.object({
    id: z.number(),
    name: z.string(),
  })),
})

type Props = z.infer<typeof PropsSchema>

export default function MyComponent(props: Props) {
  const { title, count, items } = PropsSchema.parse(props)
  // ...
}
```

## Deployment

Deployed via **Kamal** to `65.108.228.167` (Hetzner). Domain: `invoices.rinik.net`.

Three roles: `web` (Puma/Thruster), `job` (Solid Queue via `bin/jobs`), `cron` (whenever gem).

### Automatic Deployment

Every deployment-relevant push to `main` triggers `.github/workflows/deploy.yml`. Markdown-only, `docs/`, and root `screenshot.png` changes are ignored. The workflow:

1. Installs the Ruby and Node versions from `.mise.toml`.
2. Runs the TypeScript check and the full RSpec suite against PostgreSQL.
3. Verifies that all deployment secrets are present.
4. Builds and pushes the image to GHCR, then deploys all three roles with Kamal.
5. Requires `https://invoices.rinik.net/up` to return a successful response.

Deployments use the `production` concurrency group with `cancel-in-progress: false`. The running deployment is never cancelled by a newer push. GitHub retains at most one pending deployment, however, so a newer push can cancel and replace an older pending run; queued commits are not guaranteed to deploy individually.

#### Deployment Speed Optimizations

Added after reviewing automatic deploys #10 and #11 on 2026-07-20:

- The workflow caches the active mise Ruby's `Gem.dir` and `Gem.bindir`, keyed by `.mise.toml` and `Gemfile.lock`. Both paths are required: deploy #15 showed that caching only `Gem.dir` made Bundler skip installation while leaving executables such as `rspec` unavailable. The corrected cache uses the `ruby-gems-v2` prefix so it cannot restore that incomplete cache. If the cache causes Bundler problems, delete the GitHub Actions cache or remove the `Cache Ruby gems` step; do not configure a project-local Bundler path.
- PostgreSQL's service health check runs every 2 seconds instead of every 10 seconds. Retries were raised to preserve the previous total startup allowance. Revert the interval to 10 seconds if startup becomes flaky.
- Documentation-only pushes do not start a deploy. Markdown, docs, specs, and the root screenshot are also excluded from the Docker context where appropriate. Remove an ignore entry if one of those files becomes a production runtime dependency.
- The `cron` role uses a 2-second `stop_timeout`. The old cron container previously ignored the stop signal until Kamal force-killed it after 30 seconds, so this preserves the eventual forced-stop behavior with less waiting. Remove the override if cron shutdown behavior changes or running cron commands need a longer grace period.
- The Docker build writes dependency and application Bootsnap caches separately, then merges them into `/rails/tmp/cache/bootsnap` in the final image. This keeps the large dependency cache in a stable layer instead of retransferring it after every code change. If production boot reports missing or invalid Bootsnap cache entries, revert the separate `BOOTSNAP_CACHE_DIR` steps to the original `/rails/tmp/cache` precompile commands.

The registry-backed BuildKit cache remains in `mode=max`; npm installation, TypeScript, and RSpec were already fast enough that more caching was not justified.

After pushing ordinary completed application work to `main`, do not wait for the automatic deployment. Report the commit and push as complete without claiming that the change is deployed.

Wait for deployment only when subsequent work depends on it—for example, before running a production migration or data operation, when deployment-dependent verification or coordination is required, or when the user explicitly requests deployment confirmation. In those cases, find the run for the pushed commit and wait for it:

```bash
deploy_sha=$(git rev-parse HEAD)
gh run list --workflow Deploy --commit "$deploy_sha" --limit 1 \
  --json databaseId,status,conclusion,url
gh run watch RUN_ID --exit-status --interval 10
```

It can take a few seconds for a run to appear and several minutes for a pending or in-progress run to finish. When waiting is required, continue monitoring rather than starting a competing manual deploy.

If the run is cancelled because a newer pending run replaced it, fetch `origin/main` and check whether the newer branch still contains the pushed commit with `git merge-base --is-ancestor "$deploy_sha" origin/main`. When it does, wait for the newest `main` deployment instead of rerunning the obsolete commit. When it does not, investigate before claiming deployment. Always inspect the newest `main` run before claiming that current production is up to date.

If a deployment fails, inspect the failed step with `gh run view RUN_ID --log-failed`. Fix the root cause and push again, or rerun the failed workflow when the fix was an external configuration change such as a repository secret. Independently verify a successful deployment with:

```bash
curl --fail --show-error --silent https://invoices.rinik.net/up > /dev/null
```

Kamal uses a deployment lock. Never release a lock merely because a workflow is waiting. First check active and queued GitHub Actions runs and confirm whether another deploy is genuinely running. Check lock state with:

```bash
set -a; source .env; set +a
mise exec -- bin/kamal lock status
```

Release a lock only when it is demonstrably stale—for example, there is no matching active deployment, no Kamal process remains, and production containers show an abandoned partial rollout. Record that evidence before running `mise exec -- bin/kamal lock release`, then rerun or continue monitoring the affected workflow.

### Manual Deployment

Prefer the automatic workflow. Use a manual Kamal deploy only when explicitly needed and when no automatic deployment is active or queued.

Useful Kamal commands:
- `bin/kamal console` — Rails console on production
- `bin/kamal shell` — Bash shell on production
- `bin/kamal logs -r job` — Tail job processor logs
- `bin/kamal app exec 'bin/rails runner "SomeJob.perform_later"'` — Run a job

Before running Kamal deploy commands, export `.env` in the same shell session so `.kamal/secrets` variables are available:

```bash
set -a; source .env; set +a
mise exec -- bin/kamal deploy
```

## Key Jobs

- `TransactionSyncJob` — Syncs bank transactions via GoCardless/Nordigen. Runs every 12h.
- `PeriodicSyncAndProcessJob` — Syncs Gmail and processes invoices. Runs every 1h.
- Rake: `sync:transactions`, `sync:emails`, `sync:process`, `sync:all`

## Architecture

- Rails + Inertia.js + React frontend
- Solid Queue for jobs, Solid Cache for caching
- PostgreSQL database (shared on same server)
- Bank integration: GoCardless/Nordigen API
- Email sync: Gmail API with Google OAuth
