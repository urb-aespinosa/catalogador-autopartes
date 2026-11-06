# Catalogador de autopartes — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Una app Rails que toma el Excel de origen del ERP y genera el catálogo con aplicaciones, intercambios y atributos de fuentes oficiales, más las hojas Fuentes y Validación, idéntico en cada corrida.

**Architecture:**
- La lógica es un pipeline de objetos Ruby puros en `app/services/catalog/`. Cada adaptador de fuente está en `app/services/sources/`, y todos comparten un único `Catalog::Fetcher` con caché en `SourceSnapshot`.
- Cada pieza la procesa un job, que guarda su resultado como JSON en `SourceItem#result` y transmite su estado por Turbo Streams.
- Un job final arma el `.xlsx` con caxlsx.
- La tarea `catalog:run` ejecuta el mismo pipeline de forma síncrona.

**Tech Stack:**
- Rails 8.1, Ruby 3.3.5, SQLite.
- Solid Queue, Solid Cable y Active Storage.
- Para leer y escribir Excel: `roo` y `caxlsx`.
- Para HTTP y HTML: `faraday` y `nokogiri`.
- `pdftotext` (poppler) para los PDF.
- Tests: Minitest + `webmock`.

**Spec:** `docs/superpowers/specs/2026-11-05-catalogador-design.md`. Las decisiones D1–D11 están en `docs/DECISIONS.md`. Léelos antes de cualquier tarea.

## Global Constraints

- **Sin IA en ejecución.** Traducciones, nombres y textos salen solo de los YAML de `config/catalog/`.
- **La descripción del ERP nunca genera filas** (D1). Única excepción: la sobremedida, que sale del **número de parte** (D10).
- **Red:**
  - timeout de **15 s** (abrir conexión + leer);
  - máximo **1 solicitud por segundo por host**;
  - User-Agent `catalogador-autopartes/1.0 (prueba tecnica)`;
  - sin reintentos.
  - Una respuesta fallida no se guarda en caché. `FORCE_REFRESH=1` vuelve a descargar.
- **Pulgadas → mm:** `(valor * 25.4).round(2)`.
- **Años de dos dígitos:** pivote fijo `AA < 30 → 20AA`, si no `19AA`. Nunca depende de la fecha actual.
- **Encabezados exactos**, en este orden:
  - `Origen`: `Cod interno, Número de parte, Descripción del artículo, Descripcion, Grupo de articulos, Fabricante, Unidad`
  - `Aplicaciones`: `Referencia, Marca, Producto, Posición, Fabricante, Modelo, Submodelo, Año, Litros, CC, CID, Cilindros, Bloque, Combustible, Mercado`
  - `Intercambios`: `Referencia, Marca, Producto, Intercambio, Marca intercambio, Origen`
  - `Atributos`: `Referencia, Marca, Producto, Clase, Atributo, Unidad, Valor`
  - `Catálogo`: `Referencia, Marca, Categoría, Sistema, Subsistema, Producto, Descripción`
  - `Fuentes`: `Referencia, Tipo de dato, Origen, URL, Valor original`
  - `Validación`: `Referencia, Campo, Valor ERP, Valor fuente, URL, Estado`
- **Orden de hojas:** `Origen, Métricas, Aplicaciones, Intercambios, Atributos, Catálogo, Fuentes, Validación`.
- **Valores fijos (texto exacto):**
  - Estados de Validación: `coincide`, `difiere`, `no encontrado`, `sin traducción`, `error de fuente`.
  - Tipos de dato de Fuentes: `aplicación`, `intercambio`, `atributo`.
  - Orígenes de Fuentes: `oficial`, `vía intercambio de {número} ({marca})`, `verificación NHTSA vPIC`, `identificación de marca NHTSA vPIC`, `número de parte`.
- **Mercado:** Fraco y Rexite → `MEX`; Elgin, Safety, Melling y Cloyes → `USA`.
- **Submodelo:** vacío salvo que la fuente lo traiga. Nunca `Base`.
- **Fabricante:** nunca vacío ni `GM`.
- **Idioma:** código, nombres y commits en inglés; textos de UI y del Excel en español.
- **Commits:** pequeños, uno por paso verde. Cada mensaje termina con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Tests sin red:** WebMock bloquea toda conexión. En tests, el intervalo del limitador es `0`.

## Review Focus

1. **Archivo subido que no es un `.xlsx`, o sin hoja `Origen`, o sin las columnas esperadas.** Se espera un mensaje claro en la página, no un error 500. Test en Task 1 y Task 15.
2. **Filas vacías al final de `Origen`.** El Excel de ejemplo trae una. Se ignoran y no cuentan en `Referencias:`. Test en Task 1.
3. **Una fuente responde 200 pero el HTML o el PDF cambió y no se puede leer.** La pieza queda como `error de fuente`, con el detalle, y la corrida sigue. Test en Task 3 y Task 13.
4. **Números de parte con `/` y `+`** (`SP26-329R/L+20`) **en URLs o búsquedas.** Se espera que se escapen correctamente, sin pedir rutas equivocadas. Test en Task 3.
5. **Dos jobs piden la misma URL al mismo tiempo.** No debe fallar por el índice único de `SourceSnapshot`; el segundo reutiliza la copia guardada. Test en Task 3.

---

## Ejecución (D13)

- **Modo directo**, en la rama `feature/catalog-pipeline` (no en `master`). Cada decisión técnica se le explica al desarrollador en español y en términos simples.
- **Revisor independiente** (subagente) al terminar las tareas **4, 9 y 14**, y una revisión final de toda la rama.

## Calendario

| Día | Tareas |
|---|---|
| Jueves 5 (tarde) | 1–4 |
| Viernes 6 | 5–15 |
| Antes de entregar | 16 (verificación) |

Si algo no cabe, solo se recorta el adaptador de Cloyes con navegador automatizado, que no está en este plan. Al cerrar cada sesión se actualiza la tabla "Registro de horas" de `docs/DECISIONS.md`.

## Mapa de archivos

```
config/catalog/                 YAML versionados (Task 2, 10)
  parser.yml                    armadoras y palabras de nota para el parser
  makes.yml                     nombres de armadora normalizados, grupos de Safety
  brands.yml                    marcas de pieza
  products.yml                  producto normalizado, subsistema, frase de apertura, orden de atributos
  attributes.yml                nombre/clase de atributos fuente → español
  values.yml                    valores categóricos fuente → español
  fuels.yml                     combustibles fuente → español
app/models/run.rb, source_item.rb, source_snapshot.rb
app/services/catalog/
  source_workbook.rb            lee el Excel de entrada (Task 1)
  records.rb                    value objects compartidos (Task 1)
  description_parser.rb         (Task 2)
  fetcher.rb, host_throttle.rb  (Task 3)
  snapshot_archive.rb           exporta/importa snapshots en db/snapshots (Task 3)
  vpic.rb                       verificación modelo-año e identificación de marca (Task 6)
  normalizer.rb                 (Task 10)
  reconciler.rb                 (Task 11)
  catalog_description.rb        (Task 12)
  item_processor.rb             orquesta una pieza (Task 13)
  workbook_exporter.rb          (Task 14)
app/services/sources/
  registry.rb, elgin.rb, fraco.rb, rexite.rb, safety.rb, melling.rb (+ cloyes.rb si aplica)
app/jobs/process_item_job.rb, finalize_run_job.rb
app/controllers/runs_controller.rb + vistas
lib/tasks/catalog.rake          catalog:run, catalog:snapshots:dump / :load
db/snapshots/                   snapshots versionados para la entrega (Task 16)
test/fixtures/files/sources/    respuestas reales guardadas, una por URL
```

---

### Task 1: Modelos, value objects y lectura del Excel de origen

**Files:**
- Modify: `Gemfile` (agregar `roo`, `caxlsx`, `faraday`; en `:test`, `webmock`)
- Create:
  - migraciones para `runs`, `source_items`, `source_snapshots`
  - `app/models/run.rb`, `app/models/source_item.rb`, `app/models/source_snapshot.rb`
  - `app/services/catalog/records.rb`
  - `app/services/catalog/source_workbook.rb`
