# Adenda al spec: Mercado por ventas, verificación de motor y combustible (D19)

**Fecha:** 2026-11-06 · **Estado:** aprobada por el desarrollador
**Modifica:** `2026-11-05-catalogador-design.md` §4.3 (Mercado y Submodelo, D3) y §5.7 (vPIC). Todo lo demás del spec sigue vigente.

## 0. Resumen en lenguaje simple

Hasta ahora, el Mercado de cada aplicación era el del catálogo que la reporta: Elgin → USA, Fraco → MEX (D3). El evaluador pidió conseguir o generar los datos que faltan, con estrategias comprobables. Con esta adenda:

- **El mercado se decide por dónde se vendió el vehículo**, no por el catálogo ni por dónde se fabricó.
  - **MEX** lo confirman las **ventas de INEGI**.
  - **USA** lo confirma **EPA fueleconomy.gov**.
  - Si una fuente de ventas no cubre ese modelo-año, se usa el mercado del catálogo, y queda dicho.
- **EPA también verifica el motor** de las aplicaciones de EE. UU. Si EPA tiene ese modelo-año y ninguno de sus motores coincide, la aplicación **se elimina**: es una combinación que no existió, como "Buick Allure 2005 5.3L".
- **EPA llena Combustible** en la fila USA cuando hay un solo combustible posible para ese motor.
- **Submodelo** sigue vacío: ninguna fuente oficial gratuita lo publica. El README describe la estrategia para producción.
- Nada se inventa. Cada dato vale **solo para el mercado de la fuente que lo respalda**, y cada decisión deja su URL en Fuentes y su nivel en Validación.

## 1. Intención

El evaluador quiere ver qué estrategias se eligen cuando hay mucha incertidumbre: *"la idea es que encuentres la manera de conseguir, o generar, esa data"*. El principio no cambia: **todo comprobable, nada inventado**. Esta adenda sustituye una regla arbitraria (el mercado del catálogo) por evidencia oficial de ventas, y usa una segunda fuente oficial para eliminar combinaciones falsas que hoy genera el cruce motor × modelo de Elgin.

## 2. Metas, no-metas, anti-metas

**Metas**
1. Mercado MEX con evidencia de ventas (INEGI) donde exista. **Va primero** **[decisión del desarrollador]**.
2. Verificación de motor con EPA para modelo-años que EPA cubre, y eliminación de combinaciones refutadas. **Va segundo.**
3. Combustible desde EPA en filas USA cuando no es ambiguo. **Va tercero.**
4. Tablas de equivalencias de nombres explícitas, en YAML, revisadas por el desarrollador.

**No-metas**
- Submodelo/versión: no hay fuente oficial gratuita (§7).
- Verificar el motor en MEX: INEGI no publica motor.
- Mercados distintos de MEX y USA.

**Anti-metas** (fracaso aunque "funcione")
- Una fila MEX o USA sin evidencia de ese mercado: ni de ventas (nivel a) ni del catálogo de ese mismo mercado (nivel b).
- Eliminar una aplicación por *falta* de datos: solo se elimina cuando EPA la **refuta**.
- Llevar un dato de un mercado a otro, como el combustible de EPA a la fila MEX.
- Equivalencias de nombres "adivinadas" en el código en lugar de una tabla revisada.

## 3. Fuentes

### 3.1 INEGI RAIAVL — ventas en México **[decisión del desarrollador]**
- **Archivo:** datos abiertos "Registro Administrativo de la Industria Automotriz de Vehículos Ligeros. Venta de vehículos", de `https://www.inegi.org.mx/datosprimarios/iavl/`, 2005-01 a 2026-09. El desarrollador lo descargó a mano: la API PxWeb respondió 403 y el tabulado limita la exportación a 150,000 celdas.
- **Versionado:**
  - ZIP original: `db/reference/inegi/conjunto_de_datos_raiavl_mensual_venta_csv.zip`.
  - Procedencia: `.yml` con URL, fecha y sha256.
  - Extracto que lee la app: `db/reference/inegi/raiavl_venta_nissan_gm.csv`, generado por `bin/rails catalog:inegi:filter`. Su test lo regenera y compara el sha256. **Ya implementado.**
