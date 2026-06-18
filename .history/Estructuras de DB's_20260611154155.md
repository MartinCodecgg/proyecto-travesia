# Estructura de Bases de Datos Moodle

## Criterio general

La mayoría de los campos que almacenan datos compuestos se guardan como **texto plano en formato JSON serializado**. El código los lee como string y hace `JSON.parse(campo)` para trabajarlos como objeto normal. Esto evita tener que modificar la estructura de la DB en Moodle cada vez que cambia un campo del modelo de datos.

La excepción son campos simples donde Moodle los usa directamente:

- Campos numéricos donde se quiere ordenar o filtrar desde Moodle (`ird`, `aprobadas`, `alargamiento`).
- Menús desplegables que Moodle renderiza nativamente (`origen` en los logs).
- Textos cortos de identificación (`id_alumno`, `nombre_alumno`, `cuatrimestre`, `fecha_snapshot`).

---

## 0. DB Solicitudes de ayuda

**Propósito:** registrar solicitudes de ayuda enviadas por alumnos.

**Configuración en Moodle:**

- Requiere aprobación antes de que la entrada sea visible para terceros.
- Cada alumno solo ve sus propias entradas. Tutores ven todas, incluyendo pendientes.
- La aprobación programática (al marcar como atendida) archiva la solicitud.

**Campos a crear:**

|Campo|Tipo en Moodle|Obligatorio|Descripción|
|---|---|---|---|
|`descripcion`|Área de texto|No|Mensaje opcional del alumno al solicitar ayuda|

Moodle provee automáticamente: ID de entrada, nombre completo del autor, foto, fecha de envío, estado de aprobación (pendiente / aprobado).

> Un solo campo es suficiente. Todo lo relevante lo da Moodle sin configuración adicional.

---

## 1. DB Log de asistencias

**Propósito:** registrar cada asistencia realizada por un tutor, ya sea proactiva o en respuesta a una solicitud.

**Configuración en Moodle:**

- Sin requerimiento de aprobación.
- Solo accesible para tutores y profesores.

**Campos a crear:**

|Campo|Tipo en Moodle|Obligatorio|Descripción|
|---|---|---|---|
|`nombre_alumno`|Texto corto|Sí|Nombre completo del alumno asistido|
|`id_alumno`|Texto corto|Sí|ID Moodle del alumno (para cruzar datos)|
|`nombre_tutor`|Texto corto|Sí|Nombre del tutor — se guarda para no tener que hacer un fetch adicional al parsear|
|`origen`|Menú desplegable|Sí|`Proactivo` / `Solicitud`|
|`mensaje`|Área de texto|No|Mensaje enviado al alumno al asistirlo|

Moodle provee automáticamente: fecha de la entrada, ID de entrada.

> `origen` se deja como menú desplegable nativo de Moodle porque tiene solo dos valores fijos y puede ser útil filtrarlo desde la interfaz de Moodle directamente.

---

## 2. DB Config

**Propósito:** almacenar toda la configuración del sistema en un único registro de texto plano JSON, editable desde la Actividad Página de configuración sin tocar código.

**Configuración en Moodle:**

- Solo accesible para tutores y profesores.
- Se espera una única entrada. El código siempre lee la primera.
- Si no existe o falla el fetch, el sistema usa los valores hardcodeados como fallback.

**Campos a crear:**

|Campo|Tipo en Moodle|Obligatorio|Descripción|
|---|---|---|---|
|`config`|Área de texto|Sí|JSON completo con toda la configuración del sistema|

**⚠️ Importante — valores hardcodeados en el código:**

Los únicos dos valores que **no** vienen de esta DB (porque el código los necesita para saber dónde leer primero) deben estar visibles y comentados al inicio del código:

```javascript
// ─────────────────────────────────────────────────────────────
// VALORES HARDCODEADOS — necesarios para cargar la config antes que nada
// Estos son los únicos IDs que no vienen de la DB Config
const CMID_DB_CONFIG   = 0   // ← completar con el ID de la URL al navegar a la DB Config
const DATAID_DB_CONFIG = 0   // ← completar con el ?d= al abrir "Agregar entrada" en DB Config
// ─────────────────────────────────────────────────────────────
```

**Estructura del JSON de configuración** (el agente genera este JSON para que vos lo pegues como entrada en la DB):