- Copy: `docs/input/data_prueba_tecnica.xlsx` y `docs/input/ejemplo_prueba_tecnica.xlsx` → `test/fixtures/files/`
- Test:
  - `test/services/catalog/source_workbook_test.rb`
  - `test/models/source_snapshot_test.rb`

**Interfaces:**
- **Produces:**
  - `Run`
    - Active Storage: `has_one_attached :input`, `has_one_attached :output`.
    - `status`: string `pending|processing|finalizing|done|failed`.
    - `has_many :source_items, -> { order(:position) }`.
  - `SourceItem`
    - `belongs_to :run`.
    - `position:integer`; `status`: string `pending|fetching|done|not_found|error`.
    - Las 7 columnas de origen: `internal_code`, `part_number`, `item_description`, `description`, `item_group`, `manufacturer`, `unit` (strings).
    - `product:string`; `result:json`, default `{}`.
  - `SourceSnapshot`
    - Campos: `url` (string, índice único), `body` (binary), `content_type`, `sha256`, `fetched_at`.
  - `Catalog::Records`: structs `Data.define`.
    - `Application(manufacturer, model, submodel, year, years, liters, cc, cid, cylinders, block, fuel, market, url, origin, original, evidence_urls)`
      - `years`: Range o nil. Es el rango por motor que todavía no se ha expandido (Elgin, Task 6).
      - `evidence_urls`: array de `[origin, url]` extra, como las verificaciones vPIC.
    - `Interchange(number, brand, kind, url, origin)`
      - `kind`: `"OEM"` o `"Aftermarket"`.
    - `Attribute(klass, name, unit, value, url, origin, original)`
    - `Validation(field, erp_value, source_value, url, status)`
    - `ItemResult(product, applications, interchanges, attributes, validations)`
      - con `#to_h` / `.from_h` para guardarlo en `SourceItem#result`.
  - `Catalog::SourceWorkbook.read(path) -> Array<Hash>`
    - Cada hash tiene las 7 llaves de `SourceItem` y `:position`.
    - Lanza `Catalog::SourceWorkbook::InvalidFile` con un mensaje en español.
  - `Run.create_from_upload!(io, filename) -> Run`
    - Adjunta `input` y crea un `SourceItem` por fila.

- [ ] **Step 1: Write the failing tests**

```ruby
test "reads the five source rows in order" do
  rows = Catalog::SourceWorkbook.read(file_fixture("data_prueba_tecnica.xlsx"))
  assert_equal %w[FSX-5840301 HL-7025S RM-152 SP26-329R/L+20 TK1283-1], rows.map { _1[:part_number] }
  assert_equal "6536", rows.first[:internal_code]
  assert_equal "QJC20G FS-001225 JC20 NISSAN PICK UP 4 CIL 2.4 KA24E SOHC 12 VAL 89/03", rows.first[:description]
  assert_equal "REVO", rows.last[:manufacturer]
end

test "skips blank trailing rows" do
  rows = Catalog::SourceWorkbook.read(file_fixture("ejemplo_prueba_tecnica.xlsx"))
  assert_equal 10, rows.size
end

test "rejects a workbook without an Origen sheet" do
  error = assert_raises(Catalog::SourceWorkbook::InvalidFile) { Catalog::SourceWorkbook.read(file_fixture("no_origen.xlsx")) }
  assert_match "hoja Origen", error.message
end

test "rejects a non-xlsx file" do
  assert_raises(Catalog::SourceWorkbook::InvalidFile) { Catalog::SourceWorkbook.read(file_fixture("not_excel.txt")) }
end

test "ItemResult round-trips through JSON" do
  r = Catalog::Records::ItemResult.new(product: "X", applications: [], interchanges: [], attributes: [], validations: [])
  assert_equal r, Catalog::Records::ItemResult.from_h(JSON.parse(r.to_h.to_json))
end
```

`no_origen.xlsx` se genera en el test con caxlsx y una sola hoja `Hoja1`. `not_excel.txt` es un archivo de texto.

`internal_code` se guarda como entero en texto (`"6536"`, no `"6536.0"`).

- [ ] **Step 2: Run** `bin/rails test test/services/catalog/source_workbook_test.rb`. Expected: FAIL, `uninitialized constant Catalog::SourceWorkbook`.
- [ ] **Step 3: Implement**
  - `bundle add` las gemas, `bin/rails active_storage:install`, migraciones, modelos, `records.rb` y `source_workbook.rb`.
  - Los encabezados se buscan por nombre exacto, no por posición.
  - Las filas sin `Número de parte` se ignoran.
- [ ] **Step 4: Run** `bin/rails db:migrate && bin/rails test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: read source workbook into runs and items`

---

### Task 2: DescriptionParser

**Files:**
- Create: `config/catalog/parser.yml`, `app/services/catalog/description_parser.rb`
- Test: `test/services/catalog/description_parser_test.rb`

**Interfaces:**
- **Produces:** `Catalog::DescriptionParser.call(text) -> Catalog::Hints`, un `Data.define` con:
  - `interchanges` (Array<String>)
  - `make` (String o nil)
  - `models_text` (String)
  - `cylinders` (Array<Integer>), `blocks` (Array<"L"|"V">)
  - `liters` (Array<Float>), `cids` (Array<Integer>)
  - `engine_codes` (Array<String>), `valvetrains` (Array<"SOHC"|"DOHC">), `valves` (Array<Integer>)
  - `years` (Range o nil), `notes` (Array<String>)

**Reglas:**
- Los tokens antes de la primera armadora de `parser.yml` son intercambios.
- Después de la armadora, los tokens hasta el primer token de motor forman `models_text`.
- Son tokens de motor: `\d CIL`, `[LV]\d`, litros `\d\.\d`, CID de 3 dígitos, `SOHC`/`DOHC`, `\d+ ?VAL` / `\d+V`.
- Los tokens alfanuméricos restantes antes del rango `AA/AA` son `engine_codes`, salvo las palabras de nota de `parser.yml` (`INC`, `CON`, `RESORTE`, `C/S`, `RAN`…).
- Todo lo que va después del rango de años es `notes`.
- `V6` agrega `6` a `cylinders` y `"V"` a `blocks`; `4 CIL` agrega `4` sin bloque.

- [ ] **Step 1: Write the failing tests**, uno por cada descripción del origen y dos del ejemplo:

```ruby
test "fraco description" do
  h = parse("QJC20G FS-001225 JC20 NISSAN PICK UP 4 CIL 2.4 KA24E SOHC 12 VAL 89/03")
  assert_equal %w[QJC20G FS-001225 JC20], h.interchanges
  assert_equal "NISSAN", h.make
  assert_equal "PICK UP", h.models_text
  assert_equal [4], h.cylinders
  assert_equal [2.4], h.liters
  assert_equal %w[KA24E], h.engine_codes
  assert_equal %w[SOHC], h.valvetrains
  assert_equal [12], h.valves
  assert_equal 1989..2003, h.years
end

test "elgin description with mixed engines and trailing note" do
  h = parse("HL7011 CHEVROLET V8 294 4.3 VORTEC 325 5.3 LS1 , 6.0 6.2 VORTEC 16 VAL 99/23 CON RESORTE")
  assert_equal %w[HL7011], h.interchanges
  assert_equal [8], h.cylinders
  assert_equal %w[V], h.blocks
  assert_equal [294, 325], h.cids
  assert_equal [4.3, 5.3, 6.0, 6.2], h.liters
  assert_equal %w[VORTEC LS1], h.engine_codes
  assert_equal 1999..2023, h.years
  assert_equal ["CON RESORTE"], h.notes
end

test "rexite description with several layouts" do
  h = parse("DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14")
  assert_equal [4, 6], h.cylinders
  assert_equal %w[L], h.blocks
  assert_equal %w[KA24DE L20B], h.engine_codes
  assert_equal %w[DOHC SOHC], h.valvetrains
  assert_equal [8, 12], h.valves
  assert_equal 1976..2014, h.years
end

test "safety description" do
  h = parse("83-301 CHEVROLET SILVERADO V6 262 4.3 INC ECOTEC 12 VAL 14/18")
  assert_equal %w[83-301], h.interchanges
  assert_equal "SILVERADO", h.models_text
  assert_equal [262], h.cids
  assert_equal %w[ECOTEC], h.engine_codes
  assert_equal 2014..2018, h.years
end

test "revo description with two models" do
  h = parse("9-0511S SA-76260 DDM-77020 CHRYSLER DURANGO JOURNEY V6 3.6 SOHC 24 VAL PENTASTAR 11/13")
  assert_equal %w[9-0511S SA-76260 DDM-77020], h.interchanges
  assert_equal "DURANGO JOURNEY", h.models_text
  assert_equal [24], h.valves
  assert_equal %w[PENTASTAR], h.engine_codes
end

test "description without interchanges" do
  h = parse("HONDA RIDGELINE V6 3.5 07/08 197 DIENTES")
  assert_equal [], h.interchanges
  assert_equal 2007..2008, h.years
  assert_equal ["197 DIENTES"], h.notes
end

test "unknown make yields no make and no crash" do
  h = parse("XYZ123 FOO BAR")
  assert_nil h.make
end
```

