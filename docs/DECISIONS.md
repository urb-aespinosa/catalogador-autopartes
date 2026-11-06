# Bitácora de decisiones

Formato: fecha y hora (CDMX) · decisión · por qué · consecuencias.

## Registro de horas

| Sesión | Fecha | Inicio | Fin | Horas | Qué se hizo |
|---|---|---|---|---|---|
| 1 | 2026-11-05 | 11:07 | 18:12 | 7.1 | Esqueleto Rails, brief, CLAUDE.md, spike de fuentes, brainstorming, decisiones D1–D16, spec aprobado, plan, Tareas 1–15 (pipeline completo, 3 revisiones independientes, UI con progreso en vivo, primera corrida real y doble corrida idéntica) |
| 2 | 2026-11-06 | 08:19 | (en curso) | | Diagnóstico del CI de GitHub Actions, D17, cierre de PRs de dependabot, Tarea 15b |

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

## 2026-11-05 17:29 — Corrección: se revierte la regla de primeras palabras; se aplica el spec §5.7

**Por qué se revierte**
- El revisor independiente de las tareas 5–9 señaló que la regla de 17:14 **contradice el spec**. El §5.7 nombra `Express Pasajeros` y `Silverado 1500 HD Classic` como ejemplos de nombres que vPIC no reconoce y que deben ir a Validación.
- La regla además **inventaba combinaciones**. `Silverado 1500 Classic` solo existió en 2007, pero con el rango del motor (2007–20) habría salido de 2008 a 2020 porque vPIC confirma "Silverado". Eso va contra la anti-meta de "nunca generar combinaciones no verificadas".

**Regla vigente (spec §5.7):** los nombres se comparan ignorando solo mayúsculas, espacios y guiones. Las variantes y los nombres de mercado que vPIC no lista van a Validación.

**Impacto medido con los fixtures (HL-7025S, solo Chevrolet)**
- Elgin lista 32 modelos Chevrolet y vPIC reconoce 9: Avalanche, Camaro, Colorado, Corvette, Impala, Monte Carlo, Suburban, Tahoe y Trailblazer.
- Quedan fuera, y van a Validación, todas las variantes de Silverado, Express y Suburban (`Silverado 1500`, `Express 2500`, `Suburban 2500`…) y los nombres mexicanos (`Cheyenne`, `Sonora`, `Express Pasajeros`).

**Pendiente del desarrollador (spec §9.3):** decidir si se agrega una tabla de alias revisada, por ejemplo `Silverado 1500 → Silverado`. Mientras no se decida, rige la regla del spec.

## 2026-11-05 17:32 — Hallazgo (Tarea 13): no hay confirmación oficial de las equivalencias de intercambio

Dos time-boxes de desarrollo de 30 minutos (D11, punto 3). Usé unos 15 minutos en total.

**RM-152 = Melling M152**
- **Rexite** vende `RM-152` y también `Bomba Melling M-152` (`rexite.net/producto/bomba-de-aceite-m-152-nissan/`), con la misma aplicación (280ZX 81–82). Pero ninguna de las dos fichas dice que sean equivalentes: no hay descripción, etiqueta ni campo de intercambio. Que los números se parezcan y las aplicaciones coincidan es una inferencia, no una confirmación.
- **Melling** (`melling.com`) remite a `melling.mypartfinder.com`, una aplicación JavaScript. Su API (`api.mypartfinder.com`) pide un token OAuth con credenciales que vienen incrustadas en el JavaScript del sitio.
- **Resultado:** sin confirmación oficial. El complemento **no se activa**, RM-152 queda solo con la fila oficial de Rexite y la equivalencia va a Validación.

**TK1283-1 = Cloyes 9-0511S**
- REVO no tiene sitio oficial (spike).
- El buscador de Cloyes consulta **Algolia** con una llave incrustada en su JavaScript.
- Ninguna fuente oficial conocida menciona `TK1283-1`. La equivalencia solo aparece en la descripción del ERP y en un sitio de terceros (finditparts).
- **Resultado:** sin confirmación oficial. TK1283-1 queda como pieza sin fuente, con producto "KIT DE DISTRIBUCIÓN" (D11).

**Pregunta abierta para el desarrollador** (resuelta en D14): no usé las credenciales incrustadas de Melling (OAuth) ni de Cloyes (Algolia). Usarlas sería reproducir lo que hace un navegador, pero con llaves extraídas de su código, y eso merece una decisión explícita. Aun usándolas, es poco probable que esos catálogos mencionen piezas de Rexite o de REVO.

## 2026-11-05 17:14 — Hallazgo (Tarea 7): las fichas de Fraco no publican intercambios

- Revisé el texto de las fichas FSX-5840299 y FSX-5840301 buscando números de otras marcas: `JC-47-1`, `QJC`, `TF Victor`, `Quebec`, `FS-0…`, `JC20`.
- **No aparecen.** Las fichas solo listan componentes propios de Fraco (`HGX-…`, `VSX-…`, `OSX-…`).
- **Consecuencia (D9):** los números de intercambio de la descripción del ERP de FSX-5840301 (`QJC20G`, `FS-001225`, `JC20`) no tienen confirmación oficial. Van a Validación como "no encontrado" y no entran a la hoja Intercambios.

## 2026-11-05 17:46 — D14. Alias de capacidad para vPIC, credenciales incrustadas y README

**1. Nombres de modelo en vPIC (spec §9.3)**
- Se agrega una **tabla de alias en YAML, explícita y revisada por el desarrollador**, solo para **sufijos de capacidad**: `1500`, `2500`, `3500` y `HD`. Ejemplos:
  - `Silverado 1500` → `Silverado`
  - `Express 2500` → `Express`
  - `Suburban 2500` → `Suburban`
- El alias **solo se usa para consultar vPIC**. En el Excel se conserva el nombre de Elgin.
- **Sin alias** para:
  - las variantes `Classic`;
  - `Cheyenne`, `Sonora` y `Express Pasajeros`.

  Esos nombres siguen yendo a Validación.
- **Tabla aprobada por el desarrollador tal cual**, incluidos `Silverado 1500 LTD` → `Silverado LTD` y `Sierra 1500 Limited` → `Sierra Limited`.
- **HD** se consulta como `Silverado` o `Sierra`. vPIC separa "Silverado HD" solo a partir de 2020; antes, esas versiones estaban dentro de "Silverado".
- **Limitación conocida:** vPIC confirma la línea de modelo y el año, no la versión de carga (1500/2500/3500), igual que no confirma el motor (D11).
  - Algunas versiones dejaron de fabricarse antes que su línea. Por ejemplo, Express 1500 después de 2014 y Suburban 2500 después de 2013.
  - Por eso pueden aparecer combinaciones de versión y año que no existieron.
  - Ninguna fuente oficial gratuita publica años por versión de carga.
  - La aplicación sigue respaldada por Elgin como fuente oficial.

