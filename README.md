# Catalogador de autopartes

> README en construcción: la versión completa (instalación, uso, fuentes, decisiones) se escribe en la Tarea 16. Las decisiones con su razonamiento están en `docs/DECISIONS.md`.

## Limitaciones conocidas

### Verificación de motor con EPA (D21, D22)

**EPA puede refutar un motor solo donde su cobertura de esa línea es completa.**

- **Qué cubre EPA:** fueleconomy.gov solo evalúa vehículos ligeros.
- **Qué no cubre:** las pickups y vans 2500/3500 HD, y las versiones más pesadas de las 2500, quedan fuera de su alcance.
- **Por qué importa:** si EPA no lista el motor de una aplicación, puede ser porque ese motor no existió, o porque pertenece a una versión que EPA no evalúa.
- **Modelos que solo confirman, nunca borran** (`confirm_only` en `config/catalog/epa_models.yml`):
  - los nombres 2500, 3500 y HD;
  - los nombres genéricos de líneas con versiones HD (Silverado, Sierra, Suburban, Express, Savana).

  Esos modelos confirman el motor y aportan combustible y evidencia. Si el motor no coincide, la fila se conserva y Validación registra `difiere`.
- **Huecos en los datos de EPA:** los casos donde el vehículo existió pero EPA no lo lista se registran como excepciones revisadas por modelo · año · motor, con su motivo. Por ejemplo, el Cadillac CTS-V 2009 con 6.2L: EPA lista el CTS-V solo desde 2010. Esos casos se conservan como `difiere`, nunca como confirmados.
- **Límite:** un hueco de EPA que nadie ha revisado todavía puede refutar un motor real. Por eso el reporte de refutaciones se revisa contra la historia de cada motor antes de aceptar cambios en las equivalencias.
