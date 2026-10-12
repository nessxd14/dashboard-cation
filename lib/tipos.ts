/** Forma del JSON que devuelve public.dash_resumen(desde, hasta). */
export type Resumen = {
  periodo: { desde: string; hasta: string; dias: number; prev_desde: string; prev_hasta: string };
  vendido: {
    total: number;
    prev: number;
    pedidos: number;
    ventas_retail: number;
    por_canal: { canal: string; monto: number }[];
  };
  cobrado: {
    total: number;
    prev: number;
    retail: number;
    cuenta: number;
    qr_sin_verificar: number;
    por_medio: { medio: string; monto: number }[];
  };
  egresos_caja: { tipo: string; monto: number }[];
  cartera: { total: number; clientes: number; top: { cliente: string; saldo: number }[] };
  salidas: {
    valor_total: number;
    por_origen: { origen: string; unidades: number; valor: number | null }[];
  };
  serie: { fecha: string; pedidos: number; retail: number }[];
  top_productos: { descripcion: string; monto: number }[];
  turnos: {
    id: number;
    estado: "ABIERTA" | "CERRADA" | "EN_REVISION";
    abierta_en: string;
    cajero: string;
    diferencia: number | null;
  }[];
  hoy: {
    fecha: string;
    vendido: number;
    turno_abierto: { id: number; cajero: string } | null;
    pedidos_abiertos: number;
    lineas_por_despachar: number;
    por_comprar: number;
  };
};

/** Un indicador de public.dash_salud(). */
export type IndicadorSalud = {
  clave: string;
  nivel: "ok" | "medio" | "alto";
  titulo: string;
  detalle: string;
  valor: number;
  unidad: "Bs" | null;
};
