# Bitácora de decisiones

Formato: fecha y hora (CDMX) · decisión · por qué · consecuencias.

## Registro de horas

| Sesión | Fecha | Inicio | Fin | Horas | Qué se hizo |
|---|---|---|---|---|---|
| 1 | 2026-11-05 | 11:07 | (en curso) | | Esqueleto Rails, brief, CLAUDE.md, spike de fuentes, brainstorming, decisiones D1–D9, spec de diseño (borrador) |

---

## 2026-11-05 12:26 — D1. Criterio de fuentes de datos

**Decisión**
- La descripción del ERP **nunca genera filas**. Solo sirve para buscar la pieza y para validar lo encontrado.
- Lo que reporta la **fuente oficial del fabricante** entra al Excel, siempre con su URL.
- Si la fuente oficial está incompleta o no existe, se complementa con la **fuente oficial de una pieza de intercambio**. Esas filas se registran con origen "vía intercambio de X".
- Sin fuente oficial ni de intercambio no se generan filas de datos.

**Por qué:** el evaluador pide datos reales. La descripción del ERP es ambigua y trae errores de captura.

**Evidencia del spike (2026-11-05):**
- **Rexite** reporta RM-152 solo para el Nissan 280ZX 81–82 (2.8L, L6). Su API JSON trae lo mismo que la página, y su ficha de Melling M-152 también. Concluimos que está **incompleta, no contradictoria**: el rango 76/14 y el `L6` de la descripción del ERP incluyen ese vehículo.
- **REVO** no tiene sitio oficial localizable: `revo.com.mx` es un dominio estacionado y la marca solo aparece en marketplaces. TK1283-1 se complementará vía su intercambio Cloyes 9-0511S.

## 2026-11-05 12:26 — D2. Hojas de salida y trazabilidad

**Decisión**
- Las hojas del ejemplo (`Origen`, `Métricas`, `Aplicaciones`, `Intercambios`, `Atributos`, `Catálogo`) quedan **idénticas**, sin columnas extra.
- Se agregan dos hojas al final:
  - **Fuentes**: Referencia, tipo de dato (aplicación / intercambio / atributo), origen (oficial / vía intercambio de X), URL.
  - **Validación**: Referencia, campo, valor ERP, valor fuente, URL, estado (coincide / difiere / no encontrado).
- Las discrepancias **no se resuelven automáticamente**: se reportan en Validación.
- Una pieza sin fuente aparece en `Origen`, en `Catálogo` (referencia, marca y producto normalizados) y en `Validación` como "no encontrado".

**Por qué:** se respeta el formato que espera el evaluador y cada dato queda auditable.

## 2026-11-05 12:26 — D3. Mercado y Submodelo

**Decisión**
- **Mercado** lo define cada adaptador según el mercado de su fuente: catálogos de EE. UU. (Elgin, Safety, Cloyes, Melling) dan `USA`; sitios mexicanos (Fraco, Rexite) dan `MEX`. En filas vía intercambio, el mercado es el de la fuente que reporta la aplicación.
- **Submodelo** solo se llena si la fuente lo trae. Si no, queda vacío. **No se usa "Base" como relleno**, porque en el ejemplo "Base" es un submodelo real.

**Limitación conocida:** el ejemplo parece usar una base de vehículos propia (submodelos por año y mercado) que no tenemos. Se preguntó al evaluador si existe una tabla de vehículos de referencia; pendiente de respuesta.

## 2026-11-05 12:26 — D4. Descripción del Catálogo con plantillas, sin IA en ejecución

**Decisión**
- Una **frase de apertura por tipo de producto normalizado**, guardada en un YAML versionado.
- Después, **una frase por atributo verificado**, en un **orden fijo por tipo de producto**, con el formato "{atributo} de {valor} {unidad}".
- La descripción **solo menciona datos que están en la hoja Atributos**.
- Las frases de apertura se redactan durante el diseño (con ayuda de IA) y las revisa el desarrollador. **La IA se usa para diseñar, no al ejecutar.**

**Por qué:** garantiza que el texto sea idéntico en cada corrida (requisito de determinismo) y que no aparezca nada que no venga de una fuente.

## 2026-11-05 12:31 — D5. Producto normalizado y frases de apertura

**Decisión**
- **El producto normalizado se decide con la fuente oficial**, no solo con el grupo del ERP: pieza vs. juego, cadena vs. banda, etc.
  - `HL-7025S` → **JUEGO DE PUNTERÍAS DE MOTOR**. Elgin la describe como "Package of 4 each of HL-7025"; sigue el patrón de "KIT DE PISTÓN" y "JUEGO DE ANILLOS" del ejemplo.
  - `TK1283-1` → **KIT DE CADENA DE TIEMPO**. Cloyes publica su intercambio 9-0511S como reemplazo de cadena de tiempo del Pentastar 3.2/3.6L.
