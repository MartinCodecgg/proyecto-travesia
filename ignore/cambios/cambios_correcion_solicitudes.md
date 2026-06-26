# Cambios — Corrección de Lógica de Solicitudes y Logs de Asistencia

## IMPORTANTE — Causa del bug "Uncaught SyntaxError: Unexpected token '&'"

Este error fue introducido en la sesión anterior cuando se usaron comandos **PowerShell** (`Set-Content`) para reescribir bloques grandes del archivo. PowerShell corrompió los caracteres del contenido del `<script>` al escribirlo.

**Esta sesión usó únicamente el Edit tool** (reemplazo literal de strings, sin re-escritura completa del archivo). Esto evita el problema.

**Regla para el futuro:** Si se necesita modificar este archivo, usar SIEMPRE el Edit tool de Claude. Nunca usar PowerShell `Set-Content` o `Out-File` para re-escribir el HTML/JavaScript del script.

El `&` que se agregó en el nuevo código (`"&rid=" + existingLogRid`) está dentro de un string literal — igual que los `"&info="`, `"&sesskey="`, etc. que ya existían en el original y funcionaban correctamente.

---

Archivo modificado: `scripts/tablero_principal.html`

---

## 1. Función `parseLogs` (REESCRITA)

**Línea aprox.:** 1485–1558 (versión funcional)

**Qué se eliminó:**
- Lectura de campos `tutor` y `origen` buscando labels en `.row div span`
- Lectura de la fecha desde `.data-timeinfo span[title]` (formato Moodle español)
- Función interna `parseMoodleDate` (parseaba fechas en español como "17 de junio de 2026, 15:30")
- Lógica de "múltiples entradas por alumno, quedarse con la más reciente"

**Qué se agregó:**
- Extracción de `rid` desde los enlaces de acción de cada entrada (`a[href*='rid=']`, `a[href*='delete=']`, etc.)
- Lectura del campo `asistencias_json`: busca el primer array JSON válido en `.data-field-html`
- Fallback: busca array JSON en cualquier texto de la entrada con regex `\[[\s\S]*?\]`
- Si no hay JSON válido, la entrada se ignora (compatible con entradas del formato antiguo)
- El mapa retornado ahora incluye: `{ rid, date (Date), fechaText (ISO), tutor, origen, asistencias[] }`

**Por qué:**
Opción B para db_logs (d=16): una entrada por alumno con campo `asistencias_json` (Área de texto) que almacena todas las asistencias en formato JSON. Requiere que el campo `asistencias_json` sea creado manualmente en Moodle (d=16).

---

## 2. `computedAlumnos.push()` — Campo `logRid` agregado

**Línea aprox.:** 1901

**Qué se agregó:**
```javascript
logRid: logObj ? logObj.rid : null,
```
(insertado antes de `ultimaAsistencia`)

**Por qué:**
El submit de asistencia necesita saber el `rid` de la entrada existente en db_logs para actualizarla (en vez de crear una nueva).

---

## 3. Display de `asistText` en `renderDashboard`

**Línea aprox.:** 2167–2169

**Qué se cambió:**
- Antes: `alumno.ultimaAsistencia.substring(0, 16)` (cortaba el string ISO de forma cruda)
- Ahora: `formatFechaISO(alumno.ultimaAsistencia)` (formatea fecha ISO a dd/mm/yyyy hh:mm)

**Por qué:**
`ultimaAsistencia` ahora se guarda como ISO string (ej. "2026-06-17T15:30:00.000Z"). La función `formatFechaISO` convierte este formato a uno legible.

---

## 4. Submit handler de asistencia (PARCIALMENTE REESCRITO)

### 4a. Resolución de campos (primer `forEach` sobre `label[for]`)

**Qué se eliminó:**
- Detección de `nombre_tutor` / `tutor`
- Detección de `origen`
- Detección de `mensaje` / `orientacion`

**Qué se agregó:**
- Detección de `asistencias` → `fieldsMapeo.asistencias_json`

---

### 4b. Fallback de resolución (segundo loop por filas)