```json
{
  "urls": {
    "base": "https://moodle.tuuniversidad.edu.ar",
    "cmids": {
      "encuesta_inicial":        0,
      "encuesta_cuatrimestral":  0,
      "db_solicitudes":          0,
      "db_logs":                 0,
      "db_historico":            0,
      "db_historico_1er_anio":   0,
      "db_1er_anio":             0
    },
    "dataids": {
      "db_solicitudes":        0,
      "db_logs":               0,
      "db_historico":          0,
      "db_historico_1er_anio": 0,
      "db_1er_anio":           0
    }
  },
  "umbrales": {
    "threshold_ird":            40,
    "cooldown_actualizar_seg":  30,
    "quarterly_warning_days":   90,
    "cuatrimestres_desercion":   2,
    "historico_delay_ms":       500,
    "results_per_page_moodle":  10,
    "page_size_paneles":        30
  },
  "encuesta_inicial": {
    "preguntas": [
      {
        "id":        "PENDIENTE — completar con selector HTML del Feedback",
        "texto":     "PENDIENTE — texto visible de la pregunta en Moodle",
        "beta":       0.0,
        "max_value":  0,
        "respuestas": {
          "PENDIENTE texto opción A": 0,
          "PENDIENTE texto opción B": 0
        }
      }
    ]
  },
  "encuesta_cuatrimestral": {
    "preguntas": [
      {
        "id":        "PENDIENTE — completar con selector HTML del Feedback",
        "texto":     "PENDIENTE — texto visible de la pregunta en Moodle",
        "beta":       0.0,
        "max_value":  0,
        "respuestas": {
          "PENDIENTE texto opción A": 0,
          "PENDIENTE texto opción B": 0
        }
      }
    ]
  },
  "preguntas_especiales": {
    "id_percepcion_riesgo": "PENDIENTE — selector HTML de la pregunta ¿Te percibís en riesgo?",
    "id_egreso":            "PENDIENTE — selector HTML de la pregunta ¿Estás egresado?",
    "id_anio_ingreso":      "PENDIENTE — selector HTML de la pregunta ¿En qué año ingresaste?"
  }
}
```

> Los campos marcados como `PENDIENTE` se completan una vez que tenés el HTML real del Feedback (ver sección "Cómo obtener cada dato" en el plan de implementación). Los `0` en cmids/dataids se reemplazan con los valores reales una vez creadas las actividades.

---

**Campos a crear:**

|Campo|Tipo en Moodle|Descripción|
|---|---|---|
|`id_alumno`|Texto corto|ID Moodle del alumno|
|`nombre_alumno`|Texto corto|Nombre completo — se guarda para no tener que cruzar con otra fuente al leer el histórico|
|`cuatrimestre`|Texto corto|Período del snapshot. Formato: `2026-1` / `2026-2`|
|`fecha_snapshot`|Texto corto|Fecha exacta del snapshot. Formato: `YYYY-MM-DD`|
|`ird`|Número|IRD calculado en el momento del snapshot|
|`se_percibe_riesgo`|Texto corto|`si` / `no` / `sin_dato`|
|`anio_ingreso`|Texto corto|Año de ingreso a la carrera — permite separar cohortes|
|`datos`|Área de texto|JSON serializado con respuestas y materias (ver estructura abajo)|

**Estructura del campo `datos`:**

```json
{
  "respuestas": {
    "id_pregunta_1": 3,
    "id_pregunta_2": 1
  },
  "materias": [
    { "materia": "Física A", "nota": 8 },
    { "materia": "Álgebra I-B", "nota": 6 }
  ]
}
```

---

## 3. DB Histórico

**Propósito:** guardar snapshots cuatrimestrales del estado de cada alumno para análisis histórico y exportación.

**Configuración en Moodle:**

- Solo accesible para tutores y profesores.
- Sin aprobación requerida.

**Campos a crear:**

|Campo|Tipo en Moodle|Descripción|
|---|---|---|
|`id_alumno`|Texto corto|ID Moodle del alumno|
|`nombre_alumno`|Texto corto|Nombre completo — se guarda para no cruzar con otra fuente al leer el histórico|
|`cuatrimestre`|Texto corto|Período del snapshot. Formato: `2026-1` / `2026-2`|
|`fecha_snapshot`|Texto corto|Fecha exacta del snapshot. Formato: `YYYY-MM-DD`|
|`anio_ingreso`|Texto corto|Año de ingreso a la carrera — permite separar cohortes|
|`ird`|Número|IRD calculado en el momento del snapshot|
|`ralentizacion`|Número|Ralentización calculada en el momento del snapshot. Fórmula: `(1 - aprobadas / esperadas) × 100`|
|`estado`|Texto corto|Estado del alumno en el momento del snapshot: `activo` / `desertor` / `egresado`|
|`se_percibe_riesgo`|Texto corto|`si` / `no` / `sin_dato`|
|`datos`|Área de texto|JSON serializado con respuestas y materias (ver estructura)|

