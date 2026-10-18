-- =============================================================================
-- HYGIES — SUPABASE DATABASE SETUP
-- =============================================================================
-- Paste this whole file into the Supabase SQL Editor of the NEW Hygies project
-- and press Run. It is safe to run once on an empty project.
--
-- Who can do what (enforced by the database itself, not the web page):
--   * Anyone can browse products and read reviews.
--   * Orders can ONLY be created through place_order(), which re-prices every
--     item and re-checks the discount code on the server.
--   * A guest can open an order only if they know its long random id (the link
--     in their email). A signed-in shopper sees their own orders.
--   * Only addresses listed in admin_emails (and confirmed) are admins.
-- To add another admin later:  insert into admin_emails values ('x@y.com');
-- =============================================================================

-- ------------------------------ admins ---------------------------------------
create table if not exists public.admin_emails (email text primary key);
alter table public.admin_emails enable row level security;   -- no policies: not readable from the web
insert into public.admin_emails (email) values ('iqnestofficial@gmail.com') on conflict do nothing;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from auth.users u
    join public.admin_emails a on lower(a.email) = lower(u.email)
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;

-- ------------------------------ profiles -------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text not null default '' check (char_length(name)  <= 80),
  phone      text not null default '' check (char_length(phone) <= 30),
  addresses  jsonb not null default '[]'::jsonb check (jsonb_typeof(addresses) = 'array' and jsonb_array_length(addresses) <= 5),
  wishlist   jsonb not null default '[]'::jsonb check (jsonb_typeof(wishlist)  = 'array' and jsonb_array_length(wishlist)  <= 100),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy profiles_select_own on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ------------------------------ price catalog --------------------------------
-- The server prices every order from this table (name + pack size, lower case).
-- weight '' = the price shown on shop listing cards. If you change a price on a
-- product page, change it here too (admin page -> Prices tab).
create table if not exists public.prices (
  name   text not null,
  weight text not null default '',
  price  integer not null check (price > 0),
  primary key (name, weight)
);
alter table public.prices enable row level security;
create policy prices_read  on public.prices for select to anon, authenticated using (true);
create policy prices_admin on public.prices for all    to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.prices (name, weight, price) values
  ('detox powder', '', 1000),
  ('detox powder', '1kg', 2200),
  ('detox powder', '250gm', 500),
  ('detox powder', '500gm', 1000),
  ('disturbed stomach tea', '', 1000),
  ('disturbed stomach tea', '1kg', 2200),
  ('disturbed stomach tea', '250gm', 500),
  ('disturbed stomach tea', '500gm', 1000),
  ('flu & fever tea', '', 1200),
  ('flu & fever tea', '1kg', 2400),
  ('flu & fever tea', '250gm', 600),
  ('flu & fever tea', '500gm', 1200),
  ('glowing powder', '', 1500),
  ('glowing powder', '1kg', 2700),
  ('glowing powder', '250gm', 750),
  ('glowing powder', '500gm', 1500),
  ('sliming powder', '', 1200),
  ('sliming powder', '1kg', 2700),
  ('sliming powder', '250gm', 750),
  ('sliming powder', '500gm', 1500),
  ('sliming tea', '', 1500),
  ('sliming tea', '1kg', 2700),
  ('sliming tea', '250gm', 750),
  ('sliming tea', '500gm', 1500),
  ('teeth whitening powder', '', 1400),
  ('teeth whitening powder', '100gm', 2800),
  ('teeth whitening powder', '25gm', 700),
  ('teeth whitening powder', '50gm', 1400),
  ('teeth whitening powder charcoal flavor', '', 1500),
  ('teeth whitening powder charcoal flavor', '100gm', 2900),
  ('teeth whitening powder charcoal flavor', '25gm', 800),
  ('teeth whitening powder charcoal flavor', '50gm', 1500),
  ('teeth whitening powder clove flavor', '', 1400),
  ('teeth whitening powder clove flavor', '100gm', 2800),
  ('teeth whitening powder clove flavor', '25gm', 700),
  ('teeth whitening powder clove flavor', '50gm', 1400),
  ('teeth whitening powder mint flavor', '', 1400),
  ('teeth whitening powder mint flavor', '100gm', 2800),
  ('teeth whitening powder mint flavor', '25gm', 700),
  ('teeth whitening powder mint flavor', '50gm', 1400)
