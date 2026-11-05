# Diseño — Catalogador de autopartes

- **Fecha:** 2026-11-05
- **Estado:** aprobado por el desarrollador el 2026-11-05 a las 16:17 (CDMX)
- **Insumos:** `docs/DESIGN_BRIEF.md`, `docs/DECISIONS.md` (D1–D11), `docs/input/*.xlsx` y el spike de fuentes del 2026-11-05.
- **Cómo leer las marcas de este documento:**
  - **[decisión del desarrollador]**: la decidió Antonio y no se cambia sin preguntarle.
  - **[criterio de diseño]**: decisión razonable tomada al diseñar; puede ajustarse.
  - **[a criterio del constructor]**: queda libre.

---

## 0. Resumen en lenguaje simple

**Qué hace la app**

Una refaccionaria tiene en su sistema (ERP) una lista de piezas de motor con datos mínimos: número de parte, marca y una descripción abreviada y llena de errores. La app toma ese Excel y produce un catálogo completo con cuatro cosas por pieza:

- **Aplicaciones:** en qué vehículos sirve.
- **Intercambios:** qué piezas de otras marcas la reemplazan.
- **Atributos:** sus medidas y características.
- **Descripción de catálogo:** un texto en español.

**Cómo fluyen los datos**

1. Subes el Excel en una página web.
2. La app lee cada pieza y "desarma" la descripción del ERP para sacar pistas: marca del vehículo, motor, años y números de otras marcas.
3. Con esas pistas busca la pieza **en el sitio oficial de su fabricante** (Fraco, Elgin, Rexite, Safety…). Guarda una copia de cada página o PDF que consulta.
4. De esas copias extrae aplicaciones, intercambios y atributos. Los traduce al español, convierte pulgadas a milímetros y unifica nombres.
5. Compara lo que dice la fuente oficial contra lo que decía el ERP y anota cada coincidencia o diferencia.
6. Arma el Excel final. Tiene las mismas hojas que el ejemplo del evaluador más dos extra:
   - **Fuentes:** de dónde salió cada dato.
   - **Validación:** qué coincidió y qué no.

Mientras trabaja, la página muestra el avance pieza por pieza, para que nunca parezca trabada.

**Por qué se decidió así**

- **La fuente de verdad es el fabricante, no el ERP.** La descripción del ERP tiene abreviaturas y errores. Sirve para *buscar* y para *comparar*, nunca para llenar el catálogo. Si la fuente oficial no tiene un dato, el dato no se inventa.
- **Mismo archivo, mismo resultado, siempre.** El evaluador lo pide expresamente. Para lograrlo, la app:
  - guarda una copia de todo lo que descarga y la reutiliza en vez de volver a descargar;
  - ordena siempre las filas igual;
  - **no usa inteligencia artificial al ejecutarse**: traducciones y textos salen de diccionarios y plantillas fijas.
- **Todo es auditable.** Cada dato del catálogo lleva su URL de origen. Las diferencias entre el ERP y el fabricante no se "arreglan" en silencio: quedan visibles en la hoja Validación para que una persona decida.
- **Si el fabricante no publica algo, se usa la pieza equivalente.** Cuando la fuente oficial está incompleta (Rexite) o no existe (REVO), se consulta la fuente oficial de una pieza de intercambio. Esas filas quedan marcadas como "vía intercambio".
- **No se generan vehículos que no existieron.** Cuando una fuente dice "este motor se usó de 2007 a 2020 en estos modelos", cada combinación modelo-año se confirma contra la base oficial de vehículos del gobierno de EE. UU. (NHTSA). Lo que no se confirma no entra al catálogo.

---

## 1. Intención y contexto

Esta es una prueba técnica para una refaccionaria.

- **Entrada:** `docs/input/data_prueba_tecnica.xlsx`, hoja `Origen`, con 5 piezas:

  | Pieza | Marca |
  |---|---|
  | FSX-5840301 | FRACO |
  | HL-7025S | ELGIN |
  | RM-152 | REXITE |
  | SP26-329R/L+20 | SAFETY |
  | TK1283-1 | REVO |

- **Salida:** un Excel con la forma de `docs/input/ejemplo_prueba_tecnica.xlsx`, con datos reales.

El evaluador califica sobre todo el *approach*, las decisiones y el tiempo. Tiene una regla explícita: **si el mismo dataset se corre dos veces y los resultados difieren, algo está mal.**

## 2. Metas, no-metas y anti-metas

**Metas**
- Excel con las 6 hojas del ejemplo, idénticas en nombre y columnas, más `Fuentes` y `Validación`.
- Aplicaciones, intercambios y atributos tomados de fuentes oficiales, cada dato con su URL.
- Resultado idéntico en corridas repetidas sobre el mismo archivo.
- Una pantalla web: subir archivo → progreso en vivo por pieza → descargar Excel.
- `bin/setup && bin/dev` funciona en una máquina limpia siguiendo el README.

**No-metas**
- Autenticación, usuarios, diseño visual elaborado y despliegue a producción.
- Reproducir los submodelos del ejemplo. Parecen venir de una base de vehículos propia del evaluador (§9).
- Soportar fabricantes distintos de los cinco del origen y de las fuentes de intercambio necesarias.

