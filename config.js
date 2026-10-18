/* =========================================================================
   HYGIES — YOUR SETTINGS  (the only file you normally need to edit)
   =========================================================================
   index.html (the shop) and admin.html (the dashboard) both read this file,
   so you enter your keys once. Save it, upload it next to index.html.

   The publishable / "anon" key is MEANT to be public: what it can do is
   limited by the security rules in supabase/schema.sql. NEVER put the
   "service_role" / secret key in this file or anywhere on the website.
   ========================================================================= */
window.HYGIES_CONFIG = {

  /* Supabase dashboard -> Settings -> API */
  SUPABASE_URL: "https://saysntwvjkpwjmrxcode.supabase.co",
  SUPABASE_KEY: "sb_publishable_rndD5brTYbNOY32ralpKcw_B8ZmZRg2",

  /* Contact details / delivery rules. The shop's own web address is detected
     automatically, so there is no need to type it here. */
  SITE: {
    phoneDisplay: "0300 9236520",
    phoneIntl: "923009236520",          // for wa.me links, no + sign
    email: "iqnestofficial@gmail.com",
    freeShippingFrom: 10000,
    shippingFee: 250,
    deliveryEstimate: "3-5 business days"
  },

  /* Who SEES the admin button. The real protection is the admin_emails table
     in Supabase (supabase/schema.sql) — keep the two lists the same. */
  ADMIN_EMAILS: ["iqnestofficial@gmail.com"],

  /* Payment methods offered at checkout.
     type "cod"    = pay the courier on delivery.
     type "manual" = the customer sends money first, then types the reference
                     number; the order shows "Awaiting payment check" until you
                     verify it in the admin page. No card details are collected.
     Replace every [BRACKETED] value with your real account details. */
  PAYMENT_METHODS: [
    { id: "COD", label: "Cash on Delivery", type: "cod", note: "Pay the courier when your parcel arrives." },
    { id: "BANK", label: "Bank Transfer", type: "manual",
      note: "Transfer the total, then enter the transaction reference below.",
      details: [["Bank", "[BANK NAME]"], ["Account title", "[ACCOUNT TITLE]"], ["Account number / IBAN", "[ACCOUNT NUMBER OR IBAN]"]] },
    { id: "EASYPAISA", label: "Easypaisa", type: "manual",
      note: "Send the total, then enter the transaction ID below.",
      details: [["Account title", "[ACCOUNT TITLE]"], ["Easypaisa number", "[03XX XXXXXXX]"]] },
    { id: "JAZZCASH", label: "JazzCash", type: "manual",
      note: "Send the total, then enter the transaction ID below.",
      details: [["Account title", "Samina Kauser"], ["JazzCash number", "0322 7375474"]] }  ]
};
