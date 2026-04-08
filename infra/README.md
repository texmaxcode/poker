# AWS CDK — Texas Hold'em Gym

Infrastructure as code for:

1. **`TexasHoldemGym-DownloadAssets`** — private S3 bucket + CloudFront (OAC) for Windows/macOS installer files. Set `NEXT_PUBLIC_DOWNLOAD_BASE_URL` to the `NextPublicDownloadBaseUrl` output (HTTPS, no trailing slash).
2. **`TexasHoldemGym-AmplifyHosting`** — Amplify Hosting (`WEB_COMPUTE`) connected to GitHub for the Next.js app under `website/`. Requires `-c githubOwner`, `-c githubRepo`, `-c githubToken` (or deploy only the download stack first).

Monorepo build is defined in the repository root **`amplify.yml`** (`appRoot: website`).

## Prerequisites

- Node.js 20+
- AWS CLI configured (`aws sts get-caller-identity`)
- CDK bootstrap once per account/region: `./scripts/bootstrap.sh`

## GitHub Actions (Amplify website)

Workflow [`.github/workflows/deploy-amplify-website.yml`](../.github/workflows/deploy-amplify-website.yml) runs on pushes to **`main`** / **`stage`** when **`website/`**, **`infra/`**, or **`amplify.yml`** change. It **CDK-deploys** `TexasHoldemGym-AmplifyHosting` when `infra/` changes, and **starts an Amplify build** when the site or `amplify.yml` changes. Configure repository **secrets** listed at the top of that workflow (AWS keys, `AMPLIFY_GITHUB_PAT`, `AMPLIFY_APP_ID`). The live hostname (**e.g. texasholdemgym.com**) is set under Amplify → **Domain management**, not in the workflow file.

## Commands

| Action | Command |
|--------|---------|
| Synth | `npm run synth` or `./scripts/synth.sh` |
| Bootstrap | `./scripts/bootstrap.sh` |
| Deploy installers CDN only | `./scripts/deploy-downloads.sh` |
| Deploy Amplify only | `GITHUB_OWNER=… GITHUB_REPO=… GITHUB_TOKEN=… ./scripts/deploy-amplify.sh` |
| Deploy both | Same env as Amplify, then `./scripts/deploy-all.sh` |

Amplify stack synth/deploy example:

```bash
npx cdk synth -c githubOwner=myorg -c githubRepo=poker -c githubToken=ghp_xxx
```

## After deploy

1. **Download stack**: Upload builds to `s3://<bucket>/downloads/` (see `UploadExample` output). Paths must match `website/src/lib/downloads.ts`.
2. **Amplify**: In the AWS Amplify console, open the app → *Environment variables* — add `DATABASE_URL`, `STRIPE_*`, `RESEND_*`, `ADMIN_*`, `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_DOWNLOAD_BASE_URL`, etc. (see `website/.env.example`).
3. **Stripe webhook**: Point to `https://<your-domain>/api/stripe/webhook`.
4. **Custom domain**: Amplify → *Domain management*; for the download domain, use Route 53 or CNAME to the CloudFront domain from stack 1 if you serve installers on a separate hostname.

## Project layout

```
infra/
  bin/texas-holdem-gym-infra.ts   # CDK app entry
  lib/download-assets-stack.ts
  lib/amplify-hosting-stack.ts
  scripts/*.sh
```
