# Brief de diseño — Catalogador de autopartes (prueba técnica)

> Documento de entrada para la fase de *brainstorming* de Superpowers.
> Autor: Antonio Espinosa · Inicio del ejercicio: 2026-11-05 11:07 (CDMX)

## 1. Contexto

Prueba técnica para una refaccionaria. Se recibe un Excel de **origen** con piezas de motor
(datos mínimos de un ERP) y un Excel de **ejemplo** que muestra el entregable esperado.

Tarea: construir una aplicación **Ruby on Rails** que tome el archivo de origen y genere un
Excel equivalente al ejemplo, con **aplicaciones, intercambios y atributos reales** de cada pieza.

Reglas explícitas del evaluador:
- Se vale cualquier herramienta, librería, IA o servicio.
- **Si el mismo dataset se corre dos veces y los resultados difieren, algo está mal.**
- Se evalúa sobre todo el *approach*, las decisiones y las estrategias. También el tiempo.

Entregables: (1) Excel generado con los datos catalogados, (2) acceso al repositorio.

## 2. Entrada (`data_prueba_técnica.xlsx`, hoja `Origen`)

Columnas: `Cod interno | Número de parte | Descripción del artículo | Descripcion | Grupo de articulos | Fabricante | Unidad`

| Número de parte | Fabricante | Grupo | Descripcion (semilla) |
|---|---|---|---|
| FSX-5840301 | FRACO | JUEGO DE EMPAQUES | QJC20G FS-001225 JC20 NISSAN PICK UP 4 CIL 2.4 KA24E SOHC 12 VAL 89/03 |
| HL-7025S | ELGIN | PUNTERIAS | HL7011 CHEVROLET V8 294 4.3 VORTEC 325 5.3 LS1 , 6.0 6.2 VORTEC 16 VAL 99/23 CON RESORTE |
| RM-152 | REXITE | BOMBA DE ACEITE | DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14 |
| SP26-329R/L+20 | SAFETY | PISTONES | 83-301 CHEVROLET SILVERADO V6 262 4.3 INC ECOTEC 12 VAL 14/18 |
| TK1283-1 | REVO | KIT DE DISTRIBUCION | 9-0511S SA-76260 DDM-77020 CHRYSLER DURANGO JOURNEY V6 3.6 SOHC 24 VAL PENTASTAR 11/13 |

El archivo de origen también trae las hojas de salida (`Métricas`, `Aplicaciones`, `Intercambios`,
`Atributos`, `Catálogo`) **vacías**.

### Anatomía del campo `Descripcion`
- **Primeros tokens = números de intercambio** de otras marcas (QJC20G, DM-152, 9-0511S, SA-76260…).
- Luego **vehículo abreviado**: armadora, modelo(s), cilindros (`4 CIL`, `V6`, `L4`), litros (`2.4`),
  CID (`294`, `262`), código de motor (`KA24E`, `LS1`, `PENTASTAR`), árbol (`SOHC/DOHC`),
  válvulas (`12 VAL`, `16V`), **rango de años `AA/AA`** (`89/03` → 1989–2003; `76/14` → 1976–2014).
- Datos **ambiguos o incompletos**: listas de motores mezcladas (`L4 L6 1.8 2.4 2.0`), errores de
  captura, notas libres (`CON RESORTE`, `INC`). **No se deben tomar como verdad**: sirven para
  buscar y para validar contra la fuente oficial.

## 3. Salida esperada (`ejemplo_prueba_técnica.xlsx`)

El ejemplo usa **otras 10 piezas** (no las 5 del origen) y genera:

