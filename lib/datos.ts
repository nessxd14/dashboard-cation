import "server-only";
import { cache } from "react";
import { crearClienteServidor } from "./supabase/server";
import type { IndicadorSalud, Resumen } from "./tipos";

/** Error con un mensaje que se puede mostrar tal cual en pantalla. */
export class ErrorDatos extends Error {
  constructor(
    message: string,
    public tipo: "sin_acceso" | "sin_migracion" | "otro",
  ) {
    super(message);
  }
}

function traducir(error: { code?: string; message: string }): ErrorDatos {
  if (error.code === "42501") {
    return new ErrorDatos("Tu cuenta no tiene acceso al dashboard.", "sin_acceso");
  }
  // PGRST202: la función no existe en el schema cache → la migración no está aplicada.
  if (error.code === "PGRST202" || /could not find the function/i.test(error.message)) {
    return new ErrorDatos(
      "La capa analitica todavía no está aplicada en la base (migración 2026-10-12_analitica_fase0.sql).",
      "sin_migracion",
    );
  }
  return new ErrorDatos(error.message, "otro");
}

/** ¿El usuario actual puede ver el dashboard? (Ness y el gerente). */
export const tieneAcceso = cache(async (): Promise<boolean> => {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("dash_acceso");
  if (error) throw traducir(error);
  return data === true;
});

export const usuarioActual = cache(async () => {
  const supabase = await crearClienteServidor();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
});

export async function obtenerResumen(desde: string, hasta: string): Promise<Resumen> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("dash_resumen", { p_desde: desde, p_hasta: hasta });
  if (error) throw traducir(error);
  return data as Resumen;
}

export const obtenerSalud = cache(async (): Promise<IndicadorSalud[]> => {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("dash_salud");
  if (error) throw traducir(error);
  return (data ?? []) as IndicadorSalud[];
});