- **Qué aporta:** venta por año calendario, mes, grupo (`MARCA` = "General Motors" o "Nissan") y nombre comercial mexicano (`MODELO`). **No** trae motor, versión ni combustible.
- **Criterio "vendido ese año":** suma de `UNI_VEH` **mayor a cero** en el **mismo año calendario** que el año modelo de la aplicación **[decisión del desarrollador]**. Por qué es estricto:
  - un año modelo se vende durante casi todo su año calendario;
  - una ventana más amplia confirmaría años posteriores a la descontinuación por ventas de inventario;
  - INEGI solo decide el mercado: la existencia del modelo-año la confirman el catálogo y vPIC.

### 3.2 EPA fueleconomy.gov — ventas y motores en EE. UU.
- **Qué es:** el servicio público de la EPA, sin llave. Cubre los años modelo 1984–2027.
- **Qué aporta por modelo-año:** las configuraciones certificadas para EE. UU., con cilindrada (`displ`), cilindros (`cylinders`), combustible (`fuelType`), tracción y transmisión. **No** trae versión: `trim` viene vacío.
- **Cobertura:** vehículos ligeros. **No** incluye pickups pesadas (Silverado/Sierra 2500/3500 HD) ni modelos solo mexicanos (Ichivan, Tsuru, Estaquitas).
- **Cómo se consulta** **[criterio de diseño, a confirmar en el plan]:**
  - **Opción preferida:** el archivo masivo oficial de EPA (`vehicles.csv`). Sería una descarga versionada como la de INEGI, con procedencia y extracto filtrado. Así se evitan miles de solicitudes y queda un snapshot fijo.
  - **Alternativa** si el archivo no existe o no es utilizable: la API `/ws/rest/vehicle/menu/{model,options}` y `/ws/rest/vehicle/{id}`, a través de `Catalog::Fetcher`, con caché `SourceSnapshot`, User-Agent del proyecto y 1 solicitud por segundo.
  - La primera tarea del plan es verificar cuál de las dos se usa, con una sola solicitud mostrada antes al desarrollador.

### 3.3 Rol de cada fuente USA **[decisión del desarrollador]**
- **vPIC** sigue confirmando que **el modelo existió ese año** (D8, spec §5.7). Cubre también las HD.
- **EPA** agrega la **verificación de motor y combustible** donde tiene cobertura, y es la evidencia de venta en EE. UU. (nivel a de USA).
- Ninguna de las dos es fuente de aplicaciones: la aplicación sigue siendo del catálogo de la pieza.

## 4. Reglas de negocio

### 4.1 Mercado por niveles, por mercado **[decisión del desarrollador]**
Para cada aplicación con año modelo se evalúa **cada mercado por separado**:

| Nivel | MEX | USA |
|---|---|---|
| **a — confirmado por ventas** | ventas INEGI > 0 ese año calendario | EPA lista ese modelo-año **y**, si la aplicación trae motor, tiene una configuración con motor coincidente (regla de §4.2) |
| **b — según catálogo** | solo si el catálogo de la aplicación es de mercado MEX | solo si el catálogo de la aplicación es de mercado USA |

- **Una fila por cada mercado** que quede con nivel a o b.
- **El nivel b solo vale para el mercado del propio catálogo.** El otro mercado entra únicamente con nivel a.
- Toda aplicación conserva al menos el mercado de su catálogo (nivel b), así que **ninguna se pierde por falta de ventas**. Solo la elimina la regla 4.2, y solo si su catálogo es USA.
- **Ejemplos:**
  - Silverado 2500 HD 2016 (Elgin): MEX nivel a (INEGI) + USA nivel b (EPA no cubre HD; vPIC confirma que existió).
  - Nissan D21 1993 (Fraco): MEX nivel b (INEGI empieza en 2005) + USA nivel a, solo si EPA lista el equivalente ("Truck 2WD/4WD") ese año.
- **Filas vía intercambio** (complementos, D11): mismas reglas, con el mercado del catálogo que reporta la aplicación.
- **Sin equivalencia en el YAML** (§4.4): ese mercado no puede llegar al nivel a. Que un nombre no esté en la tabla **nunca** se interpreta como "no se vendió".

### 4.2 Verificación de motor con EPA **[decisión del desarrollador]**
- **Aplica** cuando la aplicación trae litros y cilindros, su modelo tiene equivalencia EPA y **EPA lista ese modelo-año**.
- **Coincide** si alguna configuración de EPA de ese modelo-año tiene la misma cilindrada (redondeada a 1 decimal) y los mismos cilindros **[criterio de diseño]**.
- **Si ninguna coincide, el resultado depende del mercado del catálogo** **[decisión del desarrollador]**:
  - **Catálogo USA** (Elgin, Safety): la fila **se elimina de Aplicaciones en todos los mercados** (caso Allure 2005 5.3L). Por qué: el dato viene de un catálogo de EE. UU. y la fuente oficial de EE. UU. lo refuta.
  - **Catálogo MEX** (Fraco, Rexite): **se conserva la fila MEX** y solo se niega la fila USA. El motor puede ser una configuración que se vendió en México y no en EE. UU.
