# Dashboard CATION

Lectura de todas las operaciones de CATION/ROARI (ventas, almacén y finanzas) en un solo lugar. Solo lectura: no corrige nada, cada alerta apunta a la app que sí puede (Seller, Almacén o Conciliador).

## Cómo funciona

- **Datos:** el mismo proyecto Supabase que Seller, Almacén y Conciliador. El dashboard **solo** llama a RPCs (`dash_acceso`, `dash_resumen`, `dash_salud`) que leen del esquema `analitica`. Nunca hace `SELECT` directo a tablas.
- **Reglas de conteo:** viven en `supabase/migrations/2026-10-12_analitica_fase0.sql` (pedidos TIENDA fuera, líneas rechazadas fuera, cobro de cuenta desde `hermes.pago`, etc.).
- **Acceso:** login con las cuentas de Supabase Auth; además la base exige que la cuenta esté en `analitica.acceso` (Ness y el gerente).
- **Fechas:** todo se agrupa por día en `America/La_Paz`.

## Puesta en marcha

1. Aplicar `supabase/migrations/2026-10-12_analitica_fase0.sql` en el SQL Editor (validada en `BEGIN…ROLLBACK`).
2. Copiar `.env.example` a `.env.local` y pegar la anon key del proyecto.
3. `npm install` y `npm run dev` → http://localhost:3000

En Vercel: mismas dos variables de entorno, sin pasos extra.

## Pantallas

| Ruta | Estado |
| --- | --- |
| `/` Resumen | Listo (Fase 1) |
| `/salud` Salud de datos | Listo (Fase 1) |
| `/ventas`, `/almacen` | Listo (Fase 2, migración `2026-10-12b_dash_ventas_almacen.sql`) |
| `/finanzas` | Fase 3 |
| `/auditoria` La Chismosa | Cuando La Chismosa suba al repo |

El efecto vidrio se apaga solo en equipos que no lo soportan o con "reducir transparencia"; también hay un botón "Modo liviano" en el menú.