**Anti-metas (sería un fracaso aunque "funcione")**
- Datos inventados o rellenados:
  - un submodelo "Base" puesto por defecto;
  - una traducción adivinada;
  - una aplicación sacada de la descripción del ERP;
  - una combinación modelo-año sin verificar.
- Resultados distintos entre dos corridas.
- Discrepancias resueltas en silencio.
- Llamadas a IA o a la red durante los tests.

## 3. Restricciones

- **Stack:** Rails 8.1, Ruby 3.3.5, SQLite y Solid Queue / Cache / Cable. Sin Redis ni Postgres. **[ya existe en el repo]**
- **Tests:** Minitest y TDD estricto (rojo → verde → refactor). **La calidad y los tests no se recortan.** **[decisión del desarrollador, D6]**
- **Idioma:** código, nombres y commits en inglés; documentos y UI en español. Commits pequeños y frecuentes.
- **Dependencia del sistema:** `pdftotext` (poppler) para los PDFs de Fraco. El README debe indicarlo.
- **Plazo:** entrega a más tardar el lunes 2026-11-09 en la mañana (D6).

## 4. Reglas de negocio (decididas)

### 4.1 Fuentes de datos — D1 y D9 **[decisión del desarrollador]**
- La descripción del ERP **nunca genera filas**. Solo sirve para buscar la pieza y para validar.
- Lo que reporta la fuente oficial entra al Excel, con su URL.
- Si la fuente oficial está incompleta o no existe, se complementa con la **fuente oficial de una pieza de intercambio**. Esas filas llevan el origen "vía intercambio de X".
- Sin fuente oficial ni de intercambio, no hay filas de datos.
- **Intercambios que aparecen en la descripción del ERP (D9):**
  - Entran a la hoja Intercambios **solo si una fuente oficial los confirma**: la ficha de la pieza o el catálogo oficial de la otra marca.
  - Cuando entran, su URL va en Fuentes.
  - Si no se confirman, van a Validación como `no encontrado`.

### 4.2 Hojas y trazabilidad — D2 y D7 **[decisión del desarrollador]**
- Las hojas del ejemplo se mantienen **sin columnas extra**.
- Hoja **Fuentes**: `Referencia | Tipo de dato | Origen | URL | Valor original`.
  - Tipo de dato: `aplicación` / `intercambio` / `atributo`.
  - Origen: `oficial` / `vía intercambio de {número} ({marca})` / `verificación NHTSA vPIC` (§5.7) / `número de parte` (D10, §5.4).
  - Valor original: el texto de la fuente antes de convertir o traducir, por ejemplo `3.880 IN`.
- Hoja **Validación**: `Referencia | Campo | Valor ERP | Valor fuente | URL | Estado`.
  - Estado: `coincide` / `difiere` / `no encontrado` / `sin traducción` / `error de fuente`.
    - `no encontrado`: la fuente respondió y no tiene la pieza o el dato.
    - `error de fuente`: la fuente no respondió bien (timeout, error de red, respuesta HTTP inesperada). Lleva el detalle del error. Es distinto de `no encontrado` (§6.7).
- Una pieza sin fuente aparece en tres hojas:
  - `Origen`;
  - `Catálogo`, con referencia, marca y producto normalizados, y el resto vacío;
  - `Validación`, como `no encontrado`.

### 4.3 Mercado y Submodelo — D3 **[decisión del desarrollador]**
- `Mercado` lo declara cada adaptador según el mercado de su fuente:
  - Elgin, Safety, Melling y Cloyes → `USA`.
  - Fraco y Rexite → `MEX`.
  - En filas vía intercambio, el mercado es el de la fuente que reporta la aplicación.
- `Submodelo` solo se llena si la fuente lo trae; si no, queda vacío. Nunca se usa "Base" como relleno.

### 4.4 Producto normalizado y descripción de catálogo — D4 y D5 **[decisión del desarrollador]**
- El producto normalizado se decide con la **fuente oficial** (pieza vs. juego, cadena vs. banda), no solo con el grupo del ERP.
- **Descripción** = frase de apertura del tipo de producto + una frase por atributo verificado.
  - Las frases de atributo siguen un orden fijo por tipo de producto y usan una de dos plantillas (D13):
    - numérico con unidad: `"{atributo} de {valor} {unidad}."`;
    - texto: `"{atributo}: {valor}."`, con el valor en minúsculas. Por ejemplo, "Material de la carcasa: hierro fundido.".
  - Solo menciona datos que están en la hoja Atributos.
  - Sin IA en ejecución.
- **Frases de apertura:** se copian del ejemplo cuando existen; solo se redactan para tipos de producto nuevos.

