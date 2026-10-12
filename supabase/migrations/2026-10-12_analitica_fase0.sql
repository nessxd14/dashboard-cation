-- =====================================================================
-- Dashboard CATION — Fase 0: capa de lectura `analitica`
-- 2026-10-12
--
-- Crea:
--   analitica.acceso          quién puede leer el dashboard (Ness + gerente)
--   analitica.hecho_venta     una fila por línea vendida (retail + pedidos)
--   analitica.hecho_stock     una fila por movimiento de kardex, con origen
--   analitica.hecho_dinero    una fila por cobro (retail, cuenta) o egreso/ingreso de caja
--   public.dash_acceso()      true si el usuario actual puede ver el dashboard
--   public.dash_resumen(desde, hasta)  primer RPC de la pantalla Resumen
--
-- Reglas de conteo (ver doc "Dashboard CATION — Diseño"):
--   * Ventas: venta COMPLETADA + pedido no CANCELADO; pedidos TIENDA fuera
--     (reposición interna). Líneas RECHAZADO / RETIRADA fuera. Una línea
--     CAMBIADA lleva el dinero de su reemplazo (el reemplazo viene con
--     subtotal NULL); si el reemplazo trae su propio subtotal, manda el reemplazo.
--   * Stock: kardex clasificado por enlace (venta_linea / despacho / traslado),
--     nunca por el texto de `referencia`. Despachos de pedidos TIENDA =
--     REPOSICION_TIENDA (movimiento interno). Valor = precio de venta de la línea.
--   * Dinero: retail = venta_pago de ventas COMPLETADA; cuenta de cliente =
--     hermes.pago CONFIRMADO/ACREDITADO. movimiento_caja ANTICIPO y ANULACION
--     NO se suman (ya están representados en hermes.pago / en ventas anuladas).
--   * Fechas: día en America/La_Paz.
--
-- Solo lectura sobre tablas existentes. No modifica nada operativo.
-- =====================================================================

create schema if not exists analitica;
revoke all on schema analitica from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Acceso
-- ---------------------------------------------------------------------
create table if not exists analitica.acceso (
  perfil_id  uuid primary key references public.perfil(id) on delete cascade,
  nota       text,
  creado_en  timestamptz not null default now()
);
revoke all on analitica.acceso from public, anon, authenticated;

insert into analitica.acceso (perfil_id, nota) values
  ('06d97fe8-b246-4c82-99d5-f5e612b4bb60', 'Ness'),
  ('fdf2f198-c3e7-41ec-8dd9-321e19a44cd5', 'Rony (gerente)')
on conflict (perfil_id) do nothing;

-- ---------------------------------------------------------------------
-- hecho_venta
-- ---------------------------------------------------------------------
create or replace view analitica.hecho_venta as
select
  'RETAIL'::text                                         as origen,
  v.id                                                   as doc_id,
  v.numero                                               as doc_numero,
  vl.id                                                  as linea_id,
  v.creado_en                                            as momento,
  (v.creado_en at time zone 'America/La_Paz')::date      as fecha,
  case when u.codigo_zona = 'VENTAS DIRECTAS' then 'VTD' else 'MOSTRADOR' end as canal,
  v.cliente_id,
  coalesce(pf.nombre, v.creado_por)                      as vendedor,
  vl.producto_id,
  coalesce(vl.es_personalizado, false)                   as es_personalizado,
  coalesce(vl.descripcion, pr.nombre)                    as descripcion,
  pr.familia_id,
  vl.cantidad                                            as cantidad_base,
  vl.precio_lista,
  vl.precio_unitario,
  coalesce(vl.subtotal, 0)                               as monto,
  vl.cantidad                                            as cantidad_entregada,
  v.sesion_caja_id
from public.venta v
join public.venta_linea vl on vl.venta_id = v.id
join public.ubicacion u    on u.id = v.ubicacion_id
left join public.perfil pf on pf.id = v.vendedor_id
left join public.producto pr on pr.id = vl.producto_id
where v.estado = 'COMPLETADA'

union all

select
  'PEDIDO'::text,
  p.id,
  p.numero,
  pl.id,
  p.creado_en,
  (p.creado_en at time zone 'America/La_Paz')::date,
  p.categoria::text,
  p.cliente_id,
  p.creado_por::text,
  coalesce(r.producto_id, pl.producto_id),
  coalesce(r.es_personalizado, pl.es_personalizado, false),
  coalesce(r.descripcion, rp.nombre, pl.descripcion, pr.nombre),
  coalesce(rp.familia_id, pr.familia_id),
  coalesce(r.cantidad_base, pl.cantidad_base),
  pl.precio_lista,
  pl.precio_unitario,
  case
    when pl.estado = 'CAMBIADA' and coalesce(r.subtotal, 0) <> 0 then 0
    else coalesce(pl.subtotal, 0)
  end,
  coalesce(r.cantidad_despachada, pl.cantidad_despachada, 0),
  null::bigint
