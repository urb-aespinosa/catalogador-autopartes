# Adenda de mercado (D19) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El Mercado de cada aplicación sale de evidencia de ventas (INEGI → MEX, EPA → USA) por niveles. EPA refuta motores que no existieron y llena Combustible en filas USA.

**Architecture:**
- Dos lectores de datos versionados, sin red en ejecución:
  - `Catalog::InegiSales` lee el extracto INEGI que ya existe.
  - `Catalog::Epa` lee un extracto nuevo del archivo masivo de EPA.
- Los dos traducen nombres con tablas YAML revisadas por el desarrollador.
- `Catalog::MarketResolver` toma las aplicaciones ya normalizadas de una pieza y devuelve:
  - las filas por mercado, con su evidencia en Fuentes;
  - las filas de Validación (nivel, motor, combustible).
- `Catalog::ItemProcessor` lo llama entre `Normalizer` y `Reconciler`.
- **Desvío deliberado del spec §5:** la adenda sugería resolver el mercado antes de normalizar. Aquí va **después**, porque las tablas YAML y el combustible se comparan con armadoras y combustibles ya en el vocabulario del Excel ("Chevrolet", "Gasolina"). La adenda deja este detalle a criterio del constructor (§9).

**Tech Stack:** Ruby 3.3.5, Rails 8.1, Minitest, `csv`, `rubyzip` (ya en el bundle), YAML.

**Spec:** `docs/superpowers/specs/2026-11-06-mercado-adenda-design.md` (aprobada). D19 en `docs/DECISIONS.md`.

## Global Constraints

- Cada solicitud HTTP usa el User-Agent `catalogador-autopartes/1.0 (prueba tecnica)`, con máximo una por segundo por sitio. Nunca un User-Agent de navegador. Antes de cualquier solicitud, se le muestra al desarrollador el comando exacto.
- Si un sitio bloquea o no responde, no se esquiva: se registra en `DECISIONS.md` como "el sitio bloquea solicitudes automatizadas".
- Los tests no usan la red. Los datos de referencia viven versionados en `db/reference/`, con un `.yml` de procedencia (URL, fecha, sha256).
- `config/catalog/inegi_models.yml`, `config/catalog/epa_models.yml` y las entradas nuevas de `config/catalog/fuels.yml` **las revisa el desarrollador antes del commit**. Hay que mostrárselas y esperar su aprobación.
- Textos fijos del spec, copiados tal cual:
  - estados de Validación: `confirmado por ventas`, `según catálogo`, `difiere`;
  - campos de Validación: `Mercado`, `Motor`, `Combustible`;
  - origen en Fuentes del nivel b: `mercado según catálogo`.
- Criterio de venta MEX: suma de `UNI_VEH` **> 0** en el **mismo año calendario** que el año modelo.
- Comparación de motor: `liters.round(1)` igual a `displ.round(1)` **y** los mismos cilindros.
- Regla general: cada dato vale para el mercado de la fuente que lo respalda.
- Determinismo: dos corridas dan contenido idéntico (`test/integration/determinism_test.rb`).
- Strict TDD. Commits pequeños. Push al terminar cada tarea. Código y commits en inglés; textos del Excel en español.

## Review Focus

1. **Una aplicación sin año** (`year` nil) o sin motor (falta `liters` o `cylinders`) no debe romper nada. Sin año, se conserva tal cual, con el mercado de su catálogo. Sin motor, no se verifica (Task 5).
2. **Nombres de INEGI con espacios dobles o guiones al final** ("Cheyenne  Doble Cabina", "Aveo-"). Se comparan después de quitar espacios repetidos y al inicio o al final, nunca con similitud (Task 2).
3. **Cilindradas como 5.33 o 5.3** de distintas fuentes. Se comparan redondeadas a 1 decimal (Task 5).
4. **La misma aplicación repetida en una pieza.** Las filas por mercado y las de Validación no deben duplicarse (Task 4).
5. **Un modelo sin equivalencia en el YAML.** Nunca se interpreta como "no vendido": solo impide el nivel a de ese mercado (Tasks 4 y 5).

---

### Task 1: Extracto versionado del archivo masivo de EPA

**Files:**
- Create: `db/reference/epa/vehicles.csv.zip` (descarga), `db/reference/epa/vehicles.yml` (procedencia), `db/reference/epa/vehicles_scope.csv` (extracto)
- Create: `app/services/catalog/epa_vehicles_filter.rb`, `test/services/catalog/epa_vehicles_filter_test.rb`
- Modify: `lib/tasks/catalog.rake` (tarea `catalog:epa:filter`), `docs/DECISIONS.md`

