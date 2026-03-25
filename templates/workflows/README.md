# Service Workflow Templates

Copy these files into your service's `.github/workflows/` directory.
No customization needed — they all reference reusable workflows from `antinvestor/common`.

| File | Triggers | What it does |
|------|----------|-------------|
| `ci.yaml` | Push to main, PRs | Build, test, lint |
| `release.yaml` | Tag `v*.*.*` | Docker images + BSR proto push |
| `dependabot.yaml` | Dependabot PRs | Auto-approve and merge |
| `auto-merge.yaml` | Labeled PRs, check completions | Merge PRs labeled `auto-merge` |
| `changelog.yaml` | PR opened | Generate changelog entry |
| `draft-release.yaml` | Push to main | Update draft release notes |
| `publish-release.yaml` | Scheduled (every 5 days) | Publish draft releases |

**Total: 7 small files instead of 10 large duplicated ones.**
