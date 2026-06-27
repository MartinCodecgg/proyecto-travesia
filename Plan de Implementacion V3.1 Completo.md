## 1. Descripción General

Sistema web embebido en Moodle para calcular y visualizar el **Índice de Riesgo de Deserción (IRD)** de cada alumno, gestionar la asistencia por parte de tutores, y registrar datos históricos para análisis longitudinal.

El sistema se implementa como bloques de código (HTML + CSS + JS) incrustados en actividades de tipo **Página** de Moodle. No utiliza frameworks externos ni librerías de terceros. Cada actividad Página es una feature independiente.

### 1.1 Usuarios y accesos

| Usuario          | Página / Actividad                    | Puede hacer                                                               |
| ---------------- | ------------------------------------- | ------------------------------------------------------------------------- |
| Tutor / Profesor | Dashboard principal (Paneles 1 y 2)   | Ver IRD de todos los alumnos, asistir alumnos, ver solicitudes pendientes |
| Tutor / Profesor | Panel Histórico                       | Guardar snapshots, buscar y filtrar alumnos, exportar CSV                 |
| Tutor / Profesor | Panel 1er Año                         | Subir CSV de alumnos y notas, ver alargamiento, exportar                  |
| Tutor / Profesor | Configuración (pestaña oculta)        | Modificar parámetros del sistema sin editar código                        |
| Alumno           | Panel del alumno (actividad separada) | Ver su propio IRD, solicitar asistencia                                   |

### 1.2 Acceso al dashboard

Protegido por una pantalla falsa (seguridad por oscuridad). El tutor accede haciendo clic en la palabra `accumsan` del tercer párrafo, que tiene `cursor: text` para no delatarse. No es seguridad real: cualquiera que inspeccione el HTML ve el panel completo. Su único propósito es evitar que un alumno que abra la actividad por error vea datos de sus compañeros.

```html
<div id="pantalla-falsa">
  <!-- texto lorem ipsum -->
  <!-- 3er párrafo: <span id="btn-oculto" style="cursor:text;">accumsan</span> -->
</div>
<div id="tablero" style="display:none;"><!-- panel real --></div>
<script>
  document.getElementById("btn-oculto").addEventListener("click", function () {
    document.getElementById("pantalla-falsa").style.display = "none";
    document.getElementById("tablero").style.display = "block";
  });
</script>
```

El título de la actividad Página se oculta con:

```javascript
document.querySelector(".page-header-headings").style.display = "none";
```

---

## 2. Arquitectura del Sistema

### 2.1 Stack técnico

- **Lenguaje:** JavaScript vanilla (ES2020+), HTML, CSS
- **Empaquetado e Inyección de Estilos:** Un único archivo HTML con JS. Para evitar que el filtro purificador de HTML de Moodle elimine las etiquetas `<style>`, todo el código CSS debe declararse dentro de una variable de JavaScript e inyectarse dinámicamente al `document.head` al inicializar la aplicación.
- **Elementos Gráficos Sin Emojis:** Todos los íconos e indicadores gráficos estáticos (en botones, títulos o labels) deben implementarse con vectores SVG en lugar de emojis de texto plano. Solo se permiten emojis para reportes de estado dinámico o logs transitorios (`⏳`, `✅`, `❌`).
- **Persistencia:** Actividades "Base de datos" de Moodle, accedidas vía `fetch` simulando acciones del usuario autenticado.
- **Datos del IRD:** Scraping de páginas de resultados de Feedback de Moodle.
- **Sin frameworks:** Cero dependencias externas.
- **Sin handlers HTML:** Todos los eventos registrados exclusivamente vía `addEventListener` (restricción de Moodle).

### 2.2 Actividades del sistema (resumen)

| Actividad Moodle     | Tipo      | Propósito                                        |
| -------------------- | --------- | ------------------------------------------------ |
| Dashboard principal  | Página    | Feature 1 — Paneles IRD y Solicitudes            |
| Panel del alumno     | Página    | Feature 2 — Vista individual del alumno          |
| Panel Histórico      | Página    | Feature 3 — Snapshots y análisis histórico       |
| Panel 1er Año        | Página    | Feature 4 — Gestión de alumnos ingresantes       |
| Config (pestaña)     | BD Moodle | Parámetros configurables sin editar código       |
| DB Solicitudes       | BD Moodle | Solicitudes de ayuda enviadas por alumnos        |
| DB Logs asistencias  | BD Moodle | Registro de asistencias realizadas por tutores   |
| DB Histórico         | BD Moodle | Snapshots cuatrimestrales de todos los alumnos   |
| DB Histórico 1er Año | BD Moodle | Snapshots del alargamiento de alumnos de 1er año |
| DB 1er Año           | BD Moodle | Estado actual de alumnos ingresantes (CSV)       |
| DB Config            | BD Moodle | Parámetros del sistema modificables por el tutor |

### 2.3 Flujo general de datos — Dashboard principal

```
[Tutor abre el dashboard]
          │
          ▼
[Leer config desde DB Config (+300ms)]
          │
          ▼
[Promise.all — 4 fuentes en paralelo]
    │          │           │           │
[Encuesta  [Encuesta   [DB Solic.  [DB Logs]
 inicial]   cuatrim.]   alumnos]
          │
          ▼
[Parseo y merge de datos por id_alumno]
          │
          ▼
[Cálculo de Z_max dinámico desde estructura de encuestas]
          │
          ▼
[Cálculo de IRD por alumno: Z / Z_max × 100  — truncar a 0 si Z < 0]
          │
          ▼
[Calcular "Peso por Pregunta" (indicador de indicadores)]
          │
          ▼
[Separar alumnos: "se percibe en riesgo" vs resto]
          │
          ▼
[Ordenar cada grupo por IRD descendente — nulls al final]
          │
          ▼
[Renderizar Panel 1 y Panel 2 con paginación de 30]
```

### 2.4 Consideraciones de rendimiento

Los fetches se realizan por internet. Cada fetch a Moodle toma aproximadamente 200–600ms. Con `Promise.all`, todas las fuentes se consultan en paralelo, por lo que el tiempo total es el del fetch más lento: **600ms–1.5s** más los ~300ms de la carga de config. Aceptable con un spinner visible.

Cada fuente puede estar paginada. Estrategia:

1. Fetch del primer page de cada fuente para detectar el total de páginas.
2. Lanzar en paralelo todos los fetches restantes de cada fuente.
3. Una vez completos todos, procesar y renderizar.

**Cooldown del botón Actualizar:** deshabilitado durante `ACTUALIZAR_COOLDOWN_SEG` segundos (default: 30) después de cada uso. Se muestra un contador regresivo junto al botón.

---

## 3. Fuentes de Datos

### 3.1 Fuentes de lectura (scraping vía GET)

| #   | Fuente                  | URL patrón                                                      | Datos obtenidos                                            |
| --- | ----------------------- | --------------------------------------------------------------- | ---------------------------------------------------------- |
| 1   | Encuesta inicial        | `/mod/feedback/show_entries.php?id=[CMID_INICIAL]&page=N`       | Respuestas estáticas por alumno (nombre, foto, respuestas) |
| 2   | Encuesta cuatrimestral  | `/mod/feedback/show_entries.php?id=[CMID_CUATRIMESTRAL]&page=N` | Respuestas dinámicas + fecha de última entrega             |
| 3   | DB Solicitudes de ayuda | `/mod/data/view.php?id=[CMID_DB_SOLICITUDES]&page=N`            | Solicitudes pendientes y atendidas                         |
| 4   | DB Log de asistencias   | `/mod/data/view.php?id=[CMID_DB_LOGS]&page=N`                   | Historial de asistencias por tutor                         |
| 5   | DB Config               | `/mod/data/view.php?id=[CMID_DB_CONFIG]&page=0`                 | Parámetros del sistema                                     |
| 6   | DB Histórico            | `/mod/data/view.php?id=[CMID_DB_HISTORICO]&page=N`              | Snapshots cuatrimestrales de todos los alumnos             |
| 7   | DB Histórico 1er Año    | `/mod/data/view.php?id=[CMID_DB_HIST_1ER_ANIO]&page=N`          | Snapshots del alargamiento por cuatrimestre                |
| 8   | DB 1er Año              | `/mod/data/view.php?id=[CMID_DB_1ER_ANIO]&page=N`               | Estado actual de materias y alargamiento                   |

### 3.2 Escritura (POST simulando acciones del usuario)

| Acción                                     | URL                                              |
| ------------------------------------------ | ------------------------------------------------ |
| Tutor agrega entrada al log de asistencias | `/mod/data/edit.php?d=[DATAID_DB_LOGS]`          |
| Tutor aprueba solicitud de alumno          | `/mod/data/view.php` + parámetros a descubrir    |
| Alumno envía solicitud de ayuda            | `/mod/data/edit.php?d=[DATAID_DB_SOLICITUDES]`   |
| Guardar snapshot histórico                 | `/mod/data/edit.php?d=[DATAID_DB_HISTORICO]`     |
| Guardar snapshot histórico 1er año         | `/mod/data/edit.php?d=[DATAID_DB_HIST_1ER_ANIO]` |
| Guardar/actualizar alumno en DB 1er Año    | `/mod/data/edit.php?d=[DATAID_DB_1ER_ANIO]`      |
| Guardar config                             | `/mod/data/edit.php?d=[DATAID_DB_CONFIG]`        |

