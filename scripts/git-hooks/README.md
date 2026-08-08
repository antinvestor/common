# Shared git quality gates

Part of **[antinvestor/common](https://github.com/antinvestor/common)** — same home as `Makefile.common`, workflow templates, and shared scripts.

Installs **pre-commit** and **pre-push** hooks so changes are **formatted/linted and fully tested** before they reach GitHub CI.

## Layout

```
scripts/git-hooks/
  pre-commit        # format/lint + full tests on commit
  pre-push          # full lint + tests before push
  install-all.sh    # copy hooks into repos under ~/code (or CODE_ROOT)
  README.md
```

## What runs

| Hook | When | Checks |
|------|------|--------|
| `pre-commit` | `git commit` | Format/lint, nested UI checks, then full `make test` / language fallbacks |
| `pre-push` | `git push` | Full lint + tests again (catches `--no-verify` commits) |

**Makefile targets** (preferred, matches CI / `Makefile.common`):

1. `format` or `fmt` (includes lint when using Makefile.common)
2. `lint` / `vet` when format is absent
3. `test` or `tests` or `check`

**Extras when Makefile only has `test` (e.g. some monorepos):**

- Staged-file `gofmt` + `golangci-lint` when `go.mod` is present
- Nested Node UI packages (`ui/app`, `ui/admin`, package roots of staged `.ts`/`.tsx`) with `lint` / `typecheck` / `prettier --check` to mirror UI CI

**Fallbacks** when there is no Makefile: Go, Dart/Flutter, Node, Python.

Commits that only touch non-source assets skip heavy checks.

Hook template version is in the file header (`Version: YYYY-MM-DD.N`). Re-run `install-all.sh` after pulling common.

## Install / refresh

From a checkout of this repo:

```bash
# All git repos under ~/code
./scripts/git-hooks/install-all.sh

# Preview
./scripts/git-hooks/install-all.sh --dry-run

# Only certain trees
./scripts/git-hooks/install-all.sh --only antinvestor,pitabwire,stawi

# One repo
./scripts/git-hooks/install-all.sh /path/to/service-notification
```

Environment overrides:

| Variable | Default | Meaning |
|----------|---------|---------|
| `CODE_ROOT` | `$HOME/code` | Tree to scan for git repos |
| `COMMON_ROOT` | parent of `scripts/` | This common checkout |

Each install copies hooks into `<repo>/.githooks/` and sets `git config core.hooksPath .githooks`.

Re-run after updating templates in this directory (or after pulling common).

## Policy

**Lint and test failures must be fixed before they leave the machine.**  
Pre-commit and pre-push hard-fail on lint/test errors so GitHub CI stays green.

## Escape hatches (emergency only)

```bash
# Both env vars required — SKIP_HOOKS alone is refused
ALLOW_SKIP_HOOKS=1 SKIP_HOOKS=1 git commit -m "emergency"
ALLOW_SKIP_HOOKS=1 SKIP_HOOKS=1 git push

git commit --no-verify   # git built-in; still blocked again by pre-push
PRECOMMIT_QUICK=1 git commit -m "..."   # lint only at commit; pre-push always full tests
```

## Committing hooks into a service repo (optional)

Installer updates are local by default. To share with teammates, commit `.githooks/` and document:

```bash
git config core.hooksPath .githooks
```

or re-run this installer after clone.

## Relationship to the Python `pre-commit` framework

Some repos also have `.pre-commit-config.yaml`. With `core.hooksPath=.githooks`, Git uses these scripts instead. That is intentional for one consistent gate across Ant Investor services.
