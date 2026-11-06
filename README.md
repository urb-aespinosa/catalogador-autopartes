# Catalogador de autopartes

Una refaccionaria tiene en su ERP una lista de piezas de motor con datos mínimos: número de parte, marca y una descripción abreviada, a veces con errores. Esta app de Rails toma ese Excel y genera un catálogo completo por pieza:

- **Aplicaciones:** en qué vehículos sirve, por mercado.
- **Intercambios:** qué piezas de otras marcas la reemplazan.
- **Atributos:** medidas y características, en español y en mm.
- **Descripción de catálogo:** un texto en español armado con plantillas.

El Excel de salida tiene las mismas hojas y columnas que `docs/input/ejemplo_prueba_tecnica.xlsx`, más dos hojas al final: **Fuentes** y **Validación**.

El catálogo generado con los datos de la prueba está en `docs/output/catalogo_bonaparte.xlsx`.

## El principio: toda la información del catálogo es comprobable

- **Cada dato del catálogo lleva su fuente.** La hoja Fuentes guarda, por cada aplicación, intercambio y atributo, la URL oficial de donde salió y, si se tradujo o se convirtió, el valor original (por ejemplo `3.880 IN`).
- **La fuente de verdad es el fabricante, no el ERP.** La descripción del ERP solo sirve para *buscar* la pieza y para *comparar* lo encontrado. Nunca llena el catálogo.
- **Lo que no se puede comprobar no se inventa.** Si una fuente oficial no publica un dato, la celda queda vacía y la hoja Validación dice por qué.
- **Las diferencias no se arreglan en silencio.** Cuando el ERP y el fabricante no coinciden, o cuando dos fuentes oficiales se contradicen, la hoja Validación lo registra para que una persona decida.
- **Mismo archivo, mismo resultado.** Cada página, PDF o respuesta consultada se guarda como copia (snapshot) y se reutiliza. Las filas siempre salen en el mismo orden. No se usa inteligencia artificial al ejecutar: las traducciones y los textos salen de diccionarios y plantillas versionados.

## Requisitos

- Ruby 3.3.5 (ver `.ruby-version`).
- SQLite 3.
- `pdftotext`, del paquete poppler. Lo usa el adaptador de Fraco para leer sus fichas en PDF.
  - macOS: `brew install poppler`
  - Debian/Ubuntu: `sudo apt install poppler-utils`
  - El `Dockerfile` ya lo instala.

## Instalación y uso

```bash
bin/setup --skip-server   # instala gemas, prepara la base y carga los snapshots versionados
bin/dev                   # levanta el servidor en http://localhost:3000
```

`bin/setup` carga las copias de `db/snapshots/` (`bin/rails catalog:snapshots:load`). Con ellas, el catálogo se genera **sin conexión** y sale idéntico en cualquier máquina.

### Desde el navegador

1. Abre `http://localhost:3000` y sube el Excel del ERP (hoja `Origen`).
2. La pantalla muestra el avance pieza por pieza mientras trabaja (Turbo Streams).
3. Al terminar, descarga el Excel.

‹Captura o GIF de la pantalla de progreso: se agrega en la sesión de verificación.›

### Desde la terminal

```bash
bin/rails "catalog:run[docs/input/data_prueba_tecnica.xlsx,docs/output/catalogo_bonaparte.xlsx]"
```

### Volver a descargar las fuentes

Por defecto, la app nunca vuelve a descargar algo que ya tiene en caché. Para forzar una descarga nueva:

```bash
FORCE_REFRESH=1 bin/rails "catalog:run[entrada.xlsx,salida.xlsx]"
bin/rails catalog:snapshots:dump   # guarda las copias nuevas en db/snapshots/
```

Una descarga nueva es otro snapshot y puede cambiar el resultado, porque los sitios cambian. Todas las solicitudes se identifican con el User-Agent del proyecto, `catalogador-autopartes/1.0 (prueba tecnica)`, y hacen como máximo una solicitud por segundo por sitio.

### Pruebas