### 3.3 CSRF — Sesskey

```javascript
const sesskey = M.cfg.sesskey;
```

Disponible en cualquier página Moodle. No requiere fetch adicional.

### 3.4 Solicitudes de alumnos — política de aprobación

**Nunca aprobar las entradas** de alumnos en la DB de solicitudes. El sistema itera siempre sobre las solicitudes en estado pendiente. Si se aprobara una entrada, quedaría visible para otros alumnos dado el modo de privacidad configurado. La aprobación desde el código solo ocurre programáticamente cuando el tutor marca una solicitud como atendida, y sirve para archivarla, no para hacerla visible.

---

## 4. Bases de Datos Moodle

### 4.1 DB Solicitudes de ayuda

**Configuración Moodle:**

- Requiere aprobación antes de que la entrada sea visible para terceros.
- Cada alumno solo ve sus propias entradas.
- Tutores ven todas, incluyendo pendientes.

**Campos:**

| Campo         | Tipo en Moodle | Obligatorio | Descripción                 |
| ------------- | -------------- | ----------- | --------------------------- |
| `descripcion` | Área de texto  | No          | Mensaje opcional del alumno |

Moodle provee automáticamente: ID de entrada, nombre completo, foto, fecha de envío, estado de aprobación.

### 4.2 DB Log de asistencias

**Configuración Moodle:**

- Sin requerimiento de aprobación.
- Solo accesible para tutores y profesores.

**Campos:**

| Campo           | Tipo en Moodle   | Obligatorio | Descripción                                         |
| --------------- | ---------------- | ----------- | --------------------------------------------------- |
| `nombre_alumno` | Texto corto      | Sí          | Nombre completo del alumno asistido                 |
| `id_alumno`     | Texto corto      | Sí          | ID Moodle del alumno (para cruzar datos)            |
| `nombre_tutor`  | Texto corto      | Sí          | Nombre del tutor (evita fetch adicional al parsear) |
| `origen`        | Menú desplegable | Sí          | `Proactivo` / `Solicitud`                           |
| `mensaje`       | Área de texto    | No          | Mensaje enviado al alumno al asistirlo              |

Moodle provee automáticamente: fecha de la entrada, ID de entrada, autor.

> **¿De dónde sale `id_alumno`?** El scraping del Feedback extrae el ID numérico desde el link de perfil incluido en cada entrada: `/user/view.php?id=123&course=456` → el `123` es el `id_alumno`.

### 4.3 DB Histórico

**Configuración Moodle:**

- Solo accesible para tutores y profesores.
- Sin aprobación requerida.

**Campos:**

| Campo               | Tipo en Moodle | Descripción                                                       |
| ------------------- | -------------- | ----------------------------------------------------------------- |
| `id_alumno`         | Texto corto    | ID Moodle del alumno                                              |
| `nombre_alumno`     | Texto corto    | Nombre completo                                                   |
| `fecha_snapshot`    | Texto corto    | Fecha en formato `YYYY-MM-DD` de cuando se guardó el snapshot     |
| `cuatrimestre`      | Texto corto    | Ej: `2025-1` o `2025-2`                                           |
| `ird`               | Número         | IRD calculado en ese momento                                      |
| `se_percibe_riesgo` | Menú/texto     | `si` / `no` / `sin_dato`                                          |
| `respuestas_json`   | Área de texto  | JSON con todas las respuestas de ambas encuestas en ese momento   |
| `materias_json`     | Área de texto  | JSON con materias y notas reportadas en la encuesta cuatrimestral |
| `anio_ingreso`      | Texto corto    | Año de ingreso a la carrera (para separar cohortes)               |

### 4.4 DB 1er Año (estado actual)

**Configuración Moodle:**

- Solo accesible para tutores y profesores.

**Campos:**

| Campo          | Tipo en Moodle | Descripción                                            |
| -------------- | -------------- | ------------------------------------------------------ |
| `id_alumno`    | Texto corto    | Identificador arbitrario del alumno (recomendado: DNI) |
| `materias`     | Área de texto  | `"Física 1:8,Matemática 2:4"` — pares materia:nota     |
| `aprobadas`    | Número         | Contador de materias con nota >= 6                     |
| `alargamiento` | Número         | Indicador calculado al momento de cargar el CSV        |

> **Sobre `id_alumno`:** es un identificador arbitrario definido por el profesor al subir el CSV. En la práctica se recomienda el DNI por ser único y estable, pero el sistema no impone ninguna restricción al respecto. No se usa scraping de Moodle para alumnos de 1er año.

### 4.5 DB Histórico 1er Año

**Configuración Moodle:**

- Solo accesible para tutores y profesores.

**Campos:**

| Campo            | Tipo en Moodle | Descripción                            |
| ---------------- | -------------- | -------------------------------------- |
| `id_alumno`      | Texto corto    | Identificador del alumno               |
| `fecha_snapshot` | Texto corto    | Fecha `YYYY-MM-DD` de la carga del CSV |
| `cuatrimestre`   | Texto corto    | Ej: `2026-1`                           |
| `aprobadas`      | Número         | Materias aprobadas en ese momento      |
| `alargamiento`   | Número         | Indicador calculado en ese momento     |

Se escribe un registro por alumno cada vez que el tutor ejecuta "Guardar histórico 1er año".

### 4.6 DB Config

**Configuración Moodle:**

- Solo accesible para tutores y profesores.
- Una única entrada (la primera). Si no existe, se usan los valores por defecto del código.

**Campos:**

| Campo                     | Tipo en Moodle | Default | Descripción                                                              |
| ------------------------- | -------------- | ------- | ------------------------------------------------------------------------ |
| `threshold_ird`           | Número         | 40      | IRD mínimo para mostrar botón "Asistir"                                  |
| `cooldown_actualizar_seg` | Número         | 30      | Segundos de espera entre clicks en "Actualizar"                          |
| `quarterly_warning_days`  | Número         | 90      | Días sin encuesta cuatrimestral antes de mostrar advertencia             |
| `cuatrimestres_desercion` | Número         | 2       | Cuatrimestres sin completar encuesta para considerar al alumno desertor  |
| `beta_values_json`        | Área de texto  | —       | JSON con overrides de β por pregunta (si está vacío, usa los del código) |

> **Carga de config:** se realiza al abrir cualquier panel, antes del `Promise.all` principal. Agrega aproximadamente 300ms al tiempo de carga inicial. Si la DB Config está vacía o el fetch falla, el sistema usa los valores hardcodeados como fallback sin interrumpir la carga.

---

## 5. Cálculo del Índice de Riesgo de Deserción (IRD)

### 5.1 Fórmula

**Paso 1 — Puntaje bruto:**

```
Z = Σ (βᵢ × xᵢ)
```

**Paso 2 — Truncar a cero si Z < 0** (posible porque hay respuestas con valores negativos):

```
Z = max(Z, 0)
```

**Paso 3 — Normalización a escala 0–100:**

```
IRD = (Z / Z_max) × 100
```

Donde `Z_max` es el puntaje máximo teórico posible, calculado dinámicamente:

```
Z_max = Σ (βᵢ × valor_máximo_i)
```

`Z_max` se recalcula en cada apertura porque las encuestas pueden cambiar.

### 5.2 Escala de pesos β

| Importancia | β   |
| ----------- | --- |
| Muy baja    | 0.5 |
| Baja        | 1.0 |
| Media       | 1.5 |
| Alta        | 2.0 |
| Muy alta    | 2.5 |

### 5.3 Ejemplo de preguntas con sus pesos

```javascript
// Disponibilidad horaria para estudiar (β=2.5)
// Escala 1–5
// 1 → X=0.9 | 2 → X=0.7 | 3 → X=0.0 | 4 → X=-0.2 | 5 → X=-0.5

// Tiempo de viaje a la facultad (β=1)
// Menos de 20 min → X=0 | 20–40 min → X=0.08 | 41–60 min → X=0.156 | Más de 60 min → X=0.25

// Medio de transporte (β=0) — no contribuye al IRD pero se almacena

// Financiamiento de estudios (β=1.8)
// Beca → X=-1 | Financiamiento familiar → X=0 | Financiamiento propio → X=0.5 | Otros → X=?
```

### 5.4 Colores y umbral del IRD

| Rango IRD | Color       | Descripción            | Botón "Asistir" en Panel 1    |
| --------- | ----------- | ---------------------- | ----------------------------- |
| 80 – 100  | 🔴 Rojo     | Intervención inmediata | Visible (si cumple condición) |
| 40 – 79   | 🟡 Amarillo | Seguimiento y tutoría  | Visible (si cumple condición) |
| 0 – 39    | 🟢 Verde    | Sin riesgo             | No visible                    |
| Sin datos | —           | Encuestas incompletas  | No visible                    |