**Interfaces:**
- Produces: `Catalog::EpaVehiclesFilter.call(source = SOURCE, output = OUTPUT, makes: MAKES) -> Integer` (filas escritas). Constantes `SOURCE`, `OUTPUT`, `MAKES = %w[Buick Cadillac Chevrolet GMC Hummer Isuzu Nissan Pontiac Saab]`.
- Produces: `db/reference/epa/vehicles_scope.csv`, columnas `year,make,model,id,displ,cylinders,fuelType,atvType`, orden total por esas columnas (`year`, `id`, `displ` y `cylinders` numéricos).

- [ ] **Step 1: Verificar la fuente.** Mostrarle al desarrollador este comando (una sola solicitud HEAD) y ejecutarlo solo con su aprobación:
  `curl -sI -A "catalogador-autopartes/1.0 (prueba tecnica)" https://www.fueleconomy.gov/feg/epadata/vehicles.csv.zip`
  - Esperado: `200`, con `Content-Length` en MB.
  - Si no es 200: registrar el hallazgo en `DECISIONS.md` y detenerse. El plan B (API con caché) se acuerda con el desarrollador.
- [ ] **Step 2: Descargar** con el mismo User-Agent a `db/reference/epa/vehicles.csv.zip`, calcular el sha256 y escribir `vehicles.yml`: URL, fecha y hora (de `date`), sha256, bytes, columnas usadas y regla del extracto. Mismo formato que `db/reference/inegi/conjunto_de_datos_raiavl_mensual_venta_csv.yml`.
- [ ] **Step 3: Test que falle**, con la misma estructura que `test/services/catalog/inegi_sales_filter_test.rb`:
  - `keeps the makes in scope, only the used columns, sorted totally`: un ZIP pequeño con un `vehicles.csv` de 3 marcas (Toyota se descarta) y columnas extra. Se compara el CSV exacto de salida.
  - `two runs produce identical bytes`.
  - `a missing column fails loudly`: lanza `Catalog::EpaVehiclesFilter::FormatError` sin escribir el archivo.
  - `the committed extract is exactly what the committed zip produces`: compara sha256.
- [ ] **Step 4:** `bin/rails test test/services/catalog/epa_vehicles_filter_test.rb`. Esperado: FAIL (`uninitialized constant`).
- [ ] **Step 5: Implementar `EpaVehiclesFilter`.** Lee la única entrada `.csv` del ZIP con encabezado y selecciona las columnas por nombre: el archivo de EPA trae muchas más, y su orden no es estable. Si falta alguna columna, `FormatError`. Agregar la tarea `catalog:epa:filter`.
- [ ] **Step 6:** `bin/rails catalog:epa:filter`, luego `bin/rails test test/services/catalog/epa_vehicles_filter_test.rb`. Esperado: PASS.
- [ ] **Step 7:** Registrar en `DECISIONS.md` (hora de `date`): fuente, tamaño y filas del extracto. Commit `feat: version EPA vehicles snapshot with a deterministic in-scope extract` y push.

### Task 2: `Catalog::InegiSales` y `inegi_models.yml`

**Files:**
- Create: `app/services/catalog/inegi_sales.rb`, `test/services/catalog/inegi_sales_test.rb`, `config/catalog/inegi_models.yml`

**Interfaces:**
- Consumes: `Catalog::InegiSalesFilter::OUTPUT` (CSV existente).
- Produces: `Catalog::InegiSales.new(rows: default_rows, models: default_models)`, más `Catalog::InegiSales.default` (instancia memoizada).
  - `#sales(make:, model:, year:) -> Array<[String, Integer]>`: pares (MODELO de INEGI, unidades), solo los que tienen total > 0 ese año, ordenados por MODELO. `[]` si no hay ventas o no hay equivalencia.
  - `#mapped?(make:, model:) -> Boolean`.
  - `SOURCE_URL = "https://www.inegi.org.mx/datosprimarios/iavl/"`.
- YAML: `{ "Chevrolet" => { "Silverado 1500" => [ { "marca" => "General Motors", "modelo" => "Silverado 1500 Cabina Regular" }, … ] } }`. Cada entrada lleva un comentario con el motivo.

