"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { salir } from "@/app/login/actions";
import { alternarLiviano } from "@/app/(dash)/actions";

type Props = {
  correo: string;
  alertas: number;
  hora: string;
  liviano: boolean;
};

const PANTALLAS = [
  { href: "/", texto: "Resumen" },
  { href: "/ventas", texto: "Ventas" },
  { href: "/almacen", texto: "Almacén" },
  { href: "/finanzas", texto: "Finanzas" },
  { href: "/salud", texto: "Salud de datos", alertas: true },
  { href: "/auditoria", texto: "Auditoría", extra: "Chismosa" },
] as const;

export function Menu({ correo, alertas, hora, liviano }: Props) {
  const ruta = usePathname();

  return (
    <nav aria-label="Pantallas del dashboard" className="vidrio menu">
      <div className="marca">
        <div aria-hidden="true" className="marca-logo" />
        <div>
          <div className="marca-nombre">CATION</div>
          <div className="marca-sub">Operaciones</div>
        </div>
      </div>

      <div className="nav">
        {PANTALLAS.map((p) => (
          <Link key={p.href} href={p.href} aria-current={ruta === p.href ? "page" : undefined}>
            <span>{p.texto}</span>
            {"alertas" in p && alertas > 0 ? (
              <span className="insignia mono" aria-label={`${alertas} alertas`}>
                {alertas}
              </span>
            ) : null}
            {"extra" in p ? <span className="nav-extra">{p.extra}</span> : null}
          </Link>
        ))}
      </div>

      <div className="menu-pie">
        <strong>{correo}</strong>
        <span>Fuente: analitica</span>
        <span>Actualizado {hora} · La Paz</span>
        <form action={alternarLiviano}>
          <button type="submit" className="boton-texto">
            {liviano ? "Activar efecto vidrio" : "Modo liviano (sin vidrio)"}
          </button>
        </form>
        <form action={salir}>
          <button type="submit" className="boton-texto">
            Salir
          </button>
        </form>
      </div>
    </nav>
  );
}
