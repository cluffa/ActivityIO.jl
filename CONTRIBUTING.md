# Contributing

## Commit / PR Process

1. **Branch off main** — `git checkout -b <short-description>`
2. **Make changes** — keep each PR focused on one thing
3. **Run tests locally** before pushing: `julia --project=. -e "using Pkg; Pkg.test()"`
4. **Open a PR against `main`** — CI runs automatically on all 3 platforms (Linux, macOS, Windows) using the latest stable Julia
5. **All CI checks must pass** before merging
6. **Squash-merge** into main with a descriptive commit message

## Commit Message Format

```
<type>: <short description>

<optional body>
```

Types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`

## What CI Checks

- `Pkg.test()` on ubuntu-latest, macos-latest, windows-latest (latest stable Julia)