**Qué se cambió:**
- Condición de entrada: antes `if (!fieldsMapeo.nombre_alumno)`, ahora `if (!fieldsMapeo.nombre_alumno || !fieldsMapeo.asistencias_json)`
- Se eliminaron detecciones de `nombre_tutor`, `origen`, `mensaje`
- Se agregó detección de `asistencias` → `fieldsMapeo.asistencias_json`

**Qué se agregó después del loop:**
```javascript
// Fallback final: el último textarea del formulario es asistencias_json
if (!fieldsMapeo.asistencias_json) {
  const textareas = Array.from(docForm.querySelectorAll("textarea[name]"));
  if (textareas.length > 0) {
    fieldsMapeo.asistencias_json = textareas[textareas.length - 1].getAttribute("name");
  }
}
if (!fieldsMapeo.asistencias_json) {
  throw new Error("No se encontro el campo asistencias_json en db_logs...");
}
```

---

### 4c. Lógica de studentObj + existingLogRid + array de asistencias

**Agregado después de `tutorNombre`:**
```javascript
const studentObj = alumnosCalculados.find(a => a.id === activeStudentId);
const existingLogRid = studentObj ? studentObj.logRid : null;

let asistencias = [];
if (existingLogRid) {
  // GET formulario de edición para leer JSON existente
  const editFormRes = await fetch(...edit.php?d=db_logs&rid=existingLogRid);
  if (editFormRes.ok) {
    const jsonInput = docEdit.querySelector('[name="' + fieldsMapeo.asistencias_json + '"]');
    if (jsonInput) {
      const parsed = parseCleanJSON(jsonInput.value.trim());
      if (Array.isArray(parsed)) asistencias = parsed;
    }
  }
}

asistencias.push({ fecha: ISO, tutor, origen, mensaje });
```

**Por qué:**
Si ya existe una entrada en db_logs para este alumno, se lee el JSON actual y se agrega el nuevo registro. Si no existe, se empieza con array vacío.

---

### 4d. FormData — campo `rid` y `camposAEnviar`

**Qué se agregó al FormData:**
```javascript
if (existingLogRid) {
  formData.append("rid", existingLogRid);
}
```

**Qué se eliminó de `camposAEnviar`:**
- `nombre_tutor`
- `origen`
- `mensaje`

**Qué se agregó a `camposAEnviar`:**
```javascript
camposAEnviar[fieldsMapeo.asistencias_json] = JSON.stringify(asistencias);
```

---

### 4e. Sección "disapprove" (ELIMINADA)

**Qué se eliminó (era la sección "2. Si el origen es Solicitud, RECHAZAR"):**
```javascript
const studentObj = alumnosCalculados.find(...);  // redeclaración eliminada
if (origen === "Solicitud") {
  if (studentObj && studentObj.solicitudRid) {
    fetch(disapproveUrl);
  }
}
```

**Por qué:**
Con el nuevo diseño, el estado "pendiente" de una solicitud se determina por comparación de fechas (solicitudFecha > ultimaAsistencia), no por el estado de aprobación en Moodle. No es necesario llamar al endpoint `disapprove`.

---

### 4f. Hot-update de la UI

**Qué se eliminó:**
- `const studentObj = ...` (ya declarado antes en el mismo scope)
- `const hoy = new Date()` y construcción de `fechaFormateada` en español

**Qué se cambió:**
- `studentObj.ultimaAsistencia = fechaFormateada` → `studentObj.ultimaAsistencia = new Date().toISOString()`

**Qué se agregó:**
```javascript
solicitudesPendientes = solicitudesPendientes.filter(s => s.idAlumno !== activeStudentId);
```

---

## Paso manual requerido en Moodle

Antes de que los cambios funcionen, se debe agregar el campo `asistencias_json` a la base de datos d=16 (db_logs) en Moodle:
- **Tipo de campo:** Área de texto
- **Nombre:** `asistencias_json` (el label debe contener la palabra "asistencias")
- **Obligatorio:** No

Las entradas anteriores de db_logs (sin este campo) serán ignoradas por `parseLogs` y no causarán errores.