- **Frases de apertura:** si el ejemplo del evaluador tiene frase para ese tipo de producto, se copia tal cual. Solo se redactan frases nuevas para tipos que el ejemplo no trae.
- **Kit de cadena de tiempo:** de las tres variantes del ejemplo se usa siempre "Kit de cadena de tiempo para sincronizar el árbol de levas con el cigüeñal." (la más específica).

**Por qué:** el grupo del ERP es genérico ("KIT DE DISTRIBUCION" puede ser cadena o banda). La fuente oficial dice qué es realmente la pieza. Copiar las frases del ejemplo mantiene el estilo que espera el evaluador.

## 2026-11-05 12:43 — D6. Plazo y alcance

**Decisión**
- Entrega a más tardar el **lunes 9 de noviembre de 2026 en la mañana**.
- **Jueves 5:** cerrar spec y plan; empezar el núcleo (import, parser de descripciones, adaptador de Elgin).
- **Viernes 6:** resto de adaptadores, normalización, export y jobs.
- **Antes de entregar:** una sesión completa solo de verificación: clonar limpio, seguir el README, comparar contra el ejemplo y hacer la doble corrida.
- **La calidad y los tests no se recortan.** Si algo no cabe, se recorta de la lista "si alcanza".

**Núcleo (entra sí o sí)**
- Import y parser de descripciones.
- Adaptadores de FRACO, ELGIN, REXITE y SAFETY (descargas HTTP simples).
- Normalización y export con las 8 hojas (las 6 del ejemplo + Fuentes + Validación).
- Caché de descargas, test de doble corrida y jobs.
- Pantalla: subir archivo → **progreso en vivo por pieza con Turbo Streams** → descargar Excel. Es requisito del desarrollador desde el inicio: la app no debe parecer trabada mientras procesa.
- **Complemento de RM-152 vía Melling M152.** Es la demostración real de la regla de intercambios de D1; sin al menos un caso, la regla queda solo en papel.
- **Intento acotado para TK1283-1 (REVO), máximo 30 minutos:** buscar el servicio JSON que usa el buscador de Cloyes, o las fuentes oficiales de Dayco KTC1372 / SA Gear 76260. Si nada funciona, TK1283-1 va a Validación como "no encontrado".

**Si alcanza**
- Adaptador de Cloyes con navegador automatizado.

**Nota:** las horas trabajadas se registran por sesión en la tabla "Registro de horas" al inicio de este archivo.

## 2026-11-05 12:55 — D7. Conversión y traducción de atributos

**Decisión**
- Los atributos de fuentes en inglés o en pulgadas (Elgin, Safety, Melling, Cloyes) se convierten al formato del ejemplo: **en español y en mm**.
- **Pulgadas → mm:** multiplicar por 25.4 y **redondear siempre a 2 decimales**. Es una regla fija, cubierta por test.
- **Nombres, Clase y valores categóricos** se traducen con un **diccionario YAML versionado**. Ejemplos: Length → Longitud, Lifter Type → Tipo de puntería, Hydraulic → Hidráulica, Steel → Acero, Roller Yes/No → Rodillo Sí/No.
- **Término que no esté en el diccionario:** no se traduce con IA ni se adivina. Sale con su texto original y se registra en Validación con estado **"sin traducción"**.
- **Evidencia:** el valor original con su unidad (ej. "3.880 IN") queda en la hoja **Fuentes**.

**Consecuencias**
- La hoja Fuentes suma la columna "Valor original".
- Validación suma el estado "sin traducción" a los de D2 (coincide / difiere / no encontrado).

**Por qué:** mantiene el formato del ejemplo sin perder trazabilidad, y el resultado es idéntico en cada corrida.

## 2026-11-05 16:06 — D8. Verificación de combinaciones modelo-año

**Contexto:** Elgin publica, por motor, una lista de modelos y un solo rango de años (ej. 6.0L 2007–20: Avalanche, Express, Silverado…). Cruzar cada modelo con cada año del rango puede generar vehículos que no existieron.

**Decisión**
1. Primero, un **intento de 30 minutos** para ver si Elgin publica años por modelo en otra vista. Si los publica, se usan.
2. Si no, cada combinación modelo × año se cruza contra **NHTSA vPIC** (API oficial y gratuita; ej. `GetModelsForMakeYear`). Sus respuestas se guardan en `SourceSnapshot` como cualquier fuente.
3. **Solo se generan las combinaciones que vPIC confirma.** Las que no coinciden van a Validación.
4. **Nunca** se generan combinaciones no verificadas.

