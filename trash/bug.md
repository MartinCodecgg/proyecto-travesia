## Causa real del bug (resumen para el agente)

El parche de `decodeHTMLEntities` con `textarea.innerHTML` **solo decodifica un nivel** de entidades por ejecución. El problema real no es codificación doble fija, sino **codificación acumulativa en cada ciclo de lectura-escritura**:

1. Se lee el JSON ya guardado en Moodle (con N niveles de entidades, por ejemplo `&quot;` o `&amp;quot;`).
2. Se decodifica una sola vez → si N > 1, queda un residuo de entidades sin resolver (ej. `&amp;quot;` → `&quot;`, que sigue sin ser comilla real).
3. Se hace `JSON.stringify()` del array con ese residuo y se hace POST de vuelta a Moodle.
4. El campo de Moodle (muy probablemente un field tipo **Textarea/editor enriquecido**, no "Text" simple) vuelve a pasar el contenido por `format_text()`/HTMLPurifier/Atto al guardar, que **vuelve a codificar las comillas restantes**, sumando un nivel más de encoding del que tenía antes.

Resultado: cada asistencia que se registra incrementa la profundidad de codificación. El bug "parece resuelto" un par de veces y luego reaparece — porque de hecho está empeorando con cada escritura, no es estático.

Causa raíz de fondo: el tipo de campo de Moodle usado para `asistencias_json` pasa por el pipeline de filtros/editor (Atto/TinyMCE + HTMLPurifier) en cada guardado, en lugar de almacenarse como texto plano sin procesar.

---

## Soluciones (de más a menos efectiva)

**1. Codificar el JSON en Base64 antes de enviarlo, decodificar al leerlo.**
El alfabeto Base64 (`A-Z a-z 0-9 + / =`) no contiene `< > & "`, así que ningún filtro de Moodle (Atto, HTMLPurifier, webservice) puede tocarlo, sin importar cuántas veces pase por el pipeline. Es la solución más robusta porque ataca el problema sin depender de configuración de Moodle ni de cuántas capas de encoding existan hoy.

```javascript
// Al guardar:
const payload = btoa(
  unescape(encodeURIComponent(JSON.stringify(asistenciasArray))),
);
// Al leer:
const asistenciasArray = JSON.parse(
  decodeURIComponent(escape(atob(campoMoodle))),
);
```

**2. Cambiar el tipo de campo en la actividad "Base de datos" de Moodle de "Área de texto/Textarea" (rich text) a "Texto" simple (single-line text).**
Los campos "Text" no pasan por el editor Atto/TinyMCE ni por el mismo nivel de limpieza HTML, por lo que no se re-codifican las comillas en cada guardado. Esto elimina la causa raíz, pero requiere acceso de administrador/profesor a la configuración de la actividad y reconfigurar el campo existente (puede perder datos si ya hay encoding acumulado).

**3. Hacer el decode recursivo/idempotente (loop hasta estabilizar), no solo un pase.**
Mejora el parche actual sin resolver la causa de fondo (si el campo sigue siendo rich text, seguirá acumulando capas en cada escritura, solo que tardará más en romperse):

```javascript
function decodeHTMLEntitiesFull(text, maxIter = 5) {
  let prev = text;
  for (let i = 0; i < maxIter; i++) {
    const ta = document.createElement("textarea");
    ta.innerHTML = prev;
    const next = ta.value;
    if (next === prev) break;
    prev = next;
  }
  return prev;
}
```

**4. Verificar con `JSON.parse` en un try local antes de cada POST, y loguear el string crudo devuelto por Moodle tras guardar.**
No corrige el problema, pero permite confirmar en qué punto exacto se introduce cada capa de encoding (útil para diagnóstico si las soluciones 1–3 no aplican por restricciones del entorno).

**5. Rediseñar para que cada asistencia sea una entrada (row) separada de la actividad `mod_data`, en vez de un único campo JSON acumulativo por alumno.**
Es la solución "correcta" a largo plazo (usa `mod_data` como está pensado: una fila por evento), elimina el problema de raíz y de paso evita el límite de ~10,000 caracteres por campo. Pero implica reescribir la lógica de lectura/agregación (`parseLogs`, `fieldsMapeo`, etc.), por lo que es la de mayor esfuerzo de implementación.
