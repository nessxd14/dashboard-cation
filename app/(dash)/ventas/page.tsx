import { Proximamente } from "@/components/Proximamente";

export default function VentasPage() {
  return (
    <Proximamente
      titulo="Ventas"
      fase="Fase 2 · pendiente"
      puntos={[
        "Ventas por canal, vendedor y cliente, con detalle de cada documento",
        "Top productos y familias",
        "Ticket promedio y conversión de cotización a pedido",
        "Descuento otorgado: precio de lista contra precio final",
        "Vendido contra entregado por pedido",
      ]}
    />
  );
}
