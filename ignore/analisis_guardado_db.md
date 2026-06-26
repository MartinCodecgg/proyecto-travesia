# Análisis de Lógica de Guardado en Bases de Datos de Moodle

Este documento detalla la investigación sobre el comportamiento de guardado, edición y eliminación de datos en las bases de datos de Moodle (actividades de tipo Base de Datos) a través de los scripts `editar_config.html`, `tablero_principal.html` y `panel_1er_anio.html`.

---

## 1. `editar_config.html`

**Propósito:** Administrar la configuración del sistema (URLs, CMIDs, DATAIDs, coeficientes de preguntas y umbrales de IRD).

- **Lectura previa:**
  Al cargar el script, se realiza una petición GET a la base de datos de configuración de Moodle (`/mod/data/view.php?d=CONFIG_DB_ID`). Se analiza el HTML buscando la estructura JSON encerrada en llaves `{...}` y se extrae el identificador de registro (`rid`) asociado si ya existe una entrada.
- **Operación de Guardado:**
  Al enviar el formulario, se construye un objeto `FormData` con los datos del sistema serializados en JSON.
- **Estrategia utilizada:** **Edición (Update) o Creación (Insert)**
  - **Si ya existe una entrada (`rid` válido):** Se añade la variable `rid` al `FormData`. Esto le indica a Moodle que edite el registro existente.
  - **Si no existe (`rid` nulo o 0):** Se envía `rid = 0` (o se omite), lo que le indica a Moodle que cree un registro nuevo.
  - _No se realizan eliminaciones ni duplicaciones redundantes._

---

## 2. `tablero_principal.html`

**Propósito:** Visualizar a los estudiantes, calcular riesgos, registrar asistencias y sincronizar históricos.

- **Registro de Asistencias (logs):**
  - **Estrategia utilizada:** **Solo Creación (Insert)**
  - Cada vez que el tutor asiste a un estudiante, se envía un `POST` a `/mod/data/edit.php?d=db_logs` con `rid = 0`. Esto **agrega una nueva entrada** al registro de logs de asistencia de forma incremental.
- **Borrado de Solicitudes Atendidas:**
  - **Estrategia utilizada:** **Eliminación Directa (Delete)**
  - Si la asistencia proviene de una solicitud activa del alumno, se envía un `POST` de confirmación a `/mod/data/view.php` con el parámetro `delete=solicitudRid` y `confirm=1`. Esto **elimina definitivamente** la solicitud de la base de datos de Moodle.
- **Historial Cuatrimestral Académico (`guardarHistorico`):**
  - **Estrategia utilizada:** **Upsert (Edición/Creación)**
  - Se buscan los registros históricos por el correo del alumno. Si se encuentra una entrada, se recupera su `rid`.
  - Se lee el JSON histórico del alumno (un array de periodos). Se actualiza el objeto correspondiente al cuatrimestre en curso en memoria.
  - Se realiza un `POST` a `/mod/data/edit.php?d=db_historico` enviando el `rid` (si existía) para **editar** la entrada preexistente con el JSON actualizado, o `rid = 0` para **crear** un nuevo registro para el alumno.
- **Historial General del Periodo (`guardarHistoricoGeneral`):**
  - **Estrategia utilizada:** **Upsert (Edición/Creación)**
  - Se escanea `db_historico_general` buscando si el periodo actual (ej. `2026-1`) ya cuenta con una entrada general. Si se localiza, se extrae el `rid` del enlace de edición/borrado.
  - Se envía el consolidado de estadísticas mediante `POST` a `edit.php` pasando dicho `rid` para **sobreescribir** la información del periodo actual, o de lo contrario, se **crea** una nueva entrada general.

---

## 3. `panel_1er_anio.html`

**Propósito:** Supervisar el desempeño y ralentización de los alumnos de primer año.

- **Importación de Alumnos (CSV A - Altas):**
  - **Estrategia utilizada:** **Solo Creación (Insert con filtro de DNI en frontend)**
  - El frontend compara los alumnos del CSV contra los ya cargados en memoria.
  - Para cada alumno nuevo que no se encuentre en Moodle, se realiza un `POST` a `/mod/data/edit.php` con `rid = 0` para **insertar el nuevo estudiante**.
- **Importación de Notas/Materias (CSV B - Notas):**
  - **Estrategia utilizada:** **Actualización/Edición (Update)**
  - El script asocia las notas del CSV al alumno mediante su DNI. Se obtiene el `rid` obligatorio del registro del alumno en Moodle.
  - Se combina el array de materias previo con los nuevos datos, se calculan las materias aprobadas/alargamiento, y se realiza un `POST` enviando el `rid` del alumno. Moodle **edita/actualiza** los campos calculados y la lista de materias en el registro del estudiante.