| Grupo ERP | Pieza | Producto normalizado | Subsistema | Frase de apertura |
|---|---|---|---|---|
| JUEGO DE EMPAQUES | FSX-5840301 | JUEGO DE EMPAQUES DE MOTOR | JUNTAS Y SISTEMAS DE SELLADO | Juego de empaques de motor para sellar las uniones del motor. |
| PUNTERIAS | HL-7025S | JUEGO DE PUNTERÍAS DE MOTOR | COMPONENTES DEL TREN DE VÁLVULAS **[criterio de diseño]** | Juego de punterías de motor para transmitir el movimiento del árbol de levas a las válvulas. |
| BOMBA DE ACEITE | RM-152 | BOMBA DE ACEITE DEL MOTOR | BOMBAS | Bomba de aceite del motor para impulsar y distribuir el aceite del motor. |
| PISTONES | SP26-329R/L+20 | PISTÓN DE MOTOR | COMPONENTES DEL BLOQUE DE CILINDROS | El Pistón de motor forma parte del conjunto móvil del motor. |
| KIT DE DISTRIBUCION | TK1283-1 | KIT DE CADENA DE TIEMPO **solo si una fuente oficial confirma la equivalencia con Cloyes 9-0511S**; si no, **KIT DE DISTRIBUCIÓN** (D11) | COMPONENTES DEL TREN DE VÁLVULAS | Kit de cadena de tiempo para sincronizar el árbol de levas con el cigüeñal. *(Para KIT DE DISTRIBUCIÓN, la frase aprobada es: "Kit de distribución para sincronizar el árbol de levas con el cigüeñal." — D13.)* |

Para las cinco piezas, `Categoría` = `Vehículo ligero` y `Sistema` = `MOTOR`.

### 4.5 Conversión y traducción de atributos — D7 **[decisión del desarrollador]**
- **Pulgadas → mm:** `valor × 25.4`, redondeado **siempre a 2 decimales**. Es una regla fija con test.
- **Nombres, Clase y valores categóricos** se traducen con un diccionario YAML versionado.
- **Término sin entrada en el diccionario:** sale con su texto original y se registra en Validación como `sin traducción`. Nunca se traduce con IA ni se adivina.

### 4.6 Marcas **[criterio de diseño]**
- Diccionario YAML de marcas con las equivalencias del ejemplo:
  - `HASTING → HASTINGS PISTON RINGS`
  - `TECH TIMMING → TECH TIMING`
  - `CONTITECH → CONTITECH PRODUCTS`
- Las cinco marcas del origen (FRACO, ELGIN, REXITE, SAFETY y REVO) se dejan como vienen.
- Las marcas de intercambio se escriben como las nombra la fuente (por ejemplo `Cloyes`, `Melling` o `SA Gear`).

### 4.7 Verificación de combinaciones modelo-año — D8 **[decisión del desarrollador]**
**Alcance:**
- Aplica **solo** cuando la fuente da un rango de años **por motor** y no por modelo (hoy, solo Elgin).
- La verificación vPIC se usa **solo para aplicaciones de mercado USA**.
- Cuando la fuente da años **por modelo** (Fraco, Rexite, Safety), esos años se usan tal cual, sin verificación vPIC.

1. **Intento acotado de 30 minutos (investigación durante el desarrollo, no un límite de ejecución; ver §7):** buscar si Elgin publica años por modelo en otra vista. Si los publica, se usan esos años.
2. **Si no:** cruzar cada combinación modelo × año contra **NHTSA vPIC** (§5.7).
   - Solo se generan las combinaciones que vPIC confirma.
   - Las combinaciones que vPIC no confirma van a Validación (estado `no encontrado`, campo `Modelo-año`).
3. **Nunca** se generan combinaciones no verificadas.

## 5. Fuentes por fabricante (resultado del spike)

Todas las URLs y respuestas se observaron el 2026-11-05. Las copias del spike están en el scratchpad de la sesión. **Hay que volver a descargarlas como fixtures** al implementar cada adaptador.

### 5.1 FRACO — mercado MEX
- **URL:** `https://www.fraco.com.mx/QRMX/{numero_de_parte}.pdf`. Responde 200 con `application/pdf` y una sola página.
- **Contenido de la ficha FSX-5840301:**
  - Modelos con rangos de año: `Ichivan 91/94`, `Pickup, Estaquitas 91/97`, `Stanza 90/92`, `D21 90/94`, `Silvia 89/92`, `Terrano 99/99`.
  - Motor: `KA24E / SOHC`, `L4`, `12V`, `2.4 L`.
  - Medidas: `Ø Cil. 89 mm`, carrera `96 mm`, `2.389 c.c.`, `146 pulg³`.
  - Tipo de junta de cabeza.
  - Números de componentes del juego (`HGX-…`, `VSX-…`, `OSX-…`).
- **Extracción:** con `pdftotext -layout`.
  - El texto sale en columnas mezcladas, así que la relación modelo↔años debe reconstruirse por posición.
  - Si `-layout` no basta, usar `pdftotext -bbox-layout`, que da coordenadas.
  - **Sin IA en ejecución** **[criterio de diseño, consistente con D4]**.
- **Pieza de control: `FSX-5840299`**, que aparece en el ejemplo.
  - Su ficha debe dar `Número de válvulas 16`, `Diámetro 89 mm`, junta de cabeza multicapa, `CC 2488` y los modelos NP300, NP300 Frontier y NV350 Urvan.
  - Los submodelos y las filas `USA` del ejemplo **no** saldrán de esta fuente. Es lo esperado.
- **Junta de cabeza:** el PDF dice `MLO` (Multilámina Acerada) y el ejemplo reporta `MLS`. El diccionario de valores mapea `MLO → MLS`.
- **Intercambios (D9):** si la ficha publica números de otras marcas, entran como confirmados. Los números de la descripción del ERP (`QJC20G`, `FS-001225`, `JC20`) solo entran si alguna fuente oficial los confirma.