```bash
bin/rails test   # todas las pruebas; no usan red
bin/ci           # rubocop, auditorías de seguridad y pruebas
```

## Cómo funciona

1. **Importar.** Se lee la hoja `Origen` del Excel del ERP.
2. **Leer la descripción del ERP.** Expresiones regulares y diccionarios fijos sacan pistas: armadora, motor, rango de años `AA/AA` y números de otras marcas.
3. **Buscar en el fabricante.** Un adaptador por marca consulta el sitio oficial del fabricante y guarda la copia.
4. **Extraer.** De la copia salen aplicaciones, intercambios y atributos.
5. **Verificar vehículos.** Cada combinación modelo-año se confirma contra fuentes oficiales de vehículos (ver "Rol de cada fuente").
6. **Normalizar.** Marcas, productos, atributos, unidades y combustibles se unifican con diccionarios YAML versionados en `config/catalog/`.
7. **Comparar.** Lo que dice el fabricante se compara contra la descripción del ERP; cada coincidencia o diferencia va a Validación.
8. **Exportar.** Se arma el Excel con `caxlsx`.

En la app, cada pieza se procesa en su propio job, y un job final arma el libro.

### Las hojas extra

- **Fuentes:** referencia, tipo de dato, origen, URL y valor original de cada dato.
- **Validación:** referencia, campo, valor del ERP, valor de la fuente, URL y estado. Los estados son:
  - `coincide`, `difiere` y `no encontrado`;
  - `confirmado por ventas`, `confirmado por EPA` y `según catálogo` (nivel de mercado);
  - `sin traducción`: un término que no está en el diccionario sale con su texto original;
  - `error de fuente`: la fuente no respondió o cambió de formato;
  - `sin fuente configurada`: la marca no tiene adaptador, así que no se buscó nada.

## Rol de cada fuente

| Fuente | Qué aporta | Qué no aporta |
|---|---|---|
| **Sitio oficial del fabricante** (Elgin, Fraco, Rexite, Safety) | Aplicaciones, atributos e intercambios. Es la única fuente de aplicaciones. | — |
| **NHTSA vPIC** (EE. UU.) | Confirma que el modelo existió ese año, incluidas las versiones HD. También resuelve la marca real cuando el catálogo dice "GM Trucks". | No confirma motor ni versión de carga (1500/2500/3500). |
| **EPA fueleconomy.gov** (EE. UU.) | Confirma que el modelo-año se ofreció en EE. UU. con ese motor, y da el combustible. | No cubre pickups y vans HD ni modelos solo mexicanos. No publica versión. |
| **INEGI RAIAVL** (México) | Confirma ventas en México por modelo y año calendario. | No publica versión, motor ni combustible. Empieza en 2005. |

Ninguna de las tres fuentes de vehículos agrega aplicaciones: solo confirman, niegan o ubican en un mercado las que publica el fabricante.

### Mercado por niveles

El mercado se define por dónde se vendió el vehículo (D19), por niveles y por mercado:

- **MEX, nivel a, `confirmado por ventas`:** INEGI registra ventas mayores a cero de ese modelo en el mismo año calendario que el año modelo.
- **USA, nivel a, `confirmado por EPA`:** EPA lista ese modelo-año y, si la aplicación trae motor, una configuración con el mismo motor (misma cilindrada a un decimal y mismos cilindros).
- **Nivel b, `según catálogo`:** se usa solo para el mercado del propio catálogo. Un catálogo de EE. UU. (Elgin, Safety) puede dar USA nivel b; uno mexicano (Fraco, Rexite) puede dar MEX nivel b. El otro mercado entra **solo** con nivel a.
- **Una fila por mercado.** Validación registra el nivel usado, agrupado por pieza, armadora, modelo y rango de años.

**Motor refutado por EPA.** Si EPA cubre completa esa línea y ninguna configuración tiene el motor de la aplicación:

- en un catálogo USA, la fila se elimina en todos los mercados;
- en un catálogo MEX, se conserva la fila MEX y solo se niega la USA.