**Umbral configurable:** `THRESHOLD_IRD = 40`.

### 5.5 Indicador de Peso por Pregunta ("indicador de indicadores")

Durante el cálculo del IRD de todos los alumnos, se acumula en paralelo un array con el peso total aportado por cada pregunta al riesgo global del grupo:

```
pesoPregunta[i] = Σ (βᵢ × xᵢ) para todos los alumnos con dato en pregunta i
```

El array se ordena de mayor a menor al finalizar el cálculo. Se muestra en una vista separada del dashboard indicando qué pregunta tiene más peso en el riesgo global del grupo. No usa datos del histórico — se calcula sobre los datos actuales en cada carga.

### 5.6 Pseudocódigo del cálculo

```
// ── CONSTANTES (con fallback a DB Config) ──
THRESHOLD_IRD            = 40
QUARTERLY_WARNING_DAYS   = 90
CUATRIMESTRES_DESERCION  = 2
ACTUALIZAR_COOLDOWN_SEG  = 30
RESULTS_PER_PAGE_MOODLE  = [verificar]
PAGE_SIZE_PANELS         = 30

// ── PREGUNTAS CON ROL ESPECIAL — hardcodeadas ──
// Completar con el id HTML real de cada pregunta al inspeccionar el Feedback
ID_PREGUNTA_PERCEPCION_RIESGO = "id_html_de_esa_pregunta"  // ¿Te percibís en riesgo?
ID_PREGUNTA_EGRESO            = "id_html_de_esa_pregunta"  // ¿Estás egresado?
ID_PREGUNTA_ANIO_INGRESO      = "id_html_de_esa_pregunta"  // ¿En qué año ingresaste?
// Estas preguntas están también en INITIAL_QUESTIONS / QUARTERLY_QUESTIONS como cualquier otra.
// Se usan estas constantes solo donde la lógica necesita leer su valor específicamente.

// ── DEFINICIÓN DE PREGUNTAS ──
// Para agregar una pregunta: añadir una entrada al array.
// No se requiere ningún otro cambio en el código.

const INITIAL_QUESTIONS = [
  {
    id:        "id_html_pregunta_1",
    texto:     "Nivel educativo de los padres",
    beta:      0.7,
    maxValue:  4,
    respuestas: {
      "Universitario completo":   0,
      "Universitario incompleto": 1,
      "Secundario completo":      2,
      "Secundario incompleto":    3,
      "Sin estudios":             4
    }
  },
  // ...
]

const QUARTERLY_QUESTIONS = [
  {
    id:        "id_html_pregunta_n",
    texto:     "Nivel de estrés académico actual",
    beta:      1.4,
    maxValue:  4,
    respuestas: {
      "Muy bajo": 0, "Bajo": 1, "Medio": 2, "Alto": 3, "Muy alto": 4
    }
  },
  // ...
]

// ── CÁLCULO DE Z_MAX ──
function calcularZmax():
    total = 0
    para cada pregunta en [...INITIAL_QUESTIONS, ...QUARTERLY_QUESTIONS]:
        total += pregunta.beta * pregunta.maxValue
    retornar total

// ── FETCH PAGINADO ──
async function fetchTodasLasPaginas(urlBase):
    primera = await fetch(urlBase + "&page=0")
    total   = detectarTotalPaginas(primera)
    si total == 1: retornar [primera]
    resto = await Promise.all([page=1..N].map(n => fetch(urlBase + "&page=" + n)))
    retornar [primera, ...resto]

// ── CARGA PRINCIPAL ──
async function cargarTodosLosDatos():
    config = await cargarConfig()   // ~300ms adicionales

    [paginasInicial, paginasCuat, paginasSolicitudes, paginasLogs] =
        await Promise.all([
            fetchTodasLasPaginas(URL_ENCUESTA_INICIAL),
            fetchTodasLasPaginas(URL_ENCUESTA_CUATRIMESTRAL),
            fetchTodasLasPaginas(URL_DB_SOLICITUDES),
            fetchTodasLasPaginas(URL_DB_LOGS)
        ])

    datosIniciales = parsearFeedback(paginasInicial)
    datosCuat      = parsearFeedback(paginasCuat)
    solicitudes    = parsearSolicitudes(paginasSolicitudes)
    logs           = parsearLogs(paginasLogs)

    Z_max     = calcularZmax()
    alumnos   = []
    pesosPregunta = {}   // { id_pregunta: acumulado }

    para cada id_alumno en datosIniciales:
        alumno = {
            id:               id_alumno,
            nombre:           datosIniciales[id_alumno].nombre,
            foto:             datosIniciales[id_alumno].foto,
            respInic:         datosIniciales[id_alumno].respuestas,
            respCuat:         datosCuat[id_alumno]?.respuestas ?? null,
            fechaCuat:        datosCuat[id_alumno]?.fechaEntrega ?? null,
            sePercibeRiesgo:  datosCuat[id_alumno]?.sePercibeRiesgo ?? null,
            anioIngreso:      datosIniciales[id_alumno].anioIngreso ?? null,
            tienePendiente:   solicitudes[id_alumno]?.pendiente ?? false,
            fechaSolicitud:   solicitudes[id_alumno]?.fechaSolicitud ?? null,
            entryIdSolicitud: solicitudes[id_alumno]?.entryId ?? null,
            ultimaAsistencia: logs[id_alumno]?.ultimaFecha ?? null,
            ultimoTutor:      logs[id_alumno]?.ultimoTutor ?? null,
            IRD:              null
        }

        si alumno.respInic != null Y alumno.respCuat != null:
            Z = 0
            para cada pregunta en INITIAL_QUESTIONS:
                valor = alumno.respInic[pregunta.id] ?? 0
                aporte = pregunta.beta * valor
                Z += aporte
                // El acumulador de pesos NO se trunca: acumula el valor crudo (puede ser negativo)
                // para reflejar el peso real de cada pregunta en el riesgo global del grupo
                pesosPregunta[pregunta.id] = (pesosPregunta[pregunta.id] ?? 0) + aporte
            para cada pregunta en QUARTERLY_QUESTIONS:
                valor = alumno.respCuat[pregunta.id] ?? 0
                aporte = pregunta.beta * valor
                Z += aporte
                pesosPregunta[pregunta.id] = (pesosPregunta[pregunta.id] ?? 0) + aporte
            Z = max(Z, 0)   // truncar a cero SOLO para el IRD individual, nunca antes de acumular
            alumno.IRD = redondear((Z / Z_max) * 100, 1)

        alumnos.push(alumno)

    // Ordenar: primero "se percibe en riesgo", luego resto
    // Dentro de cada grupo: IRD descendente, nulls al final
    enRiesgo  = alumnos.filter(a => a.sePercibeRiesgo == true)
    sinRiesgo = alumnos.filter(a => a.sePercibeRiesgo != true)
    ordenarPorIRD(enRiesgo)
    ordenarPorIRD(sinRiesgo)
    alumnos = [...enRiesgo, ...sinRiesgo]

    pesosPreguntaOrdenados = ordenarPorValorDesc(pesosPregunta)

    retornar { alumnos, pesosPreguntaOrdenados }

// ── HELPERS ──
function colorIRD(ird):
    si ird >= 80: retornar "rojo"
    si ird >= 40: retornar "amarillo"
    retornar "verde"

function mostrarBotonAsistir(alumno):
    si alumno.IRD == null:                                    retornar false
    si alumno.IRD < THRESHOLD_IRD:                           retornar false
    si alumno.ultimaAsistencia == null:                      retornar true
    si alumno.fechaSolicitud > alumno.ultimaAsistencia:      retornar true
    retornar false

function mostrarAdvertenciaEncuesta(alumno):
    si alumno.fechaCuat == null:                             retornar true
    si diasDesde(alumno.fechaCuat) > QUARTERLY_WARNING_DAYS: retornar true
    retornar false

function esDesertor(alumno):
    // Un cuatrimestre = 6 meses = 180 días
    DIAS_POR_CUATRIMESTRE = 180
    si alumno.fechaCuat == null:                                                       retornar false  // nunca respondió → no se considera desertor
    si diasDesde(alumno.fechaCuat) >= CUATRIMESTRES_DESERCION * DIAS_POR_CUATRIMESTRE: retornar true
    retornar false
```

---

## 6. Indicadores Adicionales

### 6.1 Ralentización / Demora individual

Mide cuánto se aleja un alumno de la trayectoria ideal según el plan de estudios.

```
Ralentización = (1 - (materias_aprobadas / materias_esperadas_segun_plan)) × 100%
```

Ejemplo: alumno que rindió 1er año, plan esperaba 7 aprobadas, tiene 5: `(1 - 5/7) × 100% = 28.58%`

- `materias_aprobadas` viene de la encuesta cuatrimestral (materias reportadas con nota >= 6).
- `materias_esperadas_segun_plan` viene del **plan de estudios hardcodeado** en el código, indexado por año de ingreso a la carrera.
- Solo aplica a alumnos de 2do año o superior (los de 1er año tienen su propio indicador).
- No considera materias aprobadas de carreras anteriores del alumno.

