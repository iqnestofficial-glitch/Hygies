# Hygies — setup guide (one-page shop · Supabase · GitHub Pages)

The whole shop is now **one file, `index.html`** (home, shop, product pages, blog, sign-in, checkout, orders … all inside it, like a single-page app), plus a separate **`admin.html`** for you and **`config.js`** for your settings. It runs on **Supabase** (database + sign-in) and is hosted free on **GitHub Pages**.

Parts A–D are required; E–G are strongly recommended before you take real orders.

---

## What's in the folder

| File / folder | What it is |
|---|---|
| `index.html` | The whole shop. Search it for `PAGE:` to jump between pages (each page is a `<template>` block), and for `THE SHOP'S CODE` for the program code. |
| `admin.html` | Your private dashboard (orders, prices, stock, coupons, reviews, sign-ups). |
| `config.js` | **Your settings** — Supabase keys, contact details, bank / Easypaisa / JazzCash details. The only file you normally edit. |
| `images/products/` | The new product pictures (compressed `.webp`) and logos. |
| `supabase.js` | The Supabase library (v2.45.4, MIT) saved next to the shop so it loads from your own site instead of waiting for a third-party server. Do not edit. |
| `supabase/schema.sql` | Everything to paste into Supabase once (Part A). |
| `supabase/update-free-delivery.sql` | Only if you **already** ran `schema.sql` earlier: paste this one small file to switch on the new "free delivery after discount" rule (safe to run more than once). |
| `tools/set-site-url.py` | Updates the web address in the search/social tags (Part C). |
| `.github/workflows/keepalive.yml` | Stops the free database from going to sleep (Part D). |
| `_backup/` | Your original pictures exactly as sent, plus a backup of the old multi-page site. **Do not upload this to GitHub** (the `.gitignore` already skips it). |

**Your existing `images/` folder:** keep the pictures you already have (`banner 1.png` … `banner 6.png`, `banner first 1.png`, `wb1.png` … `wb6.png`). The shop still uses them for the home slider and the blog. Just drop the new `images/products/` folder in beside them.

