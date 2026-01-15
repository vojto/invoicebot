# Claude Instructions

## Environment Variables

When adding new environment variables to `.env`, always update `.env.example` with the new variable using a placeholder value. This keeps the example file in sync so other developers know which variables are required.

Example:
```
# .env (gitignored, contains real values)
NEW_API_KEY=sk-real-secret-key

# .env.example (committed, contains placeholders)
NEW_API_KEY=your-api-key-here
```