- [ ] **Step 2: Run** `bin/rails test test/services/catalog/description_parser_test.rb`. Expected: FAIL.
- [ ] **Step 3: Implement** `Catalog::DescriptionParser.call(text)` y `parser.yml` (armadoras: las de los 15 textos de origen y ejemplo, además de BUICK, CADILLAC, GMC, DODGE, JEEP, RAM, LINCOLN, MAZDA, TOYOTA, VOLKSWAGEN).
- [ ] **Step 4: Run** el mismo comando. Expected: PASS.
- [ ] **Step 5: Commit** `feat: parse ERP descriptions into search hints`

---

### Task 3: Fetcher, caché, limitador y archivo de snapshots

**Files:**
- Create:
  - `app/services/catalog/fetcher.rb`, `app/services/catalog/host_throttle.rb`
  - `app/services/catalog/snapshot_archive.rb`
  - `config/initializers/catalog.rb`
  - `lib/tasks/catalog.rake` (tareas de snapshots)
- Modify:
  - `test/test_helper.rb`: `require "webmock/minitest"`, `WebMock.disable_net_connect!`, y el helper `stub_source(url, fixture_path, content_type:)`.
  - `bin/setup`: después de `db:prepare`, `bin/rails catalog:snapshots:load`.
- Test: `test/services/catalog/fetcher_test.rb`, `test/services/catalog/snapshot_archive_test.rb`

**Interfaces:**
- **Produces:**
  - `Catalog::Fetcher.get(url) -> SourceSnapshot`
    - Usa la caché.
    - Lanza `Catalog::Fetcher::SourceError` (con `#url`, `#detail`) si hay timeout, error de red o status ≠ 200.
  - `Catalog::Fetcher.get_json(url) -> Hash|Array`
  - `Catalog::Fetcher.encode_path(str) -> String`: escapa `/` y `+` en segmentos de ruta.
  - `Rails.configuration.x.catalog`: `timeout = 15`, `min_interval = 1.0` (`0` en test), `user_agent = "catalogador-autopartes/1.0 (prueba tecnica)"`.
  - `Catalog::SnapshotArchive.dump(dir)` y `.load(dir)`
    - Un JSON por snapshot: `{url, content_type, sha256, fetched_at, body_base64}`.
    - El nombre del archivo es `sha256(url).json`.
  - Tareas rake: `catalog:snapshots:dump[dir]` y `catalog:snapshots:load[dir]`, con default `db/snapshots`.

- [ ] **Step 1: Write the failing tests**

```ruby
test "downloads once and serves from cache" do
  stub = stub_request(:get, "https://example.com/a").to_return(body: "hi")
  2.times { Catalog::Fetcher.get("https://example.com/a") }
  assert_requested stub, times: 1
end

test "FORCE_REFRESH downloads again" do
  stub = stub_request(:get, "https://example.com/a").to_return(body: "hi")
  Catalog::Fetcher.get("https://example.com/a")
  with_env("FORCE_REFRESH" => "1") { Catalog::Fetcher.get("https://example.com/a") }
  assert_requested stub, times: 2
end

test "sends the project user agent" do
  stub = stub_request(:get, "https://example.com/a").with(headers: { "User-Agent" => "catalogador-autopartes/1.0 (prueba tecnica)" })
  Catalog::Fetcher.get("https://example.com/a")
  assert_requested stub
end

test "timeout raises SourceError and caches nothing" do
  stub_request(:get, "https://example.com/slow").to_timeout
  error = assert_raises(Catalog::Fetcher::SourceError) { Catalog::Fetcher.get("https://example.com/slow") }
  assert_match "timeout", error.detail
  assert_equal 0, SourceSnapshot.count
end

test "non-200 raises SourceError" do
  stub_request(:get, "https://example.com/x").to_return(status: 403)
  assert_raises(Catalog::Fetcher::SourceError) { Catalog::Fetcher.get("https://example.com/x") }
end

test "encodes slash and plus in path segments" do
  assert_equal "SP26-329R%2FL%2B20", Catalog::Fetcher.encode_path("SP26-329R/L+20")
end

test "concurrent insert of the same url reuses the stored snapshot" do
  SourceSnapshot.create!(url: "https://example.com/a", body: "x", sha256: "s", content_type: "text/html", fetched_at: Time.utc(2026, 11, 5))
  # simulates losing the race: the lookup misses, the insert hits the unique index
  Catalog::Fetcher.stub(:cached, nil) { assert_equal "x", Catalog::Fetcher.get("https://example.com/a").body }
end

test "throttle waits min_interval between requests to the same host" do
  throttle = Catalog::HostThrottle.new(min_interval: 1.0, clock: fake_clock, sleeper: sleeps = [])
  throttle.wait("a.com"); throttle.wait("a.com"); throttle.wait("b.com")
  assert_equal [1.0], sleeps
end

test "dump then load restores identical snapshots" do
  # create two snapshots (one binary PDF body), dump to tmp dir, delete all, load, compare url/body/sha256
end
```

`fake_clock` es un reloj inyectable que no avanza. Así, la segunda espera para `a.com` es de 1.0 s completo.

- [ ] **Step 2: Run** `bin/rails test test/services/catalog`. Expected: FAIL.
- [ ] **Step 3: Implement**
  - Faraday con `request: { open_timeout: 15, timeout: 15 }`.
  - `HostThrottle` es un singleton con `Mutex` y un hash host → última solicitud.
  - Ante `ActiveRecord::RecordNotUnique`, se relee el registro.
  - `fetched_at` se guarda, pero **nunca** se exporta al Excel.
- [ ] **Step 4: Run** el mismo comando. Expected: PASS.
- [ ] **Step 5: Commit** `feat: cached throttled fetcher and snapshot archive`

---

### Task 4: Adaptador Elgin (sin explosión de años todavía)

**Files:**
- Create: `app/services/sources/registry.rb`, `app/services/sources/base.rb`, `app/services/sources/elgin.rb`
- Fixtures en `test/fixtures/files/sources/elgin/`, descargadas una vez con `curl -A "catalogador-autopartes/1.0 (prueba tecnica)"`:
  - `autocomplete_HL-7025S.json`
  - la página de la pieza y **todas** sus páginas de paginación
  - una página por motor
- Test: `test/services/sources/elgin_test.rb`

**Interfaces:**
- **Consumes:** `Catalog::Fetcher.get/get_json`, `Catalog::Records`.
- **Produces:**
  - `Sources::Base#call(item:, hints:) -> Sources::Result`, un `Data.define` con:
    - `status`: `:found` | `:not_found`
    - `product_kind`: Symbol o nil, por ejemplo `:set` o `:chain`
    - `applications`: `Array<Records::Application>`
      - Valores de fuente sin traducir: `fuel` original y `manufacturer` en mayúsculas de la fuente.
      - Año: `year` nil y `year_range` en `original`.
    - `interchanges` y `attributes`: valores en inglés; `Attribute#original` = `"3.880 IN"`.
    - `per_engine_years`: Boolean
    - `market`: String
    - `validations`: `Array<Records::Validation>`, default `[]`. Safety lo usa en Task 9.
  - `Sources::Registry.for(manufacturer) -> Sources::Base | nil`, con `FRACO, ELGIN, REXITE, SAFETY` → clase.
  - `Catalog::Fetcher.cached(url) -> SourceSnapshot | nil` (Task 3) es la búsqueda en caché que el test de concurrencia reemplaza.
  - Elgin devuelve **una aplicación por motor × modelo**, con `year` = nil y `years` = el rango del motor. La explosión la hace Task 6, y `per_engine_years: true`.