En los dos casos queda una fila `Motor · difiere` en Validación, con los dos motores, la URL de EPA y lo que pasó con la fila.

**Combustible.** Cada dato vale para el mercado de su fuente. EPA llena el combustible solo en filas USA, y solo si hay un único combustible para ese motor ese año. Si hay varios (por ejemplo, la misma 5.3L en versión Flex y en versión gasolina), la celda queda vacía y la lista queda en Fuentes. Las filas MEX no llevan combustible, porque ni Fraco ni Rexite lo publican y un catálogo de EE. UU. no habla por México.

### Procedencia de los datos de referencia

Los datos de INEGI y EPA se usan desde archivos oficiales descargados y versionados, no desde consultas en vivo:

| Carpeta | Archivo oficial | Extracto que usa la app | Cómo se regenera |
|---|---|---|---|
| `db/reference/inegi/` | Datos abiertos de RAIAVL (ventas mensuales 2005–2026), descargados a mano desde `inegi.org.mx/datosprimarios/iavl/` | `raiavl_venta_nissan_gm.csv` | `bin/rails catalog:inegi:filter` |
| `db/reference/epa/` | `vehicles.csv.zip` de `fueleconomy.gov` | `vehicles_scope.csv` (12,635 configuraciones de las marcas en alcance) | `bin/rails catalog:epa:filter` |

Cada carpeta tiene un `.yml` con la URL, la fecha de descarga y el sha256. Un test regenera cada extracto desde el ZIP y compara su sha256: si alguien edita el extracto a mano, el test falla.

La API y el formulario de exportación de INEGI no funcionan con un cliente automático (la API responde 403 a nuestro User-Agent). No se esquivan: se usan los datos abiertos.

### Equivalencias de nombres, revisadas a mano

Cada fuente nombra los modelos a su manera ("Silverado 1500", "Silverado C15 2WD", "Silverado 1500 Cabina Regular"). Las equivalencias están en dos YAML revisados por el desarrollador:

- **`config/catalog/inegi_models.yml` (D20): la capacidad nunca se infiere.**
  - Un nombre genérico ("Silverado") cuenta con todas las series de esa línea en INEGI.
  - Un nombre con capacidad ("Silverado 2500 HD") cuenta solo con las series que dicen esa capacidad. Si ninguna la dice, no hay evidencia de ventas en México.
- **`config/catalog/epa_models.yml` (D21, D22): inclusiva.**
  - "1500" es toda la línea ligera de EPA.
  - `confirm_only`: modelos que EPA puede confirmar, pero nunca refutar, porque su cobertura de esa línea no es completa (ver "Limitaciones conocidas").
  - `confirm_only_years`: excepciones revisadas por modelo · año · motor, donde el vehículo existió y EPA no lo lista.
- **Por qué las dos reglas son distintas (la asimetría).** Un error en la tabla de INEGI solo hace que falte evidencia: la fila sigue saliendo con nivel b o no se agrega un mercado. Un error en la tabla de EPA **borraría filas reales**. Por eso INEGI es estricta y EPA es inclusiva: en cada caso se elige el error que hace menos daño.

**Nombres mexicanos de Elgin (D20).** Elgin lista Cheyenne, Sonora, Express Pasajeros y Express Cargo, que vPIC no conoce en ningún año. Esos nombres entran **solo como MEX nivel a**, en los años con ventas en INEGI (por ejemplo, Cheyenne 2019–2024). Nunca generan filas USA. Si vPIC conoce el modelo pero niega un año, esa negativa se respeta: INEGI no la rescata.

## Resultado con los datos de la prueba

Corrida de `docs/input/data_prueba_tecnica.xlsx` hacia `docs/output/catalogo_bonaparte.xlsx`, hecha desde los snapshots versionados, sin ninguna solicitud de red:

| Hoja | Filas |
|---|---|
| Aplicaciones | 1,449 (977 USA, 472 MEX) |
| Intercambios | 0 |
| Atributos | 10 |
| Fuentes | 2,853 |
| Validación | 517 |

