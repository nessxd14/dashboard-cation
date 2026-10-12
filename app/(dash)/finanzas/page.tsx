import { Proximamente } from "@/components/Proximamente";

export default function FinanzasPage() {
  return (
    <Proximamente
      titulo="Finanzas"
      fase="Fase 3 · pendiente"
      puntos={[
        "Cobrado por medio, día por día",
        "Cartera por cliente y antigüedad (0–30, 31–60, 61–90, +90 días)",
        "Turnos de caja con diferencia, gastos chicos, remesas y faltantes por cajero",
        "Comisiones devengadas",
      ]}
    />
  );
}