from public.pedido p
join public.pedido_linea pl     on pl.pedido_id = p.id
left join public.pedido_linea r on r.id = pl.reemplazada_por_id
left join public.producto pr    on pr.id = pl.producto_id
left join public.producto rp    on rp.id = r.producto_id
where p.estado <> 'CANCELADO'
  and p.categoria <> 'TIENDA'
  and pl.estado not in ('RECHAZADO', 'RETIRADA')
  -- el reemplazo sin precio propio ya está representado por su línea CAMBIADA
  and not (
    pl.subtotal is null
    and exists (select 1 from public.pedido_linea o where o.reemplazada_por_id = pl.id)
  );

-- ---------------------------------------------------------------------
-- hecho_stock
-- ---------------------------------------------------------------------
create or replace view analitica.hecho_stock as
select
  k.id                                                   as kardex_id,
  k.creado_en                                            as momento,
  coalesce(k.fecha_efectiva, (k.creado_en at time zone 'America/La_Paz')::date) as fecha,
  k.producto_id,
  pr.familia_id,
  k.ubicacion_id,
  u.sucursal_id,
  u.codigo_zona,
  k.tipo_movimiento::text                                as tipo,
  case
    when vl.id  is not null                              then 'VENTA_RETAIL'
    when pdm.id is not null and ped.categoria = 'TIENDA' then 'REPOSICION_TIENDA'  -- interno, no es salida de la empresa
    when pdm.id is not null                              then 'DESPACHO_PEDIDO'
    when k.traslado_grupo_id is not null
      or k.tipo_movimiento = 'TRASLADO'                  then 'TRASLADO'
    when k.tipo_movimiento = 'INV_INICIAL'               then 'INVENTARIO_INICIAL'
    when k.tipo_movimiento = 'AJUSTE'                    then 'AJUSTE'
    when k.tipo_movimiento = 'ENTRADA'                   then 'ENTRADA'
    else 'OTRO'
  end                                                    as origen,
  k.cantidad,                                            -- con signo, en unidad base
  -- Valor a precio de VENTA real de la línea que originó la salida.
  -- No se usa producto.precio_base: está por presentación, no por unidad base,
  -- y multiplicado por unidades base infla el valor (6,8 M Bs en 30 días).
  case
    when vl.id  is not null then vl.subtotal
    when pdm.id is not null and ped.categoria <> 'TIENDA' then
      coalesce(pel.subtotal, orig.subtotal) * pdm.cantidad_base / nullif(pel.cantidad_base, 0)
  end                                                    as valor_venta,
  vl.venta_id,
  pel.pedido_id,
  k.referencia,
  k.creado_por
from public.kardex_transacciones k
left join public.producto pr  on pr.id = k.producto_id
left join public.ubicacion u  on u.id = k.ubicacion_id
left join public.venta_linea vl on vl.kardex_transaccion_id = k.id
left join public.pedido_despacho_movimiento pdm on pdm.kardex_transaccion_id = k.id
left join public.pedido_despacho_evento pde on pde.id = pdm.evento_id
left join public.pedido_linea pel on pel.id = pde.pedido_linea_id
left join public.pedido ped       on ped.id = pel.pedido_id
-- si la línea despachada es el reemplazo de una CAMBIADA, el precio está en la original
left join public.pedido_linea orig on orig.reemplazada_por_id = pel.id and pel.subtotal is null;

-- ---------------------------------------------------------------------
-- hecho_dinero
-- ---------------------------------------------------------------------
create or replace view analitica.hecho_dinero as
-- Cobro de venta retail (mostrador / VTD)
select
  'COBRO_RETAIL'::text                                   as tipo,
  'venta_pago'::text                                     as fuente,
  vp.id                                                  as fuente_id,
  vp.creado_en                                           as momento,
  (vp.creado_en at time zone 'America/La_Paz')::date     as fecha,
  vp.metodo::text                                        as medio,
  vp.monto                                               as monto,
  v.cliente_id,
  v.id                                                   as venta_id,
  v.sesion_caja_id,
  vp.estado_verificacion                                 as estado
from public.venta_pago vp
join public.venta v on v.id = vp.venta_id
where v.estado = 'COMPLETADA'

union all