- [ ] **Step 1: Write the failing tests**

```ruby
test "finds HL-7025S specs" do
  r = elgin.call(item: item("HL-7025S"), hints: nil)
  assert_equal :found, r.status
  assert_equal :set, r.product_kind  # "Package of 4 each of HL-7025"
  length = r.attributes.find { _1.name == "Length" }
  assert_equal "3.880 IN", length.original
  assert_equal %w[Length Lifter\ Type Material Maximum\ Outside\ Diameter Roller], r.attributes.map(&:name).sort
  assert_equal "USA", r.market
  assert r.per_engine_years
end

test "reads all 29 engines across pages" do
  r = elgin.call(item: item("HL-7025S"), hints: nil)
  engines = r.applications.map { [_1.manufacturer, _1.liters, _1.cid, _1.years] }.uniq
  assert_equal 29, r.applications.map(&:url).uniq.size
  assert_includes engines, ["CHEVROLET", 6.0, 364, 2007..2020]
end

test "6.0L engine lists Avalanche with its fuels" do
  apps = elgin.call(item: item("HL-7025S"), hints: nil).applications.select { _1.model == "Avalanche" && _1.cid == 364 }
  assert_equal 8, apps.first.cylinders
  assert_includes apps.map(&:fuel), "FLEX"
end

test "unknown part number is not_found" do
  stub_source(autocomplete_url("NOPE-1"), json: [])
  assert_equal :not_found, elgin.call(item: item("NOPE-1"), hints: nil).status
end

test "changed page layout raises a parse error" do
  stub_source(part_url, body: "<html><body>maintenance</body></html>")
  assert_raises(Sources::ParseError) { elgin.call(item: item("HL-7025S"), hints: nil) }
end
```

- [ ] **Step 2: Run** `bin/rails test test/services/sources/elgin_test.rb`. Expected: FAIL.
- [ ] **Step 3: Implement** `Sources::Elgin` según §5.2 del spec:
  - autocomplete con coincidencia exacta de `label`;
  - página de la pieza con su paginación "Next →";
  - una página por motor (Models, Liters, CID, Cyl., Fuel / Delivery).
  - Una fila por combustible.
  - `Sources::ParseError < StandardError`.
- [ ] **Step 4: Run** el mismo comando. Expected: PASS.
- [ ] **Step 5: Commit** `feat: Elgin source adapter`

---

### Task 5: Time-box de investigación — años por modelo en Elgin (30 min, sin código de producción)

- [ ] **Step 1:** Durante máximo 30 minutos, revisar las vistas de Elgin para HL-7025S:
  - búsqueda por año, marca y modelo en `/engine/`;
  - `Parts & Details`;
  - las peticiones `hx-get`.
  El objetivo es ver si alguna publica años **por modelo**.
- [ ] **Step 2:** Registrar el resultado en `docs/DECISIONS.md` con la hora de `TZ=America/Mexico_City date`: qué URLs se revisaron y qué se encontró.
  - **Si hay años por modelo:** agregar una tarea 5b antes de Task 6. Debe extender `Sources::Elgin` con esas vistas, tener tests con fixtures y poner `per_engine_years: false`. Task 6 aplica igual a cualquier fila que siga por motor.
- [ ] **Step 3: Commit** `docs: record Elgin per-model years research`

---

### Task 6: vPIC — verificación modelo-año (D8) e identificación de marca (D11)

**Files:**
- Create: `app/services/catalog/vpic.rb`, `config/catalog/makes.yml`
- Fixtures en `test/fixtures/files/sources/vpic/`: respuestas reales de `GetModelsForMakeYear` para Chevrolet 2007 y 2020, y de `GetModelsForMake` para Chevrolet y GMC.
- Test: `test/services/catalog/vpic_test.rb`

**Interfaces:**
- **Consumes:** `Catalog::Fetcher.get_json`.
- **Produces:**
  - `Catalog::Vpic.expand(applications) -> [Array<Application>, Array<Validation>]`
    - Recibe filas con `years` y `market == "USA"`.
    - Devuelve filas con `year` puesto, una por año confirmado. Cada fila lleva en `evidence_urls` `["verificación NHTSA vPIC", url]`.
    - Más una `Validation(field: "Modelo-año", status: "no encontrado")` por combinación no confirmada.
  - `Catalog::Vpic.identify_make(model, candidates:) -> [make_or_nil, url_or_nil]`
    - Si el modelo aparece en exactamente una marca candidata, devuelve esa marca.
    - Si no aparece en ninguna o aparece en varias, devuelve `nil`.
  - `makes.yml`:
    - `display`: `CHEVROLET → Chevrolet`, `GMC → GMC`, `NISSAN → Nissan`, …
    - `safety_groups`: `GMT → [Chevrolet, GMC]`, `GMC → [Chevrolet, Buick, Cadillac, Pontiac, Oldsmobile]`, …
    - `oem_brands`: lista de armadoras, para `Intercambios.Origen = OEM`.
- **Comparación de modelo:** mayúsculas, quitando todo lo que no sea alfanumérico, y por igualdad.

- [ ] **Step 1: Write the failing tests**

```ruby
test "keeps only model-years vPIC confirms" do
  app = application(manufacturer: "Chevrolet", model: "Silverado 1500", years: 2007..2007, market: "USA")
  rows, validations = Catalog::Vpic.expand([app])
  assert_equal [2007], rows.map(&:year)
  assert_equal "verificación NHTSA vPIC", rows.first.evidence_urls.first.first
  assert_empty validations
end

test "unconfirmed model-year goes to validation" do
  app = application(manufacturer: "Chevrolet", model: "Express Pasajeros", years: 2020..2020, market: "USA")
  rows, validations = Catalog::Vpic.expand([app])
  assert_empty rows
  assert_equal ["Modelo-año", "no encontrado"], [validations.first.field, validations.first.status]
end

test "MEX rows and per-model sources are untouched" do
  app = application(model: "280ZX", year: 1981, years: nil, market: "MEX")
  assert_equal [[app], []], Catalog::Vpic.expand([app])
end

test "identifies make for Safety models" do
  assert_equal "Chevrolet", Catalog::Vpic.identify_make("Silverado", candidates: %w[Chevrolet GMC]).first
  assert_equal "GMC", Catalog::Vpic.identify_make("Sierra", candidates: %w[Chevrolet GMC]).first
  assert_nil Catalog::Vpic.identify_make("Nonexistent", candidates: %w[Chevrolet GMC]).first
end
```

Ajusta los modelos de los tests a lo que realmente contienen los fixtures. Para elegirlos, revísalos primero con `jq`.

- [ ] **Step 2: Run** `bin/rails test test/services/catalog/vpic_test.rb`. Expected: FAIL.
- [ ] **Step 3: Implement.** `make` en la URL: `Fetcher.encode_path(make)`. Se consulta un año por cada par (marca, año) distinto, y la caché evita repetir.
- [ ] **Step 4: Run** el mismo comando. Expected: PASS.
- [ ] **Step 5: Commit** `feat: vPIC model-year verification and make identification`

---

### Task 7: Adaptador Fraco

**Files:**
- Create: `app/services/sources/fraco.rb`
- Fixtures: `test/fixtures/files/sources/fraco/FSX-5840301.pdf` y `FSX-5840299.pdf`
- Test: `test/services/sources/fraco_test.rb`

**Interfaces:**
- **Consumes:** `Catalog::Fetcher.get`, `Sources::Base`.
- **Produces:** `Sources::Fraco`
  - URL: `https://www.fraco.com.mx/QRMX/{encode_path(part)}.pdf`.
  - `per_engine_years: false`, `market: "MEX"`.
  - Atributos en español tal como salen del PDF: `Número de válvulas`, `Diámetro` (mm) y `Junta Cabeza` (valor original, por ejemplo `MLO`).
  - `manufacturer` desde el encabezado del PDF (`NISSAN`).
  - Un 404 (ficha inexistente) es `:not_found`, no un error.
  - Intercambios (D9): si el PDF publica números de otras marcas, se devuelven como `Interchange` con la URL del PDF. Revisa la ficha de FSX-5840299, porque el ejemplo reporta `JC-47-1` (TF VICTOR) y `QJC-36-1MLO` (QUEBEC). Si aparecen, agrega un test que lo verifique. Si no, regístralo en `DECISIONS.md`.

