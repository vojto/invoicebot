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