**Alcance (aclaración del desarrollador):**
- La verificación con vPIC **solo aplica cuando la fuente da el rango de años por motor** (como Elgin).
- Se usa **solo para aplicaciones de mercado USA**.
- Cuando la fuente da años por modelo (Fraco, Rexite, Safety), esos años se usan tal cual.

**Por qué:** mantiene la regla de no inventar datos y usa una fuente oficial, gratuita y cacheable, así que el resultado sigue siendo determinista.

## 2026-11-05 16:06 — D9. Intercambios mencionados en la descripción del ERP (matiz de D1)

**Decisión**
- Un número de intercambio que aparece en la descripción del ERP entra a la hoja Intercambios **solo si una fuente oficial lo confirma**: la ficha de la pieza o el catálogo oficial de la otra marca. Su URL queda en Fuentes.
- Si no se confirma, va a Validación como "no encontrado".

**Por qué:** los números del ERP son pistas valiosas para buscar, pero pueden tener errores de captura. Solo se publican los que una fuente oficial respalda.

## 2026-11-05 16:17 — D10. Sobremedida desde el número de parte (excepción explícita a D1)

**Decisión**
- La **sobremedida** de una pieza se toma **del número de parte**, no de la descripción del ERP. Por ejemplo, en `SP26-329R/L+20`, el sufijo `+20` significa 0.020".
- Se registra como atributo. En la hoja Fuentes, su origen es **"número de parte"**.

**Por qué:** el número de parte es la identidad de la pieza, no una descripción libre. El ejemplo del evaluador hace lo mismo con `44338+20`.

## 2026-11-05 16:17 — Spec de diseño aprobado

- `docs/superpowers/specs/2026-11-05-catalogador-design.md` queda aprobado.
- **Ajustes finales:**
  - estado `error de fuente` en Validación, distinto de `no encontrado`;
  - D10;
  - cortesía de red: máximo 1 solicitud por segundo por sitio y un User-Agent con el nombre del proyecto.
- **Preguntas del revisor sin respuesta todavía:** quedan en §9 (puntos 6–10), cada una con el default que asume el plan.

## 2026-11-05 16:24 — D11. Respuestas a las preguntas del revisor del spec

1. **Determinismo entre máquinas — aceptado.** Las copias descargadas (snapshots) usadas para generar el Excel entregado se suben al repo, y `bin/setup` las carga. Así el resultado es idéntico en cualquier máquina.
2. **Alcance de vPIC — aceptado.** vPIC confirma **modelo + año, no motor**. El motor lo afirma la fuente (Elgin). Esto se documenta explícitamente en el README y en la hoja Fuentes.
3. **Equivalencias de intercambio — aceptado con matiz.**
   - Intento de 30 minutos de desarrollo para encontrar una fuente oficial que confirme **RM-152 = Melling M152** (ficha de Rexite, catálogo de Melling).
   - La misma exigencia aplica a **TK1283-1 = Cloyes 9-0511S**: esa equivalencia salió del ERP y de un sitio de terceros, así que también necesita confirmación oficial.
   - Si no aparece una fuente oficial, el complemento **no se activa** y queda en Validación.
   - Vía intercambio solo se traen **aplicaciones**. Los atributos de otra pieza no se copian.
4. **Producto de TK1283-1 sin fuente — aceptado con ajuste.** Sin fuente confirmada, el producto en Catálogo es el del grupo del ERP, **"KIT DE DISTRIBUCIÓN"**, no "KIT DE CADENA DE TIEMPO", porque esa precisión depende de Cloyes. Esto matiza D5.
5. **Marca real en Safety — no aceptado el default.**
   - Safety agrupa por "GM Trucks" y no da la marca de cada modelo. La columna `Fabricante` debe ser la marca real.
   - Se resuelve consultando en vPIC (`GetModelsForMake`, con caché) qué marca tiene cada modelo: Silverado → Chevrolet, Sierra → GMC.
   - Esto es **identificación de marca**, no verificación de años (D8).
   - Si un modelo no se encuentra en vPIC, va a Validación como "no encontrado" y no genera filas. `Fabricante` no puede quedar vacío ni con "GM".

## 2026-11-05 16:40 — D12. Simplificaciones técnicas del plan (cambian §6.3 del spec)

**Decisión**
- El resultado de cada pieza (aplicaciones, intercambios, atributos, validaciones) se guarda como **JSON en `SourceItem#result`**, en lugar de tablas separadas (`CatalogApplication`, `CatalogInterchange`, `CatalogAttribute`, `ValidationEntry`).
- Los jobs corren en **un solo proceso de Solid Queue con 3 hilos**. El límite de "1 solicitud por segundo por sitio" se controla dentro de ese proceso.

**Por qué**
- Las filas solo se escriben una vez y se leen juntas para armar el Excel, así que no hace falta consultarlas por separado.
- Con un solo proceso, el límite de solicitudes funciona sin coordinar entre procesos.
- Menos código y menos migraciones en un plazo corto.