| Pieza | Marca | Fuente | Resultado |
|---|---|---|---|
| FSX-5840301 | FRACO | Ficha PDF oficial (catálogo MEX) | 45 aplicaciones Nissan 2.4L: 31 MEX (según catálogo; la mayoría de los años son anteriores a 2005, cuando empieza INEGI) y 14 USA confirmadas por EPA. Sus 3 números de intercambio del ERP quedan en Validación. |
| HL-7025S | ELGIN | `catalog.elginind.com` (catálogo USA) | 1,358 aplicaciones GM: 939 USA y 419 MEX. EPA eliminó 169 combinaciones cuyo motor no existió (por ejemplo, Buick Allure 2005 5.3L). Otras 68 diferencias de motor se conservan, con su motivo. 56 grupos de modelo-año que vPIC no confirma quedan en Validación. |
| RM-152 | REXITE | `rexite.net` (catálogo MEX) | 2 aplicaciones MEX, las que publica Rexite: Nissan 280ZX 1981–1982. El rango del ERP (76/14) es más amplio; Rexite está incompleta, no contradice. |
| SP26-329R/L+20 | SAFETY | `safetyautoparts.com` (catálogo USA) | 44 aplicaciones GM: 24 USA y 20 MEX confirmadas por ventas en INEGI. |
| TK1283-1 | REVO | Sin sitio oficial | `sin fuente configurada`. Producto "KIT DE DISTRIBUCIÓN", tomado del grupo del ERP. |

**Determinismo:** dos corridas seguidas dan contenido idéntico, celda por celda, en las 8 hojas.

## La hoja Validación: un diagnóstico de los datos de origen

Validación no es solo un registro de errores de la app. También es un **diagnóstico de la calidad de los datos del ERP**: muestra qué partes de la descripción de cada pieza confirmó el fabricante, cuáles contradijo y cuáles no aparecen en ninguna fuente oficial.

**Ejemplo, HL7011.** La descripción del ERP de HL-7025S empieza con "HL7011", como si fuera un número de Elgin. Ese número **no existe** en el catálogo de Elgin: su numeración salta de HL-7005 a HL-7012. Es un error de captura del ERP. Si el catálogo se llenara desde la descripción, ese número habría llegado a la hoja Intercambios. Por eso la descripción del ERP solo se usa para buscar y validar, nunca como dato final.

Filtrando Validación por Estado, una persona puede ver de un vistazo qué corregir en el ERP y qué falta pedir a cada proveedor.

## Por qué la hoja Intercambios sale vacía en esta prueba

Ninguno de los números de intercambio de la descripción del ERP tiene, dentro de las fuentes que la app consulta, una confirmación oficial; por eso Intercambios no tiene filas. Un número entra a Intercambios **solo si una fuente oficial lo confirma** (D9, D16):

- la ficha oficial de la pieza lo menciona, o
- el catálogo oficial de la otra marca confirma que el número existe y que es para el mismo motor, con un rango de años que contiene todos los de nuestra pieza ("confirmado por aplicación").

Los fabricantes casi nunca publican equivalencias con otras marcas, así que la mayoría de los números del ERP quedan en Validación, cada uno con su motivo. Algunos casos:

- **RM-152 = Melling M152** y **TK1283-1 = Cloyes 9-0511S:** sin confirmación oficial. Los catálogos de Melling y Cloyes solo se pueden consultar con credenciales incrustadas en su JavaScript, y no se usan (D14).
- **FS-001225 (DC Gaskets), intercambio de FSX-5840301:** se **confirmó** durante la investigación en la búsqueda pública de DC Gaskets: Nissan KA24E 2.4L, 1989–2004, que contiene los años de la pieza (1989–1999). Ver `docs/DECISIONS.md`, "Hallazgo (Tarea 15b)". **El adaptador DC/Dacomsa que lo llevaría al Excel no se construyó**: fue lo primero que se recortó del alcance y queda como trabajo pendiente. Por eso hoy FS-001225 aparece en Validación y no en Intercambios.
- **JC-20 (TF Victor):** su ficha oficial cubre 1989–1998 y la pieza llega a 1999. No se confirma.
- **QJC20G (Quebec) y 83-301 (Moresa):** no se encontraron en catálogos oficiales públicos. Los sitios de Moresa y TF Victor no respondieron a nuestro User-Agent; eso se registró como hallazgo, no se esquivó.

