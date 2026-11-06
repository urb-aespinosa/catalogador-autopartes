# Bitácora de decisiones

Formato: fecha y hora (CDMX) · decisión · por qué · consecuencias.

## Registro de horas

| Sesión | Fecha | Inicio | Fin | Horas | Qué se hizo |
|---|---|---|---|---|---|
| 1 | 2026-11-05 | 11:07 | 18:12 | 7.1 | Esqueleto Rails, brief, CLAUDE.md, spike de fuentes, brainstorming, decisiones D1–D16, spec aprobado, plan, Tareas 1–15 (pipeline completo, 3 revisiones independientes, UI con progreso en vivo, primera corrida real y doble corrida idéntica) |

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