- [ ] **Step 1: Write the failing tests**

```ruby
test "FSX-5840301 models and years from the PDF" do
  r = fraco.call(item: item("FSX-5840301"), hints: nil)
  pairs = r.applications.map { [_1.model, _1.year] }.uniq
  assert_includes pairs, ["D21", 1990]
  assert_includes pairs, ["D21", 1994]
  assert_includes pairs, ["Silvia", 1989]
  assert_includes pairs, ["Terrano", 1999]
  refute_includes pairs, ["D21", 1995]
  app = r.applications.first
  assert_equal [2.4, 2389, 146, 4, "L", "MEX"], [app.liters, app.cc, app.cid, app.cylinders, app.block, app.market]
  assert_equal "12", r.attributes.find { _1.name == "Número de válvulas" }.value
end

test "control part FSX-5840299 matches the evaluator example" do
  r = fraco.call(item: item("FSX-5840299"), hints: nil)
  assert_equal ["16", "89", "MLO"], ["Número de válvulas", "Diámetro", "Junta Cabeza"].map { |n| r.attributes.find { _1.name == n }.value }
  assert_equal 2488, r.applications.first.cc
  assert (["NP300", "NP300 Frontier", "NV350 Urvan"] - r.applications.map(&:model)).empty?
end

test "missing sheet is not_found" do
  stub_source(fraco_url("FSX-0000000"), status: 404)
  assert_equal :not_found, fraco.call(item: item("FSX-0000000"), hints: nil).status
end
```

- [ ] **Step 2: Run** `bin/rails test test/services/sources/fraco_test.rb`. Expected: FAIL.
- [ ] **Step 3: Implement**
  - Llama a `pdftotext -layout` por `Open3`, pasándole el cuerpo por stdin (`-` `-`).
  - Empareja modelos y rangos por orden de renglón (§5.1).
  - Si `-layout` no alcanza para FSX-5840299, usa `-bbox-layout`.
  - `Fetcher` debe convertir el 404 en `:not_found` solo para este adaptador: lo hace con `rescue SourceError` cuando el status es 404.
- [ ] **Step 4: Run** el mismo comando. Expected: PASS.
- [ ] **Step 5: Commit** `feat: Fraco PDF source adapter`

---

### Task 8: Adaptador Rexite

**Files:**
- Create: `app/services/sources/rexite.rb`
- Fixtures: `test/fixtures/files/sources/rexite/search_RM-152.json`
- Test: `test/services/sources/rexite_test.rb`

**Interfaces:**
- **Produces:** `Sources::Rexite`
  - Consulta `https://rexite.net/wp-json/wc/store/v1/products?search={part}` y toma el `sku` exacto.
  - `market: "MEX"`, `per_engine_years: false`.

- [ ] **Step 1: Write the failing tests**

```ruby
test "RM-152 official application is the 280ZX 81-82" do
  r = rexite.call(item: item("RM-152"), hints: nil)
  assert_equal [["NISSAN", "280ZX", 1981], ["NISSAN", "280ZX", 1982]], r.applications.map { [_1.manufacturer.upcase, _1.model, _1.year] }
  assert_equal [2.8, 6, "L", "MEX"], [r.applications.first.liters, r.applications.first.cylinders, r.applications.first.block, r.market]
  assert_match "rexite.net/producto/bomba-de-aceite-rm-152-nissan", r.applications.first.url
end

test "search hit with a different sku is not_found" do
  stub_source(rexite_search("RM-999"), json: [{ "sku" => "RM-9990", "attributes" => [] }])
  assert_equal :not_found, rexite.call(item: item("RM-999"), hints: nil).status
end
```

- [ ] **Step 2–4:** Correr (FAIL), implementar y correr de nuevo (PASS) con `bin/rails test test/services/sources/rexite_test.rb`.
  - La URL de cada fila es el `permalink` del producto.
- [ ] **Step 5: Commit** `feat: Rexite source adapter`

---

### Task 9: Adaptador Safety (con marca real vía vPIC)

**Files:**
- Create: `app/services/sources/safety.rb`
- Fixtures en `test/fixtures/files/sources/safety/`:
  - `tradengines_GMT.html` y los demás grupos candidatos de CHEVROLET;
  - `tradappresults_GMT-LV3.html`;
  - las páginas de motor que **no** contienen la pieza.
- Test: `test/services/sources/safety_test.rb`

**Interfaces:**
- **Consumes:** `Catalog::Vpic.identify_make`, `makes.yml#safety_groups`, `Hints#make`.
- **Produces:** `Sources::Safety`
  - `market: "USA"`, `per_engine_years: false`.
  - Busca por el número base: `part_number.sub(/\+\d+\z/, "")`.
  - Agrega `Attribute(name: "Sobremedida", original: "+20", origin: "número de parte")` cuando el número de parte trae `+NN` (D10).
  - Devuelve, como validaciones del resultado, `Validation(field: "Fabricante", status: "no encontrado")` para cada modelo sin marca identificada. Esas filas **no** generan aplicación.
  - Para eso se agrega `validations` a `Sources::Result`, default `[]`.

- [ ] **Step 1: Write the failing tests**

```ruby
test "SP26-329R/L+20 applications with real make" do
  r = safety.call(item: item("SP26-329R/L+20"), hints: hints(make: "CHEVROLET"))
  rows = r.applications.map { [_1.manufacturer, _1.model, _1.year] }
  assert_includes rows, ["Chevrolet", "Silverado", 2014]
  assert_includes rows, ["GMC", "Sierra", 2021]
  assert_includes rows, ["Chevrolet", "Express", 2018]
  refute rows.any? { _1.first == "GM" }
  app = r.applications.first
  assert_equal [4.3, 262, 6, "V", "USA"], [app.liters, app.cid, app.cylinders, app.block, app.market]
end

test "oversize comes from the part number" do
  attr = safety.call(item: item("SP26-329R/L+20"), hints: hints(make: "CHEVROLET")).attributes.find { _1.name == "Sobremedida" }
  assert_equal ["+20", "número de parte"], [attr.original, attr.origin]
end

test "model without identifiable make produces no row and a validation" do
  # vPIC fixture without "Savana" under candidates → validation, no Savana rows
end
```

El último test usa un fixture de vPIC recortado.

- [ ] **Step 2–4:** Correr (FAIL), implementar y correr de nuevo (PASS) con `bin/rails test test/services/sources/safety_test.rb`.
  - Para leer los motores: regex `new Option\('([^']*)','([^']*)'\)`.
  - Las aplicaciones se parsean con `(\d\d)-(\d\d) ([^\d]+?)(?= \d\d-\d\d|\s*\z)`.
- [ ] **Step 5: Commit** `feat: Safety source adapter with vPIC make identification`

---

### Task 10: Normalizer y diccionarios

**Files:**
- Create:
  - `config/catalog/brands.yml`, `products.yml`, `attributes.yml`, `values.yml`, `fuels.yml`
  - `app/services/catalog/normalizer.rb`
- Test: `test/services/catalog/normalizer_test.rb`