## Fabricantes soportados y cómo agregar uno

Los adaptadores están registrados en `Sources::Registry` (D18):

| Marca | Fuente oficial | Mercado del catálogo |
|---|---|---|
| ELGIN | `catalog.elginind.com` (HTML) | USA |
| FRACO | Ficha PDF `fraco.com.mx/QRMX/{número}.pdf` | MEX |
| REXITE | `rexite.net` (API JSON de su tienda) | MEX |
| SAFETY | `safetyautoparts.com/webcatalog` (HTML) | USA |

**Una marca sin adaptador** (por ejemplo REVO) sale con lo mínimo en Catálogo (referencia, marca y producto normalizados) y en Validación con Estado `sin fuente configurada`. Ese estado es distinto de `no encontrado`: no significa que se buscó y no estaba, sino que no se buscó.

**Para agregar un adaptador:**

1. Crea una clase en `app/services/sources/` que reciba la pieza y devuelva un `Sources::Result` (aplicaciones, intercambios, atributos y evidencias con URL). Todas las descargas pasan por `Catalog::Fetcher`, que guarda el snapshot, respeta el límite por sitio y usa el User-Agent del proyecto.
2. Regístrala en `Sources::Registry::ADAPTERS` con el nombre de la marca tal como viene en el ERP.
3. Guarda copias reales de sus páginas en `test/fixtures/files/sources/<marca>/` y escribe los tests contra esas copias, sin red.
4. Si la fuente usa términos, unidades o productos nuevos, agrégalos a los diccionarios de `config/catalog/`. Un término que falte saldrá como `sin traducción` en Validación.

## Limitaciones conocidas

### Vehículos y versiones

- **Submodelo vacío (D3).** Ninguna fuente oficial gratuita publica la versión (submodelo): EPA trae el campo vacío e INEGI usa el nombre comercial sin versión. La columna queda vacía; no se usa "Base" como relleno, porque en el ejemplo "Base" es un submodelo real.
- **vPIC confirma modelo y año, no motor (D11).** El motor lo afirma el fabricante; EPA lo verifica donde tiene cobertura.
- **Versión de carga (D14).** vPIC confirma la línea de modelo y el año, no la versión 1500/2500/3500. Pueden aparecer combinaciones de versión y año que no existieron, por ejemplo Express 1500 después de 2014 o Suburban 2500 después de 2013, cuando EPA no puede refutarlas. Ninguna fuente oficial gratuita publica años por versión. La aplicación sigue respaldada por el fabricante.
- **Alias de capacidad para vPIC (D14).** vPIC usa nombres base ("Silverado") y Elgin nombres con capacidad ("Silverado 1500"). Una tabla revisada traduce solo los sufijos 1500, 2500, 3500 y HD **para consultar vPIC**. En el Excel se conserva el nombre de Elgin.

### Mercado (adenda D19)

1. **Año de venta contra año modelo.** INEGI cuenta ventas por año calendario y se compara con el año modelo de forma estricta. Un modelo 2015 vendido solo en 2014 no se confirma.
2. **MEX sin verificación de motor.** INEGI no publica motor, así que una fila MEX confirmada por ventas no dice qué motor se vendió.
3. **EPA no cubre HD ni modelos solo mexicanos.** Ahí USA queda en nivel b, si el catálogo es de EE. UU., y el motor no se verifica.
4. **INEGI empieza en 2005.** Antes de 2005, MEX solo puede ser nivel b.
5. **"General Motors" es un grupo.** INEGI registra la marca como el grupo, no como Chevrolet o GMC. La marca se resuelve con la tabla de equivalencias.
6. **Submodelo vacío** (ver arriba).

