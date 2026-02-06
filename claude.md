# Claude Instructions

## Development Mode

This project is in active development. If necessary, you can wipe all data except for the `users` table, as everything else can be easily restored by syncing from Gmail.

## Dependencies

Ruby and Node versions are managed with [mise](https://mise.jdx.dev/). Run `mise install` to install the correct versions. When updating language versions, edit `.mise.toml` (not `.ruby-version` or `.node-version`).

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
