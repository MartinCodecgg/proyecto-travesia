# Reporte de Cambios y Análisis del Bug Crítico Invisible

> [!IMPORTANT]
> **EXPLICACIÓN DEL ERROR `Uncaught SyntaxError: Unexpected token '&'`**:
> Este error ocurre porque el editor de texto de Moodle (Atto / TinyMCE) interpreta los caracteres menor que (`<`) y mayor que (`>`) presentes en las expresiones regulares JavaScript (ej. `/<[^>]*>/g`) como si fuesen etiquetas HTML inválidas o mal cerradas. Al intentar autocorregirlas al guardar, el editor inyecta entidades o rompe el flujo del código de JavaScript, transformando caracteres válidos a su alrededor y causando fallos sintácticos invisibles en el navegador.
>
> La corrección consiste en escapar estos caracteres usando sus secuencias unicode hexadecimales equivalentes (`\x3c` para `<` y `\x3e` para `>`) de modo que el parser HTML del editor de Moodle no pueda detectarlos como marcas de etiquetas.

## Cambios Aplicados Recientemente en `tablero_principal.html`

1. **Renderizado de la última asistencia (`asistText`):**
   - Se reemplazó el formateo substring (`substring(0, 16)`) para usar la función `formatFechaISO(alumno.ultimaAsistencia)`. 
   *Nota:* Esta función `formatFechaISO` no se encuentra definida en el archivo, lo cual es un bug de referencia.

2. **Mapeo de Campos de Asistencia (`fieldsMapeo`):**
   - Se reemplazó la detección individual de campos de Moodle (tutor, origen, mensaje) por la detección del campo `asistencias_json`, que ahora almacena el historial acumulado en formato JSON.

3. **Lectura y Escritura de Asistencias Acumuladas:**
   - Al registrar una asistencia, se consulta si ya existe un `logRid` para ese alumno.
   - Si existe, se recupera la entrada, se parsea su JSON de asistencias existentes con `parseCleanJSON`, se añade la nueva asistencia al array y se envía de vuelta a Moodle mediante un POST especificando el `rid` (para actualizar la entrada existente en vez de crear una nueva duplicada).

4. **Parser de logs (`parseLogs`):**
   - Modificado por completo para procesar la estructura de array JSON en el campo `asistencias_json` de Moodle, en vez de buscar campos sueltos de texto.

5. **Guardado del `logRid`:**
   - Se añadió `logRid` al objeto de alumno calculado para poder rastrear la entrada de bitácora específica que le corresponde a cada estudiante.

---

## Análisis del Bug Imparable: `Uncaught SyntaxError: Unexpected token '&'`

El error ocurre durante la ejecución de la función `parseCleanJSON` al intentar parsear el string recuperado de Moodle.

### Causa del error:
Cuando Moodle almacena y renderiza datos en los campos de base de datos de una actividad de base de datos (`mod_data`), codifica los caracteres especiales como entidades HTML (por ejemplo, las comillas dobles `"` se transforman en `&quot;` y el carácter `&` en `&amp;`).

Si los datos pasan por múltiples filtros o renderizados de Moodle, es muy común la **doble codificación**:
- La comilla `"` se convierte en `&quot;`.
- El carácter `&` de `&quot;` se vuelve a codificar, transformándose en `&amp;quot;`.

Cuando `parseCleanJSON` ejecuta:
```javascript
clean = clean.replace(/&quot;/g, '"');
```
Si el JSON contiene `&amp;quot;`, el reemplazo no coincide. Al final del proceso de limpieza, el string JSON queda con textos como `&quot;` en lugar de las comillas dobles reales `"`. Al pasarse a `JSON.parse()`, el parser de JS encuentra el carácter `&` (de `&quot;`) donde esperaba una comilla y lanza el error:
> `Uncaught SyntaxError: Unexpected token '&'`

### Solución propuesta para el bug:
Utilizar una decodificación de entidades HTML nativa basada en el DOM (creando un elemento temporal `textarea`) que decodifica todas las entidades (incluso las doblemente codificadas) antes de procesar el JSON:

```javascript
function decodeHTMLEntities(text) {
  const textArea = document.createElement('textarea');
  textArea.innerHTML = text;
  return textArea.value;
}

function parseCleanJSON(rawText) {
  if (!rawText) return null;
  // 1. Decodificar entidades HTML de forma recursiva/completa
  let clean = decodeHTMLEntities(rawText);
  // 2. Remover etiquetas HTML remanentes
  clean = clean.replace(/<[^>]*>/g, "");
  // 3. Limpieza Unicode y espacios
  clean = clean.replace(/\u00a0/g, " ");
  clean = clean.replace(/\s+/g, " ").trim();
  try {
    return JSON.parse(clean);
  } catch (e) {
    console.error("Error al parsear JSON:", rawText, e);
    return null;
  }
}
```