```javascript
const PLAN_DE_ESTUDIOS = {
  // materias que debería tener aprobadas al finalizar cada año
  anio1: 7,
  anio2: 14,
  anio3: 21,
  // completar según plan real
};
```

Se muestra como columna adicional en el Panel 1:

```
┌──────┬───────────┬───────────┬──────────┬───────────────┬──────────────────┬──────────────────┬──────┐
│ Foto │  Nombre   │ Apellido  │  IRD ↕   │ Ralentiz. ↕   │ Últ. Asistencia↕ │ Últ. Solicitud ↕ │Acción│
├──────┼───────────┼───────────┼──────────┼───────────────┼──────────────────┼──────────────────┼──────┤
│ [👤] │ Juan      │ García    │ [85] 🔴  │  28.6%        │ Prof.Ruiz 01/06  │ 03/06 10:20      │[Asist]│
│ [👤] │ María     │ López     │ [72] 🟡  │  —            │ —                │ —                │[Asist]│
```

> `—` cuando el alumno no completó la encuesta cuatrimestral o no tiene año de ingreso registrado.

### 6.2 Indicadores por cohorte

Se calculan sobre los datos actuales. No requieren histórico para mostrarse, pero el histórico permite ver su evolución en el tiempo.

**Fuentes de datos:**

- **Año de ingreso:** pregunta específica de la encuesta inicial. Determina la cohorte.
- **Desertado:** alumno cuya última entrega de la encuesta cuatrimestral fue hace `CUATRIMESTRES_DESERCION` o más cuatrimestres (default: 2). Se calcula comparando `fechaCuat` con la fecha actual: si transcurrieron al menos `CUATRIMESTRES_DESERCION × 6 meses`, se lo considera desertor. Los alumnos que nunca completaron la encuesta cuatrimestral **no** se consideran desertores (pueden ser alumnos nuevos que aún no tuvieron oportunidad de responder).
- **Egresado:** alumno que respondió `Sí` a la pregunta de egreso en la encuesta cuatrimestral.
- **Activo:** ninguna de las anteriores condiciones.

| Indicador           | Fórmula                                         |
| ------------------- | ----------------------------------------------- |
| Deserción total     | (desertores / ingresantes de la cohorte) × 100% |
| Alumnos activos     | (activos / ingresantes de la cohorte) × 100%    |
| Eficiencia terminal | (egresados / ingresantes de la cohorte) × 100%  |

> Los tres suman 100% de la cohorte.

Ejemplo hipotético: cohorte 2022 (200 ingresantes) → Egresados: 14%, Activos: 51%, Desertados: 35%.

**Vista propuesta** (sección o panel separado en el dashboard):

```
┌──────────────────────────────────────────────────────────────────────┐
│  🎓  Indicadores por Cohorte                                         │
├──────────────┬──────────────┬──────────────┬──────────────┬──────────┤
│  Cohorte     │  Ingresantes │  Activos     │  Egresados   │Desertados│
├──────────────┼──────────────┼──────────────┼──────────────┼──────────┤
│  2022        │  200         │  101 (51%)   │  29 (14%)    │  70 (35%)│
│  2023        │  185         │  140 (76%)   │  5 (3%)      │  40 (22%)│
│  2024        │  210         │  195 (93%)   │  0 (0%)      │  15 (7%) │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────┘
```

### 6.3 Indicador de Peso por Pregunta ("indicador de indicadores")

Durante el cálculo del IRD de todos los alumnos, se acumula en paralelo el peso total aportado por cada pregunta al riesgo global del grupo (ver pseudocódigo en sección 5.6). El resultado es un array ordenado de mayor a menor que se muestra en una sección del dashboard.

**Vista propuesta:**

```
┌────────────────────────────────────────────────────────────────┐
│  📈  Peso de cada pregunta en el riesgo global                 │
├─────────────────────────────────────────────────────┬──────────┤
│  Pregunta                                           │  Peso ↓  │
├─────────────────────────────────────────────────────┼──────────┤
│  Disponibilidad horaria para estudiar               │  142.5   │
│  Financiamiento de estudios                         │  98.2    │
│  Nivel de estrés académico actual                   │  87.4    │
│  ...                                                │  ...     │
└─────────────────────────────────────────────────────┴──────────┘
```

- No usa datos del histórico: se calcula sobre los datos actuales en cada carga.
- Los valores pueden ser negativos (preguntas que en promedio reducen el riesgo del grupo).
- El cálculo ya ocurre en la carga principal; esta sección solo agrega la vista.

---

## 7. Diseño de Paneles — Dashboard Principal

### Cabecera de página

```
╔══════════════════════════════════════════════════════════════════════╗
║  ████████████████████████████████████████████████████████████████  ║
║  █                                                              █  ║
║  █      TABLEROS DE CONTROL                                     █  ║  ← fondo verde, texto blanco
║  █      Sistema de Seguimiento Estudiantil                      █  ║
║  █                                                              █  ║
║  ████████████████████████████████████████████████████████████████  ║
║                                                                     ║
║  Última actualización: 03/06/2025 10:47        [↺ Actualizar datos] ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Panel 1 — Índice de Riesgo de Deserción

**Filtros colapsados (estado inicial):**

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│  📊  Índice de Riesgo de Deserción                                   [▼ Filtros]     │
├──────┬───────────┬───────────┬──────────┬──────────────────┬──────────────────┬──────┤
│ Foto │  Nombre   │ Apellido  │  IRD ↕   │ Últ. Asistencia↕ │ Últ. Solicitud ↕ │Acción│
├──────┼───────────┼───────────┼──────────┼──────────────────┼──────────────────┼──────┤
│ [👤] │ Juan      │ García    │ [85] 🔴  │ Prof.Ruiz 01/06  │ 03/06 10:20      │[Asist]│ ← se percibe en riesgo
│ [👤] │ Ana       │ Rodríguez │ [72] 🟡  │ —                │ 02/06 14:30      │[Asist]│ ← se percibe en riesgo
│ [👤] │ María     │ López     │ [72] 🟡  │ —                │ —                │[Asist]│
│ [👤] │ Pedro     │ Martínez  │ [45] 🟢  │ Prof.Ruiz 28/05  │ —                │      │
│ [👤] │ Carlos    │ Díaz      │ Sin datos│ —                │ —                │      │
├──────┴───────────┴───────────┴──────────┴──────────────────┴──────────────────┴──────┤
│                         ◀  1  [2]  3  ▶   (30 por página)                            │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

> Los alumnos que se perciben en riesgo aparecen primero, con un indicador visual diferenciador (borde lateral, badge, o fondo de fila levemente distinto). Dentro de cada grupo, ordenados por IRD descendente.

**Filtros expandidos:**

```
┌──────────────────────────────────────────────────────────────────────┐
│  📊  Índice de Riesgo de Deserción                       [▲ Filtros] │
├──────────────────────────────────────────────────────────────────────┤
│  IRD mínimo: [ 40 ]     IRD máximo: [ 100 ]                          │
│  Estado:  (•) Todos   ( ) Asistido   ( ) Sin asistir                 │
│  Se percibe en riesgo: (•) Todos  ( ) Sí  ( ) No                    │
│                                              [Aplicar]  [Limpiar]    │
│  Filtros activos: IRD 40–100  ×                                      │
├──────┬───────────┬───────────┬──────────┬────────────┬──────────┬────┤
│ ...  │ ...       │ ...       │ ...      │ ...        │ ...      │... │
```

**Columnas y ordenamiento:**

| Columna           | Ordenable                   |
| ----------------- | --------------------------- |
| Foto              | No                          |
| Nombre            | No                          |
| Apellido          | No                          |
| IRD               | Sí ↕ (default: descendente) |
| Última asistencia | Sí ↕                        |
| Última solicitud  | Sí ↕                        |
| Acción            | No                          |

### Panel 2 — Solicitudes de Ayuda Pendientes

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🆘  Solicitudes de Ayuda Pendientes                          [▼ Filtros]    │
├──────────────────────────────────────────────────────────────────────────────┤
│  Desde: [DD/MM/AAAA]        Hasta: [DD/MM/AAAA]              [Aplicar]       │
├──────┬───────────┬───────────┬──────────────────────┬────────────────────────┤
│ Foto │  Nombre   │ Apellido  │  Fecha solicitud ↕   │         Acción         │
├──────┼───────────┼───────────┼──────────────────────┼────────────────────────┤
│ [👤] │ Juan      │ García    │   03/06  10:20       │  [Marcar como atendido]│
│ [👤] │ Ana       │ Rodríguez │   02/06  08:15       │  [Marcar como atendido]│
├──────┴───────────┴───────────┴──────────────────────┴────────────────────────┤
│                       ◀  1  [2]  ▶   (30 por página)                         │
└───────────────────────────────────────────────────────────────────────────────┘
```

