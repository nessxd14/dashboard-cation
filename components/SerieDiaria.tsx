import { bs, diaMes } from "@/lib/formato";
import type { Resumen } from "@/lib/tipos";

const ALTO = 210;

/** Escala "redonda" para el eje: 100k, 50k, 20k… */
function techo(max: number): number {
  if (max <= 0) return 1000;
  const pasos = [1, 2, 2.5, 5, 10];
  const mag = 10 ** Math.floor(Math.log10(max));
  for (const p of pasos) if (p * mag >= max) return p * mag;
  return 10 * mag;
}

function corto(n: number): string {
  if (n >= 1000) return `${Math.round(n / 100) / 10}k`.replace(".0k", "k");
  return String(n);
}

/** Barras apiladas por día: pedidos arriba, retail en la base. */
export function SerieDiaria({ serie }: { serie: Resumen["serie"] }) {
  const max = techo(Math.max(0, ...serie.map((d) => d.pedidos + d.retail)));
  const marcas = [1, 0.75, 0.5, 0.25, 0].map((f) => corto(max * f));
  const cadaCuanto = serie.length > 45 ? 7 : serie.length > 20 ? 2 : 1;

  // El día que más pesó, para el titular del gráfico.
  const pico = serie.reduce((a, d) => (d.pedidos + d.retail > a.pedidos + a.retail ? d : a), serie[0] ?? { fecha: "", pedidos: 0, retail: 0 });
  const total = serie.reduce((s, d) => s + d.pedidos + d.retail, 0);
  const share = total > 0 ? ((pico.pedidos + pico.retail) / total) * 100 : 0;

  return (
    <section aria-label="Vendido por día" className="vidrio panel" style={{ gap: 18 }}>
      <div className="panel-cabeza">
        <div>
          <h2>Vendido por día</h2>
          {total > 0 ? (
            <div className="panel-sub">
              El día más fuerte fue el {diaMes(pico.fecha)}: {bs(pico.pedidos + pico.retail)}, el {Math.round(share)}% del período
            </div>
          ) : (
            <div className="panel-sub">Sin ventas en el período</div>
          )}
        </div>
        <div className="leyenda">
          <span><span aria-hidden="true" className="muestra" style={{ background: "var(--pedidos)" }} />Pedidos</span>
          <span><span aria-hidden="true" className="muestra" style={{ background: "var(--retail)" }} />Retail (mostrador + VTD)</span>
        </div>
      </div>
      <div className="grafico-scroll">
        <div className="grafico">
          <div aria-hidden="true" className="eje mono">
            {marcas.map((m, i) => (
              <span key={i}>{m}</span>
            ))}
          </div>
          <div className="area">
            <div className="columnas" role="img" aria-label={`Barras apiladas de ventas diarias del ${diaMes(serie[0]?.fecha ?? "")} al ${diaMes(serie.at(-1)?.fecha ?? "")}`}>
              {serie.map((d) => {
                const hp = d.pedidos > 0 ? Math.max(2, Math.round((d.pedidos / max) * ALTO)) : 0;
                const hr = d.retail > 0 ? Math.max(2, Math.round((d.retail / max) * ALTO)) : 0;
                return (
                  <div key={d.fecha} className="columna" title={`${diaMes(d.fecha)} · pedidos ${bs(d.pedidos)} · retail ${bs(d.retail)}`}>
                    {hp > 0 ? <div className="tramo tramo-pedidos" style={{ height: hp }} /> : null}
                    {hr > 0 ? <div className="tramo tramo-retail" style={{ height: hr }} /> : null}
                  </div>
                );
              })}
            </div>
            <div aria-hidden="true" className="fechas mono">
              {serie.map((d, i) => (
                <span key={d.fecha}>{i % cadaCuanto === 0 ? d.fecha.slice(8, 10) : ""}</span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
