-- Tabla para los "pases del día" (ingresos por día suelto, sin ser socio).
--
-- YA APLICADA en el proyecto "Fitness gym" (migración create_daily_passes).
-- Se conserva acá como referencia / para reconstruir el entorno.
-- Nota: en la base real, payment_method usa el ENUM `payment_method`
-- (no text) y la política RLS se llama `authenticated_full_access`, igual
-- que el resto de las tablas.
--
-- El precio del día NO se guarda acá: se guarda en el teléfono de la recepción
-- (rápido y sin internet). Si más adelante querés que el precio sea compartido
-- entre varios equipos, se puede mover a app_settings.

create table if not exists public.daily_passes (
  id             uuid primary key default gen_random_uuid(),
  first_name     text,
  last_name      text,
  phone          text,
  amount         integer not null,
  payment_method text    not null,
  created_at     timestamptz not null default now(),
  constraint chk_daily_amount check (amount > 0 and amount <= 100000000),
  constraint chk_daily_method check (payment_method in ('efectivo', 'tarjeta', 'transferencia', 'qr')),
  constraint chk_daily_names  check (
    (first_name is null or length(btrim(first_name)) <= 50) and
    (last_name  is null or length(btrim(last_name))  <= 50) and
    (phone      is null or length(btrim(phone))      <= 20)
  )
);

-- Para el cierre de caja y el resumen del día (filtran por fecha de cobro).
create index if not exists ix_daily_passes_created_at on public.daily_passes (created_at);

-- Seguridad: solo usuarios autenticados (mismo criterio que el resto de la app).
alter table public.daily_passes enable row level security;

create policy "daily_passes solo autenticados"
  on public.daily_passes for all
  to authenticated
  using (true)
  with check (true);