on conflict (name, weight) do nothing;

-- ------------------------------ stock ----------------------------------------
create table if not exists public.products (
  key        text primary key,
  in_stock   boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.products enable row level security;
create policy products_read  on public.products for select to anon, authenticated using (true);
create policy products_admin on public.products for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- ------------------------------ coupons --------------------------------------
create table if not exists public.coupons (
  code         text primary key check (code = upper(code) and char_length(code) between 3 and 30),
  percent      integer not null check (percent between 1 and 100),
  applies_to   text[] not null default '{}',
  min_subtotal integer not null default 0 check (min_subtotal >= 0),
  active       boolean not null default true,
  expires_at   timestamptz,
  created_at   timestamptz not null default now()
);
alter table public.coupons enable row level security;       -- codes are not listable by shoppers
create policy coupons_admin on public.coupons for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Shoppers check one code at a time (cannot list the others).
create or replace function public.get_coupon(p_code text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('code', c.code, 'percent', c.percent, 'appliesTo', to_jsonb(c.applies_to), 'minSubtotal', c.min_subtotal)
  from public.coupons c
  where c.code = upper(btrim(p_code)) and c.active and (c.expires_at is null or c.expires_at > now());
$$;

-- ------------------------------ orders ---------------------------------------
create table if not exists public.orders (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references auth.users(id) on delete set null,   -- null = guest checkout
  items            jsonb not null,
  shipping         jsonb not null,
  payment_method   text  not null check (payment_method in ('COD','BANK','EASYPAISA','JAZZCASH')),
  payment_status   text  not null,
  payment_ref      text  not null default '' check (char_length(payment_ref) <= 120),
  coupon_code      text  not null default '',
  discount         integer not null default 0,
  subtotal         integer not null,
  shipping_fee     integer not null,
  total            integer not null,
  tracking_number  text  not null unique,
  courier_name     text  not null default '' check (char_length(courier_name) <= 60),
  courier_tracking text  not null default '' check (char_length(courier_tracking) <= 80),
  status           text  not null default 'Processing' check (status in ('Processing','Packed','Shipped','Delivered','Cancelled')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists orders_user_idx on public.orders (user_id, created_at desc);
alter table public.orders enable row level security;
create policy orders_select on public.orders for select to authenticated using (public.is_admin() or user_id = auth.uid());
create policy orders_admin_update on public.orders for update to authenticated using (public.is_admin()) with check (public.is_admin());
-- (no insert/delete policy on purpose: orders are created only by place_order())

-- A guest (or anyone holding the link) opens ONE order by its random id.
create or replace function public.get_order(p_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select to_jsonb(o) from public.orders o
  where o.id = p_id and (o.user_id is null or o.user_id = auth.uid() or public.is_admin());
$$;

-- Creates an order. Prices, the discount and shipping are all worked out HERE;
-- whatever the browser sends for those is only compared, never trusted.
create or replace function public.place_order(
  p_items jsonb, p_shipping jsonb, p_payment_method text, p_payment_ref text,
  p_coupon text default '', p_expected_total integer default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  c_free_from constant integer := 10000;   -- free shipping at or above this amount (after discount)
  c_ship_fee  constant integer := 250;
  it jsonb; clean jsonb := '[]'::jsonb;
  v_title text; v_base text; v_weight text; v_qty integer; v_price integer;
  v_sub integer := 0; v_elig integer := 0; v_disc integer := 0; v_ship integer; v_total integer;
  v_c public.coupons%rowtype; v_has_c boolean := false; v_kw text; v_match boolean;
  v_track text; v_id uuid; v_try integer := 0; v_k text;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 30 then
    raise exception 'EMPTY_CART: Your cart is empty or invalid.';
  end if;
  if p_payment_method not in ('COD','BANK','EASYPAISA','JAZZCASH') then
    raise exception 'BAD_PAYMENT: Unknown payment method.';
  end if;
  if p_shipping is null or jsonb_typeof(p_shipping) <> 'object' then
    raise exception 'BAD_SHIPPING: Missing delivery details.';
  end if;
  foreach v_k in array array['firstName','lastName','email','phone','street','city','country'] loop
    if coalesce(jsonb_typeof(p_shipping->v_k), '') <> 'string' or btrim(p_shipping->>v_k) = '' or char_length(p_shipping->>v_k) > 200 then
      raise exception 'BAD_SHIPPING: Please check your delivery details (%).', v_k;
    end if;
  end loop;

  -- 1) price every item from the catalog
  for it in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(it) <> 'object' or coalesce(jsonb_typeof(it->'quantity'), '') <> 'number' then
      raise exception 'BAD_ITEM: Invalid cart item.';
    end if;
    v_qty := floor((it->>'quantity')::numeric);
    if v_qty < 1 or v_qty > 99 then raise exception 'BAD_ITEM: Invalid quantity.'; end if;
    v_title  := left(coalesce(it->>'title',''), 200);
    v_base   := lower(btrim(case when position(' | ' in v_title) > 0 then split_part(v_title, ' | ', 1)
                                 else split_part(v_title, ' - ', 1) end));
    v_weight := case when v_title like '% - %' then lower(btrim(regexp_replace(v_title, '^.* - ', ''))) else '' end;
    select p.price into v_price from public.prices p where p.name = v_base and p.weight = v_weight;
    if not found then
      raise exception 'UNKNOWN_ITEM: "%" is not available. Please remove it from your cart.', v_title;
    end if;
    v_sub := v_sub + v_price * v_qty;
    clean := clean || jsonb_build_array(jsonb_build_object(
      'id', left(coalesce(it->>'id',''), 120), 'title', v_title, 'price', v_price,
      'quantity', v_qty, 'img', left(coalesce(it->>'img',''), 300)));
  end loop;

  -- 2) discount code (re-checked here)
  if coalesce(btrim(p_coupon), '') <> '' then
    select * into v_c from public.coupons c
      where c.code = upper(btrim(p_coupon)) and c.active and (c.expires_at is null or c.expires_at > now());
    if not found then raise exception 'BAD_COUPON: That discount code is not valid.'; end if;
    v_has_c := true;
    if v_c.min_subtotal > 0 and v_sub < v_c.min_subtotal then
      raise exception 'BAD_COUPON: Spend at least Rs % to use this code.', v_c.min_subtotal;
    end if;
    for it in select * from jsonb_array_elements(clean) loop
      v_match := cardinality(v_c.applies_to) = 0;
      if not v_match then
        foreach v_kw in array v_c.applies_to loop
          if position(lower(v_kw) in lower(it->>'title')) > 0 then v_match := true; end if;
        end loop;
      end if;
      if v_match then v_elig := v_elig + (it->>'price')::int * (it->>'quantity')::int; end if;
    end loop;
    v_disc := round(v_elig * v_c.percent / 100.0)::int;
    if v_disc <= 0 then raise exception 'BAD_COUPON: This code does not apply to anything in your cart.'; end if;
  end if;

  -- 3) shipping (free once the goods total AFTER any discount reaches the limit) and total
  v_ship  := case when v_sub - v_disc >= c_free_from then 0 else c_ship_fee end;
  v_total := v_sub - v_disc + v_ship;
  if p_expected_total is not null and p_expected_total <> v_total then
    raise exception 'PRICE_MISMATCH: Prices have changed. The correct total is Rs %. Please review your cart and try again.', v_total;
  end if;

  -- 4) save, with a friendly order number (retry on the rare clash)
  loop
    v_track := 'HYG' || lpad((100000 + floor(random() * 900000))::int::text, 6, '0');
    begin
      insert into public.orders (user_id, items, shipping, payment_method, payment_status, payment_ref,
                                 coupon_code, discount, subtotal, shipping_fee, total, tracking_number)
      values (auth.uid(), clean, p_shipping, p_payment_method,
              case when p_payment_method = 'COD' then 'Pay on delivery' else 'Awaiting payment check' end,
              left(coalesce(p_payment_ref, ''), 120),
              case when v_has_c then v_c.code else '' end, v_disc, v_sub, v_ship, v_total, v_track)
      returning id into v_id;
      exit;
    exception when unique_violation then
      v_try := v_try + 1;
      if v_try > 5 then raise; end if;
    end;
  end loop;

  return jsonb_build_object('id', v_id, 'trackingNumber', v_track, 'items', clean,
    'subtotal', v_sub, 'discount', v_disc, 'shippingFee', v_ship, 'total', v_total,
    'couponCode', case when v_has_c then v_c.code else '' end,
    'paymentStatus', case when p_payment_method = 'COD' then 'Pay on delivery' else 'Awaiting payment check' end);
end;
$$;

revoke all on function public.place_order(jsonb, jsonb, text, text, text, integer) from public;
revoke all on function public.get_order(uuid)  from public;
revoke all on function public.get_coupon(text) from public;
grant execute on function public.place_order(jsonb, jsonb, text, text, text, integer) to anon, authenticated;
grant execute on function public.get_order(uuid)  to anon, authenticated;
grant execute on function public.get_coupon(text) to anon, authenticated;
grant execute on function public.is_admin()       to anon, authenticated;

-- ------------------------------ reviews --------------------------------------
create table if not exists public.reviews (
  id          uuid primary key default gen_random_uuid(),
  product_key text not null check (char_length(product_key) <= 40),
  user_id     uuid not null references auth.users(id) on delete cascade,
  author      text not null default 'Customer' check (char_length(author) <= 80),
  rating      integer not null check (rating between 1 and 5),
  text        text not null default '' check (char_length(text) <= 1000),
  created_at  timestamptz not null default now(),
  unique (product_key, user_id)                          -- one review per shopper per product
);
create index if not exists reviews_product_idx on public.reviews (product_key);
alter table public.reviews enable row level security;
create policy reviews_read   on public.reviews for select to anon, authenticated using (true);
create policy reviews_insert on public.reviews for insert to authenticated with check (user_id = auth.uid());
create policy reviews_update on public.reviews for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy reviews_delete on public.reviews for delete to authenticated using (user_id = auth.uid() or public.is_admin());

-- ------------------------------ sign-ups & stock alerts ----------------------
create table if not exists public.subscribers (
  id         uuid primary key default gen_random_uuid(),
  contact    text not null check (char_length(contact) between 5 and 120),
  source     text not null default '' check (char_length(source) <= 60),
  created_at timestamptz not null default now()
);
alter table public.subscribers enable row level security;
create policy subscribers_insert on public.subscribers for insert to anon, authenticated with check (true);
create policy subscribers_admin  on public.subscribers for select to authenticated using (public.is_admin());
create policy subscribers_delete on public.subscribers for delete to authenticated using (public.is_admin());

create table if not exists public.stock_alerts (
  id          uuid primary key default gen_random_uuid(),
  product_key text not null check (char_length(product_key) <= 40),
  contact     text not null check (char_length(contact) between 5 and 120),
  created_at  timestamptz not null default now()
);
alter table public.stock_alerts enable row level security;
create policy stock_alerts_insert on public.stock_alerts for insert to anon, authenticated with check (true);
create policy stock_alerts_admin  on public.stock_alerts for select to authenticated using (public.is_admin());
create policy stock_alerts_delete on public.stock_alerts for delete to authenticated using (public.is_admin());

-- keep updated_at fresh
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger orders_touch   before update on public.orders   for each row execute function public.touch_updated_at();
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger products_touch before update on public.products for each row execute function public.touch_updated_at();