**Estado vacío:**

```
│              ✅  Sin solicitudes pendientes en este momento                   │
```

### Panel del Alumno (actividad separada)

```
┌──────────────────────────────────────────────────────────────┐
│       Portal de Seguimiento — [Nombre del alumno]            │
├──────────────────────────────────────────────────────────────┤
│  ╔══════════════════════════════════════════════════════╗    │
│  ║  ⚠️  Sus datos pueden estar desactualizados.         ║    │  ← solo si aplica
│  ║  Complete la encuesta cuatrimestral.                 ║    │
│  ╚══════════════════════════════════════════════════════╝    │
│                                                              │
│            Su Índice de Riesgo de Deserción                  │
│                     ┌─────────┐                             │
│                     │   72    │ 🟡                          │
│                     └─────────┘                             │
│                                                              │
│  Estado de su última solicitud:                             │
│    ✅  Atendida el 01/06 por Prof. Ruiz                      │
│  — o —                                                       │
│    🕐  Pendiente — enviada el 03/06 10:20                    │
│  — o —                                                       │
│    —   (nunca solicitó asistencia)                           │
│                                                              │
│       [       Solicitar asistencia       ]  ← activo         │
│       [   Ya tenés una solicitud activa  ]  ← deshabilitado  │
└──────────────────────────────────────────────────────────────┘
```

**Reglas:**

- El alumno debe haber completado la encuesta inicial (restricción de Moodle a nivel de actividad).
- Si `diasDesde(fechaCuat) > QUARTERLY_WARNING_DAYS` o nunca entregó, se muestra la advertencia.
- Botón de solicitud deshabilitado si tiene una solicitud pendiente.

---

## 8. Feature 3 — Panel Histórico

### 8.1 Descripción

Actividad Página separada. Permite guardar snapshots cuatrimestrales del estado de todos los alumnos y consultar el historial.

### 8.2 Botón "Guardar Histórico"

Al hacer clic:

1. Se hace scraping en tiempo real de todas las fuentes (igual que el dashboard principal).
2. Se itera sobre todos los alumnos con los datos calculados.
3. Por cada alumno, se crea una entrada en DB Histórico con todos sus datos del momento.
4. Delay forzado de 500ms entre algunas escrituras para no saturar el servidor Moodle.
5. El botón tiene cooldown configurable post-ejecución.
6. Si el proceso se corta a mitad (pérdida de conexión, cierre de pestaña), el histórico queda parcialmente guardado. Esto es aceptable — el proceso dura 2–3 segundos en total y la probabilidad de corte es baja. No se implementa lógica de recuperación.

```
[Guardar Histórico]
        │
        ▼
[Scraping de todas las fuentes — igual que dashboard]
        │
        ▼
[Para cada alumno:]
   POST a DB Histórico con: id_alumno, nombre, fecha_snapshot,
   cuatrimestre, ird, se_percibe_riesgo, respuestas_json,
   materias_json, anio_ingreso
   → esperar 500ms
        │
        ▼
[Mostrar: "Histórico guardado — N alumnos registrados"]
```

### 8.3 Buscador y filtros

```
┌──────────────────────────────────────────────────────────────────────┐
│  📁  Panel Histórico                                                 │
├──────────────────────────────────────────────────────────────────────┤
│  Buscar alumno: [________________________]  [Buscar]                 │
│  Cuatrimestre:  [Todos ▼]   Desde: [__/__/____]  Hasta: [__/__/____] │
│  IRD mínimo:    [___]       IRD máximo: [___]                        │
│                                              [Filtrar]  [Limpiar]    │
├─────────────────┬──────────────┬──────────┬──────────────────────────┤
│  Alumno         │ Cuatrimestre │  IRD ↕   │ Se percibe en riesgo     │
├─────────────────┼──────────────┼──────────┼──────────────────────────┤
│  Juan García    │   2025-1     │ 85 🔴    │ Sí                       │
│  Juan García    │   2024-2     │ 72 🟡    │ No                       │
│  ...            │ ...          │ ...      │ ...                      │
├─────────────────┴──────────────┴──────────┴──────────────────────────┤
│  [Exportar CSV — todos]  [Exportar CSV — filtrado]                   │
└──────────────────────────────────────────────────────────────────────┘
```

### 8.4 Exportación CSV

- **Exportar todos:** todos los registros de DB Histórico en un CSV.
- **Exportar filtrado:** solo los registros que coincidan con el filtro/búsqueda activo.
- **Exportar por alumno:** al seleccionar un alumno en el buscador, opción de exportar solo sus registros.
- **Rango de fechas:** el filtro de fechas afecta qué registros se incluyen en el CSV exportado.
- Implementado sin librerías: `Blob` + `URL.createObjectURL`.

---

## 9. Feature 4 — Panel 1er Año

### 9.1 Descripción

Actividad Página separada para gestionar alumnos de 1er año, cuya información no proviene de encuestas sino de CSVs subidos por el profesor.

Una vez que un alumno pasa a 2do año, comienza a completar encuestas cuatrimestrales y los datos del CSV dejan de usarse para ese alumno.

### 9.2 Formatos de CSV

**CSV A — Alta de alumnos nuevos:**

```
id_alumno,alumno,año,cuatrimestre
12345678,JUAN PEREZ,2026,1
23145890,RODRIGO LA SERNA,2026,1
```

- `id_alumno`: identificador del alumno (recomendado DNI, pero arbitrario).
- `alumno`: nombre completo — **se mantiene en el sistema** para mostrar en el panel.
- `año` y `cuatrimestre`: período de ingreso.
- Si el `id_alumno` ya existe en DB 1er Año, la fila se ignora (no duplica ni sobreescribe).

**CSV B — Carga de notas:**

```
id_alumno,materia,nota
12345678,Física A,10
23145890,Análisis Matemático B,8
```

- Para cada fila, busca el `id_alumno` en DB 1er Año.
- Si no existe: ignora la fila (no se cargan notas de alumnos no dados de alta).
- Si existe: agrega la materia al campo `materias` si no estaba ya, actualiza el contador `aprobadas` y recalcula `alargamiento`.
- El mismo CSV puede subirse múltiples veces sin duplicar datos (deduplicación por nombre de materia).

### 9.3 Cálculo del indicador de alargamiento

```
alargamiento = (1 - (aprobadas / materias_esperadas_1er_anio)) × 100%
```

Donde `materias_esperadas_1er_anio` es una constante del plan de estudios hardcodeada.

Se calcula y se guarda en DB 1er Año al procesar el CSV B. Se muestra dinámicamente en el panel.

### 9.4 Vista del panel

```
┌──────────────────────────────────────────────────────────────────────┐
│  🎓  Panel 1er Año                                                   │
├──────────────────────────────────────────────────────────────────────┤
│  [Subir CSV A — Alta de alumnos]   [Subir CSV B — Carga de notas]   │
│  [Guardar Histórico 1er Año]                                         │
├──────────────────┬──────────────────┬───────────────┬────────────────┤
│  Alumno          │  Materias        │  Aprobadas    │  Alargamiento  │
├──────────────────┼──────────────────┼───────────────┼────────────────┤
│  Juan Perez      │  Física A:10 ... │  3            │  57.1%         │
│  Rodrigo La Serna│  Análisis M.:8   │  1            │  85.7%         │
├──────────────────┴──────────────────┴───────────────┴────────────────┤
│  [Exportar CSV]                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### 9.5 Guardado del Histórico 1er Año

Botón separado "Guardar Histórico 1er Año". Al hacer clic:

1. Lee todos los registros actuales de DB 1er Año.
2. Por cada alumno, crea una entrada en DB Histórico 1er Año con `id_alumno`, `fecha_snapshot`, `cuatrimestre`, `aprobadas`, `alargamiento`.
3. Delay de 500ms entre escrituras.
4. Permite ver la evolución del alargamiento cuatrimestre a cuatrimestre por alumno.

---

## 10. Feature 5 — Configuración

### 10.1 Acceso

La configuración se expone en una pestaña no principal de Moodle (usando el sistema de pestañas nativo), oculta para el usuario casual. Solo tutores y profesores tienen acceso a la actividad.

### 10.2 Qué se puede configurar

| Parámetro                 | Descripción                                                   |
| ------------------------- | ------------------------------------------------------------- |
| `THRESHOLD_IRD`           | IRD mínimo para mostrar el botón "Asistir"                    |
| `COOLDOWN_ACTUALIZAR_SEG` | Segundos de cooldown del botón Actualizar                     |
| `QUARTERLY_WARNING_DAYS`  | Días sin encuesta antes de mostrar advertencia                |
| `CUATRIMESTRES_DESERCION` | Cuatrimestres sin encuesta para considerar al alumno desertor |
| Valores β por pregunta    | Override de los pesos de cada pregunta sin editar el código   |
| Valores X por respuesta   | Override del valor numérico de cada opción de respuesta       |

### 10.3 Lógica de carga

1. Al abrir cualquier panel, se hace un GET a DB Config.
2. Si la DB está vacía o el fetch falla → se usan los valores hardcodeados en el código (fallback silencioso).
3. Si existe una entrada → se sobrescriben los valores con los de la DB.
4. El tiempo de carga adicional es ~300ms.

La configuración no es info sensible. No se ofusca ni se oculta más allá de la pestaña secundaria de Moodle.

---

## 11. Flujos de Acción Completos

### 11.1 Tutor asiste desde Panel 1 (proactivo)

```
Tutor hace clic en "Asistir" para el alumno X
          │
          ├── UI: deshabilitar todos los elementos con data-student-id="X"
          │        en la página (Panel 1 y Panel 2 simultáneamente)
          │
          ├── Abrir modal: textarea para mensaje al alumno (opcional)
          │
          ├── Al confirmar:
          │       ├── POST → DB Logs
          │       │          { nombre_alumno, id_alumno, nombre_tutor,
          │       │            origen: "Proactivo", mensaje: [texto o vacío] }
          │       │
          │       ├── POST → Moodle mensajería interna (si hay mensaje)
          │       │          core_message_send_instant_messages → touserid: id_alumno
          │       │
          │       ├── ¿Alumno X tiene solicitud pendiente?
          │       │       ├── SÍ → POST para aprobar entrada en DB Solicitudes
          │       │       └── NO → continuar
          │       │
          │       └── ¿Todos los POSTs exitosos?
          │               ├── SÍ → botón Panel 1 muestra "Asistido"
          │               │         fila Panel 2 desaparece en próximo Actualizar
          │               └── NO → revertir + mostrar error
