# Continuous integration

GitHub Actions workflows live under [`.github/workflows/`](../.github/workflows/).

## `ci.yml` — desktop CI

| Job | When it runs | Purpose |
|-----|----------------|--------|
| **Linux** (`build-linux`) | Every **push**, **pull request**, and **workflow_dispatch** | Configure with Ninja, build, run `ctest`. |
| **Windows** | Same triggers as Linux | MSVC + vcpkg, `windeployqt`, ZIP artifact. |
| **macOS** | Same triggers as Linux | Ninja build, `macdeployqt`, DMG artifact. |

All three jobs share the workflow’s **`on:`** triggers; there are no branch-only skips for Windows or macOS.

## `build-snap.yml` — Linux snap

Builds the Snap when relevant paths change on **main**, **stage**, or **master** (see the workflow file for `paths` filters).

## `deploy-amplify-website.yml` — Amplify (Next.js site)

Runs on **push** to **main** or **stage** when **`website/`**, **`infra/`**, or **`amplify.yml`** change, and on **workflow_dispatch**. If **`infra/`** changed, it deploys the **CDK** stack `TexasHoldemGym-AmplifyHosting`. If **`website/`** or **`amplify.yml`** changed, it runs **`aws amplify start-job`** so the hosted app (and SSR) rebuilds. The public hostname (e.g. **texasholdemgym.com**) is configured in the AWS Amplify console under **Domain management**; the workflow only talks to AWS APIs.

**Full setup (secrets, first deploy, App ID):** [github-actions-aws-amplify.md](github-actions-aws-amplify.md).

## Local packaging

See [poker/packaging/README.md](../poker/packaging/README.md) for Windows, macOS, and Linux packaging commands.
