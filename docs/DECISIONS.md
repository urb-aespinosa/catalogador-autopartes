# Bitácora de decisiones

Formato: fecha y hora (CDMX) · decisión · por qué · consecuencias.

## Registro de horas

| Sesión | Fecha | Inicio | Fin | Horas | Qué se hizo |
|---|---|---|---|---|---|
| 1 | 2026-11-05 | 11:07 | (en curso) | | Esqueleto Rails, brief, CLAUDE.md, spike de fuentes, brainstorming |

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
