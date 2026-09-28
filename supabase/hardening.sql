-- Endurecimiento de seguridad del lado servidor (Supabase / Postgres).
--
-- NO APLICADO TODAVÍA. Revisar contra el esquema real antes de correrlo
-- (el proyecto estaba pausado cuando se escribió y no se pudo inspeccionar).
--
-- Por qué: la app ya valida todo, pero la clave "publishable" viaja dentro de
-- la app y cualquiera puede usarla para hablarle directo a la API. Lo único que
-- protege los datos de verdad son RLS + estas restricciones en la base.

-- 1) RLS activado en todas las tablas (sin políticas = nadie accede).
alter table public.members            enable row level security;
alter table public.membership_periods enable row level security;
alter table public.plans              enable row level security;
alter table public.app_settings       enable row level security;
alter table public.stock_products     enable row level security;
alter table public.stock_lots         enable row level security;
alter table public.stock_sales        enable row level security;

-- Revisar que las políticas existentes exijan usuario autenticado, p. ej.:
--   create policy "solo admin" on public.members for all to authenticated
--     using (true) with check (true);
-- y que NO haya políticas para el rol "anon". Además, en Auth → Settings,
-- desactivar "Allow new users to sign up": si está activo, cualquiera puede
-- crearse una cuenta y pasar a ser "authenticated".
--
-- Las vistas (v_member_status, v_stock_status, etc.) deben ser
-- "security_invoker = on" para respetar el RLS de las tablas:
--   alter view public.v_member_status set (security_invoker = on);

-- 2) Valores imposibles bloqueados en la base (NOT VALID = no revisa datos viejos).
alter table public.membership_periods
  add constraint chk_period_amounts check (base_price > 0 and trainer_price >= 0 and base_price <= 100000000 and trainer_price <= 100000000) not valid,
  add constraint chk_period_days    check (days_per_week between 1 and 7) not valid,
  add constraint chk_period_dates   check (end_date > start_date) not valid;

alter table public.plans
  add constraint chk_plan_price check (price > 0 and price <= 100000000) not valid,
  add constraint chk_plan_days  check (days_per_week between 1 and 7) not valid,
  add constraint chk_plan_name  check (length(btrim(name)) between 1 and 60) not valid;

alter table public.members
  add constraint chk_member_name check (length(btrim(full_name)) between 3 and 100) not valid,
  add constraint chk_member_dni  check (dni is null or dni ~ '^[0-9]{5,10}$') not valid;

alter table public.stock_products
  add constraint chk_product_values check (servings_per_unit between 1 and 1000 and sale_price_per_serving > 0 and low_stock_threshold >= 0) not valid;

alter table public.stock_lots
  add constraint chk_lot_values check (units_purchased between 1 and 500 and unit_cost > 0) not valid;

alter table public.stock_sales
  add constraint chk_sale_values check (servings between 1 and 100 and sale_price >= 0) not valid;

-- 3) Un DNI no puede repetirse entre socios activos.
--    Falla si ya hay duplicados: buscarlos antes con
--    select dni, count(*) from public.members where deleted_at is null and dni is not null group by dni having count(*) > 1;
create unique index if not exists ux_members_dni_active on public.members (dni) where deleted_at is null and dni is not null;

-- 4) Fotos de socios: hoy se sirven con URL pública (cualquiera con el link las ve).
--    Recomendado: bucket privado + createSignedUrl en la app, límite de tamaño
--    y solo tipos de imagen:
--   update storage.buckets set public = false, file_size_limit = 5242880,
--     allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic']
--   where id = 'member-photos';