| Hoja | Filas (ejemplo) | Columnas |
|---|---|---|
| `Origen` | 10 | copia de la entrada |
| `Métricas` | — | Título `Catálogo Bonaparte - Refaccionaria Trópico de Cáncer`; `Referencias: N`; por cada bloque (Aplicaciones, Intercambios, Atributos): total, `Origen` (0) e `Incrementos` = fórmula `=Bx-By` |
| `Aplicaciones` | 2,610 | `Referencia, Marca, Producto, Posición, Fabricante, Modelo, Submodelo, Año, Litros, CC, CID, Cilindros, Bloque, Combustible, Mercado` |
| `Intercambios` | 31 | `Referencia, Marca, Producto, Intercambio, Marca intercambio, Origen` (`Aftermarket` / `OEM`) |
| `Atributos` | 74 | `Referencia, Marca, Producto, Clase, Atributo, Unidad, Valor` |
| `Catálogo` | 10 | `Referencia, Marca, Categoría, Sistema, Subsistema, Producto, Descripción` |

Observaciones clave:
- **Aplicaciones explotadas**: una fila por *submodelo × año × motor* (ej. NP300 Base/S/SE/Chasis
  Cabina… 2016, 2017, 2018). `Fabricante` = armadora del vehículo; `Posición` vacía en motor;
  `Bloque` = `L`/`V`; `Mercado` = `MEX`.
- **Normalización de marcas**: `HASTING → HASTINGS PISTON RINGS`, `TECH TIMMING → TECH TIMING`,
  `CONTITECH → CONTITECH PRODUCTS`.
- **Normalización de producto**: `PISTONES → PISTÓN DE MOTOR`, `JUEGO DE EMPAQUES → JUEGO DE
  EMPAQUES DE MOTOR`, `KIT DE DISTRIBUCION → KIT DE CADENA DE TIEMPO` (depende de si es cadena o banda).
- **Taxonomía**: `Categoría` (Vehículo ligero) → `Sistema` (MOTOR) → `Subsistema` (COMPONENTES DEL
  BLOQUE DE CILINDROS, COMPONENTES DEL TREN DE VÁLVULAS, BOMBAS, JUNTAS Y SISTEMAS DE SELLADO, KITS DE SERVICIO).
- **Descripción de catálogo** redactada en español a partir de los atributos (plantilla + datos).
- **Cruces útiles para validar**: `RM-152 (REXITE) ↔ DM-152 (TECH OIL PUMPS)` y
  `TK1283-1 (REVO) ↔ DDM-77020 (TECH TIMING)` aparecen en ambos archivos.

## 4. Fuentes de datos (decisión central)

Principio: **la fuente de verdad es el sitio oficial del fabricante**. La descripción del origen se
usa para *encontrar* la pieza y para *validar* lo encontrado, nunca como dato final sin verificar.
No hay API keys de proveedores: hay que usar sus portales, buscadores y catálogos.

| Fabricante | Fuente conocida | Estrategia probable |
|---|---|---|
| ELGIN | `catalog.elginind.com` (catálogo web con aplicaciones por motor y tabla de specs) | HTTP + parseo HTML |
| FRACO | **Ficha técnica PDF por pieza** con URL predecible: `https://www.fraco.com.mx/QRMX/{numero_de_parte}.pdf` (ej. `FSX-5840299.pdf`) | Construir la URL directa → descargar PDF → extraer texto (`pdftotext -layout` para conservar columnas) → parsear; LLM con caché solo si el layout no se puede reconstruir |
| REXITE | Por investigar | Spike de descubrimiento |
| SAFETY | Por investigar | Spike de descubrimiento |
| REVO | Por investigar | Spike de descubrimiento |

**Hallazgo FRACO (FSX-5840299, pieza que también está en el Excel de ejemplo):** la ficha trae
modelos y años de aplicación (NP300, NP300 Frontier, NV350 Urvan), motor (2.5L QR25DE DOHC 16V),
diámetro de cilindro (89 mm), desplazamiento (2,488 cc), carrera, junta de cabeza MLO (multicapa)
y números de componentes del juego (HGX-…, VSX-…). Coincide con lo que el ejemplo reporta en
Atributos (Número de válvulas 16, Diámetro 89 mm, Junta cabeza MLS) y en Aplicaciones (CC 2488).
El texto se puede extraer, pero se pierde la relación etiqueta↔valor si no se respeta el layout.
**Esta pieza es el caso de prueba ideal**: el resultado del adaptador FRACO debe reproducir las
filas del ejemplo para FSX-5840299.

