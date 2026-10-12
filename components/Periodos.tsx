import { OPCIONES, type Periodo } from "@/lib/periodo";

/** Selector de período por URL (?p=…). El rango usa un formulario GET simple. */
export function Periodos({ periodo, ruta }: { periodo: Periodo; ruta: string }) {
  return (
    <div role="group" aria-label="Período" className="vidrio periodos" style={{ borderRadius: 14 }}>
      {OPCIONES.map((o) => (
        <a key={o.clave} href={`${ruta}?p=${o.clave}`} aria-current={periodo.clave === o.clave ? "true" : undefined}>
          {o.texto}
        </a>
      ))}
      <form method="get" action={ruta} className="rango">
        <input type="hidden" name="p" value="rango" />
        <input type="date" name="desde" defaultValue={periodo.desde} aria-label="Desde" />
        <input type="date" name="hasta" defaultValue={periodo.hasta} aria-label="Hasta" />
        <button type="submit">Ver</button>
      </form>
    </div>
  );
}