**Interfaces:**
- **Consumes:** `Sources::Result`, `SourceItem`.
- **Produces:**
  - `Catalog::Normalizer.call(item:, result:) -> Catalog::Records::ItemResult`, con `product`, filas traducidas y `validations` de tipo `sin traducción`.
  - `Catalog::Normalizer.product_for(item_group:, product_kind:) -> String`.
  - `Catalog::Normalizer.inches_to_mm(value) -> Float`.
  - `products.yml`: por producto normalizado, `subsystem`, `opening` y `attribute_order`. Incluye `erp_group_fallback` (grupo ERP → producto si no hay fuente). Las reglas por grupo son:
    - `PUNTERIAS` + `:set` → `JUEGO DE PUNTERÍAS DE MOTOR`
    - `KIT DE DISTRIBUCION` + `:chain` → `KIT DE CADENA DE TIEMPO`
    - `KIT DE DISTRIBUCION` sin `product_kind` → `KIT DE DISTRIBUCIÓN` (D11)
    - `PISTONES` → `PISTÓN DE MOTOR`
    - `BOMBA DE ACEITE` → `BOMBA DE ACEITE DEL MOTOR`
    - `JUEGO DE EMPAQUES` → `JUEGO DE EMPAQUES DE MOTOR`
  - Frases de apertura: las del spec §4.4, copiadas exactas. Para `KIT DE DISTRIBUCIÓN`: `"Kit de distribución para sincronizar el árbol de levas con el cigüeñal."` (aprobada, D13).
  - `oversizes.yml` (D13): designación → valor, sin conversión.
    - `STD → STD`
    - `+10 → 0.25 mm (+0.010")`
    - `+20 → 0.50 mm (+0.020")`
    - `+30 → 0.75 mm (+0.030")`
    - `+40 → 1.00 mm (+0.040")`
    - Si la designación no está en la tabla → `sin traducción`.

- [ ] **Step 1: Write the failing tests**

```ruby
test "inches to mm, always 2 decimals" do
  assert_equal 98.55, Catalog::Normalizer.inches_to_mm(3.880)
  assert_equal 21.39, Catalog::Normalizer.inches_to_mm(0.842)
end

test "translates Elgin attributes and keeps the original" do
  out = normalize(elgin_result_with(attr("Length", "3.880", "IN"), attr("Lifter Type", "Hydraulic")))
  length = out.attributes.find { _1.name == "Longitud" }
  assert_equal ["Longitud", "mm", 98.55, "3.880 IN"], [length.klass, length.unit, length.value, length.original]
  assert_equal "Hidráulica", out.attributes.find { _1.name == "Tipo de puntería" }.value
end

test "unknown term stays original and is reported" do
  out = normalize(elgin_result_with(attr("Plating", "Zinc")))
  assert_equal "Plating", out.attributes.first.name
  assert_equal ["Traducción", "Plating", "sin traducción"], out.validations.first.then { [_1.field, _1.source_value, _1.status] }
end

test "fuels and makes" do
  out = normalize(elgin_result_with_app(manufacturer: "CHEVROLET", fuel: "MILD HYBRID EV-GAS (MHEV)"))
  assert_equal ["Chevrolet", "Híbrido MHEV"], [out.applications.first.manufacturer, out.applications.first.fuel]
end

test "oversize is a designation from the fixed table, not a conversion" do
  out = normalize(safety_result_with(attr("Sobremedida", "+20", origin: "número de parte")))
  assert_equal ["Sobremedida", "Sobremedida", nil, "0.50 mm (+0.020\")"], out.attributes.first.then { [_1.klass, _1.name, _1.unit, _1.value] }
end

test "unknown oversize designation is reported" do
  out = normalize(safety_result_with(attr("Sobremedida", "+25", origin: "número de parte")))
  assert_equal "sin traducción", out.validations.first.status
end

test "product from source kind, fallback to ERP group" do
  assert_equal "JUEGO DE PUNTERÍAS DE MOTOR", Catalog::Normalizer.product_for(item_group: "PUNTERIAS", product_kind: :set)
  assert_equal "KIT DE DISTRIBUCIÓN", Catalog::Normalizer.product_for(item_group: "KIT DE DISTRIBUCION", product_kind: nil)
end

test "MLO maps to MLS" do
  assert_equal "MLS", normalize(fraco_result_with(attr("Junta Cabeza", "MLO"))).attributes.first.value
end
```

- [ ] **Step 2–4:** Correr (FAIL), implementar y correr de nuevo (PASS) con `bin/rails test test/services/catalog/normalizer_test.rb`.
  - Los diccionarios cubren exactamente los términos de las fixtures de Tasks 4, 7, 8 y 9.
  - Para encontrar los que faltan, corre el normalizer sobre esas fixtures y revisa los `sin traducción`.
- [ ] **Step 5:** Mostrar al desarrollador los YAML de `attributes.yml`, `values.yml` y `products.yml` (`attribute_order` y la frase de KIT DE DISTRIBUCIÓN) y aplicar sus correcciones.
- [ ] **Step 6: Commit** `feat: normalizer with versioned dictionaries`

---

### Task 11: Reconciler

**Files:**
- Create: `app/services/catalog/reconciler.rb`
- Test: `test/services/catalog/reconciler_test.rb`

**Interfaces:**
- **Consumes:** `Catalog::Hints`, `Records::ItemResult` (normalizado), `SourceItem`.
- **Produces:** `Catalog::Reconciler.call(item:, hints:, result:) -> Array<Records::Validation>`
  - Nombres de `field`: `Armadora`, `Modelo`, `Litros`, `Cilindros`, `CID`, `Válvulas`, `Árbol de levas`, `Código de motor`, `Años`, `Intercambio`, `Unidad`.
  - Una fila por cada valor de pista; por ejemplo, cada intercambio va en su propia fila.
  - Reglas de §6.4 del spec.
  - Modelos: `coincide` si el nombre normalizado de algún modelo de la fuente está contenido en `models_text` normalizado (mayúsculas, sin espacios ni guiones), o al revés.

- [ ] **Step 1: Write the failing tests**

```ruby
test "RM-152 hints vs Rexite 280ZX" do
  v = reconcile(hints_for("DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14"), rexite_280zx_result)
  assert_equal "coincide", status(v, "Armadora")
  assert_equal "coincide", status(v, "Años")          # 1976..2014 overlaps 1981..1982
  assert_equal "difiere", status(v, "Modelo")          # PICKUP vs 280ZX
  assert_equal "coincide", status(v, "Cilindros", "6")
  assert_equal "difiere", status(v, "Cilindros", "4")
  assert_equal "no encontrado", status(v, "Intercambio", "DM-152")
  assert_equal "no encontrado", status(v, "Código de motor", "KA24DE")
end

test "unit PZA vs package differs" do
  assert_equal "difiere", status(reconcile(hints(unit: "PZA"), result(product_kind: :set)), "Unidad")
end

test "years without overlap differ" do
  assert_equal "difiere", status(reconcile(hints(years: 1989..1990), result(years: [2014, 2015])), "Años")
end
```

Regla del caso Cilindros: un valor de pista que no aparece en la fuente es `difiere` si la fuente sí trae ese campo, y `no encontrado` si no lo trae.

- [ ] **Step 2–4:** Correr (FAIL), implementar y correr de nuevo (PASS) con `bin/rails test test/services/catalog/reconciler_test.rb`.
- [ ] **Step 5: Commit** `feat: reconcile ERP hints against source data`

---

### Task 12: CatalogDescription

**Files:**
- Create: `app/services/catalog/catalog_description.rb`
- Test: `test/services/catalog/catalog_description_test.rb`

**Interfaces:**
- **Produces:** `Catalog::CatalogDescription.call(product:, attributes:) -> String`
  - Concatena la frase de apertura de `products.yml` y, en el orden de `attribute_order`, una frase por atributo, separadas por un espacio. Usa dos plantillas (D13):
    - numérico con unidad: `"#{name} de #{value} #{unit}."`;
    - texto (o número sin unidad): `"#{name}: #{value.to_s.downcase}."`.
  - Los números se formatean sin `.0` final (`16`, no `16.0`).
  - Los atributos que no aparecen en `attribute_order` van al final, en orden alfabético.

- [ ] **Step 1: Write the failing test**

```ruby
test "opening plus ordered attribute sentences" do
  text = describe("JUEGO DE PUNTERÍAS DE MOTOR", [attr("Material", "Acero"), attr("Longitud", 98.55, "mm")])
  assert_equal "Juego de punterías de motor para transmitir el movimiento del árbol de levas a las válvulas. Longitud de 98.55 mm. Material: acero.", text
end

test "text attribute uses colon template with lowercase value" do
  text = describe("BOMBA DE ACEITE DEL MOTOR", [attr("Material de la carcasa", "Hierro fundido")])
  assert_equal "Bomba de aceite del motor para impulsar y distribuir el aceite del motor. Material de la carcasa: hierro fundido.", text
end

test "no attributes gives only the opening" do
  assert_equal "Bomba de aceite del motor para impulsar y distribuir el aceite del motor.", describe("BOMBA DE ACEITE DEL MOTOR", [])
end
```