-- Cobro a cuenta de cliente (pedidos), sea por caja o por banco
select
  'COBRO_CUENTA',
  'hermes.pago',
  hp.id,
  coalesce(hp.confirmado_en, hp.creado_en),
  coalesce(hp.fecha_recepcion, (hp.creado_en at time zone 'America/La_Paz')::date),
  hp.medio::text,
  hp.monto,
  hp.cliente_id,
  null::bigint,
  null::bigint,
  hp.estado::text
from hermes.pago hp
where hp.estado in ('CONFIRMADO', 'ACREDITADO')

union all

-- Egresos e ingresos de caja (gasto, remesa, inyección)
select
  mc.tipo::text || '_' || coalesce(mc.subtipo, 'OTRO'),
  'movimiento_caja',
  mc.id,
  mc.creado_en,
  (mc.creado_en at time zone 'America/La_Paz')::date,
  mc.metodo::text,
  case when mc.tipo = 'EGRESO' then -mc.monto else mc.monto end,
  mc.cliente_id,
  mc.venta_id,
  mc.sesion_caja_id,
  null::text
from public.movimiento_caja mc
where mc.tipo in ('EGRESO', 'INGRESO');

revoke all on all tables in schema analitica from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- RPC: acceso
-- ---------------------------------------------------------------------
create or replace function public.dash_acceso()
returns boolean
language sql
stable
security definer
set search_path = public, analitica, pg_temp
as $$
  select exists (
    select 1
    from analitica.acceso a
    join public.perfil p on p.id = a.perfil_id
    where a.perfil_id = auth.uid() and p.activo
  );
$$;
revoke all on function public.dash_acceso() from anon, public;
grant execute on function public.dash_acceso() to authenticated, service_role;

-- ---------------------------------------------------------------------
-- RPC: resumen del período (pantalla Resumen)
-- ---------------------------------------------------------------------
create or replace function public.dash_resumen(p_desde date, p_hasta date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, analitica, pg_temp
as $$
declare
  r jsonb;
begin
  if not public.dash_acceso() and current_user <> 'service_role' then
    raise exception 'sin acceso al dashboard' using errcode = '42501';
  end if;
  if p_hasta < p_desde then
    raise exception 'rango inválido: % > %', p_desde, p_hasta;
  end if;

  select jsonb_build_object(
    'desde', p_desde,
    'hasta', p_hasta,
    'vendido_por_canal', (
      select coalesce(jsonb_object_agg(canal, monto), '{}'::jsonb)
      from (select canal, round(sum(monto), 2) monto
            from analitica.hecho_venta
            where fecha between p_desde and p_hasta
            group by canal) s),
    'vendido_total', (
      select coalesce(round(sum(monto), 2), 0)
      from analitica.hecho_venta where fecha between p_desde and p_hasta),
    'documentos', (
      select jsonb_build_object(
        'ventas_retail', count(distinct doc_id) filter (where origen = 'RETAIL'),
        'pedidos',       count(distinct doc_id) filter (where origen = 'PEDIDO'))
      from analitica.hecho_venta where fecha between p_desde and p_hasta),
    'cobrado_por_medio', (
      select coalesce(jsonb_object_agg(medio, monto), '{}'::jsonb)
      from (select medio, round(sum(monto), 2) monto
            from analitica.hecho_dinero
            where tipo in ('COBRO_RETAIL', 'COBRO_CUENTA') and fecha between p_desde and p_hasta
            group by medio) s),
    'cobrado_total', (
      select coalesce(round(sum(monto), 2), 0)
      from analitica.hecho_dinero
      where tipo in ('COBRO_RETAIL', 'COBRO_CUENTA') and fecha between p_desde and p_hasta),
    'egresos_caja', (
      select coalesce(jsonb_object_agg(tipo, monto), '{}'::jsonb)
      from (select tipo, round(sum(monto), 2) monto
            from analitica.hecho_dinero
            where tipo like 'EGRESO%' and fecha between p_desde and p_hasta
            group by tipo) s),
    'salidas_por_origen', (
      select coalesce(jsonb_object_agg(origen, jsonb_build_object(
               'unidades', unidades, 'valor_venta', valor)), '{}'::jsonb)
      from (select origen, round(sum(-cantidad), 2) unidades, round(sum(valor_venta), 2) valor
            from analitica.hecho_stock
            where cantidad < 0 and origen in ('VENTA_RETAIL', 'DESPACHO_PEDIDO', 'AJUSTE', 'OTRO')
              and fecha between p_desde and p_hasta
            group by origen) s),
    'cartera_por_cobrar', (
      select coalesce(round(sum(saldo_confirmado), 2), 0)
      from hermes.v_saldo_cliente where saldo_confirmado > 0)
  ) into r;

  return r;
end;
$$;
revoke all on function public.dash_resumen(date, date) from anon, public;
grant execute on function public.dash_resumen(date, date) to authenticated, service_role;