**Consecuencia:** si en el futuro se quisiera consultar filas sueltas (por ejemplo, "todas las aplicaciones de Nissan"), habría que pasar a tablas.

## 2026-11-05 16:40 — D13. Sobremedida como designación y plantillas de frases de atributo

**Decisión**
- **La sobremedida es una designación estándar, no una conversión de unidades.** Se usa una tabla fija en YAML:

  | Designación | Valor en el Excel |
  |---|---|
  | STD | STD |
  | +10 | 0.25 mm (+0.010") |
  | +20 | 0.50 mm (+0.020") |
  | +30 | 0.75 mm (+0.030") |
  | +40 | 1.00 mm (+0.040") |

  - El valor se escribe como en el ejemplo: `0.50 mm (+0.020")`.
  - La regla de D7 (multiplicar por 25.4 y redondear) aplica solo a **medidas**, no a designaciones.
- **Dos plantillas para las frases de atributo** en la descripción del Catálogo (matiz de D4):
  - **numérico con unidad:** "{atributo} de {valor} {unidad}." Ejemplo: "Longitud de 98.55 mm."
  - **texto:** "{atributo}: {valor}." con el valor en minúsculas. Ejemplo: "Material de la carcasa: hierro fundido.", como en el ejemplo del evaluador.
- **Frase de apertura aprobada para KIT DE DISTRIBUCIÓN:** "Kit de distribución para sincronizar el árbol de levas con el cigüeñal."

**Ejecución:** modo directo en una rama nueva, explicando cada decisión. Habrá un revisor independiente al terminar las tareas 4, 9 y 14, y otro al final.

## 2026-11-05 17:04 — Hallazgo (Tarea 5): Elgin no publica años por modelo

Time-box de desarrollo de 30 minutos (D8, paso 1). Usé unos 5.

**Qué se revisó**
- `catalog.elginind.com/engine/chevrolet/`: el índice de motores por armadora tiene filtros de litros, CID y año.
- El mismo índice con `?year=2008` y con `?year=2020`.
- La página de motor de HL-7025S (6.0L 364 CID, 2007–20) y sus vistas `hx-get` (`/engine/part-spec/...`, que son especificaciones de pieza).

**Resultado**
- El filtro de año solo **selecciona motores** cuyo rango incluye ese año.
- La columna de modelos es **idéntica** en 2008 y en 2020. Por ejemplo, lista Avalanche para 2020, aunque el Avalanche dejó de fabricarse en 2013.
- Ninguna vista publica años por modelo.

**Consecuencia:** las aplicaciones de Elgin se expanden con la verificación de NHTSA vPIC (D8, paso 2, Tarea 6).

## 2026-11-05 17:14 — Hallazgo (Tarea 6): nombres de modelo en vPIC vs. Elgin — regla de comparación

**Contexto**
- vPIC usa nombres base: `Silverado`, `Express`.
- Elgin usa variantes: `Silverado 1500`, `Silverado 2500 HD Classic`, `Express 2500`, `Express Pasajeros`.
- Con igualdad exacta, la verificación habría descartado casi todas las Silverado y Express.

**Decisión del ejecutor (por revisar con el desarrollador)**
- Un modelo de la fuente se confirma si el nombre de vPIC coincide con **sus primeras palabras completas**.
- Ejemplos:
  - `Silverado` confirma `Silverado 1500 HD Classic`;
  - `Express` confirma `Express Pasajeros`;
  - `Express` **no** confirma `Expressway`.
- Es una regla fija y determinista, no una tabla de alias.
- Los modelos sin equivalente en vPIC van a Validación. Por ejemplo, `Cheyenne` y `Sonora`, nombres del mercado mexicano.
- Los años no confirmados se reportan **una fila de Validación por aplicación**, con rangos compactos (`Chevrolet Avalanche 2008-2020`).

**Costo si no se acepta:** se cambia un solo método (`Catalog::Vpic.same_model?`) a igualdad exacta, y el catálogo pierde muchas aplicaciones.

## 2026-11-05 17:14 — Hallazgo (Tarea 7): las fichas de Fraco no publican intercambios

- Revisé el texto de las fichas FSX-5840299 y FSX-5840301 buscando números de otras marcas: `JC-47-1`, `QJC`, `TF Victor`, `Quebec`, `FS-0…`, `JC20`.
- **No aparecen.** Las fichas solo listan componentes propios de Fraco (`HGX-…`, `VSX-…`, `OSX-…`).
- **Consecuencia (D9):** los números de intercambio de la descripción del ERP de FSX-5840301 (`QJC20G`, `FS-001225`, `JC20`) no tienen confirmación oficial. Van a Validación como "no encontrado" y no entran a la hoja Intercambios.