- [ ] **Step 1: Test que falle**, inyectando `rows:` y `models:` pequeños:
  - `sums the twelve months and keeps only positive totals`: dos meses de 2016 con 3 y 0 unidades → `[["Silverado 1500 Cabina Regular", 3]]`; un año con 0 en todos los meses → `[]`.
  - `the sale must be in the same calendar year as the model year`: ventas solo en 2015 → `sales(year: 2016) == []`.
  - `names match after collapsing repeated and edge spaces`: la fila de INEGI `"Cheyenne  Doble Cabina "` coincide con el YAML `"Cheyenne Doble Cabina"`.
  - `General Motors rows only count for the make that maps them`: el mismo MODELO mapeado a Chevrolet no cuenta para GMC.
  - `an unmapped model has no sales and is not mapped`: `mapped?` es false y `sales` es `[]`.
- [ ] **Step 2:** `bin/rails test test/services/catalog/inegi_sales_test.rb`. Esperado: FAIL.
- [ ] **Step 3: Implementar.** Indexar una vez `{ [MARCA, modelo_normalizado, ANIO] => total }`.
- [ ] **Step 4:** Mismo comando. Esperado: PASS.
- [ ] **Step 5: Borrador de `inegi_models.yml`.** Para cada (armadora, modelo) de `tmp/run2.xlsx` (hoja Aplicaciones), proponer los MODELO de INEGI del extracto. Solo equivalencias evidentes por nombre y segmento; si hay duda, se deja fuera con un comentario.
- [ ] **Step 6: Mostrarle el YAML completo al desarrollador** y esperar su revisión. Aplicar sus cambios.
- [ ] **Step 7:** Commit `feat: INEGI sales lookup with reviewed model equivalences` y push.

### Task 3: `Catalog::Epa` y `epa_models.yml`

**Files:**
- Create: `app/services/catalog/epa.rb`, `test/services/catalog/epa_test.rb`, `config/catalog/epa_models.yml`

**Interfaces:**
- Consumes: `Catalog::EpaVehiclesFilter::OUTPUT` (Task 1).
- Produces: `Catalog::Epa::Configuration = Data.define(:id, :model, :displ, :cylinders, :fuel_key)`. `fuel_key` es `fuelType`, o `"#{fuelType} (#{atvType})"` si `atvType` no está vacío.
- Produces: `Catalog::Epa.new(rows:, models:)` y `Catalog::Epa.default`:
  - `#configurations(make:, model:, year:) -> Array<Configuration> | nil`: `nil` si no hay equivalencia **o** si EPA no tiene ninguno de los modelos equivalentes ese año. Ordenadas por `id`.
  - `#options_url(make:, year:, epa_model:) -> String`: `https://www.fueleconomy.gov/ws/rest/vehicle/menu/options?year=#{year}&make=#{make}&model=#{model_encoded}`, con el modelo codificado por `Catalog::Fetcher.encode_path`.
  - `#evidence_url(make:, year:, configurations:) -> String`: el `options_url` del modelo EPA de la primera configuración.
- YAML: `{ "Nissan" => { "D21" => [ "Truck 2WD", "Truck 4WD" ] }, "Buick" => { "Allure" => [ "Lacrosse/Allure" ] } }`, con comentarios.

- [ ] **Step 1: Test que falle**, con `rows:` y `models:` inyectados:
  - `returns every configuration of the equivalent EPA models that year`: Buick Allure 2005 → displ `[3.6, 3.8]`, cylinders `[6, 6]`.
  - `nil when the model is not mapped`.
  - `nil when EPA has no equivalent model that year` (HD).
  - `fuel_key includes the ATV type`: `atvType "Hybrid"` → `"Regular (Hybrid)"`.
  - `options_url encodes the model`: `"Lacrosse/Allure"` → `model=Lacrosse%2FAllure`.
- [ ] **Step 2:** `bin/rails test test/services/catalog/epa_test.rb`. Esperado: FAIL.
- [ ] **Step 3: Implementar.** Índice `{ [make, model, year] => [Configuration] }`.
- [ ] **Step 4:** Mismo comando. Esperado: PASS.
- [ ] **Step 5: Borrador de `epa_models.yml`** a partir de `tmp/run2.xlsx` y del extracto (modelos EPA por marca y año), con comentarios. Mostrárselo al desarrollador, esperar su revisión y aplicar sus cambios.
- [ ] **Step 6:** Commit `feat: EPA configurations lookup with reviewed model equivalences` y push.