### Free delivery and coupons
Free delivery starts at **Rs 10,000** (change `freeShippingFrom` in `config.js`; also change `c_free_from` in `schema.sql`'s `place_order` so the database agrees). The amount is counted **after** any coupon or discount. The cart and checkout show a live line ("Add Rs 1,000 more for FREE delivery", then "You've unlocked FREE delivery") with a progress bar, and the green banner at the top of every page follows the same number. The server re-checks the rule when the order is placed, so the total a customer sees is the total they pay.

### Speed (measured, not guessed)
Home page, first visit, over the wire: about **1.2 MB -> about 0.35 MB** (27 -> 22 requests). What changed: two icon fonts (270 KB) replaced by the 9 icons actually used (about 3 KB, built in); logos converted to WebP (217 KB -> 19 KB); shop cards use the 480 px pictures; the animation library (GSAP, about 70 KB) replaced by a few lines of CSS; Poppins limited to the 6 weights used; the Supabase library served from your own site. Pictures that are off-screen load only when needed.
**The one big thing left is yours:** `banner 1.png` ... `banner 6.png`, `banner first 1.png` and `wb1-6.png` are probably 1-2 MB each as PNG. Send them to me and I'll convert them to WebP (typically 15-25x smaller), or convert them yourself at squoosh.app.

### How the addresses look now
Pages are reached with a `#` address, so nothing reloads when someone clicks around:
`index.html#/shop` · `#/teas` · `#/powders` · `#/oral-care` · `#/blog` · `#/contact` · `#/product/flu-fever-tea` · `#/product/disturbed-stomach-tea` · `#/product/sliming-tea` · `#/product/sliming-powder` · `#/product/detox-powder` · `#/product/glowing-powder` · `#/product/teeth-whitening-powder` (and `-mint`, `-clove`, `-charcoal`) · `#/checkout` · `#/orders` · `#/wishlist` · `#/profile`.
On GitHub Pages the shop's address is `https://YOUR-NAME.github.io/hygies/` and a product link is `https://YOUR-NAME.github.io/hygies/#/product/glowing-powder`. Share those links as normal.

---

## Part A — Create the database (Supabase)

1. Sign in at https://supabase.com with the new account and click **New project**.
   - Name: `Hygies` · Region: **South Asia (Mumbai)** · set a database password and save it somewhere safe.
   - Wait about 2 minutes until the project is ready.
2. Open **SQL Editor → New query**, paste the whole of `supabase/schema.sql`, and press **Run**. You should see "Success. No rows returned". This creates everything:
   - tables for orders, price list, coupons, stock, reviews, profiles, sign-ups;
   - security rules (shoppers only see their own data; only admins see all orders);
   - the order function that **re-checks prices and discount codes on the server**;
   - `iqnestofficial@gmail.com` as the shop admin. To add another admin later, run `insert into admin_emails values ('someone@gmail.com');`
3. Open **Settings → API** and copy two things: the **Project URL** and the **publishable (anon) key**. Do *not* copy or share the `service_role` / secret key.

## Part B — Sign-in settings (Supabase)

1. **Authentication → Providers → Email:** keep it enabled and keep **Confirm email** switched on (stops people signing up with someone else's address; also required for the admin check).
2. **Authentication → URL Configuration:**
   - **Site URL:** your shop address, e.g. `https://YOUR-NAME.github.io/hygies/` (you get this in Part D).
   - **Redirect URLs:** add `https://YOUR-NAME.github.io/hygies/**`.
   Confirmation, magic-link, Google and password-reset emails all send people back to the shop's front page, which then takes them to the right place.
3. **Important — email delivery:** Supabase's built-in email sender is only for testing (a handful of emails per hour, and only to your own team's addresses). Before real customers sign up, add your own email sender: **Authentication → Emails → SMTP Settings → Enable custom SMTP**.
   - Easiest: a Gmail account with an **App Password** (Google Account → Security → 2-Step Verification → App passwords). Host `smtp.gmail.com`, port `465`, username = the Gmail address, password = the 16-character app password, sender = the same Gmail address.
   - Alternative with a bigger free allowance: Brevo (300 emails/day) or Resend.
4. *Optional* — Google button: **Authentication → Providers → Google**, and follow Supabase's short guide to create a Google OAuth client. The callback URL to give Google is `https://saysntwvjkpwjmrxcode.supabase.co/auth/v1/callback`. Customers can use email without it.

## Part C — Connect the website to the database

Open **`config.js`** and fill in:

```js
SUPABASE_URL: "https://saysntwvjkpwjmrxcode.supabase.co",   // already filled in
SUPABASE_KEY: "sb_publishable_... or eyJ...",               // paste your publishable / anon key
```
Also replace the `[BRACKETED]` **bank / Easypaisa / JazzCash** details further down in the same file. These are shown to customers at checkout.

Once you know your final address (Part D), tell the search/social tags about it — from the site folder:

```bash
python3 tools/set-site-url.py https://YOUR-NAME.github.io/hygies
```
(The shop itself and its emails find their own address automatically; this only updates `index.html`'s canonical/social tags, `sitemap.xml` and `robots.txt`.)

## Part D — Put the site online (GitHub Pages)

1. On github.com create a new **public** repository named `hygies`.
2. Upload **everything in this folder except `_backup/`**: `index.html`, `admin.html`, `supabase.js`, `config.js`, `robots.txt`, `sitemap.xml`, `images/` (your existing pictures **plus** `images/products/`), `supabase/`, `tools/`, `.github/`, `.nojekyll`, `.gitignore`. Easiest: **Add file → Upload files**, drag them in, **Commit**.
3. **Settings → Pages →** Source: *Deploy from a branch* → Branch `main`, folder `/ (root)` → Save. After about a minute the site is live at `https://YOUR-NAME.github.io/hygies/`.
4. Go back to Part B step 2 and enter that address; run the `set-site-url.py` command from Part C; commit the changed files.
5. Every later change: edit/upload the file on GitHub and commit. Pages republishes automatically.

Why GitHub Pages and not Railway: the shop is a static site (no server code), so Pages is free and simpler. The repository is public, which is fine: nothing secret is in it (the publishable key is designed to be public). **Never** put a `service_role` key in the files.

*Keep-awake (recommended on the free plan):* Supabase pauses free projects after ~1 week with no activity. In the GitHub repo go to **Settings → Secrets and variables → Actions** and add `SUPABASE_URL` and `SUPABASE_KEY` (same two values as in `config.js`). The included `.github/workflows/keepalive.yml` then pings the database every 3 days. (A Supabase Pro plan avoids pausing altogether.)

## Part E — Emails to customers (EmailJS template)

Order confirmation, the alert to you, and the "shipped" email all use one EmailJS template. In EmailJS → Email Templates, edit `template_1lxa8ok`:

- **To email:** `{{to_email}}`
- **Subject:** `{{headline}} — {{order_number}}`
- **Content (HTML):** paste the block below.

```html
<div style="font-family:Arial,Helvetica,sans-serif;max-width:600px;margin:0 auto;color:#1e1e1e;">
  <div style="background:#79B933;height:8px;"></div>
  <h2 style="margin:24px 0 4px;">{{headline}}</h2>
  <p style="margin:0 0 16px;color:#555;">Hi {{customer_name}}, order <strong>{{order_number}}</strong></p>
  <p style="line-height:1.6;">{{intro_text}}</p>

  {{#courier_line}}
  <p style="background:#f3f9ea;border-radius:8px;padding:12px 14px;"><strong>{{courier_line}}</strong></p>
  {{/courier_line}}

  <table style="width:100%;border-collapse:collapse;margin:16px 0;">
    {{#items}}
    <tr>
      <td style="padding:8px 0;width:64px;"><img src="{{image_url}}" width="56" height="56" style="border-radius:8px;object-fit:cover;" alt=""></td>
      <td style="padding:8px;">{{title}}<br><span style="color:#777;font-size:13px;">Qty {{qty}} × {{price}}</span></td>
      <td style="padding:8px 0;text-align:right;">{{line_total}}</td>
    </tr>
    {{/items}}
  </table>

  <table style="width:100%;font-size:14px;">
    <tr><td>Subtotal</td><td style="text-align:right;">{{subtotal}}</td></tr>
    {{#discount_line}}<tr><td>Discount</td><td style="text-align:right;">{{discount_line}}</td></tr>{{/discount_line}}
    <tr><td>Shipping</td><td style="text-align:right;">{{shipping_fee}}</td></tr>
    <tr><td><strong>Total</strong></td><td style="text-align:right;"><strong>{{total}}</strong></td></tr>
  </table>
  <p style="font-size:14px;color:#555;">{{payment_line}}</p>

  <p style="font-size:14px;line-height:1.6;"><strong>Delivering to</strong><br>{{ship_name}}<br>{{ship_street}}<br>{{ship_city_country}}<br>{{ship_phone}}<br>Estimated delivery: {{delivery_estimate}}</p>

  <p style="margin:24px 0;">
    <a href="{{button1_url}}" style="background:#1e1e1e;color:#fff;text-decoration:none;padding:12px 22px;border-radius:6px;font-weight:bold;display:inline-block;">{{button1_label}}</a>
    <a href="{{button2_url}}" style="border:1.5px solid #1e1e1e;color:#1e1e1e;text-decoration:none;padding:10px 20px;border-radius:6px;font-weight:bold;display:inline-block;margin-left:8px;">{{button2_label}}</a>
  </p>
  <p style="font-size:13px;color:#777;">{{footer_note}}</p>
</div>
```

## Part F — First run: become admin and test

1. Open your site → **Sign In / Sign Up** → create an account with **iqnestofficial@gmail.com** (this is the admin address from the SQL) → click the confirmation link in the email → you land back on the shop, signed in. A **🛠️ Admin Dashboard** item now appears in your avatar menu (it opens `admin.html`).
2. In the admin page: **Discount codes → Fill 35% oral-care example → Save** creates `HYGIES35`.
3. Place a test order as a guest (cash on delivery) with one teeth-whitening item and the code. Check: you get the confirmation email, the owner alert email, and the order appears in **Admin → Orders**.
4. In the admin page mark it **Shipped**, add a courier tracking number, and tick "email customer": the shipped email goes out and the customer's tracking page updates.
5. Switch a product off under **Stock** and check its page shows "Out of stock" with the notify-me form. Switch it back on.

## Part G — Everyday use

- **Orders tab:** change status, mark payment received, enter courier name and tracking number, export CSV. For bank/wallet orders, confirm the money arrived (reference shown) before packing.
- **Prices tab — important:** the server prices every order from this list. **If you change a price on a product page, change it here too.** If they differ, checkout refuses the order and tells the customer the correct total, so you will notice quickly. New products must be added here as well (name in lower case + pack size, exactly as in the cart title).
- **Stock / Discount codes / Reviews / Sign-ups:** as in the tabs.
- **Editing the text or prices shown in the shop:** open `index.html` and search. Product names, sizes, prices, descriptions and picture lists are in one block — search for `slug: "flu-fever-tea"` (each product has one; the product cards on the shop pages carry their own price too, so search for the old price and change it everywhere). Page wording (home, contact, policies…) is in the `<template id="v-…">` blocks. Keep the "full title" format `Name | …` because checkout uses the part before `|` to find the price.
- **Adding blog posts:** search `index.html` for `hygiesBlogPosts` and add another entry in the same shape.

---

## What changed in this version

- **One page.** `Hygies.html`, the shop/category pages, ten product pages, blog, contact, sign-in, checkout, orders, tracking, profile, wishlist and the policy pages are all inside `index.html`. The header, cart and footer are written once. `admin.html` stays separate.
- **New product pictures** (from your batches 1–3): compressed, with a gallery on each product page. The originals are kept untouched in `_backup/`.
- **Sign-in:** email + password, **"email me a sign-in link"**, forgot-password reset, and optional Google. Email sign-up sends a confirmation email.
- **Prices and discount codes are checked on the server**, so a customer can no longer tamper with prices in the browser.
- Existing Firebase accounts and orders are **not** copied across: customers create new accounts. The old Firebase project is left untouched.
- The footer's old "payment gateways" picture was replaced by text chips (Cash on Delivery, Bank Transfer, Easypaisa, JazzCash) because the shop does not take cards.

## Things to know (honest limitations)

1. **Google search and single-page sites.** Because everything is one page with `#` addresses, Google indexes the shop's front page well but individual product pages are much weaker in search than separate pages would be (and per-product social-share previews show the home page's picture and text). If search traffic matters later, the pages can be split out again — a backup of the old multi-page site is in `_backup/old-multipage-site.zip`.
2. **No online card payments.** A real gateway needs a merchant account. Checkout offers cash on delivery plus manual bank/Easypaisa/JazzCash transfer with a reference number you verify.
3. **Stock switch** is enforced on product pages. The shop-list "Add" buttons and checkout don't check it.
4. **Courier tracking** shows the number you enter plus a link; there is no automatic live courier status.
5. **Urdu translation** is a text swap for the main interface strings and has not been proofread by a native speaker.
6. **Policy pages are generic templates** with `[placeholders]`. Fill them in and have them reviewed.
7. **Health wording.** The product descriptions say things like "cure your flu & fever in just less than 3-4 days" and some pack pictures print "Dentist Approved". Claims like these need to be supportable and can create legal/regulatory risk; please review the wording (and any registration number you want printed on packs) before launch.
8. **Allergen and dosage information** shown on product pages (ingredient lists, "gluten-free", dosage calculator) are placeholders written from the product names. They must be checked against your real formulation and labels.
9. **Sign-up spam:** the footer sign-up form and "notify me" form can be filled by anyone (no CAPTCHA); you can delete junk rows in the admin page. Add Supabase's CAPTCHA protection (Authentication → Attack Protection) if abuse appears.
10. **Tested:** the database rules were tested on a real Postgres, and the whole shopper and admin flow (guest order, coupon, tampered-price refusal, signed-in order, wishlist, review, profile, shipped email, stock, admin gate, page-to-page navigation, back button, cart, sign-in-link arrival and password-reset arrival) passed automated browser tests against a local copy of the database. I could **not** test the real Supabase sign-in emails, the Google button or the live GitHub Pages site, so do the Part F run-through after setup.