### 5.2 ELGIN — mercado USA
- **Búsqueda:** `GET https://catalog.elginind.com/part-autocomplete/?q={numero}` devuelve JSON `[{"label":"HL-7025S","value":"<uuid>"}]`. Se toma la coincidencia exacta de `label`.
- **Pieza:** `GET /engine/part/{uuid}/` devuelve HTML con:
  - Specs: `Length 3.880 IN`, `Lifter Type Hydraulic`, `Material Steel`, `Maximum Outside Diameter 0.842 IN`, `Roller Yes`.
  - `Description: Package of 4 each of HL-7025` y `Quantity: 8`.
  - Lista de motores con armadora y rango de años: 29 motores para HL-7025S, **paginada** con "Next →".
- **Motor:** `GET /engine/{armadora}/{categoria}/{engine_uuid}/` devuelve:
  - `Models` (lista separada por comas), `Liters`, `CID`, `Fuel / Delivery` y `Cyl.`;
  - `Version` (códigos de motor), `Head` y `Misc.` (por ejemplo `16 Valve`).
- **Explosión de aplicaciones:** según D8 (§4.7). Primero, el intento de encontrar años por modelo en Elgin; si falla, la verificación vPIC.
- **Combustible:** se traduce con diccionario.
  - `GAS → Gasolina`
  - `FLEX → Flex`
  - `FULL HYBRID EV-GAS (FHEV) → Híbrido FHEV`
  - `MILD HYBRID EV-GAS (MHEV) → Híbrido MHEV`
  - `CNG → …`
  - Si falta una entrada, el término sale original con estado `sin traducción`.
  - Si un motor lista varios combustibles, se genera una fila por combustible **[criterio de diseño]**.
- **Unidad:** el ERP dice `PZA` y Elgin vende un paquete. Va a Validación como `difiere` en el campo `Unidad`.

### 5.3 REXITE — mercado MEX
- **API pública de WooCommerce:** `GET https://rexite.net/wp-json/wc/store/v1/products?search={numero}`. Se filtra por `sku` exacto.
- **Atributos del registro:** `Compatible` (`Nissan 280Zx 1981`, `Nissan 280Zx 1982`), `Marcas`, `Motores` (`2.8L 6Cyl L`), `Modelos`, `Litros`, `Cilindros` y `Años`. La página del producto trae exactamente lo mismo.
- **Hallazgo:** RM-152 solo lista el 280ZX 81–82. La ficha está **incompleta, pero no contradice** al ERP. Se complementa vía Melling M152 (§5.6).
- **Bloque:** si `Motores` termina en `L` o `V`, ese valor va a la columna `Bloque`.

### 5.4 SAFETY — mercado USA
- **Sitio:** `https://www.safetyautoparts.com/webcatalog/`, un catálogo HTML antiguo con frames. El catálogo moderno (ShowMeTheParts) **bloquea bots** (403 de Incapsula) y no se usa.
- **Motores por armadora:** `GET tradengines.php?MakeCode={código}` devuelve JavaScript con `new Option('{texto}','{EngineCode}')`. Los códigos de armadora están en `tradcatalogmenus.html` (por ejemplo, `GMT` = GM Trucks y `GMC` = GM Cars).
- **Aplicaciones por motor:** `GET tradappresults.php?EngineCode={código}` devuelve una tabla `Producto | Número | Aplicación | Nota`. Para `GMT-LV3` (4.3L 262 LV3 OHV 12V V6): `Piston w/Pin | SP26-329R/L | 14-21 Silverado 14-21 Sierra 18-21 Express 18-21 Savana`.
- **Cómo encontrar la pieza:**
  - Safety no tiene búsqueda por número propio. Su búsqueda por intercambio solo acepta números de la competencia, y no encontró `83-301`.
  - Estrategia: usar la armadora de las pistas del ERP para elegir los `MakeCode` candidatos, recorrer **todos** sus motores y quedarse con los que listan el número base.
  - Todas las respuestas quedan en caché **[criterio de diseño]**.