### Task 4: Mercado MEX por niveles (INEGI) en el pipeline

**Files:**
- Create: `app/services/catalog/market_resolver.rb`, `test/services/catalog/market_resolver_test.rb`
- Modify: `app/services/catalog/item_processor.rb:29-31`, `app/services/catalog/workbook_exporter.rb:147-155` (Fuentes), `test/services/catalog/item_processor_test.rb`, `test/services/catalog/workbook_exporter_test.rb`

**Interfaces:**
- Consumes: `InegiSales#sales`, `InegiSales::SOURCE_URL`, `Vpic.year_ranges(years)`.
- Produces: `Catalog::MarketResolver.call(applications, inegi: InegiSales.default, epa: Epa.default) -> [Array<Records::Application>, Array<Records::Validation>]`.
  - **Entrada:** aplicaciones ya normalizadas. `app.market` es el **mercado del catálogo**.
  - **Salida:** una fila por mercado, con `market` = `"MEX"` o `"USA"`, y las filas de Validación.
- Produces: `evidence_urls` acepta pares `[origen, url]` (como hoy) o tríos `[origen, url, valor_original]`. En Fuentes, el valor original es el del trío o, si no lo trae, `app.original`.
- Textos en Fuentes:
  - nivel a: origen `"mercado MEX: ventas INEGI RAIAVL"`, URL `InegiSales::SOURCE_URL`, valor original `"#{modelo_inegi} · #{año} · #{unidades} unidades"`;
  - nivel b: origen `"mercado según catálogo"`, URL `app.url`.
- Validación: `field: "Mercado"`, `erp_value: nil`, `source_value: "MEX · #{make} #{model} #{Vpic.year_ranges(years)}"`, `url: app.url`, `status: "confirmado por ventas"` o `"según catálogo"`. Una fila por pieza × armadora × modelo × mercado × nivel.
- En esta tarea el lado USA conserva la regla actual: si el catálogo es USA, la fila USA sale como nivel b, sin consultar EPA. Task 5 lo reemplaza.
- **Ajuste D20 (2026-11-06 12:20):** los nombres que vPIC no reconoce en ningún año (los que no aparecen en `GetModelsForMake` de esa armadora, ya en caché) dejan de descartarse.
  - `Vpic.expand` los devuelve aparte, sin su validación de "Modelo-año".
  - Pasan por el `Normalizer` como las demás aplicaciones.
  - `MarketResolver` les da una fila **solo MEX nivel a** en los años con ventas INEGI, y Validación `"Modelo-año"` · `"no encontrado"` para los años restantes, con el mismo texto que hoy.
  - Si vPIC conoce el modelo pero no confirmó el año, no cambia nada: sigue "no encontrado".
  - Tests:
    - `a name vPIC never lists is kept as MEX level a only in years with INEGI sales` (Sonora 2005–2008 → MEX 2005–2007, "no encontrado" 2008);
    - `a model vPIC knows keeps its unconfirmed years as no encontrado` (Colorado 2013 con ventas INEGI → sin fila).

- [ ] **Step 1: Tests que fallen** en `market_resolver_test.rb`. Usar un doble de `InegiSales` y `epa:` nulo:
  - `MEX catalog with INEGI sales gives one MEX row at level a`: evidencia `["mercado MEX: ventas INEGI RAIAVL", SOURCE_URL, "Pickup Largo · 2010 · 120 unidades"]`.
  - `MEX catalog without INEGI sales keeps MEX at level b`: Fraco D21 1993 → origen `"mercado según catálogo"`.
  - `USA catalog with INEGI sales gives MEX (a) and USA (b) rows`: Silverado 2500 HD 2016 → dos filas, mercados `["MEX", "USA"]`.
  - `USA catalog without INEGI sales stays USA only`.
  - `validations are grouped with year ranges`: Silverado 1500 2014–2016 con ventas → una sola Validación `"MEX · Chevrolet Silverado 1500 2014-2016"`, `confirmado por ventas`.
  - `an application without year is returned unchanged`: Review Focus 1.
  - `a repeated application does not duplicate rows or validations`: Review Focus 4.