**2. Credenciales incrustadas de Melling (OAuth) y Cloyes (Algolia): no se usan.**
- Sería usar sus APIs sin autorización.
- Las equivalencias RM-152 = M152 y TK1283-1 = 9-0511S quedan sin confirmación oficial (hallazgo de 17:32). Los complementos no se activan.

**3. README (Tarea 16)**
- Explicar que la hoja Intercambios sale con pocas filas porque las equivalencias no tienen confirmación oficial (D9), y que cada número aparece en Validación con su motivo.
- Documentar `poppler` (`pdftotext`) en el README y en el `Dockerfile`. Era un pendiente menor del revisor.

## 2026-11-05 18:12 — D15. Combustible en aplicaciones de Elgin

**Contexto:** en la corrida 1 salió, por ejemplo, "Buick Allure 2005 5.3L Híbrido FHEV", un vehículo que no existió. El registro de motor de Elgin lista varios combustibles (Flex, GNC, híbridos, gasolina) para todos sus modelos, y se generaba una fila por cada combustible.

**Decisión**
- Se genera **una fila por motor y modelo**, nunca una por combustible.
- Si el motor lista **un solo** combustible, se usa.
- Si lista **varios**, `Combustible` queda **vacío** y la lista original queda en Fuentes como valor original ("combustibles del motor: …").

**Por qué:** la fuente no dice qué modelo usó qué combustible. Elegir uno sería inventar.

**Resultado con los datos reales (corrida desde la caché)**
- Aplicaciones: **3,599 → 1,187** filas. HL-7025S pasa de 3,542 a 1,130: 89 con "Gasolina" y 1,041 con Combustible vacío.
- Ya no aparece el Buick Allure FHEV.
- Una segunda corrida dio contenido **idéntico** celda por celda.

## 2026-11-05 18:12 — D16. Intercambios del ERP "confirmados por aplicación" (matiz de D9)

**Decisión**
- Un número de intercambio de la descripción del ERP entra a la hoja Intercambios si el **catálogo oficial de esa marca** confirma dos cosas:
  1. que el número **existe**, y
  2. que es para **el mismo motor y rango de años** que nuestra pieza.
- A esto se le llama **"confirmado por aplicación"**.
- En Fuentes se registran **las dos URLs**: la de nuestra pieza y la del catálogo de la otra marca.
- Si el número no existe o la aplicación no coincide, se queda en Validación.
- **Nunca** se buscan equivalentes solo por características parecidas.

**Siguiente paso (sesión 2, antes de la Tarea 16):** time-box de 30 minutos para buscar esa confirmación, **sin credenciales incrustadas**, en:
- DC Gaskets, `catalogo.dcp.com.mx` (FS-001225);
- Quebec / TF Victor (QJC20G, JC20);
- Moresa (83-301);
- Elgin (HL7011).

## 2026-11-06 08:34 — D17. CI de GitHub Actions, dependabot y push por tarea

**Contexto:** el CI falla en master en los jobs `test` y `system-test` con `db/schema.rb doesn't exist yet`, porque master solo tiene el esqueleto, sin migraciones. En la rama hay un segundo problema: no existe `test/system/`, y `bin/rails test:system` falla con `LoadError`.