**Estructura del campo `datos`:**

```json
{
  "respuestas": {
    "id_pregunta_1": 3,
    "id_pregunta_2": 1
  },
  "materias": [
    { "materia": "Física A", "nota": 8 },
    { "materia": "Álgebra I-B", "nota": 6 }
  ]
}
```

**Por qué `estado` y no los porcentajes calculados:** los porcentajes de cohorte (deserción 35%, activos 51%, terminal 14%) se calculan dinámicamente a partir de los snapshots en el momento que los consultás. Lo que no podés reconstruir a posteriori sin `estado` es saber si ese alumno era desertor o egresado _en ese cuatrimestre_, porque la función `esDesertor()` usa la fecha actual para comparar, no la del snapshot.

> `datos` reemplaza a los campos `respuestas_json` y `materias_json` que figuraban por separado en versiones anteriores del plan. Un solo campo es más simple de escribir y leer.

---

## 4. DB 1er Año

**Propósito:** estado actual de los alumnos ingresantes. Se actualiza al subir los CSVs.

**Configuración en Moodle:**

- Solo accesible para tutores y profesores.

**Campos a crear:**

| Campo                  | Tipo en Moodle | Descripción                                                                     |
| ---------------------- | -------------- | ------------------------------------------------------------------------------- |
| `id_alumno`            | Texto corto    | Identificador del alumno. Recomendado: DNI                                      |
| `alumno`               | Texto corto    | Nombre completo — viene del CSV A                                               |
| `anio_ingreso`         | Texto corto    | Año de ingreso. Formato: `2026`                                                 |
| `cuatrimestre_ingreso` | Texto corto    | Cuatrimestre de ingreso: `1` / `2`                                              |
| `aprobadas`            | Número         | Contador de materias con nota >= 6. Se recalcula al subir CSV B                 |
| `ralentizacion`        | Número         | Indicador calculado al subir CSV B. Fórmula: `(1 - aprobadas / 7) × 100`        |
| `materias`             | Área de texto  | JSON serializado con todas las materias y notas cargadas (ver estructura abajo) |

**Estructura del campo `materias`:**

```json
[
  { "materia": "Análisis Matemático I", "nota": 7 },
  { "materia": "Física A", "nota": 8 }
]
```

> El formato anterior (`"Física A:8,Álgebra:6"`) era frágil ante nombres de materias con comas. JSON elimina ese problema.

---

## 5. DB Histórico 1er Año

**Propósito:** snapshots cuatrimestrales del estado de alargamiento de alumnos de 1er año. Permite ver evolución a lo largo del tiempo.

**Configuración en Moodle:**

- Solo accesible para tutores y profesores.

**Campos a crear:**

| Campo            | Tipo en Moodle | Descripción                                                                              |
| ---------------- | -------------- | ---------------------------------------------------------------------------------------- |
| `id_alumno`      | Texto corto    | Identificador del alumno                                                                 |
| `alumno`         | Texto corto    | Nombre completo — se guarda para no tener que cruzar con DB 1er Año al leer el histórico |
| `cuatrimestre`   | Texto corto    | Período del snapshot. Formato: `2026-1` / `2026-2`                                       |
| `fecha_snapshot` | Texto corto    | Fecha exacta. Formato: `YYYY-MM-DD`                                                      |
| `aprobadas`      | Número         | Materias aprobadas en ese momento                                                        |
| `ralentizacion`  | Número         | Indicador en ese momento                                                                 |

> Esta DB es intencionalmente simple. No hay JSON porque todos los datos son escalares y planos.

---

## Resumen — campos JSON por DB

|DB|Campo JSON|Cuándo se parsea|
|---|---|---|
|DB Config|`config`|Al iniciar cualquier panel, como primer paso|
|DB Histórico|`datos`|Al leer el panel histórico o exportar CSV|
|DB 1er Año|`materias`|Al mostrar detalle de alumno o calcular alargamiento|

Las demás DBs (Solicitudes, Logs, Histórico 1er Año) no tienen campos JSON — todos sus datos son escalares simples.