```

### 11.2 Tutor asiste desde Panel 2 (por solicitud)

```
Tutor hace clic en "Marcar como atendido" para el alumno X
          │
          ├── UI: deshabilitar todos los elementos con data-student-id="X"
          │
          ├── Abrir modal: textarea para mensaje al alumno (opcional)
          │
          ├── Al confirmar:
          │       ├── POST → DB Logs
          │       │          { nombre_alumno, id_alumno, nombre_tutor,
          │       │            origen: "Solicitud", mensaje: [texto o vacío] }
          │       │
          │       ├── POST → Moodle mensajería interna (si hay mensaje)
          │       │
          │       ├── POST → Aprobar entrada en DB Solicitudes (entryId conocido)
          │       │
          │       └── ¿Todos los POSTs exitosos?
          │               ├── SÍ → botón Panel 2 muestra "Atendido"
          │               └── NO → revertir + mostrar error
```

### 11.3 Alumno solicita asistencia

```
Alumno hace clic en "Solicitar asistencia"
          │
          ├── UI: deshabilitar botón inmediatamente
          │
          ├── POST → DB Solicitudes
          │          { descripcion: "[texto opcional del alumno]" }
          │          Moodle agrega automáticamente: autor, fecha, estado "pendiente"
          │
          └── ¿POST exitoso?
                  ├── SÍ → mostrar "Solicitud enviada — pendiente de atención"
                  └── NO → revertir botón + mostrar error
```

### 11.4 Envío de mensaje interno de Moodle

Endpoint confirmado y funcionando:

```javascript
// POST a:
// /lib/ajax/service.php?sesskey=X&info=core_message_send_instant_messages

[
  {
    index: 0,
    methodname: "core_message_send_instant_messages",
    args: {
      messages: [
        {
          touserid: "ID_DEL_ALUMNO",
          text: "Mensaje aquí",
        },
      ],
    },
  },
];

// Headers: Content-Type: application/json
// Respuesta exitosa: [{"error":false,"data":[{"msgid":XXXX}]}]
```

---

## 12. Restricciones Técnicas de Moodle

| Restricción               | Detalle                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------- |
| Código embebido           | Todo en un único bloque HTML con `<script>` por actividad Página                      |
| Sin event handlers HTML   | Prohibido `onclick`, `onchange`, etc. Todo vía `addEventListener`                     |
| Sesskey obligatorio       | `M.cfg.sesskey` en el body de todo POST. Sin él Moodle rechaza la solicitud           |
| Foto de perfil            | Provista por Moodle en el HTML del Feedback. No requiere fetch adicional              |
| Sin dependencias externas | Cero librerías. JavaScript vanilla únicamente                                         |
| Acceso al dashboard       | Pantalla falsa activada con clic en `accumsan`                                        |
| Exportación sin librerías | CSV via `Blob` + `URL.createObjectURL`. PDF via jsPDF desde CDN de cdnjs (sin CSP)    |
| DB Solicitudes            | Nunca aprobar entradas manualmente. Solo aprobar programáticamente al marcar atendido |

### Iconos: SVG vs Emoji

**Usar SVG** para UI visible y permanente: navbar, botones principales, cards, inputs con icono, estados permanentes.

**Usar Emoji** para feedback temporal: `⏳ Enviando...`, `✅ Guardado`, `❌ Error`, `⚠️ Advertencia`.

**Regla:** UI permanente → SVG / Feedback transitorio → Emoji.

---

## 13. Datos a Relevar Antes de Codear

Seguir este orden estrictamente: primero crear las actividades en Moodle, porque sin ellas no hay IDs ni HTML que inspeccionar.

---

### 13.1 Paso 1 — Crear las actividades en Moodle

Crear en este orden:

0. DB Solicitudes de ayuda
1. DB Log de asistencias
2. DB Config
3. DB Histórico
4. DB 1er Año
5. DB Histórico 1er Año
6. Actividad Página — Dashboard principal
7. Actividad Página — Panel del alumno
8. Actividad Página — Panel Histórico
9. Actividad Página — Panel 1er Año
10. Actividad Pagina — Editar Config del Sistema

---

### 13.2 Paso 2 — Relevar los IDs numéricos de cada actividad

Hay dos tipos de ID por cada Base de Datos Moodle, y uno por cada Feedback. Ver sección **"Cómo obtener CMID y DATAID"** al final del documento para el procedimiento detallado.

| Constante                     | Qué es                                | Cómo obtenerlo                             |
| ----------------------------- | ------------------------------------- | ------------------------------------------ |
| `MOODLE_BASE_URL`             | Dominio del sitio                     | Copiarlo de la barra del navegador         |
| `CMID_ENCUESTA_INICIAL`       | ID del Feedback inicial               | `?id=` en la URL al navegar al Feedback    |
| `CMID_ENCUESTA_CUATRIMESTRAL` | ID del Feedback cuatrimestral         | `?id=` en la URL al navegar al Feedback    |
| `CMID_DB_SOLICITUDES`         | ID de la DB Solicitudes               | `?id=` en la URL al navegar a la actividad |
| `DATAID_DB_SOLICITUDES`       | ID interno de la DB Solicitudes       | `?d=` en la URL al abrir "Agregar entrada" |
| `CMID_DB_LOGS`                | ID de la DB Logs                      | `?id=` en la URL al navegar a la actividad |
| `DATAID_DB_LOGS`              | ID interno de la DB Logs              | `?d=` en la URL al abrir "Agregar entrada" |
| `CMID_DB_CONFIG`              | ID de la DB Config                    | `?id=` en la URL al navegar a la actividad |
| `DATAID_DB_CONFIG`            | ID interno de la DB Config            | `?d=` en la URL al abrir "Agregar entrada" |
| `CMID_DB_HISTORICO`           | ID de la DB Histórico                 | `?id=` en la URL al navegar a la actividad |
| `DATAID_DB_HISTORICO`         | ID interno de la DB Histórico         | `?d=` en la URL al abrir "Agregar entrada" |
| `CMID_DB_1ER_ANIO`            | ID de la DB 1er Año                   | `?id=` en la URL al navegar a la actividad |
| `DATAID_DB_1ER_ANIO`          | ID interno de la DB 1er Año           | `?d=` en la URL al abrir "Agregar entrada" |
| `CMID_DB_HIST_1ER_ANIO`       | ID de la DB Histórico 1er Año         | `?id=` en la URL al navegar a la actividad |
| `DATAID_DB_HIST_1ER_ANIO`     | ID interno de la DB Histórico 1er Año | `?d=` en la URL al abrir "Agregar entrada" |

---

### 13.3 Paso 3 — Relevar el HTML de las encuestas (Feedback)

Este paso es el más importante para que la IA pueda generar el código de scraping. Sin el HTML real, los selectores CSS/DOM no se pueden determinar.

**Qué obtener:**

Para cada una de las dos encuestas (Feedback inicial y cuatrimestral), navegar a:

```
/mod/feedback/show_entries.php?id=[CMID_ENCUESTA]&page=0
```

Asegurarse de que haya al menos una respuesta cargada. Luego:

1. Hacer clic derecho en la página → **"Ver código fuente de la página"** (no Inspeccionar, sino el fuente completo).
2. Copiar todo el HTML.
3. Pegarlo en el contexto que se le pasa a la IA al momento de codear.

**Para qué sirve:** la IA necesita el HTML real para identificar los selectores que envuelven cada respuesta, el nombre del alumno, la foto de perfil, el link al perfil (que contiene el `id_alumno`), la fecha de entrega, y el texto exacto de cada opción de respuesta (que debe coincidir exactamente con las claves del mapeo `respuestas: { "texto": valor }`).

**Qué NO hace falta entregar en este paso:** el HTML de las DBs de Moodle (Solicitudes, Logs, etc.) — el código de referencia funcional ya tiene esos selectores confirmados y funcionando.

---

### 13.4 Paso 4 — Completar la definición de preguntas de las encuestas

Una vez que se tiene el HTML del Feedback, por cada pregunta de ambas encuestas definir:

| Campo           | Descripción                                                                                                                  |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `id`            | Selector HTML que identifica esa pregunta en el HTML del Feedback (se extrae del HTML del paso anterior)                     |
| `textoPregunta` | Texto visible de la pregunta                                                                                                 |
| `beta`          | Peso asignado (ver escala en sección 5.2)                                                                                    |
| `maxValue`      | Valor numérico máximo posible entre las opciones de respuesta                                                                |
| `respuestas`    | Objeto `{ "texto exacto de Moodle": valorNumérico }` — el texto debe coincidir carácter a carácter con lo que muestra Moodle |

Las tres preguntas con rol especial en la lógica deben identificarse también con estas constantes:

```javascript
const ID_PREGUNTA_PERCEPCION_RIESGO = "id_html_de_esa_pregunta"; // ¿Te percibís en riesgo?
const ID_PREGUNTA_EGRESO = "id_html_de_esa_pregunta"; // ¿Estás egresado?
const ID_PREGUNTA_ANIO_INGRESO = "id_html_de_esa_pregunta"; // ¿En qué año ingresaste?
```

---

### 13.5 Paso 5 — Interceptar el endpoint de aprobación de entradas (DevTools)

Este es el único endpoint que todavía no está confirmado. Ver tabla de estado:

| Acción                            | Estado        | Cómo obtenerlo                                                                      |
| --------------------------------- | ------------- | ----------------------------------------------------------------------------------- |
| Aprobar entrada en DB Solicitudes | **Pendiente** | DevTools → Network → aprobar una entrada manualmente en la DB y capturar el request |
| Mensajería interna Moodle         | ✅ Confirmado | `/lib/ajax/service.php` con `core_message_send_instant_messages`                    |
| POST a DB (crear entrada)         | ✅ Confirmado | `/mod/data/edit.php?d=X`                                                            |
| Leer DB (scraping)                | ✅ Confirmado | `/mod/data/view.php?id=X`                                                           |
| Leer Feedback (scraping)          | ✅ Confirmado | `/mod/feedback/show_entries.php?id=X`                                               |

---

### 13.6 Paso 6 — Plan de estudios (Valores Reales)

Datos reales:

```javascript
// Materias acumuladas que el alumno debería tener aprobadas al finalizar cada año
const PLAN_DE_ESTUDIOS = {
  anio1: 7,
  anio2: 18,
  anio3: 30,
  anio4: 41,
  anio5: 51,
};