- [ ] **Step 2:** `bin/rails test test/services/catalog/market_resolver_test.rb`. Esperado: FAIL.
- [ ] **Step 3: Implementar `MarketResolver`** (solo MEX + nivel b de USA).
- [ ] **Step 4:** Mismo comando. Esperado: PASS.
- [ ] **Step 5: Test que falle en `workbook_exporter_test.rb`:** `Fuentes uses the third element of an evidence as its original value`. Implementar en `source_rows`. Correr y esperar PASS.
- [ ] **Step 6: Conectar en `ItemProcessor#call`.** Después de `Normalizer.call`, reemplazar las aplicaciones por las de `MarketResolver` y sumar sus validaciones a `final`. Aceptar `market_resolver:` en `initialize` para los tests. Test en `item_processor_test.rb`: `applications come out split by market`. Luego actualizar las expectativas existentes que cambien por las filas MEX nuevas.
- [ ] **Step 7:** `bin/rails test`, `bin/rubocop`. Esperado: todo en verde, incluido `determinism_test`.
- [ ] **Step 8: Corrida real** desde la caché: `bin/rails 'catalog:run[docs/input/data_prueba_tecnica.xlsx,tmp/run3.xlsx]'`. Registrar en `DECISIONS.md` (hora de `date`) el conteo de Aplicaciones por mercado y nivel, comparado con `tmp/run2.xlsx` (1,187). Commit `feat: market by sales evidence, MEX via INEGI (D19)` y push.

### Task 5: Mercado USA con EPA y verificación de motor

**Files:**
- Modify: `app/services/catalog/market_resolver.rb`, `test/services/catalog/market_resolver_test.rb`

**Interfaces:**
- Consumes: `Epa#configurations`, `Epa#evidence_url`, `Epa#refutes?(make:, model:, year:, liters:, cylinders:)`.
- **Ajuste D22 (2026-11-06 12:48):** un motor que no coincide solo elimina la fila si `refutes?` es true. Si no, la fila se conserva, con o sin fila USA según las reglas de nivel, y Validación registra `difiere` con los dos motores y la URL de EPA.
  - Tests: `a confirm_only model keeps the row and records difiere` (Express 2500 6.0L 2007) y `a reviewed exception keeps only its engine` (CTS 2009: 6.2L se conserva y 6.0L se elimina).
- Produces (lado USA, para cada aplicación con año):
  - **Coincidencia de motor:** `app.liters` **y** `app.cylinders` presentes; `config.displ.round(1) == app.liters.round(1) && config.cylinders == app.cylinders`.
  - `configurations` es nil → USA nivel b solo si el catálogo es USA; si no, no hay fila USA.
  - Hay configuraciones y la aplicación no trae motor → USA nivel a.
  - Hay coincidencias → USA nivel a, con evidencia `["mercado USA: EPA fueleconomy.gov", evidence_url]`.
  - No hay coincidencias:
    - catálogo USA → **se eliminan todas las filas** de esa aplicación (incluida la MEX);
    - catálogo MEX → se conserva la MEX y no hay fila USA.
    - En los dos casos va una Validación con `field: "Motor"`, `erp_value: nil`, `status: "difiere"`, `url: app.url` y `source_value: "#{make} #{model} #{year} #{liters}L #{cylinders} cil · EPA: #{configs únicas 'displL cyl cil' unidas por ', '} · #{evidence_url}"`.
  - Validación `Mercado` para USA, igual que en MEX: `"USA · …"`, con nivel a o b.

- [ ] **Step 1: Tests que fallen:**
  - `EPA engine match gives USA level a`: Silverado 1500 2010, 4.3 L 6 cil → evidencia EPA.
  - `USA catalog engine refuted by EPA removes the application in every market`: Buick Allure 2005 5.3 L 8 cil, con ventas INEGI → `[]` aplicaciones y una Validación `Motor`/`difiere` que menciona `"EPA: 3.6L 6 cil, 3.8L 6 cil"`.
  - `MEX catalog engine refuted by EPA keeps MEX and denies USA`: Fraco D21 1993 2.4 L 4 cil contra EPA "Truck 2WD" con solo 3.0 L 6 cil → una fila MEX y la Validación `Motor`/`difiere`.
  - `without engine data EPA presence is enough for USA level a`: Review Focus 1.
  - `liters are compared rounded to one decimal`: 5.33 coincide con 5.3 (Review Focus 3).
  - `EPA without that model-year leaves USA at level b for a USA catalog`: Silverado 2500 HD.
  - `MEX catalog with an unmapped EPA model gets no USA row`: Review Focus 5.