- En los dos casos, Validación registra `difiere` en el mercado USA, con:
  - el motor de la fuente,
  - los motores de EPA de ese modelo-año,
  - las dos URLs.
- **Si EPA no cubre ese modelo-año** (HD, modelo solo mexicano, año sin datos) o la aplicación no trae motor, **no se verifica ni se elimina**.
- Una fila eliminada no genera filas en Fuentes ni en la descripción del Catálogo.

### 4.3 Combustible **[decisión del desarrollador]**
- **Regla general: cada dato vale para el mercado de la fuente que lo respalda.**
- **Fila USA:** se toman las configuraciones de EPA de ese modelo-año que coinciden con el motor (4.2).
  - Si todas tienen **un solo** combustible, se llena `Combustible` con ese valor, normalizado con `config/catalog/fuels.yml`. En Fuentes queda la URL de EPA.
  - Si hay **varios** (por ejemplo, Silverado 5.3 L 2016 con y sin FFV), queda vacío, y la lista de EPA va a Fuentes como valor original. Es la misma regla que D15.
- **Fila MEX:** `Combustible` queda **vacío**, salvo que una fuente del mercado mexicano lo indique. El combustible de EPA nunca se copia a la fila MEX (FFV/E85 no aplica igual en México).
- **Si el catálogo ya trae un solo combustible (D15) y EPA da otro distinto** **[criterio de diseño]**: se conserva el del catálogo de la pieza, y Validación registra `difiere` con los dos valores y las dos URLs.
- Valores nuevos de EPA (por ejemplo "Gasoline or E85", "Regular") se agregan a `fuels.yml` y los revisa el desarrollador.

### 4.4 Tablas de equivalencias de nombres **[decisión del desarrollador]**
- Dos archivos nuevos, explícitos y **revisados por el desarrollador antes del commit**, igual que `vpic_aliases.yml` (D14):
  - `config/catalog/inegi_models.yml`: (armadora, modelo nuestro) → lista de (`MARCA`, `MODELO`) de INEGI. Ejemplos: Chevrolet "Silverado 1500" → "Silverado 1500 Cabina Regular", "Silverado Cabina Regular"…; Nissan "Pickup" → "Pickup Largo", "Pickup Doble Cabina"…
  - `config/catalog/epa_models.yml`: (armadora, modelo nuestro) → lista de (`make`, `model`) de EPA. Ejemplos: Nissan "D21" → "Truck 2WD", "Truck 4WD"; Chevrolet "Silverado 1500" → "Silverado C15 2WD", "Silverado K15 4WD"…
- El constructor propone las tablas a partir de los datos reales (extracto de INEGI y menús de EPA). Cada entrada lleva un comentario con el motivo. El desarrollador las revisa.
- Para resolver el grupo "General Motors" de INEGI hace falta la armadora: la tabla va de (armadora, modelo) a nombres de INEGI, nunca al revés. Así, Chevrolet y GMC no se confunden.
- La comparación con las tablas es exacta, después de quitar espacios repetidos y al inicio o al final **[criterio de diseño]**.

### 4.5 Trazabilidad **[criterio de diseño]**
- **Fuentes** (por fila y mercado):
  - nivel a de MEX → origen `ventas INEGI RAIAVL`, URL de la página de datos abiertos, valor original "MODELO INEGI · año · unidades";
  - nivel a de USA → origen `EPA fueleconomy.gov`, URL del modelo-año en EPA;
  - nivel b → origen `mercado según catálogo`, URL del catálogo.
- **Validación**, campo `Mercado`: se agrupa por pieza × armadora × modelo × mercado × nivel, con rangos de años como en vPIC ("2016-2020"), en lugar de una fila por año. Así Validación sigue siendo legible con más de mil aplicaciones.
  - Estado: `confirmado por ventas` (nivel a) o `según catálogo` (nivel b).
  - El modelo-año eliminado por EPA va con el campo `Motor` y el estado `difiere` (4.2).
- **Orden total** de Aplicaciones: el actual más `Mercado`, para conservar el determinismo.

