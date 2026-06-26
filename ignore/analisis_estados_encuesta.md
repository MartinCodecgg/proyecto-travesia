# Análisis de la pestaña "Estados de encuesta"

Este documento contiene el análisis del flujo, comportamiento y consumo de datos de la pestaña **"Estado Encuesta Cuatrimestral"** (denominada en el HTML como `tab-estado-encuestas`) del archivo [tablero_principal_renzo.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/others-scripts/tablero_principal_renzo.html).

---

## 1. Flujo de Trabajo y Funcionamiento

La pestaña permite visualizar qué alumnos completaron la Encuesta Cuatrimestral y quiénes no. El flujo se detalla a continuación:

1. **Interacción del Usuario:** El usuario hace clic en los botones de la interfaz:
   - **"Hicieron la encuesta"** (`btn-encuesta-cuat-si`), el cual ejecuta `cargarListaEstadoEncuestaCuatrimestral(true)`.
   - **"No hicieron la encuesta"** (`btn-encuesta-cuat-no`), el cual ejecuta `cargarListaEstadoEncuestaCuatrimestral(false)`.
2. **Carga y Cache de Datos:** Se invoca la función asíncrona `obtenerDatosEstadoEncuestaCuatrimestral()`.
   - Si los datos ya se descargaron previamente en la sesión actual (es decir, la variable `cacheEstadoEncuestaCuat` no es `null`), se reutilizan inmediatamente sin realizar nuevas peticiones de red.
   - Si es la primera vez que se consulta o la caché está vacía, se realizan dos peticiones `fetch` en paralelo para descargar las respuestas de ambas encuestas en formato CSV desde Moodle.
3. **Procesamiento de Coincidencias (Cruce de Datos):**
   - Se crea un `Set` (`emailsCuat`) con todos los correos electrónicos (en minúsculas) extraídos de la encuesta cuatrimestral (`csvCuat`).
   - Se itera sobre cada registro de la encuesta inicial (`csvInicial`).
   - Para cada alumno de la encuesta inicial, se evalúa si su correo electrónico existe en el `Set` de la encuesta cuatrimestral (`hizoCuat = emailsCuat.has(emailKey)`).
   - Si la condición de haber completado o no coincide con la opción seleccionada por el usuario (`hizoCuat === completaron`), el alumno se añade a la lista de resultados con su nombre, DNI (`id_alumno`) y correo.
4. **Ordenamiento y Renderizado:**
   - La lista resultante se ordena alfabéticamente por el nombre del alumno.
   - Se genera el HTML dinámico de las filas para insertarlas en el cuerpo de la tabla (`estado-encuesta-cuat-tbody`).
   - Se aplica en caliente cualquier filtro de texto que esté escrito en el input de búsqueda (`filter-estado-encuesta-cuat`).

---

## 2. Respuestas a Preguntas Específicas

### ¿Utiliza los datos que ya se encuentran en memoria o hace fetches nuevamente?
- **La primera vez que se consulta** (al hacer clic en cualquiera de los dos botones), la función **hace fetches nuevamente** desde Moodle para descargar los archivos CSV actualizados.
- **En consultas posteriores durante la misma sesión**, la función detecta que la caché en memoria `cacheEstadoEncuestaCuat` ya está poblada y **utiliza los datos que ya se encuentran en memoria** sin hacer nuevas solicitudes a la red.
- **Nota:** Esta pestaña opera de manera independiente al flujo general de carga del tablero (`updateDashboardData()`) y no utiliza el listado global procesado en `alumnosCalculados`.

### ¿Qué fetches realiza?
Realiza únicamente dos solicitudes de red en paralelo:
1. **Encuesta Inicial:** Fetch a la URL de descarga de CSV correspondiente al CMID de la encuesta inicial:
   `[origen]/mod/feedback/show_entries.php?sesskey=[sesskey]&download=csv&id=[cmid_encuesta_inicial]`
2. **Encuesta Cuatrimestral:** Fetch a la URL de descarga de CSV correspondiente al CMID de la encuesta cuatrimestral:
   `[origen]/mod/feedback/show_entries.php?sesskey=[sesskey]&download=csv&id=[cmid_encuesta_cuatrimestral]`

### ¿Hace fetch a la lista de integrantes (participantes) del curso?
- **No, no realiza ningún fetch a la lista de integrantes del curso** (la página de participantes `user/index.php`).
- El universo de alumnos considerados como "alumnos del curso" para esta pestaña está delimitado únicamente por aquellos que respondieron la **Encuesta Inicial** (`csvInicial`). Quien no haya respondido la encuesta inicial no aparecerá en ninguno de los dos listados de esta pestaña.