const MATERIAS_ESPERADAS_1ER_ANIO = 7; // usado en el Panel 1er Año (alargamiento)
const TOTAL_MATERIAS_CARRERA = 51; // igual a anio5, pero explícito para no asumir cuál es el último año
```

**Cómo determinar en qué año está un alumno** (necesario para elegir el denominador correcto en la ralentización):

```javascript
// anioIngreso viene de la pregunta ID_PREGUNTA_ANIO_INGRESO de la encuesta inicial
// Se calcula al momento de renderizar, usando el año lectivo actual

function anioEnCarrera(anioIngreso):
    anioActual = new Date().getFullYear()
    anio = anioActual - anioIngreso + 1
    retornar Math.min(Math.max(anio, 1), 5)  // clamp entre 1 y 5

function materiasEsperadas(anioIngreso):
    anio = anioEnCarrera(anioIngreso)
    claveAnio = "anio" + anio
    retornar PLAN_DE_ESTUDIOS[claveAnio]
```

> La ralentización solo se muestra para alumnos de 2do año en adelante (`anioEnCarrera >= 2`). Para alumnos de 1er año se usa el indicador de alargamiento del Panel 1er Año.

---

### 13.7 Configurables — valores por defecto sugeridos

Datos reales:
(Si falta algo el agente debe notificar)

| Constante                 | Valor sugerido | Descripción                                             |
| ------------------------- | -------------- | ------------------------------------------------------- |
| `THRESHOLD_IRD`           | 40             | IRD mínimo para mostrar botón "Asistir"                 |
| `ACTUALIZAR_COOLDOWN_SEG` | 30             | Segundos entre clicks en "Actualizar"                   |
| `QUARTERLY_WARNING_DAYS`  | 90             | Días sin encuesta cuatrimestral antes de advertencia    |
| `CUATRIMESTRES_DESERCION` | 2              | Cuatrimestres sin encuesta para considerar desertor     |
| `HISTORICO_DELAY_MS`      | 500            | Delay entre escrituras al guardar histórico             |
| `RESULTS_PER_PAGE_MOODLE` | Verificar      | Resultados por página en Feedback (inspeccionar Moodle) |
| `PAGE_SIZE_PANELS`        | 30             | Resultados por página en paneles del dashboard          |

---

### 13.8 A evaluar durante la implementación

- **Carga a demanda con botón:** si el tiempo de carga del panel principal resulta demasiado alto con muchos alumnos, considerar mostrar un botón "Cargar datos" en lugar de carga automática al abrir la página. Implementar solo si es un problema real.

---

### 14 Carga de datos en base de datos Moodle via fetch

#### Funcionamiento general

El script lanza un POST a `edit.php` con los datos del alumno en memoria,
sin leer ni modificar el DOM más allá de lo estrictamente necesario.

#### Qué se lee del DOM (y por qué)

- `sesskey`: token de sesión, cambia por usuario/sesión, no se puede hardcodear
- `d`: ID de la instancia de la base de datos en el curso actual
- `rid`: ID de la entrada a editar (0 para nueva entrada)
- Mapeo `label → field_X`: los IDs numéricos de los campos cambian si la actividad
  se importa a otro curso, por eso se resuelven dinámicamente buscando el texto
  del `div.font-weight-bold` asociado a cada input

#### Qué viene de memoria

Los datos del alumno propiamente dichos: `id_alumno`, `alumno`, `anio_ingreso`, etc.

#### Estabilidad de los labels

Los nombres de los campos (`id_alumno`, `alumno`, `anio_ingreso`, etc.) no cambian,
son definidos por el administrador al crear la actividad y son el punto de anclaje
confiable para el mapeo.

---

# Codigo Referencia Funcional 1: Crear Registro en base de datos

**(Contiene Pantalla falsa que debera implementarse en la pagina de los tableros de control)** **Al hacer click en `accusam` recien es visible el panel con el objetivo de ocultar el contenido a otros grupos.**

```html
<p>
  <script>
    // Quitar margen del <p> que Moodle crea alrededor del script
    if (document.currentScript?.parentElement?.tagName === "P") {
      document.currentScript.parentElement.style.margin = "0";
    }

    // Pequeño Script para ocultar el titulo default de la actividad pagina lo mas rapido posible
    (function () {
      var style = document.createElement("style");
      style.textContent = `
         h2:first-of-type {
           display: none !important;
         }

         .activity-header {
           display: none !important;
         }
        `;
      document.head.appendChild(style);
    })();
  </script>
</p>
<!-- BLOQUE MOODLE: Crear entrada en Base de Datos -->
<div id="pantalla-falsa">
  <p
    style="font-size: 15px; color: #444; line-height: 1.8;"
    data-darkreader-inline-color=""
  >
    <strong>Página de pruebaa Moodle</strong>
  </p>
  <p
    style="font-size: 14px; color: #555; line-height: 1.8;"
    data-darkreader-inline-color=""
  >
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod
    tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
    quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
    consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
    cillum dolore eu fugiat nulla pariatur.
  </p>
  <p
    style="font-size: 14px; color: #555; line-height: 1.8;"
    data-darkreader-inline-color=""
  >
    Pellentesque habitant morbi tristique senectus et netus et malesuada fames
    ac turpis egestas. Vestibulum tortor quam, feugiat vitae, ultricies eget,
    tempor sit amet, ante. Donec eu libero sit amet quam egestas semper. Aenean
    ultricies mi vitae est, et nunc
    <span id="btn-oculto" style="cursor: text;">accumsan</span> vehicula nisi.
    Mauris placerat eleifend leo, quisque sit amet est et sapien ullamcorper
    pharetra.
  </p>
  <p
    style="font-size: 14px; color: #555; line-height: 1.8;"
    data-darkreader-inline-color=""
  >
    Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius,
    turpis molestie dictum semper, quam quam congue erat, vitae sodales nisi
    metus a nunc. Aliquam erat volutpat. Nam dui ligula, fringilla a, euismod
    sodales, sollicitudin vel, wisi.
  </p>