- [ ] **Step 2:** `bin/rails test test/services/catalog/market_resolver_test.rb`. Esperado: FAIL en los nuevos.
- [ ] **Step 3: Implementar** el lado USA.
- [ ] **Step 4:** `bin/rails test` y `bin/rubocop`. Esperado: PASS.
- [ ] **Step 5: Corrida real** a `tmp/run4.xlsx`. Comprobar que no aparece "Allure 2005" con 5.3L. Registrar en `DECISIONS.md` los conteos por mercado y nivel y las filas eliminadas por EPA, con ejemplos. Commit `feat: USA market and engine verification via EPA (D19)` y push.

### Task 6: Combustible desde EPA en filas USA

**Files:**
- Modify: `app/services/catalog/market_resolver.rb`, `test/services/catalog/market_resolver_test.rb`, `config/catalog/fuels.yml`

**Interfaces:**
- Consumes: `Configuration#fuel_key`, `Normalizer::FUELS` (mapa `fuel_key` → valor del Excel).
- Produces:
  - **Fila MEX:** `fuel` = `app.fuel` solo si el catálogo es MEX; si no, `nil`.
  - **Fila USA:** si el catálogo es USA y trae `app.fuel`, se conserva. Si EPA da un solo combustible distinto, va una Validación `field: "Combustible"`, `erp_value: nil`, `status: "difiere"`, `source_value: "catálogo: #{app.fuel} · EPA: #{epa} · #{evidence_url}"`.
  - **Fila USA sin combustible del catálogo:**
    - si las configuraciones coincidentes (o todas, si la aplicación no trae motor) mapean a **un** solo valor → `fuel` = ese valor, con evidencia `["combustible: EPA fueleconomy.gov", evidence_url]`;
    - si son varios → `nil`, con evidencia `["combustible: EPA fueleconomy.gov", evidence_url, "combustibles EPA: #{fuel_keys únicos unidos por ', '}"]`.
  - **Un `fuel_key` sin entrada en `fuels.yml`** no se adivina: el combustible queda `nil` y se registra con el mecanismo de `Normalizer#untranslated` que ya existe.

- [ ] **Step 1: Tests que fallen:**
  - `a single EPA fuel fills the USA row only`: la fila USA queda con `"Gasolina"` y la MEX con `nil`.
  - `several EPA fuels leave it empty with the list in Fuentes`: Silverado 5.3 L 2016, `Regular` y `Gasoline or E85`.
  - `a catalog fuel is kept and a different EPA fuel is recorded as difiere`.
  - `a USA catalog fuel never reaches the MEX row`.
  - `an unknown EPA fuel is not guessed`.
- [ ] **Step 2:** Correr. Esperado: FAIL.
- [ ] **Step 3: Proponer las entradas nuevas de `fuels.yml`** a partir de los `fuel_key` distintos del extracto en las configuraciones que usamos (por ejemplo `Regular`, `Premium`, `Gasoline or E85`, `Diesel`, `Regular (Hybrid)`). Mostrárselas al desarrollador y esperar su revisión.
- [ ] **Step 4: Implementar.**
- [ ] **Step 5:** `bin/rails test` y `bin/rubocop`. Esperado: PASS.
- [ ] **Step 6: Corrida real** a `tmp/run5.xlsx` y doble corrida: el contenido debe ser idéntico. Registrar en `DECISIONS.md` cuántas filas USA ganaron Combustible y cuántas quedaron vacías por ambigüedad. Commit `feat: fuel from EPA on USA rows only (D19)` y push.

### Task 7: Cierre de la adenda

**Files:**
- Modify: `docs/superpowers/plans/2026-11-05-catalogador.md` (Task 16 Step 3, README), `docs/superpowers/specs/2026-11-05-catalogador-design.md` (§4.3 y §5.7: nota "reemplazado por la adenda D19")

- [ ] **Step 1: Agregar al README de la Task 16:**
  - estrategia de mercado por niveles;
  - roles de vPIC, EPA e INEGI;
  - las 6 limitaciones de la adenda §6;
  - Submodelo y la estrategia para producción (§7);
  - HL7011 como ejemplo de calidad de datos de origen;
  - FS-001225, si el adaptador DC/Dacomsa no entra.
- [ ] **Step 2: Notas de reemplazo** en el spec original, apuntando a la adenda.
- [ ] **Step 3:** `bin/rails test` y `bin/rubocop` en verde. Commit `docs: point original spec to the D19 addendum; README items` y push.
