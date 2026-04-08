# GitHub Actions → AWS Amplify (marketing site)

This guide walks through configuring the repository so **[`.github/workflows/deploy-amplify-website.yml`](../.github/workflows/deploy-amplify-website.yml)** can deploy the Next.js app in [`website/`](../website/) to **AWS Amplify Hosting** (`WEB_COMPUTE` / SSR).

The workflow does **not** set DNS or your public hostname. After a build succeeds, traffic uses whatever you configure in the Amplify console (for example **texasholdemgym.com** under **Domain management**).

---

## What runs automatically

| You change | Workflow does |
|------------|----------------|
| Files under **`infra/`** | Runs **AWS CDK** and deploys stack **`TexasHoldemGym-AmplifyHosting`**, which creates or updates the Amplify app and its GitHub connection. |
| Files under **`website/`** or root **`amplify.yml`** | Calls **`aws amplify start-job`** so Amplify runs a new build using the repo’s [`amplify.yml`](../amplify.yml) (`appRoot: website`). |
| **Manual** | **Actions** → **Deploy website (Amplify)** → **Run workflow** runs both paths (full CDK + start build). |

**Branches:** pushes to **`main`** and **`stage`** only (see the workflow file). Ensure an Amplify **branch** with the same name exists if you use **`stage`** (add it in the Amplify console if the CDK stack only created **`main`**).

---

## Prerequisites

1. **AWS account** with permission to use Amplify, CloudFormation, IAM roles CDK creates, etc.
2. **CDK bootstrap** in the target account and region (once):

   ```bash
   cd infra && ./scripts/bootstrap.sh
   ```

3. **GitHub:** admin access to the repository to add **Actions secrets** ([`Settings` → `Secrets and variables` → `Actions`](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository)).
4. A **GitHub Personal Access Token (PAT)** with at least the **`repo`** scope so AWS Amplify (via CDK) can clone the repository. Create it under GitHub → **Settings** → **Developer settings** → **Personal access tokens**.

---

## Repository secrets (exact names)

In the GitHub repo: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

| Secret name | What it is |
|-------------|------------|
| **`AWS_ACCESS_KEY_ID`** | Access key for an IAM user (or access key for an IAM role pattern your org uses) that can run CDK deploy and `amplify start-job`. |
| **`AWS_SECRET_ACCESS_KEY`** | Secret for the same identity. |
| **`AMPLIFY_GITHUB_PAT`** | The GitHub PAT above, stored as a secret. CDK passes it as `-c githubToken=…` when creating/updating the Amplify app so Amplify can pull from GitHub. **Not** the automatic `GITHUB_TOKEN` that Actions provides. |
| **`AMPLIFY_APP_ID`** | The Amplify **App ID** (short alphanumeric id). Required for the **Start Amplify build** job. See [Where to get `AMPLIFY_APP_ID`](#where-to-get-amplify_app_id) below. |

The workflow sets **`AWS_REGION`** to **`us-east-1`** by default. If your app lives in another region, edit the `env:` block in [`.github/workflows/deploy-amplify-website.yml`](../.github/workflows/deploy-amplify-website.yml) or add a follow-up change to use a [repository variable](https://docs.github.com/en/actions/learn-github-actions/variables).

---

## Where to get `AMPLIFY_APP_ID`

The CDK stack **creates** the Amplify app the first time it deploys successfully. The App ID **does not exist** until then.

1. **From CDK output (recommended)**  
   After **`TexasHoldemGym-AmplifyHosting`** deploys, the stack prints **`AmplifyAppId`** in the terminal (local deploy) or in the GitHub Actions log (job **CDK deploy**). Copy that value into **`AMPLIFY_APP_ID`**.

2. **From AWS Console**  
   **AWS Amplify** → select app **texas-holdem-gym-web** → **App settings** → **General** → **App ID**.

You only need to save this secret **once** (unless you recreate the app).

---

## Recommended first-time order

1. **Create** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and **`AMPLIFY_GITHUB_PAT`** in GitHub.

2. **Create the Amplify app with CDK** (either is fine):
   - **Option A — locally** (from repo root, with AWS CLI configured):

     ```bash
     cd infra
     npm ci
     export GITHUB_OWNER=your-org
     export GITHUB_REPO=your-repo-name
     export GITHUB_TOKEN=ghp_your_pat
     ./scripts/deploy-amplify.sh
     ```

   - **Option B — push a change under `infra/`** so the **Deploy website (Amplify)** workflow runs the CDK job.  
     You do **not** need **`AMPLIFY_APP_ID`** for this job.

3. From the deploy output or console, copy **`AMPLIFY_APP_ID`** into GitHub secrets.

4. **Push a change** under **`website/`** or **`amplify.yml`** (or use **workflow_dispatch**) so the **Start Amplify build** job runs. That job **requires** **`AMPLIFY_APP_ID`**.

5. In **Amplify Console** → your app → **Environment variables**, add everything the Next.js app needs at build/runtime (see [`website/.env.example`](../website/.env.example)): `DATABASE_URL`, `STRIPE_*`, `RESEND_*`, `ADMIN_*`, `NEXT_PUBLIC_*`, etc.

6. Optional: **Amplify** → **Domain management** — connect **texasholdemgym.com** (or another domain) and complete DNS as prompted.

7. Optional: **Stripe** — set the webhook URL to `https://<your-domain>/api/stripe/webhook`.

---

## IAM permissions (summary)

The credentials behind **`AWS_ACCESS_KEY_ID`** / **`AWS_SECRET_ACCESS_KEY`** must be allowed to:

- **Deploy CDK stacks** for `TexasHoldemGym-AmplifyHosting` (CloudFormation create/update, plus resources the stack defines: Amplify, IAM role for Amplify, etc.).
- **`amplify:StartJob`** (and typically **`amplify:GetApp`**, **`amplify:ListApps`**) for the **start-job** step.

Many teams use an IAM user with broader **PowerUser**-style permissions during setup, then narrow the policy. Exact least-privilege policies depend on your account guardrails.

---

## Troubleshooting

| Problem | What to check |
|---------|----------------|
| CDK job fails on **missing context** | **`AMPLIFY_GITHUB_PAT`** must be set; owner/repo come from the workflow automatically. |
| **Start Amplify build** fails | **`AMPLIFY_APP_ID`** missing or wrong region; branch name in Amplify must match **`main`** / **`stage`**. |
| Build succeeds but site errors | **Amplify** → **Environment variables**; compare with **`website/.env.example`**. |
| Domain does not load | **Domain management** and DNS at your registrar or Route 53 — not controlled by GitHub Actions. |
| Only **`infra/`** changed | Website stack updates; no **`start-job`** unless you also changed **`website/`** or **`amplify.yml`**. Run **workflow_dispatch** for a full refresh. |

---

## Related docs

| Document | Role |
|----------|------|
| [`infra/README.md`](../infra/README.md) | CDK stacks, local `deploy-amplify.sh`, download CDN stack |
| [`docs/ci.md`](ci.md) | Other workflows (desktop CI, snap) |
| [`amplify.yml`](../amplify.yml) | Amplify build phases (`npm ci`, `prisma generate`, `npm run build` in `website/`) |
