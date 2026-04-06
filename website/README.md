# Texas Hold'em Gym — Marketing Website

Production-ready Next.js 15 marketing and sales site for the **Texas Hold'em Gym** desktop app.

- **Framework**: Next.js 15 (App Router, TypeScript)
- **Styles**: Tailwind CSS — dark poker/casino theme
- **Payments**: Stripe Checkout (one-time $79)
- **Email**: Resend (transactional download links)
- **Database**: PostgreSQL + Prisma (purchase records, analytics events)
- **Downloads**: AWS S3 + CloudFront CDN
- **Admin** (`/admin`): visits & click analytics, Stripe status, refunds

---

## Project Structure

```
src/
├── app/
│   ├── page.tsx                     # Landing page
│   ├── layout.tsx                   # Root layout (Nav + Footer)
│   ├── globals.css
│   ├── features/page.tsx
│   ├── pricing/page.tsx
│   ├── buy/page.tsx                 # Buy button page
│   ├── success/page.tsx             # Post-payment download page
│   ├── download/page.tsx            # Public download page
│   ├── privacy/page.tsx
│   ├── terms/page.tsx
│   ├── contact/page.tsx
│   └── api/
│       ├── checkout/route.ts
│       ├── stripe/webhook/route.ts
│       ├── analytics/track/route.ts
│       └── admin/                   # login, logout, stats, purchases, refund, stripe-config
├── admin/                           # Protected UI (JWT cookie)
├── components/
│   ├── SiteChrome.tsx               # Nav/Footer + analytics (skips /admin)
│   ├── AnalyticsTracker.tsx
│   ├── Nav.tsx
│   ├── Footer.tsx
│   └── BuyButton.tsx
└── lib/
    ├── stripe.ts
    ├── prisma.ts
    ├── admin-auth.ts
    ├── admin-api.ts
    ├── email.ts
    └── downloads.ts
middleware.ts                        # Protects /admin
prisma/
└── schema.prisma
public/
└── screenshots/                     # App screenshots used on site
```

---

## Setup

### 1. Install dependencies

```bash
cd website
npm install
```

### 2. Configure environment

```bash
cp .env.example .env.local
```

Fill in all values in `.env.local` (see comments in `.env.example`).

**Admin panel:** set `ADMIN_JWT_SECRET` (≥16 random characters) and `ADMIN_PASSWORD`. Open `/admin`, sign in, then use **Visits & clicks**, **Purchases & refunds**, and **Stripe**.

### 3. Set up the database

```bash
# Push schema to your Postgres database
npm run db:push

# Or run migrations (production)
npm run db:migrate
```

Generate the Prisma client:

```bash
npm run db:generate
```

### 4. Configure Stripe

1. Create a Stripe account at [stripe.com](https://stripe.com)
2. Copy your **Secret Key** from the Stripe dashboard
3. Set up a webhook endpoint pointing to `https://your-domain.com/api/stripe/webhook`
4. Listen for the event: `checkout.session.completed`
5. Copy the **Webhook Signing Secret** to `STRIPE_WEBHOOK_SECRET`

### 5. Configure Resend

1. Create an account at [resend.com](https://resend.com)
2. Verify your sending domain
3. Create an API key and set `RESEND_API_KEY`
4. Set `FROM_EMAIL` to a verified sender address

### 6. Upload app files to S3

Upload the three platform builds to your S3 bucket:

```
s3://your-bucket/downloads/texas-holdem-gym-windows.exe
s3://your-bucket/downloads/texas-holdem-gym-mac.dmg
s3://your-bucket/downloads/texas-holdem-gym-linux.AppImage
```

Then set `NEXT_PUBLIC_DOWNLOAD_BASE_URL` to your CloudFront distribution URL.

---

## Development

```bash
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000).

To test Stripe webhooks locally, use the Stripe CLI:

```bash
stripe listen --forward-to localhost:3000/api/stripe/webhook
```

---

## Production Deployment

### Vercel (recommended)

```bash
vercel --prod
```

Add all environment variables in the Vercel dashboard under **Settings → Environment Variables**.

### Other platforms (Render, Railway, Fly.io, etc.)

```bash
npm run build
npm start
```

Set all environment variables in your platform's config panel.

---

## Database Schema

- **Purchase** — email, Stripe session id, optional payment intent id, amount, refund fields (`refundedAt`, `stripeRefundId`).
- **AnalyticsEvent** — `PAGE_VIEW` / `CLICK`, name, path, referrer, user agent, IP, optional JSON metadata.

After pulling changes, run `npm run db:push` (or migrate) so new columns/tables exist.

---

## Payment Flow

1. User clicks **Buy Now**
2. `POST /api/checkout` creates a Stripe Checkout session
3. User redirected to Stripe-hosted checkout page
4. After payment: redirect to `/success?session_id=...`
5. Stripe fires `checkout.session.completed` webhook to `/api/stripe/webhook`
6. Webhook stores purchase in DB and sends download email via Resend
7. `/success` page shows download buttons immediately (no server-side validation required — user is already redirected there)

---

## Customisation

| Thing to change | Where |
|---|---|
| Price | `src/lib/stripe.ts` → `PRODUCT_PRICE_CENTS` |
| Product name | `src/lib/stripe.ts` → `PRODUCT_NAME` |
| Download file names | `src/lib/downloads.ts` |
| Email copy | `src/lib/email.ts` |
| Brand colours | `tailwind.config.ts` → `colors.gold` |
| Nav links | `src/components/Nav.tsx` |
| FAQ answers | `src/app/page.tsx` → `FAQS` array |
