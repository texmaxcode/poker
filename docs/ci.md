# Continuous integration

GitHub Actions workflows live under [`.github/workflows/`](../.github/workflows/).

## `ci.yml` — desktop CI

| Job | When it runs | Purpose |
|-----|----------------|--------|
| **Linux** (`build-linux`) | Every **push**, **pull request**, and **workflow_dispatch** | Configure with Ninja, build, run `ctest`. |
| **Windows** | **main** / **stage** only (see below) | MSVC + vcpkg, `windeployqt`, ZIP artifact. |
| **macOS** | **main** / **stage** only (see below) | Ninja build, `macdeployqt`, DMG artifact. |

Windows and macOS jobs are **skipped** on other branches (e.g. feature branches) to save runner time and cache churn. They run when:

- The workflow is **workflow_dispatch** and the selected branch is **main** or **stage**, or
- **push** to **refs/heads/main** or **refs/heads/stage**, or
- **pull_request** whose **base** branch is **main** or **stage** (so PRs into those branches still validate packaging before merge).

## `build-snap.yml` — Linux snap

Builds the Snap when relevant paths change on **main**, **stage**, or **master** (see the workflow file for `paths` filters).

## `deploy-amplify-website.yml` — Amplify (Next.js site)

Runs on **push** to **main** or **stage** when **`website/`**, **`infra/`**, or **`amplify.yml`** change, and on **workflow_dispatch**. If **`infra/`** changed, it deploys the **CDK** stack `TexasHoldemGym-AmplifyHosting`. If **`website/`** or **`amplify.yml`** changed, it runs **`aws amplify start-job`** so the hosted app (and SSR) rebuilds. The public hostname (e.g. **texasholdemgym.com**) is configured in the AWS Amplify console under **Domain management**; the workflow only talks to AWS APIs.

## Local packaging

See [poker/packaging/README.md](../poker/packaging/README.md) for Windows, macOS, and Linux packaging commands.