</div>
<div id="tablero" style="display: none; max-width: 400px;">
  <p
    style="font-size: 15px; font-weight: 600; color: #333; margin-bottom: 16px;"
    data-darkreader-inline-color=""
  >
    Nueva entrada
  </p>
  <div style="margin-bottom: 12px;">
    <label
      style="display: block; font-size: 13px; color: #555; margin-bottom: 4px;"
      for="input-materia"
      data-darkreader-inline-color=""
      >Materia</label
    >
    <input
      id="input-materia"
      style="width: 100%; padding: 9px 12px; border: 1px solid #ccc; border-radius: 6px; font-size: 14px; box-sizing: border-box;"
      type="text"
      value="Fisica 1"
      placeholder="Ej: Física 1"
      data-darkreader-inline-border-top=""
      data-darkreader-inline-border-right=""
      data-darkreader-inline-border-bottom=""
      data-darkreader-inline-border-left=""
    />
  </div>
  <div style="margin-bottom: 16px;">
    <label
      style="display: block; font-size: 13px; color: #555; margin-bottom: 4px;"
      for="input-nota"
      data-darkreader-inline-color=""
      >Nota</label
    >
    <input
      id="input-nota"
      style="width: 100%; padding: 9px 12px; border: 1px solid #ccc; border-radius: 6px; font-size: 14px; box-sizing: border-box;"
      max="10"
      min="0"
      type="number"
      value="10"
      placeholder="Ej: 10"
      data-darkreader-inline-border-top=""
      data-darkreader-inline-border-right=""
      data-darkreader-inline-border-bottom=""
      data-darkreader-inline-border-left=""
    />
  </div>
  <button
    id="btn-crear-materia"
    style="padding: 10px 24px; background: #1a73e8; color: #fff; border: none; border-radius: 6px; font-size: 15px; cursor: pointer; font-weight: 500;"
    data-darkreader-inline-bgimage=""
    data-darkreader-inline-bgcolor=""
    data-darkreader-inline-color=""
  >
    Crear entrada
  </button>
  <p id="status-crear" style="margin-top: 10px; font-size: 13px;"></p>
</div>
<p>
  <script>
    (function () {
      document
        .getElementById("btn-oculto")
        .addEventListener("click", function () {
          document.getElementById("pantalla-falsa").style.display = "none";
          document.getElementById("tablero").style.display = "block";
        });

      var BASE_URL = window.location.origin;
      var DATABASE_ID = 54127;
      var FIELD_MATERIA = 14;
      var FIELD_NOTA = 15;

      function getSesskey() {
        if (window.M && M.cfg && M.cfg.sesskey) return M.cfg.sesskey;
        var meta = document.querySelector('meta[name="sesskey"]');
        if (meta) return meta.getAttribute("content");
        var input = document.querySelector('input[name="sesskey"]');
        if (input) return input.value;
        var link = document.querySelector('a[href*="sesskey="]');
        if (link) {
          var match = link.href.match(/sesskey=([a-zA-Z0-9]+)/);
          if (match) return match[1];
        }
        return null;
      }

      document
        .getElementById("btn-crear-materia")
        .addEventListener("click", function () {
          var status = document.getElementById("status-crear");
          var materia = document.getElementById("input-materia").value.trim();
          var nota = document.getElementById("input-nota").value.trim();
          var sesskey = getSesskey();

          if (!materia || !nota) {
            status.style.color = "#c0392b";
            status.textContent = "❌ Completá ambos campos antes de enviar.";
            return;
          }

          if (!sesskey) {
            status.style.color = "#c0392b";
            status.textContent =
              "❌ No se pudo obtener el sesskey. Recargá la página.";
            return;
          }

          status.style.color = "#555";
          status.textContent = "⏳ Enviando...";

          var formData = new FormData();
          formData.append("d", "11");
          formData.append("rid", "0");
          formData.append("sesskey", sesskey);
          formData.append("field_" + FIELD_MATERIA, materia);
          formData.append("field_" + FIELD_NOTA, nota);
          formData.append("saveandview", "Guardar");

          var url = BASE_URL + "/mod/data/edit.php?id=" + DATABASE_ID;

          fetch(url, {
            method: "POST",
            body: formData,
            credentials: "include",
            redirect: "manual",
          })
            .then(function (res) {
              if (
                res.status === 303 ||
                res.status === 200 ||
                res.type === "opaqueredirect"
              ) {
                status.style.color = "#27ae60";
                status.textContent =
                  '✅ Entrada "' +
                  materia +
                  '" con nota ' +
                  nota +
                  " creada correctamente.";
                document.getElementById("input-materia").value = "";
                document.getElementById("input-nota").value = "";
              } else {
                status.style.color = "#c0392b";
                status.textContent =
                  "⚠️ Respuesta inesperada: HTTP " + res.status;
              }
            })
            .catch(function (err) {
              if (err.message && err.message.includes("opaque")) {
                status.style.color = "#27ae60";
                status.textContent = "✅ Entrada enviada (redirect detectado).";
              } else {
                status.style.color = "#c0392b";
                status.textContent = "❌ Error: " + err.message;
              }
            });
        });
    })();
  </script>
</p>
```

---

# Codigo Referencia Funcional 2: Hacer Scraping y Mostrar en Pantalla los resultados

```js
// CONSTANTS — update these IDs if activities are recreated
const MOODLE_BASE_URL = window.location.origin;
const DATABASE_ACTIVITY_ID = 54127; // mod/data activity id (from URL ?id=)
const QUESTIONNAIRE_INITIAL_ID = 0; // TODO: update after Questionnaire is installed
const QUESTIONNAIRE_QUARTERLY_ID = 0; // TODO: update after Questionnaire is installed

// Fetch and parse all entries from the Moodle Database activity
function fetchDatabaseEntries() {
  return fetch(
    `${MOODLE_BASE_URL}/mod/data/view.php?id=${DATABASE_ACTIVITY_ID}`,
  )
    .then((r) => r.text())
    .then((html) => {
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");
      const entries = doc.querySelectorAll(".defaulttemplate-list-body");
      const data = [];

      entries.forEach(function (entry) {
        const rows = entry.querySelectorAll(".row");
        const obj = {};
        rows.forEach(function (row) {
          const label = row.querySelector(".font-weight-bold");
          const value = row.querySelector(".col-8, .col-lg-9");
          if (label && value) {
            obj[label.textContent.trim()] = value.textContent.trim();
          }
        });
        if (Object.keys(obj).length > 0) data.push(obj);
      });

      return data;
    });
}

// Result: [{ materia: "Mate 2", nota: "9" }, ...]
// CONFIRMED WORKING on ingenieria.campus.mdp.edu.ar
```

---

# Ultimas Aclaraciones

1.  Se deben añadir validaciones para todos los inputs y demas, al no haber backend, la validacion del frontend debe ser fuerte.

2.  Todos los comentarios y el codigo se deben escribir en español.

3.  La config se guarda como un solo texto plano en una estructura json para ser leido u trabajado facilmente.
4.  El agente debera generar una estructura json comoda para trabajar y yo mismo añadire la config como una entrada de texto plano a la db de config.
    Esta entrada de texto plano debera tener las configuraciones iniciales para mostrar los indices, asi como el Beta, peso de cada respuesta, cantidad de preguntas, se debera poder añadir preguntas y sus respuestas aqui, de forma no programatica. (Desde la Actividad de Pagina para editar config desde la interfaz).
    Tambien aqui se definen los CMID, DATAID, urls y demas.

**Pero aunque casi todo este definido aqui, debera ir hardcoreado en el codigo el url o DATAID (lo que sea necesario) de la db de config, porque el codigo debe saber adonde leer la config primero que nada, como 1er paso, añadir de forma clara y visible.**

Idem para guardar los datos historicos.
Guardar los datos en formato texto plano facil para el codigo, y no para que sea legible, porque igual el usuario vera los datos en el panel.

---

# Correciones Martin

Correcciones (Martin): Hay algunas respuestas, valores de x o Beta que estaban mal.

Consideremoslo asi y luego de ultima lo cambiamos:

¿Cuántas personas tenés a cargo? (Numérico) (β=2)

Correcion: En realidad esto es una lista desplegable:

Ninguna -> 0

1 -> 0.25

2 -> 0.5

3 -> 0.75

4 o mas -> 1

Luego

¿Abandonó alguna materia? (Si / No) (β = 2)
[SI] (Depende de cuantas abandono el valor de X)

No -> 0

Y luego para cada opcion

1 -> 0.1

2 -> 0.6

3 -> 0. 9

4 o mas -> 1

El campo es numerico pero el codigo mapea los valores

Aclaracion:

Cualquier respuesta que sea "Otros" debe evaluarse como cero, es decir no debe afectar al funcionamiento.
Tambien actualice la preguntas de financiamiento y “por que eligio esta carrera” para que sea opcion multiple y no eleccion multiple.

Queda a decidir si lo vamos a dejar de esta forma, o lo volveremos a cambiar a eleccion multiple, y agregar alguna decision como tomar el valor de X mas alto de entre todas las opciones elegidas, o hallar el X como un promedio de los X seleccionados.