## 5. Encaje con el código actual (para el constructor)
- `Sources::*` sigue declarando `MARKET`: es el **mercado del catálogo**, usado para el nivel b.
- La expansión de años de vPIC (`Catalog::Vpic.expand`) no cambia. El cálculo de mercados y la verificación de EPA van **después** de esa expansión y **antes** de normalizar, en `Catalog::ItemProcessor`.
- Nombres sugeridos, a criterio del constructor: `Catalog::InegiSales` (lee el extracto), `Catalog::Epa` (configuraciones por modelo-año) y `Catalog::MarketResolver` (niveles, motor y combustible).
- Las pruebas no usan la red: el extracto de INEGI ya está versionado, y EPA usa snapshots o un extracto como fixtures.
- Prueba de doble corrida: sin cambios; el contenido debe ser idéntico.

## 6. Limitaciones conocidas (van al README)
1. **Año de venta vs. año modelo:** INEGI cuenta ventas por año calendario y se compara con el año modelo de forma estricta (§3.1).
2. **MEX sin verificación de motor:** INEGI no publica motor.
3. **EPA no cubre HD ni modelos solo mexicanos:** ahí USA queda en nivel b (si el catálogo es de EE. UU.) y el motor no se verifica.
4. **INEGI empieza en 2005:** antes de 2005, MEX solo puede ser nivel b.
5. **"General Motors" es un grupo:** la marca se resuelve con la tabla de equivalencias, no con INEGI.
6. **Submodelo vacío** (§7).

## 7. Submodelo **[decisión del desarrollador]**
- Ni EPA (`trim` vacío) ni INEGI (nombre comercial sin versión) aportan versión. **Queda vacío.**
- El README describe la estrategia para producción: una base de vehículos licenciada (por ejemplo VCdb de Auto Care Association, con submodelo y motor por año y mercado) o acuerdos de datos con los fabricantes.

## 8. Prioridad y recorte **[decisión del desarrollador]**
1. **Tarea 16 completa** (CI en verde con PR, snapshots, README, sesión de verificación): **no se recorta**.
2. **Esta adenda:** primero INEGI (mercado MEX por niveles), después EPA (motor y luego combustible).
3. **Adaptador DC/Dacomsa:** es lo primero que se recorta. Si no entra, el README explica que FS-001225 se confirmó en la investigación (`DECISIONS.md`, Tarea 15b) y el adaptador queda como trabajo pendiente.

## 9. A criterio del constructor
- Nombres de clases y la forma interna de las tablas YAML.
- Cómo se cachean o indexan en memoria el extracto de INEGI y los datos de EPA.

## 10. Cómo quedó implementado (diferencias con este documento)
Decisiones tomadas al implementar. Cada una está en `docs/DECISIONS.md` con su razonamiento.
- **§5, orden:** el cálculo de mercados va **después** de normalizar, no antes. Las tablas usan nombres ya normalizados ("Chevrolet").
- **§4.4, equivalencias INEGI (D20):** la capacidad nunca se infiere.
  - Nombre genérico → todas las series de la línea.
  - Nombre con capacidad → solo las series que la dicen.
  - Nombre mexicano de Elgin → la serie con el mismo nombre.
- **§3.3 y §4.1, nombres que vPIC no conoce en ningún año (D20):** entran solo como MEX nivel a, en los años con ventas INEGI.
- **§4.4, equivalencias EPA (D21):** son inclusivas. "1500" es toda la línea ligera de EPA, porque una equivalencia faltante borraría filas correctas.
- **§4.2, refutación (D22):** EPA solo refuta un motor donde su cobertura de esa línea es completa.
  - `confirm_only` (nombres 2500/3500/HD y genéricos de líneas con HD, acotados por años donde aplica) solo confirma.
  - Lo mismo las excepciones revisadas por modelo · año · motor.
  - En esos casos la fila se conserva y Validación registra `difiere`.
  - El texto de "Motor · difiere" termina con el resultado: `eliminada`, `se conserva solo MEX`, `se conserva (confirm_only)` o `se conserva (excepción revisada)`.
- **§4.5, estados:** el nivel a de USA se llama `confirmado por EPA`, no `confirmado por ventas`, porque EPA no publica ventas. Validación también registra el nivel b de USA.
- **§4.3, combustible:** un combustible de EPA sin entrada en `fuels.yml` (híbridos, bifuel, eléctricos) no se adivina. Queda vacío y se registra `sin traducción`.
- La redacción exacta de los textos de Validación y Fuentes, siempre que incluya nivel, fuente y URL.