El test supone que `attribute_order` de punterías pone Longitud antes que Material; ajústalo al YAML aprobado en Task 10.

- [ ] **Step 2–4:** Correr (FAIL), implementar y correr de nuevo (PASS).
- [ ] **Step 5: Commit** `feat: template-based catalog description`

---

### Task 13: ItemProcessor, complementos vía intercambio y `catalog:run`

**Files:**
- Create:
  - `app/services/catalog/item_processor.rb`
  - `app/services/catalog/pipeline.rb`
  - `app/services/sources/melling.rb` (solo si Step 1 confirma la equivalencia)
- Modify: `lib/tasks/catalog.rake` (`catalog:run[input,output]`)
- Test: `test/services/catalog/item_processor_test.rb`

**Interfaces:**
- **Consumes:**
  - `DescriptionParser`, `Sources::Registry`, `Vpic.expand`, `Normalizer`, `Reconciler`.
  - `config/catalog/interchanges.yml`, que lista **solo equivalencias confirmadas oficialmente**: `{part, brand, number, adapter, url}`. Al inicio está vacío; los Steps 1–2 lo llenan.
- **Produces:**
  - `Catalog::ItemProcessor.call(source_item) -> Records::ItemResult`
    - Lo guarda en `source_item.result`, con `status` `done|not_found|error`.
    - **Nunca lanza excepciones:** `Fetcher::SourceError` y `Sources::ParseError` → `Validation(field: "Fuente", source_value: error.detail, url: error.url, status: "error de fuente")`.
  - `Catalog::Pipeline.run(input_path) -> Run`: crea la corrida y procesa todo de forma síncrona.
  - `catalog:run[input,output]`: llama a `Pipeline.run` y luego a `WorkbookExporter` (Task 14).

- [ ] **Step 1: Time-box de investigación, 30 min — RM-152 = Melling M152.**
  - Buscar una fuente oficial que confirme la equivalencia: la ficha de Rexite o el catálogo de Melling.
  - Confirmar que el catálogo de Melling se puede leer sin navegador.
  - Registrar el resultado en `docs/DECISIONS.md` con la hora.
  - **Si se confirma:** agregar la entrada a `interchanges.yml`, implementar `Sources::Melling` (solo aplicaciones, `market: "USA"`) con fixtures y tests, y hacer commit.
  - **Si no se confirma:** avisar al desarrollador.
- [ ] **Step 2: Time-box de investigación, 30 min — TK1283-1 = Cloyes 9-0511S.**
  - Buscar el servicio JSON del `/part-finder` de Cloyes (pestaña Network del navegador), y las fuentes oficiales de Dayco KTC1372 y SA Gear 76260.
  - La equivalencia necesita confirmación oficial.
  - Registrar el resultado en `docs/DECISIONS.md`.
  - **Si se confirma y hay datos legibles sin navegador:** adaptador `Sources::Cloyes` (aplicaciones + `product_kind: :chain`) con fixtures y tests.
- [ ] **Step 3: Write the failing tests**

```ruby
test "unknown manufacturer: no rows, product from ERP group, not found" do
  r = process(source_item(manufacturer: "REVO", item_group: "KIT DE DISTRIBUCION", part_number: "TK1283-1"))
  assert_equal "KIT DE DISTRIBUCIÓN", r.product
  assert_empty r.applications
  assert_includes r.validations.map { [_1.field, _1.status] }, ["Fuente", "no encontrado"]
end

test "source error is recorded and does not raise" do
  stub_request(:get, /catalog.elginind.com/).to_timeout
  item = source_item(manufacturer: "ELGIN", part_number: "HL-7025S")
  r = process(item)
  assert_equal "error", item.reload.status
  assert_includes r.validations.map(&:status), "error de fuente"
end

test "confirmed interchange adds applications marked vía intercambio" do
  # with a test-only interchanges.yml entry and a fake adapter:
  # rows carry origin "vía intercambio de M152 (Melling)" and market from that adapter; no attributes copied;
  # the interchange itself (M152, Melling, Aftermarket) appears in interchanges with the confirming url
end

test "unconfirmed interchange is not used" do
  # no entry in interchanges.yml → only official rows, validation for the interchange number
end

test "end to end over fixtures for HL-7025S" do
  r = process(source_item(manufacturer: "ELGIN", part_number: "HL-7025S", item_group: "PUNTERIAS", unit: "PZA"))
  assert_equal "JUEGO DE PUNTERÍAS DE MOTOR", r.product
  assert r.applications.all? { _1.year.is_a?(Integer) && _1.market == "USA" }
end
```

- [ ] **Step 4:** Correr (FAIL), implementar y correr de nuevo (PASS) con `bin/rails test test/services/catalog/item_processor_test.rb`.
  - Orden dentro de `call`: parse → adapter → `Vpic.expand` (solo si `per_engine_years`) → complementos de `interchanges.yml` → `Normalizer` → `Reconciler`.
  - Las validaciones se acumulan.
- [ ] **Step 5: Commit** `feat: per-item processing with interchange complements`

---

### Task 14: WorkbookExporter y prueba de doble corrida

**Files:**
- Create: `app/services/catalog/workbook_exporter.rb`
- Modify: `lib/tasks/catalog.rake`
- Test:
  - `test/services/catalog/workbook_exporter_test.rb`
  - `test/integration/determinism_test.rb`
  - `test/support/workbook_reader.rb` (helper: libro → arreglo de filas por hoja, vía roo)

**Interfaces:**
- **Consumes:** `Run`, `SourceItem#result`, `CatalogDescription`, `makes.yml#oem_brands`.
- **Produces:** `Catalog::WorkbookExporter.call(run, path) -> path`
  - Las hojas y los encabezados siguen las Global Constraints.
  - **Métricas** como en spec §6.5: A1, A2/B2, bloques en las filas 4–6, 8–10 y 12–14, con fórmulas `=B4-B5`, `=B8-B9`, `=B12-B13`, y `Origen` = 0.
  - Orden de filas como en spec §6.5, con duplicados eliminados.
  - Cada fila de Aplicaciones genera una fila en Fuentes con su origen y URL, más una fila por cada `evidence_urls`.
  - `Intercambios.Origen`: `OEM` si la marca está en `oem_brands`; si no, `Aftermarket`.
  - Los números se escriben como números.

- [ ] **Step 1: Write the failing tests**

```ruby
test "sheet names and headers match the example exactly" do
  example = workbook_rows(file_fixture("ejemplo_prueba_tecnica.xlsx"))
  ours = workbook_rows(export(run_with_fixture_results))
  %w[Origen Aplicaciones Intercambios Atributos Catálogo].each do |sheet|
    assert_equal example[sheet].first.compact, ours[sheet].first
  end
  assert_equal %w[Origen Métricas Aplicaciones Intercambios Atributos Catálogo Fuentes Validación], sheet_names(ours_path)
end

test "metrics block with formulas" do
  m = metrics_cells(export(run_with_fixture_results))
  assert_equal "Catálogo Bonaparte - Refaccionaria Trópico de Cáncer", m["A1"]
  assert_equal 5, m["B2"]
  assert_equal "=B4-B5", m["B6"]
  assert_equal 0, m["B5"]
end

test "numeric cells are numbers" do
  row = workbook_rows(export(run_with_fixture_results))["Aplicaciones"][1]
  assert_kind_of Integer, row[7]   # Año
end

test "item without source still appears in Catálogo" do
  cat = workbook_rows(export(run_with_fixture_results))["Catálogo"]
  assert_includes cat.map { _1[0..1] + [_1[5]] }, ["TK1283-1", "REVO", "KIT DE DISTRIBUCIÓN"]
end
```

```ruby
# test/integration/determinism_test.rb
test "two runs over the same input produce identical workbook contents" do
  stub_all_sources_from_fixtures
  a = Catalog::WorkbookExporter.call(Catalog::Pipeline.run(file_fixture("data_prueba_tecnica.xlsx")), tmp("a.xlsx"))
  b = Catalog::WorkbookExporter.call(Catalog::Pipeline.run(file_fixture("data_prueba_tecnica.xlsx")), tmp("b.xlsx"))
  assert_equal workbook_rows(a), workbook_rows(b)
end
```