- **Número de parte:** el ERP dice `SP26-329R/L+20` y Safety lista `SP26-329R/L`. El sufijo `+20` es la sobremedida (0.020"). Se busca por el número base.
- **Sobremedida — excepción explícita a D1 (D10)** **[decisión del desarrollador]**:
  - La sobremedida se toma **del número de parte** (`+20` = 0.020"), no de la descripción.
  - El número de parte es la identidad de la pieza, y el ejemplo hace lo mismo con `44338+20`.
  - Se registra como atributo. En Fuentes, su origen es `número de parte`.
  - **Es una designación estándar, no una conversión** (D13). Se toma de una tabla fija en YAML:
    - `STD`;
    - `+10` = `0.25 mm (+0.010")`;
    - `+20` = `0.50 mm (+0.020")`;
    - `+30` = `0.75 mm (+0.030")`;
    - `+40` = `1.00 mm (+0.040")`.
  - El valor se escribe como en el ejemplo, por ejemplo `0.50 mm (+0.020")`. D7 no aplica.
- **Atributos:** esta fuente no publica medidas de pistón. La pieza tendrá pocos atributos o ninguno; es lo esperado.
- **Años:** vienen en formato `AA-AA` con dos dígitos. Las aplicaciones ya vienen por modelo, así que D8 no aplica aquí.
- **Fabricante real (D11):**
  - Safety agrupa por "GM Trucks" y no da la marca de cada modelo.
  - La marca se identifica con vPIC `GetModelsForMake` (§5.7): por ejemplo, Silverado → Chevrolet y Sierra → GMC.
  - Si un modelo no se encuentra en vPIC, **no se genera la aplicación** y va a Validación como `no encontrado`.
  - `Fabricante` nunca queda vacío ni con "GM".

### 5.5 REVO — sin fuente oficial
- `revo.com.mx` es un dominio estacionado. La marca solo aparece en marketplaces (Amazon, Walmart, eBay), y los marketplaces no se usan.
- **Equivalencias conocidas de TK1283-1:**
  - Cloyes `9-0511S`, que aparece en la descripción del ERP y en el ejemplo (vía DDM-77020).
  - SA Gear `SA-76260`.
  - Dayco `KTC1372`.
- Cloyes confirma que 9-0511S es para la cadena de tiempo del Pentastar 3.2/3.6L DOHC V6, en una página técnica de cloyes.com.
- **La equivalencia TK1283-1 = 9-0511S no está confirmada oficialmente** (D11). Salió de la descripción del ERP y de un sitio de terceros. Para activar el complemento hace falta una fuente oficial que la confirme.
- **El buscador de piezas de Cloyes (`/part-finder`) solo funciona con JavaScript.** Ver §7: intento acotado de 30 minutos.
- **Sin confirmación oficial:**
  - TK1283-1 es pieza sin fuente;
  - su producto en Catálogo es **KIT DE DISTRIBUCIÓN** (grupo del ERP);
  - en Validación queda la explicación.

### 5.6 Fuentes de intercambio
- **Regla general (D11):**
  - Un complemento vía intercambio solo se activa si una **fuente oficial confirma la equivalencia** entre la pieza y la pieza de intercambio. Sirven la ficha de la pieza o el catálogo oficial de la otra marca.
  - Vía intercambio solo se traen **aplicaciones**, nunca atributos.
  - La pieza de intercambio entra a la hoja Intercambios solo con esa confirmación oficial (D9).
- **Melling M152** (complemento de RM-152, **núcleo**): **no se verificó en el spike.**
  - Hay un intento de desarrollo de 30 minutos para encontrar una fuente oficial que confirme RM-152 = M152 (ficha de Rexite o catálogo de Melling) y para confirmar que el catálogo de Melling se puede leer sin navegador.
  - Si no aparece, el complemento **no se activa**: RM-152 queda solo con la fila oficial de Rexite y la equivalencia va a Validación.
  - Hay que avisar al desarrollador, porque D6 considera este complemento la demostración de la regla de intercambios.
- **Cloyes, Dayco y SA Gear** (para TK1283-1): intento acotado (§7), con la misma exigencia de confirmación oficial de la equivalencia.

### 5.7 NHTSA vPIC — verificación de modelo-año (D8) e identificación de marca (D11)
- **Qué es:** la API oficial y gratuita de la NHTSA, sin llave.
- **Caché:** sus respuestas se guardan en `SourceSnapshot` como cualquier otra fuente, con la misma regla de no volver a descargar.
- **Dos usos, y solo estos dos:**
  1. **Verificación modelo-año (D8):** `GET https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/{armadora}/modelyear/{año}?format=json`. Se usa solo para aplicaciones de mercado USA de fuentes que dan años por motor (§4.7). **vPIC confirma modelo + año, no motor** (D11): el motor lo afirma la fuente. Esto se documenta en el README.
  2. **Identificación de marca (D11):** `GET https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMake/{armadora}?format=json`. Se usa cuando la fuente agrupa varias marcas (Safety "GM Trucks"): el modelo se busca en las marcas candidatas del grupo y se toma la marca donde aparece. Las marcas candidatas de cada grupo se definen en un YAML **[criterio de diseño]**; por ejemplo `GMT` → Chevrolet, GMC.
     - Si el modelo aparece en **una sola** marca, se usa esa marca.
     - Si no aparece en ninguna, o aparece en más de una, **no se genera la aplicación** y va a Validación como `no encontrado` (campo `Fabricante`).
     - El caso "aparece en más de una" es **[criterio de diseño]**: no se adivina.
- **No es fuente de aplicaciones:** solo confirma combinaciones o identifica la marca.
  - La aplicación sigue siendo de Elgin, con la URL de Elgin y `Mercado` = `USA`.
  - La URL de vPIC que confirma cada combinación se agrega en Fuentes con el origen `verificación NHTSA vPIC` **[criterio de diseño]**.
- **Comparación de nombres de modelo:** se normalizan mayúsculas, espacios y guiones **[criterio de diseño]**.
  - Los nombres que vPIC no reconoce no se generan; van a Validación. Por ejemplo `Express Pasajeros` (nombre del mercado mexicano) o variantes como `Silverado 1500 HD Classic`.
  - Si esto deja fuera muchas aplicaciones reales, se registra como hallazgo en `DECISIONS.md`.
  - No se agregan alias inventados. Cualquier tabla de alias de modelos se revisa con el desarrollador.

## 6. Arquitectura

### 6.1 Flujo
```
Subir Excel ─▶ Run (registro de la corrida)
                │
                ├─ Import: roo lee la hoja Origen ─▶ SourceItem (1 por fila)
                │
                ├─ ProcessItemJob (1 por pieza, Solid Queue)
                │     1. DescriptionParser ─▶ pistas
                │     2. Adaptador del fabricante ─▶ Fetcher (caché) ─▶ SourceSnapshot
                │     3. Extract ─▶ aplicaciones / intercambios / atributos crudos
                │     4. Verificación modelo-año (vPIC, si aplica)
                │     5. Complemento vía intercambio (si aplica)
                │     6. Normalize (diccionarios YAML) ─▶ filas finales + Fuentes
                │     7. Reconcile (pistas vs. fuente) ─▶ Validación
                │     └─ broadcast Turbo Stream del estado de la pieza
                │
                └─ FinalizeRunJob (cuando todas terminan) ─▶ Export (caxlsx) ─▶ descarga
```
También debe existir una tarea `bin/rails catalog:run[ruta.xlsx]` que ejecute el mismo pipeline de forma síncrona y escriba el Excel. Sirve para la verificación final y para el test de doble corrida **[criterio de diseño]**.

### 6.2 Componentes (cada uno con su test)
- **`DescriptionParser`**: reglas deterministas (regex + diccionarios).
  - Entrada: el texto de `Descripcion`.
  - Salida, como pistas:
    - números de intercambio candidatos;
    - armadora y modelos;
    - litros, CID y cilindros (`4 CIL`, `V6`, `L4`);
    - código de motor, árbol (`SOHC`/`DOHC`) y válvulas (`12 VAL`, `16V`);
    - rango de años `AA/AA`;
    - notas libres.
  - Casos de prueba: las 5 descripciones del origen y las 10 del ejemplo.
- **`Fetcher`**: el único punto de acceso a la red.
  - Antes de descargar, busca un `SourceSnapshot` por URL. Si existe, lo usa.
  - Solo vuelve a descargar con `FORCE_REFRESH=1`.
  - **Timeout fijo por solicitud HTTP: 15 s** (conexión + lectura) **[decisión del desarrollador]**. Ver §6.7.
  - En tests la red está bloqueada (WebMock) y los snapshots vienen de fixtures.
- **Adaptadores:** `Sources::Fraco`, `Sources::Elgin`, `Sources::Rexite`, `Sources::Safety` y `Sources::Melling` (+ `Sources::Cloyes` si aplica).
  - Interfaz común: la forma queda **[a criterio del constructor]**; el contenido es fijo.
  - Dado un número de parte y las pistas, devuelve aplicaciones, intercambios, atributos, producto o tipo detectado, mercado y la URL de cada dato. Si no encuentra la pieza, devuelve "no encontrado".
  - El adaptador **no** traduce ni normaliza.
- **`ModelYearVerifier`**: aplica D8 con vPIC.
- **`Normalizer`**: aplica los YAML de `config/catalog/` y la conversión pulgadas → mm. Los YAML cubren marcas, productos, taxonomía, atributos y valores, combustibles, frases de apertura y orden de atributos por producto.
- **`Reconciler`**: compara las pistas del ERP con los datos de la fuente y produce las filas de Validación (§6.4).
- **`CatalogDescription`**: arma la descripción de `Catálogo` según §4.4.
- **`WorkbookExporter`**: genera el `.xlsx` (§6.5).

### 6.3 Modelo de datos **[criterio de diseño; los nombres quedan a criterio del constructor]**
- `Run`: archivo subido, estado y archivo generado.
- `SourceItem`: una fila del origen (las 7 columnas tal cual), su estado de procesamiento y su producto normalizado.
- `SourceSnapshot`: `url` (única), `body`, `content_type`, `sha256` y `fetched_at`. Es **global, no por corrida**: es la caché.
  - **Snapshots en el repo (D11):** las copias usadas para el Excel entregado se exportan a archivos versionados en el repo, y `bin/setup` las carga en la base. Así el resultado es idéntico en cualquier máquina.
- **Resultado por pieza (D12):** las filas finales (aplicaciones, intercambios, atributos y validaciones) se guardan como **JSON en `SourceItem#result`**, no en tablas separadas. Cada fila lleva su URL, su origen (`oficial`, vía intercambio, etc.) y su valor original.
- **Jobs (D12):** un solo proceso de Solid Queue con 3 hilos. Así, el límite de 1 solicitud por segundo por sitio (§6.7) se controla dentro del proceso.

### 6.4 Validación (Reconcile)
Por cada pista que el parser extrajo del ERP se genera una fila:

| Campo | Se compara contra | `coincide` si… |
|---|---|---|
| Armadora | armadoras de las aplicaciones | alguna coincide (sin distinguir mayúsculas) |
| Modelo(s) | modelos de las aplicaciones | el modelo aparece (comparación normalizada) |
| Litros, cilindros, CID, válvulas, árbol, código de motor | datos de motor de la fuente | algún valor coincide |
| Rango de años | años de las aplicaciones | los rangos se traslapan |
| Número de intercambio | intercambios confirmados por fuente oficial (D9) | el número aparece (normalizando guiones y espacios) |
| Unidad | presentación en la fuente (paquete vs. pieza) | coinciden |

- Si la fuente no tiene ese campo, el estado es `no encontrado`. Si lo tiene y no coincide, el estado es `difiere`.
- Además se registran estas filas:
  - pieza sin fuente → `no encontrado`;
  - término sin diccionario → `sin traducción`;
  - solicitud HTTP fallida → `error de fuente`, con detalle (§6.7);
  - combinación modelo-año no confirmada por vPIC → `no encontrado`.
- Las discrepancias **nunca** cambian los datos del catálogo.

### 6.5 Excel de salida
El orden de las hojas es: `Origen`, `Métricas`, `Aplicaciones`, `Intercambios`, `Atributos`, `Catálogo`, `Fuentes`, `Validación`.

- **Origen:** copia de las filas de entrada (7 columnas).
- **Métricas:** igual que el ejemplo.
  - A1: `Catálogo Bonaparte - Refaccionaria Trópico de Cáncer`.
  - A2: `Referencias:`; B2: el número de piezas.
  - Filas 4–6, 8–10 y 12–14: un bloque para Aplicaciones, otro para Intercambios y otro para Atributos. Cada bloque tiene el total, `Origen` e `Incrementos` con su fórmula (`=B4-B5`, `=B8-B9`, `=B12-B13`).
  - `Origen` = número de filas que la hoja correspondiente ya traía en el archivo de entrada. En el origen vienen vacías, así que vale 0 **[criterio de diseño]**.
- **Aplicaciones, Intercambios, Atributos y Catálogo:** columnas exactamente como el ejemplo (ver `DESIGN_BRIEF.md` §3).
  - `Posición`: vacía.
  - `Bloque`: `L` o `V`, solo si la fuente lo dice.
  - `CC`: solo si la fuente lo da. **No se calcula desde litros o CID** **[criterio de diseño, coherente con "no inventar"]**.
  - `Intercambios.Origen`: `OEM` si la marca del intercambio es una armadora; si no, `Aftermarket`.
- **Fuentes y Validación:** como se define en §4.2.
- **Tipos de celda:** los números van como números, como en el ejemplo. Aplica a Año, Litros, CC, CID, Cilindros y los valores numéricos de atributos.
- **Orden total y estable** **[criterio de diseño]**:
  - Las piezas van en el orden de la hoja Origen.
  - Aplicaciones de cada pieza: por `Fabricante, Modelo, Submodelo, Año, Litros, Combustible, Mercado`.
  - Intercambios: por `Marca intercambio, Intercambio`.
  - Atributos: por el orden fijo del tipo de producto.
  - Fuentes y Validación: por `Referencia` (en el orden de Origen), luego por tipo y URL.
  - Las filas duplicadas exactas se eliminan.
- **Sin metadatos variables** dentro del contenido, como la fecha de la corrida.

### 6.6 Interfaz **[decisión del desarrollador: progreso en vivo, D6]**
- **Página de inicio:** un formulario para subir el `.xlsx`.
- **Página de la corrida:**
  - Una fila por pieza con su estado (`pendiente` → `consultando fuente` → `listo` / `no encontrado` / `error`) y los conteos de aplicaciones, intercambios y atributos.
  - Se actualiza en vivo con Turbo Streams (Solid Cable).
  - Al terminar aparece el botón **Descargar Excel**.
- **Errores:** un error de red o de parseo en una pieza no detiene la corrida. La pieza queda en `error`, se registra en Validación y el Excel se genera igual.
- Diseño visual mínimo.

### 6.7 Reglas de ejecución de red **[decisión del desarrollador]**
- **Timeout:** cada solicitud HTTP tiene un timeout fijo de pocos segundos, **15 s** para conexión y lectura. Es un valor de configuración, no se ajusta solo.
- **Si una solicitud falla** (timeout, error de red, respuesta 4xx/5xx inesperada):
  - la pieza se marca en Validación con el campo `Fuente`, la URL y el estado **`error de fuente`**, con el detalle del error. No se usa `no encontrado`, que significa que la fuente respondió y no tiene la pieza;
  - la corrida **continúa** con las demás piezas, y el Excel se genera igual;
  - la pieza queda en estado `error` en la pantalla.
- **Reintentos:** sin reintentos automáticos dentro de una corrida **[criterio de diseño]**.
- **Cortesía de red** **[decisión del desarrollador]**:
  - Máximo **una solicitud por segundo por sitio**, contado por host. Aplica también cuando varios jobs corren en paralelo.
  - **User-Agent** que identifica la app con el nombre del proyecto, sin datos personales. Por ejemplo: `catalogador-autopartes/1.0 (prueba tecnica)`.
  - Las respuestas en caché no cuentan, porque no generan solicitudes.
- **Caché y fallas:** una respuesta fallida **no** se guarda como snapshot, así que la siguiente corrida vuelve a intentarlo. El determinismo se garantiza cuando todas las fuentes ya están en caché. Si una corrida tuvo fallas de red, la pantalla y la hoja Validación lo dicen explícitamente **[criterio de diseño]**.

## 7. Alcance — D6 **[decisión del desarrollador]**

> **Sobre los "intentos de 30 minutos":** son *time-boxes* de investigación **durante el desarrollo**: tiempo máximo que el desarrollador dedica a buscar una fuente o una vista. **No** son límites de ejecución de la app. Lo que la app hace al ejecutarse está en §6.7.

**Núcleo**
1. Import y `DescriptionParser`.
2. Adaptadores de FRACO, ELGIN, REXITE y SAFETY.
3. Verificación modelo-año (D8): primero el intento de 30 minutos en Elgin; si no, vPIC.
4. Normalización y export con las 8 hojas.
5. Caché de descargas, test de doble corrida y jobs.
6. Pantalla con progreso en vivo por pieza (Turbo Streams).
7. Complemento de RM-152 vía Melling M152.
8. **Intento acotado para TK1283-1, máximo 30 minutos:**
   - buscar el servicio JSON que usa el buscador de Cloyes;
   - o usar las fuentes oficiales de Dayco KTC1372 / SA Gear 76260.
   - Si nada funciona, TK1283-1 va a Validación como `no encontrado`.
   - El resultado del intento se registra en `DECISIONS.md`.

**Si alcanza**
- Adaptador de Cloyes con navegador automatizado.

**Calendario**
- Jueves 5: spec, plan e inicio del núcleo (import, parser y Elgin).
- Viernes 6: resto de adaptadores, verificación vPIC, normalización, export y jobs.
- Antes de entregar: una sesión completa de verificación.

## 8. Pruebas y determinismo

- **Unitarias:**
  - `DescriptionParser` con las 15 descripciones reales.
  - Conversión pulgadas → mm, incluidos casos de redondeo: `3.880 → 98.55` y `0.842 → 21.39`.
  - Diccionarios: un término faltante sale como `sin traducción`.
  - `ModelYearVerifier`: combinación confirmada, combinación no confirmada y modelo desconocido.
  - `CatalogDescription`, `Reconciler` y orden de filas.
- **Adaptadores:** contra snapshots guardados en `test/fixtures/files/snapshots/`, sin red. Incluye las respuestas de vPIC.
- **Integración:** del origen al Excel, con fixtures. Verifica:
  - nombres y orden de las hojas;
  - encabezados idénticos al ejemplo;
  - tipos de celda;
  - fórmulas de Métricas.
- **Pieza de control FRACO:** con el PDF de `FSX-5840299`, el adaptador reproduce los modelos, años y atributos del ejemplo que esa ficha contiene.
- **Doble corrida:** ejecutar el pipeline dos veces y comparar el **contenido** de ambos libros celda por celda, no los bytes del `.xlsx`.
- **Verificación final, en una sesión dedicada:**
  - clonar limpio y seguir el README;
  - correr la app con el archivo real;
  - comparar la estructura contra el ejemplo;
  - hacer la doble corrida;
  - revisar Validación.
- `bin/ci` en verde: rubocop, brakeman, bundler-audit y tests.

## 9. Preguntas abiertas y riesgos

1. **Tabla de vehículos del evaluador** (submodelos): pendiente de respuesta del evaluador (D3). **El plan asume que no llega** **[criterio de diseño]**. Si llega antes del viernes 6 en la noche, se evalúa con el desarrollador; si llega después, se documenta como trabajo futuro.
2. **Melling M152 no verificado** (§5.6). Es un riesgo para un elemento del núcleo.
3. **Nombres de modelo en vPIC** (§5.7). Los nombres del mercado mexicano o las variantes de Elgin pueden no existir en vPIC y quedar fuera. Mitigación: registrar el hallazgo y revisar con el desarrollador si hace falta una tabla de alias.
4. **Intercambios de FRACO:** el ejemplo reporta intercambios para FSX-5840299 (TF Victor JC-47-1 y Quebec QJC-36-1MLO). Hay que confirmar si la ficha PDF los publica. Si no, se aplica D9.
5. **Layout del PDF de Fraco:** reconstruir la tabla por posición puede ser frágil. Mitigación: `-bbox-layout` y tests con dos fichas (FSX-5840301 y FSX-5840299).

**Preguntas del revisor: resueltas en D11** (2026-11-05 16:24):

6. **Determinismo entre máquinas.** Las copias descargadas (snapshots) usadas para el Excel entregado se suben al repo y `bin/setup` las carga.
7. **vPIC** confirma modelo + año, no motor. Se documenta en el README.
8. **Equivalencias de intercambio.** Requieren confirmación oficial, tanto RM-152 = M152 como TK1283-1 = 9-0511S. Hay un intento de 30 minutos de desarrollo para cada una. Sin confirmación, el complemento no se activa. Vía intercambio solo se traen aplicaciones (§5.6).
9. **TK1283-1 sin fuente.** Su producto es "KIT DE DISTRIBUCIÓN" (§4.4, §5.5).
10. **Fabricante en Safety.** Se identifica con vPIC `GetModelsForMake`. Si no se identifica, no se genera la aplicación (§5.4, §5.7).

## 10. A criterio del constructor
- Nombres de clases, tablas y rutas; la forma exacta de la interfaz de adaptadores.
- Estructura interna de los YAML de `config/catalog/`.
- Librerías concretas para HTTP y HTML (sugerido: Faraday + Nokogiri) y para pruebas de red (sugerido: WebMock).
- Cómo correr Solid Queue en desarrollo, siempre que `bin/dev` levante todo.
- Orden fijo de atributos por tipo de producto. Se define al implementar cada adaptador, cuando se conozcan los atributos reales, y lo revisa el desarrollador.
