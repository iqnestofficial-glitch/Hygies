-- ============================================================================
-- Hygies — UPDATE: free delivery is now judged AFTER any coupon / discount
-- ----------------------------------------------------------------------------
-- Only needed if you ALREADY ran supabase/schema.sql before this change
-- (a fresh install of the new schema.sql already contains it).
-- Supabase -> SQL Editor -> New query -> paste this whole file -> Run.
-- Safe to run more than once. It only replaces the place_order() function.
-- Rule: goods total - discount  >=  10,000  ->  delivery is free (else Rs 250).
-- ============================================================================

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
grant execute on function public.place_order(jsonb, jsonb, text, text, text, integer) to anon, authenticated;