- **Guardado de Snapshots Históricos (Sincronización):**
  - **Estrategia utilizada:** **Upsert (Edición/Creación)**
  - Se consultan las entradas de `db_historico_1er_anio` y se crea un mapa `"DNI|cuatrimestre" -> rid`.
  - Para cada alumno del panel:
    - Si ya existe un snapshot de dicho alumno para el cuatrimestre actual, se envía un `POST` con el `rid` asociado para **actualizar/sobreescribir** el snapshot existente.
    - Si no existía un snapshot para ese cuatrimestre, se realiza un `POST` con `rid = 0` para **insertar** una nueva entrada.

---

## Conclusiones sobre la Estrategia de Moodle

La interacción con bases de datos en Moodle mediante scraping y llamadas POST a `edit.php` es sumamente eficiente en términos de evitar duplicados gracias al uso del Record ID (`rid`):

1. **No se requiere Borrar + Agregar** para configuraciones o históricos acumulados. Pasar el `rid` en la petición `POST` de edición es interpretado nativamente por Moodle como un `UPDATE`, modificando únicamente los campos enviados y preservando el registro.
2. La **Eliminación Directa** (`delete=rid`) es reservada estrictamente para limpiar la base de datos de solicitudes cuando éstas ya han sido atendidas, previniendo la acumulación de datos obsoletos.
3. El uso del **Upsert (Edición si existe / Inserción si no)** permite sincronizaciones continuas libres de fallos de concurrencia o duplicados, garantizando la consistencia de los datos en Moodle.

# En algun lugar se esta resolviendo el bug.

_Hay algun caso que resulte ineficiente? y que se pueda mejorar?, seme sincero. Hay algun caso de que se haga especificamente: Obtencion de datos de un json, agregado de datos a ese json y luego update del json en la db ?_!

Sí, absolutamente. De hecho, **hay dos casos muy claros en el código actual** donde se realiza exactamente ese patrón y que presentan una ineficiencia severa de rendimiento debido a las limitaciones de Moodle.

---

### 1. Casos específicos donde se realiza el patrón (Get JSON → Modify → Save JSON)

Este patrón exacto ocurre en:

1. **`tablero_principal.html` (`guardarHistorico`)**:
   - **Obtención:** Recupera de Moodle la entrada histórica del alumno y extrae la cadena JSON de su trayectoria (`entradaExistente.historialText`).
   - **Modificación:** Parsea el JSON a un array de JavaScript, añade o actualiza el registro del periodo actual (`2026-1`), y lo vuelve a convertir en string (`JSON.stringify`).
   - **Actualización:** Realiza un `POST` a `edit.php` con el string JSON final.
2. **`panel_1er_anio.html` (Importación CSV B - Notas)**:
   - **Obtención:** Lee el campo de materias en formato JSON del estudiante (`materias_json`).
   - **Modificación:** Parsea el JSON, fusiona las notas del CSV nuevo (sobrescribiendo o añadiendo materias), y vuelve a serializar el array.
   - **Actualización:** Envía el JSON modificado mediante un `POST` para actualizar la ficha del alumno.

---

### 2. ¿Por qué es ineficiente y qué problemas causa?

#### A. Ineficiencia Crítica de Red: Peticiones Secuenciales Bloqueantes

El mayor cuello de botella del sistema es la **red**. Como Moodle no tiene un endpoint nativo para procesar datos en lote (_batch_ o _bulk update_), los scripts están obligados a emular envíos de formularios HTTP individuales.
Tanto en `tablero_principal.html` como en `panel_1er_anio.html`, el código recorre la lista de alumnos en un bucle `for` y realiza **una petición HTTP secuencial por cada alumno**, esperando que termine la anterior y aplicando un retardo artificial (`historico_delay_ms` de ~300ms a 500ms) para no saturar el servidor.

- **Impacto:** Si tienes 100 alumnos, el script realiza **100 peticiones POST secuenciales**. Con el delay y el tiempo de respuesta del servidor de Moodle, guardar el histórico o importar notas puede tardar fácilmente **entre 1 y 2 minutos**, bloqueando la interfaz del usuario.

#### B. Crecimiento Ilimitado del JSON en Campos de Texto

El JSON de historial acumula periodos a lo largo del tiempo. A medida que un alumno avanza en la carrera, el tamaño de ese JSON irá creciendo.

- **Impacto:** Aunque para un alumno individual la diferencia de bytes es insignificante, para sistemas con bases de datos grandes y conexiones lentas, descargar y volver a subir strings JSON cada vez más largos en un bucle de red secuencial añade latencia y riesgo de fallos de timeout intermedios.

---

### 3. ¿Cómo se puede mejorar?

Aunque no podemos cambiar la arquitectura de Moodle (que obliga a usar `edit.php`), sí podemos optimizar radicalmente la lógica del frontend:

1. **Concurrencia Controlada (Parallel batching)**:
   En lugar de procesar los alumnos de uno en uno con `await` secuenciales, se pueden enviar peticiones en lotes concurrentes (por ejemplo, de 5 en 5 o 10 en 10) utilizando una cola de promesas controlada para no saturar la sesión del usuario. Esto reduciría el tiempo de guardado histórico de 120 segundos a menos de 15 segundos.
2. **Historial incremental y límites en JSON**:
   Limitar el JSON histórico del alumno a los últimos $N$ periodos o estructurarlo de manera compacta para evitar que el string crezca indefinidamente a lo largo de los años.

---

## Resumen de Formas de Guardado y Métodos

A continuación se presenta una tabla comparativa con todas las escrituras y sincronizaciones de datos implementadas en el proyecto:

| Archivo | Base de Datos (Moodle) | Operación de Negocio | Método Moodle / HTTP | Tipo de Operación | Crecimiento / Riesgo de Basura |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `editar_config.html` | `db_config` (Configuración) | Guardar variables globales | `POST` a `/mod/data/edit.php` | **Upsert** (si hay `rid` edita, si no crea) | **Bajo:** Solo existe un único registro de configuración activo. |
| `tablero_principal.html` | `db_logs` (Logs de asistencia) | Registrar orientaciones y tutorías | `POST` a `/mod/data/edit.php` (con `rid = 0`) | **Solo Inserción** (Insert) | **Alto:** Se crea un registro por cada asistencia. A largo plazo acumulará miles de filas de logs viejos. |
| `tablero_principal.html` | `db_solicitudes` (Pedidos ayuda) | Atender y limpiar alertas de alumnos | `POST` a `/mod/data/view.php` (parámetro `delete`) | **Eliminación Directa** (Delete) | **Bajo:** Se eliminan inmediatamente al ser asistidas. |
| `tablero_principal.html` | `db_historico` (Trayectoria alumno) | Guardar historial de riesgos del alumno | `POST` a `/mod/data/edit.php` | **Upsert** (por email de alumno) | **Medio-Alto:** Edita el registro del alumno pero su JSON crece acumulando periodos cuatrimestrales. |
| `tablero_principal.html` | `db_historico_general` | Guardar estadísticas consolidadas | `POST` a `/mod/data/edit.php` | **Upsert** (por periodo) | **Bajo:** Solo se crea un registro consolidado por cada cuatrimestre académico. |
| `panel_1er_anio.html` | `db_1er_anio` (Alumnos 1er año) | Carga de alumnos desde CSV A | `POST` a `/mod/data/edit.php` (con `rid = 0`) | **Solo Inserción** (Insert) | **Alto:** A largo plazo acumula alumnos de años pasados que ya no cursan primer año. |
| `panel_1er_anio.html` | `db_1er_anio` (Alumnos 1er año) | Carga de notas desde CSV B | `POST` a `/mod/data/edit.php` | **Edición** (Update usando `rid` previo) | **Medio:** Actualiza datos del alumno, pero almacena un JSON de materias aprobadas. |
| `panel_1er_anio.html` | `db_historico_1er_anio` (Snapshots) | Guardar snapshots de primer año | `POST` a `/mod/data/edit.php` | **Upsert** (por `DNI\|cuatActual`) | **Alto:** Se almacena una fila de snapshot por cada alumno por cada cuatrimestre. Acumula basura histórica masiva rápidamente. |

---

## Análisis de Problemas a Futuro (Almacenamiento de Basura)

Si vas a desarrollar una función para limpiar las bases de datos del sistema en un solo paso, debes priorizar e incluir las siguientes bases de datos por su tendencia a acumular datos obsoletos ("basura"):

1. **`db_logs` (Logs de asistencia - Tablero Principal):**
   * *Problema:* Cada asistencia brindada genera una nueva fila que nunca se elimina ni se consolida de forma nativa. Con el paso de los años, se acumularán registros de alumnos que ya egresaron o desertaron.
   * *Consideración:* Esta base de datos **debe ser considerada para purga periódica** (por ejemplo, eliminando registros de logs que tengan más de 2 o 3 años de antigüedad).
2. **`db_historico_1er_anio` (Snapshots Históricos - Panel 1er Año):**
   * *Problema:* Cada cuatrimestre se genera un snapshot individualizado por alumno con toda la lista de sus materias en JSON. Multiplicar cientos de ingresantes por cada periodo genera un volumen masivo de registros históricos redundantes.
   * *Consideración:* Es candidata crítica para una función de limpieza masiva una vez finalizados los ciclos de análisis de cohorte.
3. **`db_1er_anio` (Alumnos de 1er Año - Panel 1er Año):**
   * *Problema:* Cuando los alumnos avanzan a segundo año o subsiguientes, sus fichas en la base de datos activa de primer año se vuelven obsoletas y representan ruido/basura.
   * *Consideración:* Se debe limpiar para eliminar permanentemente a los estudiantes que ya no pertenezcan al ciclo lectivo inicial activo.