### Verificación de motor con EPA (D21, D22)

**EPA puede refutar un motor solo donde su cobertura de esa línea es completa.**

- **Qué cubre EPA:** fueleconomy.gov solo evalúa vehículos ligeros.
- **Qué no cubre:** las pickups y vans 2500/3500 HD, y las versiones más pesadas de las 2500, quedan fuera de su alcance.
- **Por qué importa:** si EPA no lista el motor de una aplicación, puede ser porque ese motor no existió, o porque pertenece a una versión que EPA no evalúa.
- **Modelos que solo confirman, nunca borran** (`confirm_only` en `config/catalog/epa_models.yml`):
  - los nombres 2500, 3500 y HD;
  - los nombres genéricos de líneas con versiones HD (Silverado, Sierra, Suburban, Express, Savana);
  - Avalanche 2002–2006 y Yukon XL 2000–2013, los años en que esas líneas tuvieron versión 2500.

  Esos modelos confirman el motor y aportan combustible y evidencia. Si el motor no coincide, la fila se conserva y Validación registra `difiere`.
- **Suburban sin límite de años.** Después de 2013 no hay una fuente oficial que permita acotar en qué años la Suburban tuvo versión pesada, así que queda como `confirm_only` en todos los años. Puede conservar alguna combinación que EPA habría podido refutar.
- **Huecos en los datos de EPA:** los casos donde el vehículo existió pero EPA no lo lista se registran como excepciones revisadas por modelo · año · motor, con su motivo. Por ejemplo, el Cadillac CTS-V 2009 con 6.2L: EPA lista el CTS-V solo desde 2010. Esos casos se conservan como `difiere`, nunca como confirmados.
- **Límite:** un hueco de EPA que nadie ha revisado todavía puede refutar un motor real. Por eso el reporte de refutaciones se revisa contra la historia de cada motor antes de aceptar cambios en las equivalencias.
- **Auditoría:** cada "Motor · difiere" en Validación termina con lo que pasó con la fila: `eliminada`, `se conserva solo MEX`, `se conserva (confirm_only)` o `se conserva (excepción revisada)`.

### Otras limitaciones conocidas del mercado (revisión independiente, D22)

- **Errores de datos de referencia.** Si el extracto de INEGI o de EPA, o sus YAML, están dañados, el error detiene la pieza en lugar de registrarse como "error de fuente". Los archivos están versionados y tienen tests que los regeneran.
- **Lista de modelos de vPIC.** Si falla la consulta `GetModelsForMake` (D20), la pieza completa queda como "error de fuente". Las respuestas usadas están en caché y en los fixtures.
- **Aplicaciones sin año.** Conservan el mercado de su catálogo, pero sin evidencia de mercado en Fuentes ni fila de Mercado en Validación.
- **Una URL por grupo en Validación de Mercado.** Cada grupo muestra una sola URL; la hoja Fuentes conserva todas.
- **Arranque.** `Epa.config` lee su YAML tres veces en la primera carga.
- **Excepciones revisadas.** Ningún test detecta si una excepción de `confirm_only_years` queda obsoleta después de actualizar el extracto de EPA. Al renovar el snapshot hay que repetir el reporte de refutaciones.

## Hacia producción: la visión

Esta prueba resuelve la incertidumbre con fuentes públicas y deja visible lo que no puede comprobar. En producción, la forma de cerrar esos huecos es mejorar los datos en su origen:

1. **Una base de vehículos de referencia.** Una base licenciada como VCdb, de Auto Care Association, publica submodelo y motor por año y por mercado. Con ella se llenaría Submodelo y se verificaría el motor también en México.
2. **Acordar estándares con los proveedores.** Pedir a cada fabricante sus aplicaciones e intercambios en un formato común (por ejemplo ACES para aplicaciones y PIES para atributos), con números de parte normalizados y rangos de años por modelo, no por motor.
3. **Recibir los datos directamente, mediante adaptadores.** A la larga, cada proveedor entrega sus datos por un archivo o una API acordados, y la app los lee con un adaptador como los de `app/services/sources/`. La arquitectura ya está pensada para eso: agregar un proveedor es agregar una clase, registrarla y probarla contra sus copias.
4. **Usar Validación como tablero de calidad.** Las diferencias entre el ERP y los proveedores se convierten en una lista de correcciones para el ERP y de pendientes para cada proveedor.