- [ ] **Step 2–4:** Correr (FAIL), implementar y correr de nuevo (PASS) con `bin/rails test test/services/catalog/workbook_exporter_test.rb test/integration/determinism_test.rb`.
- [ ] **Step 5: Commit** `feat: workbook exporter and double-run determinism test`

---

### Task 15: UI con progreso en vivo, jobs y Solid Queue/Cable en desarrollo

**Files:**
- Create:
  - `app/controllers/runs_controller.rb`
  - `app/views/runs/new.html.erb`, `show.html.erb`, `_item.html.erb`
  - `app/jobs/process_item_job.rb`, `app/jobs/finalize_run_job.rb`
- Modify:
  - `config/routes.rb` (`root "runs#new"`, `resources :runs, only: %i[new create show]`)
  - `config/database.yml` (development: `primary`, `queue`, `cable`, como en producción)
  - `config/environments/development.rb` (`queue_adapter :solid_queue`, `solid_queue.connects_to`)
  - `config/cable.yml` (development: `solid_cable`)
  - `config/queue.yml` (workers: `processes: 1`, `threads: 3`; el limitador es por proceso)
  - `bin/dev` (`SOLID_QUEUE_IN_PUMA=1`)
- Test:
  - `test/controllers/runs_controller_test.rb`
  - `test/jobs/process_item_job_test.rb`

**Interfaces:**
- **Consumes:** `Run.create_from_upload!`, `ItemProcessor`, `WorkbookExporter`.
- **Produces:**
  - `POST /runs` crea la corrida y encola un `ProcessItemJob` por pieza.
  - `SourceItem` hace `after_update_commit -> { broadcast_replace_to run, target: self, partial: "runs/item" }`.
  - `ProcessItemJob` termina con `run.finalize_if_complete!`. Ese método cambia de forma atómica `processing → finalizing` cuando ya no queda ninguna pieza `pending|fetching`, y en ese caso encola `FinalizeRunJob` **una sola vez**.
  - `FinalizeRunJob` adjunta `output` y pasa la corrida a `done`. Además transmite el reemplazo de `#download`.
  - Estados visibles en la pantalla: `pendiente`, `consultando fuente`, `listo`, `no encontrado`, `error`.

- [ ] **Step 1: Write the failing tests**

```ruby
test "upload creates run and enqueues one job per item" do
  assert_enqueued_jobs 5, only: ProcessItemJob do
    post runs_path, params: { run: { input: fixture_file_upload("data_prueba_tecnica.xlsx") } }
  end
  follow_redirect!
  assert_select "[id^=source_item_]", 5
end

test "invalid file shows a friendly error" do
  post runs_path, params: { run: { input: fixture_file_upload("not_excel.txt") } }
  assert_response :unprocessable_entity
  assert_select ".error", /hoja Origen|Excel/
end

test "item status change is broadcast" do
  item = source_items(:one)
  assert_turbo_stream_broadcasts(item.run) { item.update!(status: "fetching") }
end

test "last item finishing enqueues finalize exactly once" do
  run = run_with_items(statuses: %w[done done])
  assert_enqueued_jobs 1, only: FinalizeRunJob do
    2.times { run.finalize_if_complete! }
  end
end
```

- [ ] **Step 2–4:** Correr (FAIL), implementar y correr de nuevo (PASS) con `bin/rails test`.
- [ ] **Step 5: Verificación manual:** `bin/setup && bin/dev`, subir `docs/input/data_prueba_tecnica.xlsx` y comprobar tres cosas:
  - las filas cambian de estado sin recargar;
  - aparece **Descargar Excel**;
  - el archivo abre.
- [ ] **Step 6: Commit** `feat: upload page with live per-item progress`

---

### Task 15b: Time-box — intercambios del ERP confirmados por aplicación (D16, 30 min de investigación)

- [ ] **Step 1:** Buscar en los catálogos oficiales, **sin credenciales incrustadas**:
  - DC Gaskets `catalogo.dcp.com.mx` (FS-001225);
  - Quebec / TF Victor (QJC20G, JC20);
  - Moresa (83-301);
  - Elgin (HL7011).

  Un número cuenta como confirmado si existe y su aplicación es el mismo motor y rango de años que nuestra pieza.
- [ ] **Step 2:** Registrar el resultado en `docs/DECISIONS.md` con la hora.
- [ ] **Step 3 (solo si hay confirmaciones legibles sin navegador):**
  - adaptador por marca, con fixtures y tests;
  - una fila en Intercambios por número confirmado;
  - dos URLs en Fuentes: la de nuestra pieza y la del otro catálogo.

  Lo que no se confirma queda en Validación.

### Task 16: Snapshots para la entrega, README y sesión de verificación

**Files:**
- Create: `db/snapshots/*.json` (vía `catalog:snapshots:dump`), `docs/output/catalogo_bonaparte.xlsx`
- Modify: `README.md`, `docs/DECISIONS.md` (registro de horas)

- [ ] **Step 1:** Corrida real.
  - `bin/rails catalog:run[docs/input/data_prueba_tecnica.xlsx,docs/output/catalogo_bonaparte.xlsx]`
  - Revisar la hoja Validación con el desarrollador.
- [ ] **Step 2:** `bin/rails catalog:snapshots:dump` y commit de `db/snapshots/` junto con el Excel generado.
- [ ] **Step 3:** README en español con:
  - requisitos (Ruby 3.3.5, `brew install poppler` / `apt install poppler-utils`);
  - `bin/setup && bin/dev`;
  - cómo correr `catalog:run`;
  - `FORCE_REFRESH`;
  - el approach en una página, apoyándote en la sección 0 del spec;
  - limitaciones conocidas: submodelos (D3); vPIC confirma modelo + año, no motor (D11); estado de RM-152 y TK1283-1.
  - por qué la hoja **Intercambios** sale con pocas filas: las equivalencias no tienen confirmación oficial (D9). Cada número aparece en Validación con su motivo (D14).
  - alias de capacidad para vPIC: qué son y que en el Excel se conserva el nombre de Elgin (D14).
  - limitación conocida (D14): vPIC confirma línea de modelo + año, no la versión de carga (1500/2500/3500). Pueden aparecer combinaciones de versión y año que no existieron (por ejemplo, Express 1500 después de 2014 o Suburban 2500 después de 2013). Ninguna fuente oficial gratuita publica años por versión. La aplicación sigue respaldada por Elgin.
  - `poppler-utils` también en el `Dockerfile` (D14; pendiente menor del revisor).
  - Commit.
- [ ] **Step 4: Sesión de verificación** (dedicada, antes del lunes 9 en la mañana):
  1. Clonar limpio en un directorio temporal, seguir el README al pie de la letra y anotar cualquier paso faltante.
  2. `bin/ci` en verde.
  3. Subir el archivo por la UI y descargar el Excel.
  4. Comparar estructura contra `ejemplo_prueba_tecnica.xlsx`: hojas, encabezados y tipos.
  5. Doble corrida: comparar el contenido de los dos libros con `test/support/workbook_reader.rb` desde `bin/rails runner`. Además, comparar contra `docs/output/catalogo_bonaparte.xlsx`. Todo debe ser idéntico.
  6. Registrar el resultado y las horas en `docs/DECISIONS.md` y hacer commit.
- [ ] **Step 5: CI de GitHub Actions en verde** (`.github/workflows/ci.yml`):
  - Agregar `poppler-utils` al `apt-get install` del job `test`. Los tests de Fraco llaman a `pdftotext`.
  - Causa de `test` y `system-test` en master: `db/schema.rb doesn't exist yet`. En master no hay migraciones (solo el esqueleto). En la rama `schema.rb` ya existe, así que esa causa desaparece al integrar. Verificarlo en el PR, no suponerlo.
  - `system-test`: la rama no tiene `test/system/`, y `bin/rails test:system` falla con `LoadError ... test/system`. Opciones: quitar el job (no hay pruebas de sistema; la UI se prueba con tests de integración) o agregar una prueba de sistema mínima. Decidir y registrar en `docs/DECISIONS.md`.
  - Comprobarlo abriendo un pull request de `feature/catalog-pipeline` hacia `master` y esperar todos los jobs en verde.