**Decisión**
- **Se quita el job `system-test`** del workflow.
- El desarrollador verifica a mano en el navegador la actualización en vivo de la pantalla durante la sesión de verificación. La evidencia (captura o GIF) va en el README.
- **Se desactiva dependabot** en la Tarea 16. Sus 4 PRs (#1–#4) se cerraron con el comentario "Fuera del alcance de la prueba técnica."
- El job `test` instala `poppler-utils`, porque los tests de Fraco usan `pdftotext`.
- Se comprueba con un PR de `feature/catalog-pipeline` hacia `master`, con todos los jobs en verde.
- **Push a GitHub después de cada tarea terminada.**

**Por qué:** una prueba de navegador con jobs y Turbo Streams es frágil en CI y aporta poco frente a los tests de integración que ya existen.

## 2026-11-06 09:21 — Hallazgo (verificación manual): Incrementos de Métricas salían como texto

**Qué pasó:** en Métricas, las celdas B6, B10 y B14 mostraban el texto "=B4-B5" en lugar del resultado. En el XML estaban guardadas como `inlineStr`, no como fórmula. caxlsx 4.5 **escapa por defecto** los valores que empiezan con "=" (`escape_formulas`) y los guarda como texto.

**Por qué el test no lo detectó:** el lector de los tests convertía una fórmula real en el texto "=B4-B5". Una fórmula y un texto con esa forma se leían igual, así que el test pasaba con el bug.

**Corrección**
- El escape **se mantiene en todo el libro**. Protege contra la *inyección de fórmulas*: un valor de una página web que empiece con "=" nunca se ejecuta en Excel. Ningún dato de una fuente se trata como fórmula.
- Solo la celda de Incrementos lo desactiva (`escape_formulas: [true, false]`), porque esa fórmula la escribimos nosotros.
- Se guarda también el **resultado calculado** (`formula_values`). Así Roo y los visores que no recalculan (como la vista previa de macOS) muestran el número.
- El lector de los tests devuelve las fórmulas como `WorkbookReader::Formula`, nunca como texto. Así, el test de Métricas y el de doble corrida distinguen una fórmula de un texto.
- Test nuevo: el XML de B6, B10 y B14 tiene un elemento `<f>`, no es `inlineStr` y su valor guardado es la resta correcta.

## 2026-11-06 09:26 — D18. "Sin fuente configurada" vs. "no encontrado"

**Contexto:** al correr `ejemplo_prueba_tecnica.xlsx`, todas las piezas salvo las de Fraco salían "no encontrado". En realidad no se buscaron: esas marcas no tienen adaptador, porque cubrirlas no era meta del spec.

**Decisión (la opción más simple):** un **Estado propio** en Validación.
- `no encontrado`: se buscó en la fuente oficial y la pieza o el dato no estaba.
- `sin fuente configurada`: la marca no tiene adaptador en `Sources::Registry`, así que no se buscó nada.
- Para esa pieza, **todas** sus filas de Validación llevan `sin fuente configurada`: la fila Fuente y las de cada pista de la descripción (Armadora, Años, Intercambio…). Valor fuente queda vacío.
- La pantalla de progreso muestra "sin fuente configurada" (estado `no_source` de la pieza), no "no encontrado".

**Por qué un Estado y no un texto en Valor fuente:** Estado ya es la columna por la que se filtra Validación. Con un valor propio, un filtro muestra todo lo que faltó por adaptador, sin mezclar un motivo con un valor de la fuente.

**README (Tarea 16):** fabricantes soportados; qué sale para una marca sin adaptador (lo mínimo en Catálogo y en Validación); pasos para agregar un adaptador nuevo.

## 2026-11-06 09:55 — Hallazgo (Tarea 15b): intercambios del ERP en catálogos oficiales

**Cómo se buscó:** todas las solicitudes llevan el User-Agent del proyecto, con máximo una por segundo por sitio y sin credenciales. Una primera ronda usó un User-Agent de navegador; el desarrollador la detuvo, y todas las consultas se repitieron con el del proyecto. Los resultados de abajo son de esa segunda ronda. **Regla:** si un sitio bloquea o no responde con nuestro User-Agent, no se esquiva; se registra aquí y el intercambio queda en Validación.

**Regla aprobada para "confirmado por aplicación" (precisa D16):** se confirma solo si el rango de años del otro catálogo **contiene todos** los años de nuestra pieza, y además coinciden motor, litros y cilindros. Si el otro rango es más corto, no se confirma.

**Resultados (pieza FSX-5840301, Fraco: Nissan 2.4L, 2389 cc, 4 cil., 12V, 1989–1999)**

| Número | Fuente oficial | Resultado |
|---|---|---|
| FS-001225 (DC Gaskets) | búsqueda pública `www.dcp.com.mx/CatalogoElectronico?operacion=BuscaRapida&term=FS-001225` | Nissan 4L 2.4L (2389cc) SOHC 12V, KA24E/KA24S, 1989/2004. **Confirmado.** |
| JC-20 (TF Victor) | ficha de Dacomsa, dueña de TF Victor: `dacomsa.com/dacomsastorefront/dacomsa/es/Todas-las-lineas/TF-VICTOR/Juego-completo-para-motor/p/JC-20`. Es la URL principal; la de `/p/JC-20` redirige (301) a esta. | Nissan L4 2.4L (2389cc) SOHC 12V KA24E (1989-98). Además, DC lista JC-20 como equivalente de FS-001225. |
| QJC20G (Quebec) | DC: sin resultados; Dacomsa: 404 | No encontrado → Validación. |
| 83-301 (Moresa) | DC: sin resultados que coincidan; Dacomsa: 404 | No encontrado → Validación. |
| HL7011 (Elgin) | `catalog.elginind.com/part-autocomplete/` | **No existe:** la numeración salta de HL-7005 a HL-7012. Es un **error de captura del ERP**. Ejemplo para la sección del README sobre calidad de los datos de origen. |

**Sitios que no respondieron a nuestro User-Agent:** `www.moresa.com.mx` y `www.tfvictor.com.mx`, sin respuesta (código 000). `catalogo.dcp.com.mx` responde, pero el catálogo pide login; no se usa.

**Pendiente (después de la adenda de mercado):** con la regla de arriba, JC-20 cubre 1989–1998 y nuestra pieza llega a 1999, así que JC-20 **no se confirma**: queda en Validación con su URL. FS-001225 (1989–2004) sí se confirma. El adaptador DC/Dacomsa, con snapshots y tests, queda para después de la adenda.

## 2026-11-06 10:31 — Hallazgo (spike de mercado): INEGI RAIAVL y EPA fueleconomy.gov

Todas las consultas automáticas usaron el User-Agent del proyecto y una solicitud por segundo.

**INEGI RAIAVL**
- La **API PxWeb** (`/app/tabulados/pxwebv2/api/v1/…/RAIAVL_8_9.px`) respondió **403** a nuestro User-Agent. Se registra; no se esquiva.
- La **exportación del tabulado RAIAVL_8_9** falla incluso con selecciones pequeñas y está limitada a 150,000 celdas (lo comprobó el desarrollador en su navegador). No se automatiza el formulario.
- La sección **"Datos abiertos"** de `https://www.inegi.org.mx/datosprimarios/iavl/` sí funciona. Es la **fuente oficial que usamos**: el desarrollador la descargó a mano, y la procedencia está en `db/reference/inegi/conjunto_de_datos_raiavl_mensual_venta_csv.yml` (URL, fecha y sha256).
- **Contenido:** ventas mensuales de 2005-01 a 2026-09 por marca, modelo, tipo, segmento, origen y país de origen. **No** trae versión, motor ni combustible.
- **La marca es el grupo** ("General Motors"), no Chevrolet, GMC o Buick. El nombre comercial a veces lo dice ("GMC Sierra Cabina Regular"), a veces no ("Silverado 1500 Cabina Regular").
- **Cobertura de nuestros modelos:**
  - Nissan: Pickup Largo, Estacas Largo y Chasis Largo hasta 2016; Tsuru hasta 2018. No hay "D21" ni "Ichivan" (son anteriores a 2005).
  - GM: aparecen Silverado 1500/2500/3500, Express, Suburban, Tahoe, Escalade, Sierra, Yukon, entre otros. **En México sí se vendieron Silverado 2500/3500**, que EPA no cubre.
- Las cifras **se revisan cada mes**. Por determinismo se fija la copia descargada; una descarga nueva es otro snapshot.

**EPA fueleconomy.gov** (`/ws/rest/vehicle/menu/{year,make,model,options}` y `/ws/rest/vehicle/{id}`)
- Responde en JSON con nuestro User-Agent y cubre de 1984 a 2027.
- **Nombres propios de EPA:** "Truck 2WD" (Nissan 1995), "Silverado C15 2WD", "Lacrosse/Allure", "Express 2500 2WD Passenger".
- **Las "options" dan motor, transmisión y combustible**, pero **no la versión**: el campo `trim` viene vacío. Ejemplos: "Auto 4-spd, 4 cyl, 2.4 L"; "Auto 6-spd, 8 cyl, 5.3 L, SIDI; FFV". La ficha trae `displ`, `cylinders`, `fuelType` ("Regular", "Gasoline or E85"), `drive` y `VClass`.
- **Comprobación útil:** Buick Lacrosse/Allure 2005 solo tiene 3.6 L y 3.8 L. Así EPA **refuta "Allure 2005 5.3L"**.
- **Matiz para combustible:** en 2016, el Silverado C15 5.3 L aparece **con y sin FFV**. Si el mismo motor tiene varias opciones de combustible ese año, el combustible sigue siendo ambiguo y queda vacío, igual que en D15.
- **Cobertura:** no incluye pickups pesadas (Silverado/Sierra 2500/3500 HD). Sí incluye Express 2500/3500 Passenger en 2016. No incluye modelos solo mexicanos.

## 2026-11-06 11:44 — D19. Mercado por ventas, verificación de motor y combustible con EPA (reemplaza el Mercado de D3)

**Contexto:** respuesta del evaluador: *"la idea es que encuentres la manera de conseguir, o generar, esa data… quiero evaluar qué estrategias eliges y cómo planteas la solución cuando hay mucha incertidumbre"*. El principio se mantiene: todo comprobable, nada inventado. Detalle completo en `docs/superpowers/specs/2026-11-06-mercado-adenda-design.md` (aprobada).

**Decisión**
- **El mercado se define por dónde se vendió el vehículo**, por niveles y por mercado:
  - **Nivel a, confirmado por ventas.** MEX: ventas INEGI > 0 en el mismo año calendario que el año modelo (criterio estricto). USA: EPA lista ese modelo-año y, si la aplicación trae motor, tiene una configuración con motor coincidente.
  - **Nivel b, según catálogo.** Solo para el mercado del propio catálogo. El otro mercado entra únicamente con nivel a.
  - Una fila por mercado. Validación registra qué nivel se usó.
- **Rol de las fuentes USA:** vPIC confirma que el modelo existió ese año (incluye HD). EPA verifica motor y combustible donde tiene cobertura.
- **Motor refutado por EPA** (misma cilindrada a 1 decimal y mismos cilindros; ninguna configuración coincide):
  - catálogo USA → la fila se elimina en todos los mercados;
  - catálogo MEX → se conserva la fila MEX y solo se niega la USA.
  - En los dos casos, Validación registra `difiere` con los dos motores y las dos URLs.
- **Combustible:** cada dato vale para el mercado de la fuente que lo respalda.
  - EPA llena Combustible solo en la fila USA, y solo si hay un único combustible para ese motor.
  - La fila MEX queda vacía, salvo que lo indique una fuente mexicana.
  - Si el catálogo ya da un combustible y EPA otro, se conserva el del catálogo y Validación registra `difiere`.
- **Equivalencias de nombres** en `config/catalog/inegi_models.yml` y `config/catalog/epa_models.yml`, revisadas por el desarrollador antes del commit.
- **EPA** se consulta preferentemente con su archivo masivo oficial (`vehicles.csv`), versionado con procedencia.
- **Submodelo** vacío: ninguna fuente oficial gratuita lo publica. El README describe la estrategia para producción (VCdb licenciada o acuerdos con fabricantes).
- **Prioridad:**
  1. La Tarea 16 completa no se recorta.
  2. En la adenda: INEGI, luego EPA motor, luego EPA combustible.
  3. El adaptador DC/Dacomsa es lo primero que se recorta.
- **La entrega se mueve al sábado 2026-11-07:** calidad primero.

**Limitaciones conocidas (README):** año de venta vs. año modelo; MEX sin verificación de motor; EPA no cubre HD ni modelos solo mexicanos; INEGI empieza en 2005; "General Motors" es un grupo.

## 2026-11-06 12:01 — Hallazgo (adenda, Tarea 1): snapshot del archivo masivo de EPA

- **Fuente:** `https://www.fueleconomy.gov/feg/epadata/vehicles.csv.zip`.
  - Primero una solicitud HEAD y luego una GET, las dos con el User-Agent del proyecto (11:58–11:59). Respondió `200`, sin bloqueo.
  - Pesa 2,228,192 bytes. `Last-Modified: 2026-11-04`.
- **Contenido:** un solo `vehicles.csv` con 84 columnas y 50,647 configuraciones, de los años modelo 1984 a 2027.
- **Extracto** `db/reference/epa/vehicles_scope.csv`: 12,635 filas y 8 columnas (`year, make, model, id, displ, cylinders, fuelType, atvType`).
  - Por marca: Chevrolet 4,619 · GMC 2,916 · Nissan 1,754 · Pontiac 893 · Cadillac 836 · Buick 732 · Isuzu 434 · Saab 432 · Hummer 19.
- **Cómo se reconstruye:** `bin/rails catalog:epa:filter`. Un test regenera el extracto desde el ZIP y compara el sha256, igual que con INEGI. La procedencia está en `db/reference/epa/vehicles.yml`.
- **Columnas por nombre:** se eligen por su nombre, no por su posición, porque el orden de las 84 columnas de EPA no está garantizado. Si falta alguna, falla con `FormatError` y no escribe nada.
- **Celdas vacías:** una celda vacía entre comillas (`""`) y una sin comillas se escriben igual, como vacío.
- **Plan B no necesario:** con el archivo masivo no hace falta consultar la API de EPA modelo por modelo.

## 2026-11-06 12:20 — D20. Equivalencias INEGI sin inferir capacidad, y nombres mexicanos que vPIC no conoce

**Contexto:** al revisar `config/catalog/inegi_models.yml` (Tarea 2 de la adenda) aparecieron dos problemas.
- **Capacidad:** nuestros catálogos dicen la capacidad ("Silverado 1500", "Sierra 2500 HD") y muchas series de INEGI no ("Sierra Cabina Regular", "Chevrolet Express Cargo Van").
- **Nombres mexicanos:** Elgin lista nombres mexicanos (Cheyenne, Sonora, Express Pasajeros, Express Cargo). Hoy se descartan porque vPIC no los conoce, aunque INEGI registra ventas con esos mismos nombres.

**Decisión 1. Equivalencias de nombres: la capacidad nunca se infiere.** La regla queda escrita también en el encabezado del YAML.
- **Nombre genérico** de nuestro catálogo, sin capacidad (por ejemplo "Silverado" de Safety): cuenta con todas las series de esa línea en INEGI, incluidas las que INEGI renombró en 2019 ("Silverado Cabina Regular/Doble Cabina", "Sierra Cabina Regular/Doble Cabina").
- **Nombre con capacidad** ("Silverado 1500", "Silverado 2500 HD"): cuenta solo con las series de INEGI que dicen esa misma capacidad. Si ninguna la dice, no hay equivalencia; nunca se toma la serie genérica.
  - Sin equivalencia, el modelo no tiene evidencia de ventas en México. Eso no significa "no vendido": si el catálogo es MEX, conserva MEX con nivel b.
  - El alias de capacidad de vPIC (D14) sirve solo para consultar vPIC; no da cobertura en INEGI.
- **Nombre mexicano** que lista Elgin: cuenta con la serie de INEGI que tiene ese mismo nombre.
  - Cheyenne → "Cheyenne Cabina Regular/Doble Cabina" (2019+).
  - Sonora → "Sonora Suv".
  - Express Pasajeros → "Chevrolet Express Passenger Van".
  - Express Cargo → "Chevrolet Express Cargo Van".
  - Cheyenne no se mapea a "Silverado 1500", ni al revés. Cheyenne Nueva y Sierra Nueva no tienen serie con ese nombre en INEGI, así que quedan fuera.

**Decisión 2. Nombres que vPIC no reconoce en ningún año: entran solo como MEX nivel a.**
- **Cuándo aplica:** solo cuando el nombre del modelo no aparece en ningún año de la lista de modelos de vPIC para esa armadora (`GetModelsForMake`, ya en caché para Chevrolet y GMC). Es el caso de Cheyenne, Sonora, Express Pasajeros y Express Cargo.
- **Qué se hace:** la aplicación entra únicamente como **MEX nivel a**, y solo en los años calendario con ventas en INEGI. Nunca sale una fila USA para estos nombres.
  - Resultado esperado: Cheyenne 2019–2024, Sonora 2005–2007, Express Pasajeros 2005–2020, Express Cargo 2005–2025.
  - Los años sin ventas siguen en Validación como "no encontrado".
- **Cuándo no aplica:** si vPIC conoce el modelo pero no confirmó ese año (Colorado 2013–2014, CTS 2020–2021, Avalanche 2014+, Camaro 2009), esa negativa se respeta y el año sigue como "no encontrado". INEGI no puede rescatarlo.
- **Por qué:** INEGI cuenta ventas por año calendario y no dice qué versión ni qué motor se vendió. Elgin publica rangos de años más amplios que la vida real de cada motor.
  - Ejemplo: la Colorado con V8 5.3L se vendió de 2009 a 2012 y Elgin la extiende a 2013–2014.
  - INEGI tiene ventas de Colorado en 2013 y 2014, pero de otras versiones. Si esas ventas confirmaran el año, aparecería una aplicación que nunca existió.
  - Cuando vPIC conoce el modelo, su negativa sobre el año es la evidencia más específica que tenemos. Cuando no conoce el nombre, no dice nada, y entonces INEGI es la única fuente oficial disponible.

**Ajuste al plan de la adenda (Tarea 4):**
- `Vpic.expand` deja de descartar las aplicaciones cuyo nombre vPIC no reconoce en ningún año. Las devuelve aparte, sin emitir su validación de "Modelo-año".
- Esas aplicaciones pasan por el `Normalizer` como las demás.
- `MarketResolver` les aplica la decisión 2: fila MEX nivel a en los años con ventas, con la evidencia INEGI en Fuentes, y "Modelo-año · no encontrado" en Validación para el resto de los años, con el mismo texto que hoy.

## 2026-11-06 12:31 — D21. Equivalencias EPA inclusivas: "1500" es toda la línea ligera

**Contexto:** al revisar `config/catalog/epa_models.yml` (Tarea 3 de la adenda). En la Tarea 5, EPA refuta un motor cuando ninguna configuración mapeada de ese modelo-año coincide con él, y la fila se elimina.

**Decisión**
- **Nombre genérico** (Silverado, Sierra, Tahoe, Escalade, CTS…): cuenta con toda la línea en EPA.
  - Incluye variantes de tracción, códigos GM (C15/K15, C10/K10, C1500/K1500), Classic, Hybrid, XFE, LD, Cab Chassis y versiones deportivas (CTS-V, Z06).
  - Nunca otros modelos que comparten una palabra (Escalade ESV/EXT, Yukon XL, TrailBlazer EXT, Envoy XL/XUV, City Express, Grand Am), ni versiones eléctricas.
- **Nombre "1500":** cuenta con la misma línea ligera completa, menos las series que dicen otra capacidad.
  - EPA solo evalúa vehículos ligeros y las pickups y vans HD están fuera de su alcance, así que toda serie de EPA de la línea es de clase 1500.
  - Aquí la capacidad no se deduce del nombre del vehículo: sale de lo que EPA cubre.
- **Nombre "2500", "3500" o "HD":** cuenta solo con las series que dicen esa capacidad. "1500/2500" cuenta para ambas.
  - Si no hay ninguna serie así, no hay entrada: el modelo queda sin verificar en EPA, no refutado.
- **Sin entrada:** los nombres solo mexicanos (Estaquitas, Ichivan) y los modelos que EPA no lista.

**Por qué esta regla es distinta de la de INEGI (D20), que no infiere capacidad:**
- **En INEGI,** una equivalencia faltante solo quita evidencia. La fila baja a nivel b o no tiene fila MEX, pero nada correcto se borra. Por eso INEGI es estricta: una equivalencia de más confirmaría ventas de otra versión.
- **En EPA,** una equivalencia faltante borra filas correctas. Si "Silverado 1500" contara solo con las series que dicen "15", el 6.2L de 2019 quedaría refutado. Ese año EPA lo publica como "Silverado K10 4WD", y su serie "LD C15/K15" de 2019 es la generación anterior, solo con 5.3. Por eso EPA es inclusiva dentro de la misma línea.
- **El criterio común es evitar el error que causa daño.** En INEGI el daño es confirmar algo falso; en EPA, borrar algo verdadero.

**Control:** un test verifica que cada nombre de EPA del YAML existe en el extracto. Antes del commit, un reporte local lista las aplicaciones de `tmp/run2.xlsx` que este YAML refutaría, para revisarlas una por una.

## 2026-11-06 12:48 — D22. EPA solo puede refutar un motor donde su cobertura de esa línea es completa

**Contexto:** el reporte de refutaciones con las equivalencias de D21 (sobre `tmp/run2.xlsx`, 1,187 filas) dio 237 filas refutadas. Casi todas coinciden con la historia real de los motores. Por ejemplo:
- Allure/LaCrosse 5.3L antes de 2008;
- Silverado 1500 6.0L de 2014 en adelante;
- Colorado 5.3L fuera de 2009–2012.

Pero dos tipos de casos borraban filas correctas:
- **Cobertura parcial de capacidades pesadas.** EPA solo evalúa la parte ligera de las 2500/3500 y de las líneas con versiones HD.
  - Ejemplo: en 2007–2008 publica "Express 1500/2500 2WD" solo con 5.3. La Express 2500 con 6.0 pesaba más de lo que EPA evalúa, así que su 6.0 quedaba refutado aunque existió.
  - Igual con la "Suburban" genérica 6.0L 2015–2020, que es la 2500 y no está en EPA después de 2013.
- **Huecos en los datos de EPA.** El CTS-V 2009 (6.2L) existió, pero EPA lista el CTS-V solo desde 2010.

**Decisión**
- **`confirm_only` en `config/catalog/epa_models.yml`:**
  - (a) nombres 2500, 3500 y HD;
  - (b) nombres genéricos de líneas con versiones HD fuera de EPA: Silverado, Sierra, Suburban, Express y Savana.

  Estos modelos confirman el motor y aportan combustible y evidencia, pero nunca borran. Si el motor no coincide, la fila se conserva y Validación registra `difiere`.
- **`confirm_only_years`:** lista corta de excepciones revisadas. Cada una lleva modelo · año · motor (litros a un decimal y cilindros), para proteger solo el caso revisado, y su motivo. Se conservan como `difiere`, no como confirmadas.
  - Cadillac CTS · 2009 · 6.2L/8: el CTS-V 2009 existió y EPA lo lista solo desde 2010.
  - GMC Yukon XL 1500 · 2007 · 6.2L/8: la Yukon XL Denali 2007 tuvo el 6.2. EPA 2007 parece agrupar Denali y Denali XL como "Yukon Denali 1500 AWD", y lista Yukon XL 1500 con 6.2 a partir de 2008.
- **Interfaz:** `Epa#refutes?(make:, model:, year:, liters:, cylinders:)`. La Tarea 5 la consulta antes de eliminar una fila.
- **README, sección de limitaciones:** "EPA puede refutar un motor solo donde su cobertura de esa línea es completa".

**Resultado del reporte** (`run2`, 1,187 filas):

| Resultado | Filas |
|---|---|
| Motor confirmado | 662 |
| Sin evidencia de EPA | 288 |
| Refutadas (se eliminarán en la Tarea 5) | **169** (antes 237) |
| Difiere, se conservan | **68** |

- **Primera versión de las excepciones,** que era solo por modelo y año: también protegía el CTS 6.0L 2009, un motor que no existió ese año. Con la excepción por motor queda refutado.
- **Lo que se pierde:** algunas refutaciones válidas, como la Express 3500 5.3L, quedan como `difiere` en lugar de borrarse. Es el error que no hace daño.

**Ajuste 2026-11-06 13:32, tras la revisión independiente de la Tarea 5** (veredicto "listo con correcciones", sin hallazgos críticos):
- **`confirm_only` (b) ahora incluye Yukon XL (GMC) y Avalanche (Chevrolet).** Las dos son líneas con versiones 2500 fuera de la cobertura de EPA:
  - la Yukon XL 2500 solo aparece en EPA de 2011 a 2013;
  - la Avalanche 2500 (8.1L, 2002–2006) no aparece.
  - ~~Hoy no cambia ninguna fila de `run4`~~. **Corrección (2026-11-06 13:58):** esa afirmación era falsa. La repetí del revisor sin comprobarla. Al poner la Avalanche genérica en `confirm_only`, cuatro aplicaciones que `run4` eliminaba (Avalanche 6.0L de 2010 a 2013, en MEX y USA, 8 filas) pasaron a conservarse. Se detectó al comparar `run4` con `run5` en la Tarea 6.
  - Un test fija la lista de genéricos del grupo (b).
- **Ajuste 2026-11-06 13:58: `confirm_only` por años.**
  - **Por qué:** la razón de D22(b) depende del año. Fuera de los años en que existió la versión que EPA no cubre, la cobertura de EPA es completa y sí puede refutar.
  - **Formato:** una entrada de `confirm_only` puede llevar un rango de años, `{ model:, years: [inicio, fin] }`. `Epa#confirm_only?` ahora recibe el año.
  - **Avalanche:** solo 2002–2006, los años de la Avalanche 2500 con 8.1L. Desde 2007 la línea es solo 1500.
  - **Yukon XL:** solo 2000–2013, los años de la Yukon XL 2500. Desde 2014 es solo 1500.
  - **Silverado, Sierra, Express y Savana:** sin límite, porque sus versiones HD (2500/3500) existieron en todos los años de cada línea.
  - **Suburban, sin límite por incertidumbre:**
    - La Suburban 2500 existió hasta 2013, y EPA la lista de 2011 a 2013.
    - No hay fuente oficial sobre si hubo una versión HD después de 2013 (por ejemplo, una 3500 HD para flotillas).
    - Acotar el rango sin evidencia sería inventarlo. Dejarlo abierto tiene como peor caso conservar filas marcadas `difiere`, en vez de borrar filas reales (criterio de D21).
    - Hoy afecta a la "Suburban" genérica 6.0L de 2010 y de 2014 a 2020. Esas filas se conservan como `difiere`.
    - Queda pendiente de una fuente.
  - **Verificación en `run6`:**
    - la Avalanche 6.0L 2010–2013 vuelve a quedar como `eliminada`;
    - Aplicaciones baja de 1,457 a 1,449 (8 filas);
    - "Motor · difiere" suma 237: 169 eliminadas, 66 conservadas por `confirm_only` y 2 por excepción revisada;
    - `run6` y `run6b` tienen las 8 hojas idénticas.
- **Validación dice qué pasó con la fila:** el texto de "Motor · difiere" termina con el resultado.
  - `eliminada`: catálogo USA, la aplicación sale de todos los mercados.
  - `se conserva solo MEX`: catálogo MEX, se niega solo la fila USA. Este cuarto texto no estaba en la propuesta aprobada; se agregó porque "eliminada" sería falso en ese caso.
  - `se conserva (confirm_only)`.
  - `se conserva (excepción revisada)`.
- **Tests nuevos** de casos que ya funcionaban pero nada protegía:
  - un motor conocido a medias (litros sin cilindros, o al revés) no se refuta;
  - un nombre de D20 con modelo mapeado en EPA no recibe fila USA;
  - un catálogo MEX con motor confirmado por EPA da fila MEX y fila USA;
  - un modelo que vPIC conoce no se rescata con ventas INEGI en un año sin confirmar.
- **Hallazgos menores,** registrados y no corregidos; también están en las limitaciones del README:
  1. Un error dentro de `MarketResolver` (extracto o YAML corruptos) no se convierte en "error de fuente": detiene la pieza. Los archivos están versionados y tienen test.
  2. Si falla la consulta de la lista de modelos de vPIC (`GetModelsForMake`), la pieza completa queda como "error de fuente". Hoy las respuestas están en caché y en fixtures.
  3. Las aplicaciones sin año pasan con el mercado de su catálogo, pero sin evidencia de mercado en Fuentes ni fila de Mercado en Validación.
  4. La Validación de Mercado muestra una sola URL por grupo (la menor). Fuentes conserva todas.
  5. `Epa.config` lee el YAML tres veces en la primera carga. Es un costo menor de arranque.
  6. Ningún test avisa si una excepción de `confirm_only_years` queda obsoleta después de actualizar el extracto de EPA. Al renovar el snapshot hay que repetir el reporte de refutaciones.

## 2026-11-06 13:09 — Hallazgo (adenda, Tarea 4): mercado MEX por ventas INEGI en la corrida real

- **Corrida:** `tmp/run3.xlsx`, hecha desde la caché. Había 404 snapshots antes y 404 después, así que no hubo ninguna solicitud nueva.
  - Para D20, antes se descargaron las listas de modelos de vPIC (`GetModelsForMake`) de Buick, Cadillac, Pontiac, Saab, Isuzu y Hummer: seis solicitudes con el User-Agent del proyecto, aprobadas por el desarrollador.
  - La lista de la armadora solo se consulta cuando vPIC no confirmó ningún año de la aplicación.
- **Aplicaciones:** 1,733 en `run3` contra 1,187 en `run2`.
  - Las filas USA no cambian: 1,154 (HL-7025S 1,130, SP26-329R/L+20 24). EPA todavía no interviene; entra en la Tarea 5.
  - Las filas MEX pasan de 33 a 579.

  | Pieza | MEX | USA |
  |---|---|---|
  | FSX-5840301 (Fraco, catálogo MEX) | 31 | — |
  | HL-7025S (Elgin, catálogo USA) | 526 | 1,130 |
  | RM-152 (Rexite, catálogo MEX) | 2 | — |
  | SP26-329R/L+20 (Safety, catálogo USA) | 20 | 24 |
- **Validación de Mercado** (filas agrupadas por pieza, armadora, modelo, mercado y nivel):
  - MEX "confirmado por ventas": 28.
  - MEX "según catálogo": 8. Son Fraco y Rexite, con aplicaciones de antes de 2005, el año en que empieza INEGI.
  - USA "según catálogo": 54.
- **D20, nombres que vPIC no conoce en ningún año:** entraron solo como MEX nivel a, en los años con ventas.
  - Cheyenne 2019–2024 (6 filas).
  - Sonora 2005–2007 (3).
  - Express Pasajeros 2005–2020 (26).
  - Express Cargo 2005–2025 (38).

  Sus demás años siguen en Validación como "Modelo-año · no encontrado".
- **Decisiones de implementación** (registro de la Tarea 4):
  - La marca `vpic_unknown` viaja en la aplicación desde `Vpic.expand` hasta `MarketResolver`, que la quita.
  - El resolvedor corre después del `Normalizer` y antes del `Reconciler`.
  - Validación registra también el nivel b de USA, porque el spec dice que Validación registra el nivel usado.
  - En esta tarea, el combustible de la fila MEX es el de la aplicación; la regla por mercado llega en la Tarea 6.

## 2026-11-06 13:15 — Hallazgo (adenda, Tarea 5): mercado USA y verificación de motor con EPA en la corrida real

- **Corrida:** `tmp/run4.xlsx`, hecha desde la caché. Había 404 snapshots antes y 404 después, así que no hubo ninguna solicitud nueva.
- **Aplicaciones:** 1,500 en `run4` contra 1,733 en `run3`.

  | Pieza | MEX | USA |
  |---|---|---|
  | FSX-5840301 (Fraco, catálogo MEX) | 31 | **14** (nuevas, nivel a) |
  | HL-7025S (Elgin, catálogo USA) | 448 (antes 526) | 961 (antes 1,130) |
  | RM-152 (Rexite, catálogo MEX) | 2 | — |
  | SP26-329R/L+20 (Safety, catálogo USA) | 20 | 24 |
- **Validación de Mercado** (filas agrupadas):
  - MEX "confirmado por ventas": 27.
  - MEX "según catálogo": 8.
  - USA "confirmado por EPA": 46.
  - USA "según catálogo": 27.
- **Nombre del nivel a en USA:** se llama "confirmado por EPA", no "confirmado por ventas", porque EPA no publica ventas. Confirma que el vehículo se ofreció en USA con ese motor.
- **Motor · difiere:** 237 filas en Validación, las mismas que dio el reporte previo de D22.
  - **169 eliminadas.** En catálogo USA, la aplicación sale de todos los mercados. Por eso HL-7025S pierde 169 filas USA y 78 filas MEX.
    - Ejemplos: Buick Allure 2005–2007 5.3L (EPA: 3.6L y 3.8L V6), Buick LaCrosse 2005–2006 5.3L.
  - **68 conservadas,** por `confirm_only` o por una excepción revisada.
    - Ejemplos: Express 2500 6.0L 2007–2008 (EPA solo lista "Express 1500/2500 2WD" con 5.3L), CTS 6.2L 2009.
- **Casos de control:**
  - **Allure 2005 5.3L** ya no aparece.
  - **Silverado 1500 2019 6.2L** se conserva en MEX y en USA.
- **Fraco ahora tiene filas USA (ver Tarea 6 abajo para el combustible):** las aplicaciones Nissan de Fraco (catálogo MEX) ganan 14 filas USA de nivel a. EPA lista "Truck 2WD/4WD" con el mismo motor 2.4L de 4 cilindros esos años. Es la regla de D19: el otro mercado entra solo con nivel a.

## 2026-11-06 15:15 — Hallazgo (adenda, Tarea 6): combustible de EPA solo en filas USA

- **Entradas nuevas en `fuels.yml`,** revisadas por el desarrollador:
  - Regular y Premium → Gasolina.
  - Gasoline or E85 (FFV) → Flex.
  - Diesel y Diesel (Diesel) → Diésel.
  - CNG (CNG) → Gas natural.

  Usan las mismas escrituras que ya existían, y un test lo fija.
- **Sin entrada, a propósito:** híbridos (EPA no distingue FHEV de MHEV), bifuel y eléctricos. Quedan como "sin traducción".
- **Corrida:** `tmp/run6.xlsx`, desde la caché (404 snapshots antes y después). Doble corrida contra `tmp/run6b.xlsx`: contenido idéntico en las 8 hojas.
- **Aplicaciones:** 1,449 (977 USA, 472 MEX).
  - **Diferencia con `run4`:** la bajada desde 1,500 se debe a filas que solo se distinguían por el combustible y ahora salen idénticas. Al comparar `run4` con `run5` sin la columna Combustible, no falta ninguna aplicación.
  - **Otras 8 filas menos:** son la Avalanche 6.0L 2010–2013, que vuelve a eliminarse con `confirm_only` por años.
- **Combustible en filas USA:** 473 llenas (337 Gasolina, 136 Flex) y 504 vacías.
  - **Vacías por ambigüedad (132 casos únicos en Fuentes, con la lista de EPA):**
    - "Gasoline or E85 (FFV), Regular": 89. Es el mismo motor en versión FFV y no FFV.
    - "Regular (Hybrid)" solo: 25.
    - Otras combinaciones con híbridos: 18.
  - **Vacías por otra razón:** el resto son filas USA de nivel b, sin datos de EPA (HD, años sin la serie), o filas `confirm_only` cuyo motor no coincidió.
- **Combustible en filas MEX:** ninguna lo lleva. Un catálogo USA no habla por México, y Fraco y Rexite (catálogos MEX) no publican combustible.
- **Validación:**
  - "Combustible · difiere": 8. El catálogo USA y EPA dan combustibles distintos; se conserva el del catálogo.
  - "Traducción · sin traducción": 43 de EPA ("Regular (Hybrid)" 41, "Premium (Hybrid)" 2).

## 2026-11-06 15:43 — Tarea 16: corrida de entrega, snapshots y CI en verde

- **Corrida real:** `docs/output/catalogo_bonaparte.xlsx`, desde la caché. Había 404 snapshots antes y 404 después, así que no hubo ninguna solicitud de red.
  - Aplicaciones 1,449 (977 USA, 472 MEX), Intercambios 0, Atributos 10, Fuentes 2,853, Validación 517.
  - Contenido idéntico al de `tmp/run6.xlsx` en las 8 hojas.
- **Snapshots:** `bin/rails catalog:snapshots:dump` exportó los 404 a `db/snapshots/` (7.7 MB), versionados junto con el Excel.
- **README:** completo, revisado por el desarrollador. Incluye el principio "toda la información es comprobable", Validación como diagnóstico de los datos de origen, la visión para producción (VCdb, ACES/PIES, adaptadores por proveedor) y la sección "Proceso", con el uso de IA.
- **Intercambios vacía:** ningún número del ERP tiene confirmación oficial dentro de las fuentes que consulta la app. FS-001225 se confirmó en la investigación, pero el adaptador DC/Dacomsa se recortó (D19, prioridad 3) y queda pendiente.
- **CI (D17):** `poppler-utils` en el job `test` y en el `Dockerfile`; se quitaron el job `system-test` y `.github/dependabot.yml`. PR #5 (`feature/catalog-pipeline` → `master`): `lint`, `scan_js`, `scan_ruby` y `test` en verde. La causa `db/schema.rb doesn't exist yet` desapareció, como se esperaba.

## 2026-11-06 16:07 — Revisión final de la rama y correcciones

**Revisor independiente** (contexto nuevo, solo lectura, sobre `dd9f156..0a18287`): "listo con correcciones", sin hallazgos críticos. El desarrollador aprobó la clasificación y subió dos menores a importantes.

**Corregido, cada uno con su test fallando primero:**
1. **Un error inesperado en una pieza colgaba la corrida web.** Un error fuera de los adaptadores (un YAML dañado, un bug) dejaba la pieza en "consultando fuente" y el Excel nunca se armaba. Ahora la pieza termina con estado `error`, sin datos, y Validación registra `Proceso · error interno` con el error. Las demás piezas y el Excel siguen.
2. **`FORCE_REFRESH=1` descargaba la misma URL muchas veces.** vPIC habría recibido unas 1,000 solicitudes repetidas. Ahora cada URL se descarga como máximo una vez por proceso.
3. **Una hoja Origen sin piezas dejaba la pantalla en "Procesando…".** Ahora se rechaza: "La hoja Origen no tiene piezas."
4. **Origen perdía el tipo de las celdas.** Un código de texto como `"00451"` salía como el número 451. Ahora se guarda cada celda tal como se leyó (columna nueva `source_items.origin_values`): un número sigue siendo número y un texto sigue siendo texto, con sus ceros.

**Menores incluidos a pedido del desarrollador:**
- Test de que un dato que empieza con "=" sale como texto. Pasó desde el principio, porque caxlsx ya lo protege por defecto; el test impide que esa protección se desactive sin que nadie lo note.
- El README registra la versión de poppler usada (26.08.0).

**Comprobado sin cambios:** subir un `.docx` (un zip que no es Excel) ya daba el mensaje "no es un Excel válido". El test se queda.

**Se quedan como están** (app local de prueba, sin efecto en el contenido): sin autenticación, sin límite de tamaño de archivo, `snapshots:load` sin comparar sha256, redirecciones como "error de fuente", `||=` entre hilos, y D20.

**Resultado:** 233 pruebas en verde y rubocop limpio. El Excel de entrega, regenerado, es idéntico en las 8 hojas.

## 2026-11-06 16:21 — Sesión de verificación (Tarea 16, Paso 4), parte automática

1. **Clon limpio** de `feature/catalog-pipeline` (`6656dc0`), siguiendo el README: `bin/setup --skip-server` terminó sin errores y cargó los 404 snapshots. No faltó ningún paso.
2. **`bin/ci` en el clon:** en verde. Pasaron estilo, auditoría de gemas, importmap, Brakeman, 233 pruebas y seeds.
3. **Subida por la pantalla y GIF:** pendiente, la hace el desarrollador en su navegador.
4. **Estructura contra `ejemplo_prueba_tecnica.xlsx`:** las 6 hojas del ejemplo, en el mismo orden, con encabezados idénticos y la misma columna A en Métricas.
   - **Tipos:** en cada columna, número o texto como en el ejemplo. Las únicas diferencias son del ejemplo, que mezcla tipos en una misma columna: algunos Modelo como número y algunos CC/CID como texto. Nuestro Excel usa un solo tipo por columna.
5. **Doble corrida en el clon:** dos corridas seguidas dan contenido idéntico entre sí y con `docs/output/catalogo_bonaparte.xlsx`, en las 8 hojas. Había 404 snapshots antes y 404 después: ninguna solicitud de red.
   - **Prueba nueva** `test/integration/delivered_catalog_test.rb`: regenera el Excel de entrega desde `db/snapshots` y lo compara hoja por hoja. Primero falló sin cargar los snapshots (la app intentó ir a la red y WebMock lo bloqueó); con ellos pasa. Así, los conteos del README quedan cubiertos por una prueba.
