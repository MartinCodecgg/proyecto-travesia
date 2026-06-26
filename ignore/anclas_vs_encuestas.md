# Diferencia entre Anclas Especiales y Preguntas de Encuesta

En el sistema de seguimiento estudiantil de **Travesía**, la configuración del archivo de configuración JSON se divide principalmente en dos tipos de preguntas debido a la función que cumple cada una en el procesamiento de datos y la lógica del sistema:

---

## 1. Preguntas de Encuesta (Inicial y Cuatrimestral)

Estas son las preguntas estándar de los formularios de Moodle que contribuyen de forma cuantitativa al **Índice de Riesgo de Deserción (IRD)**.

### Características principales:
* **Cálculo Matemático:** Cada una de estas preguntas está asociada a un peso **Beta ($\beta$)** y a un mapeo de **Valores X** para cada respuesta posible (por ejemplo: `"Bachiller": 0.2`, `"Técnico": 0`).
* **Puntaje Ponderado:** El IRD de un alumno se calcula sumando el producto de cada respuesta del alumno ($X_i$) por su respectivo coeficiente ($\beta_i$).
* **Flexibilidad y Dinamismo:** Pueden agregarse nuevas preguntas, eliminarse o modificarse sus pesos directamente desde el Editor de Configuración si los cuestionarios de Moodle sufren modificaciones.
* **Mantenimiento:** Si una pregunta de la encuesta no se incluye en esta sección del JSON, sus respuestas se seguirán guardando en el histórico de la base de datos de Moodle, pero no afectarán el cálculo del IRD.

---

## 2. Anclas Especiales (Preguntas Especiales)

Las **Anclas Especiales** son un conjunto de preguntas fijas que el código del sistema requiere de forma obligatoria para realizar procesos lógicos, segmentaciones y clasificaciones administrativas de los alumnos.

### Características principales:
* **Sin Rol en la Fórmula del IRD:** No aportan de manera directa a la sumatoria ponderada del IRD general, por lo que no poseen un peso Beta ni valores de respuesta numéricos editables en el JSON.
* **Control de Flujo y Estados:** Actúan como disparadores lógicos o metadatos clave para el sistema.
* **Rigidez:** Sus claves identificadoras son estáticas. El sistema las busca específicamente en el código JS del tablero principal y otros scripts.

### Roles específicos en el Sistema:

1. **`id_anio_ingreso` (Cohorte) y `id_cuat_ingreso`:**
   * *Propósito:* Indican el cuatrimestre y año exacto en que el estudiante ingresó a la carrera.
   * *Uso en código:* Permite agrupar las estadísticas en la pestaña **Cohortes** del tablero general, permitiendo analizar la deserción y retención de alumnos a lo largo del tiempo agrupados por año de ingreso.
2. **`id_egreso` (Estado de Egreso):**
   * *Propósito:* Identifica la columna que indica si un alumno ha egresado.
   * *Uso en código:* Si el alumno responde afirmativamente, el sistema lo marca internamente como egresado, lo que permite excluirlo del cálculo de alerta de deserción activa y filtrar sus datos en los tableros generales.
3. **`id_percepcion_riesgo` (Autopercepción de Riesgo):**
   * *Propósito:* Captura la respuesta de la pregunta donde el alumno evalúa su propio riesgo de abandonar la carrera.
   * *Uso en código:* Se expone de forma directa y visual en las fichas del alumno y en los KPIs, sirviendo como contraste directo frente al IRD calculado automáticamente por el modelo.

---

## Resumen de Distinción

| Criterio | Preguntas de Encuesta | Anclas Especiales |
| :--- | :--- | :--- |
| **Objetivo** | Alimentar cuantitativamente el modelo de riesgo (IRD). | Determinar el estado administrativo, cohorte o autopercepción del alumno. |
| **Parámetros** | Requieren pesos Beta ($\beta$) y valores X mapeados. | Solo requieren el nombre exacto de la pregunta/columna del CSV. |
| **Lógica** | Sumatoria ponderada dinámica. | Evaluaciones condicionales estáticas y agrupaciones (cohortes). |
| **Modificabilidad** | Se pueden añadir o remover preguntas del listado libremente. | La lista de campos es fija en el código, solo se edita a qué columna del CSV mapean. |
