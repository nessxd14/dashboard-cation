import { Proximamente } from "@/components/Proximamente";

export default function AlmacenPage() {
  return (
    <Proximamente
      titulo="Almacén"
      fase="Fase 2 · pendiente"
      puntos={[
        "Salidas por origen (retail, despacho, ajuste) día por día",
        "Entradas por compra y traslados en tránsito",
        "Cumplimiento de despacho y horas de pedido a completado",
        "Productos sin movimiento en 30, 60 y 90 días",
        "Bandeja Por comprar",
      ]}
    />
  );
}