## Proceso

Este proyecto se hizo con **Claude Code** (un asistente de programación con IA) y el conjunto de habilidades **Superpowers**, con un método *spec-first*:

1. **Brief:** el problema, en `docs/DESIGN_BRIEF.md`.
2. **Spec:** un diseño aprobado, con las reglas de negocio y lo que queda fuera.
3. **Plan:** tareas pequeñas, cada una con sus pruebas.
4. **TDD estricto:** primero una prueba que falla, después el código mínimo que la pasa.

**Quién hizo qué:**
- **El desarrollador** definió el problema, tomó las decisiones D1–D22 (fuentes aceptables, qué se publica y qué no, cómo se tratan la incertidumbre y el riesgo) y revisó cada paso: las equivalencias en YAML, los reportes de filas eliminadas, cada script antes de ejecutarlo y cada solicitud a un sitio nuevo.
- **Claude** implementó el código y las pruebas, hizo la investigación de fuentes y redactó la documentación, siempre con las decisiones registradas en `docs/DECISIONS.md`.
- **La IA no se usa al ejecutar la app.** Las frases de apertura de las descripciones se redactaron con ayuda de IA durante el diseño y las revisó el desarrollador (D4); en ejecución salen de plantillas fijas.

**Revisiones independientes.** Un revisor con contexto nuevo (otra instancia del modelo, sin el historial de la sesión) revisó el spec, bloques de tareas del plan original y la tarea de la adenda que elimina filas. Algunos errores importantes que se detectaron así:
- **La regla de vPIC que inventaba combinaciones.** Para comparar nombres, una regla de "primeras palabras" confirmaba "Silverado 1500 Classic" de 2008 a 2020 porque vPIC conoce "Silverado", aunque esa versión solo existió en 2007. El revisor señaló que contradecía el spec y se revirtió.
- **El Avalanche.** El revisor de la adenda señaló que EPA podía borrar filas reales de la Avalanche y la Yukon XL, porque tuvieron versiones 2500 que EPA no evalúa. Al corregirlo se repitió sin comprobar la afirmación de que "no cambia ninguna fila"; era falsa: la corrección conservaba cuatro aplicaciones Avalanche 6.0L 2010–2013 que no existieron. Se detectó al comparar dos corridas, se corrigió limitando la protección a los años con versión 2500 (2002–2006) y se dejó la corrección visible en `docs/DECISIONS.md`.
- **Otros, de la verificación manual:** las fórmulas de Métricas se guardaban como texto, y una primera ronda de investigación usó un User-Agent de navegador; el desarrollador la detuvo y todas las consultas se repitieron con el del proyecto.

**Horas reales** (registro de horas en `docs/DECISIONS.md`):

| Sesión | Fecha | Horas | Qué se hizo |
|---|---|---|---|
| 1 | 2026-11-05 | 7.1 | Brief, spike de fuentes, decisiones D1–D16, spec, plan y pipeline completo |
| 2 | 2026-11-06 | ‹se cierra al terminar la sesión› | CI, intercambios en catálogos oficiales, adenda de mercado (D17–D22), README y verificación |

## Documentación del proyecto

- `docs/DESIGN_BRIEF.md`: el brief original.
- `docs/DECISIONS.md`: cada decisión (D1–D22) y cada hallazgo, con fecha, hora, razonamiento y consecuencias. Incluye el registro de horas.
- `docs/superpowers/specs/`: el diseño aprobado y la adenda de mercado.
- `docs/superpowers/plans/`: los planes de implementación, tarea por tarea.