Jerarquía de respaldo (si la fuente oficial no tiene el dato): fuente oficial → catálogo PDF
oficial → fuente del fabricante del intercambio (ej. Cloyes para `9-0511S`) → marcar como
**no encontrado** (nunca inventar). Cada dato guarda su **URL de origen**.

## 5. Arquitectura propuesta

- **Rails 8 + SQLite + Solid Queue** (sin Redis/Postgres → `bin/setup && bin/dev` en cualquier máquina).
- UI mínima: subir archivo → pantalla de corrida con progreso por pieza (Turbo Streams) → descargar Excel.
- Un job por pieza + job finalizador que arma el Excel.

### Pipeline (cada paso es un service object testeable)
1. **Import** — `roo` lee el Excel → `SourceItem`.
2. **DescriptionParser** — reglas deterministas (regex + diccionarios) → hints estructurados
   (intercambios candidatos, armadora, modelos, litros, cilindros, código de motor, válvulas, años).
3. **Fetch** — adaptador por fabricante (`Sources::Elgin`, `Sources::Fraco`, …; patrón Strategy,
   interfaz común). Faraday para HTML estático; Ferrum/Playwright solo si el sitio requiere JS.
   Cada respuesta se persiste como `SourceSnapshot(url, body, sha256, fetched_at)`.
4. **Extract** — snapshot → aplicaciones, intercambios, atributos. LLM **solo** para texto no
   estructurado (PDF), con temperatura 0, *structured output* (JSON schema) y caché por hash de entrada.
5. **Reconcile** — compara fuente oficial vs. hints de la descripción; registra coincidencias y
   discrepancias (confianza).
6. **Normalize** — diccionarios versionados en YAML: marcas, nombres de producto, taxonomía,
   clases/unidades de atributos, nombres de vehículos.
7. **Export** — `caxlsx`, mismas hojas/columnas que el ejemplo, **orden de filas estable**,
   metadatos de fecha fijos. Hoja extra opcional `Fuentes` (trazabilidad por dato).

### Determinismo (requisito duro)
- Nada se descarga dos veces: los snapshots son caché y a la vez *fixtures* de tests.
- Re-fetch solo con bandera explícita (`FORCE_REFRESH`).
- Orden total en cada hoja (ej. Referencia, Fabricante, Modelo, Submodelo, Año…).
- Test de idempotencia: correr el pipeline dos veces y comparar el **contenido** de ambos libros
  (no los bytes del .xlsx, que traen timestamps).
- LLM: caché por hash; si el caché existe, no se llama al modelo.

## 6. Estrategia de pruebas
- TDD estricto (rojo → verde → refactor).
- Unit: `DescriptionParser` (casos reales de las 5 + 10 descripciones), normalizadores, exportador.
- Adaptadores: tests contra snapshots HTML/PDF guardados (sin red en CI).
- Integración: origen → Excel, comparado contra estructura del ejemplo (hojas, encabezados, tipos).
- Determinismo: test de doble corrida.

## 7. Fuera de alcance
- Autenticación/usuarios, diseño visual elaborado, despliegue a producción (opcional al final).

## 8. Preguntas abiertas para el brainstorming
1. ¿Qué tiene cada portal (Rexite, Safety, REVO)? → spike de descubrimiento por fabricante antes del plan.
2. Cuando la fuente oficial y la descripción no coinciden, ¿qué gana y cómo se reporta?
3. ¿Cómo expandir "modelo + rango de años" a submodelos (como hace el ejemplo) si la fuente oficial
   no los trae? ¿Se omite el submodelo o se usa `Base`?
4. ¿Las métricas deben contar lo que traía el origen como 0 (como en el ejemplo)?
5. Taxonomía y redacción de `Descripción`: ¿plantillas por tipo de producto?

## 9. Entregables y bitácora
- Repo público en GitHub con README (setup + approach), `docs/DECISIONS.md` (decisiones con fecha y hora),
  specs y planes de Superpowers en `docs/`, commits pequeños.
- Excel final generado por la app a partir de `data_prueba_técnica.xlsx`.
