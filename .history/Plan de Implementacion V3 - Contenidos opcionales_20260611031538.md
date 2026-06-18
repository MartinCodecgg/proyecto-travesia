# Sistema de Seguimiento Estudiantil — Features Opcionales y Backlog

Este archivo complementa el plan principal (`Tableros_de_Control_Plan_v3.md`). Contiene features que no forman parte del scope inicial pero que están suficientemente definidas para implementarse en el futuro.

---

## O-1. Filtro por "Completó última encuesta cuatrimestral"

### Descripción

Filtro disponible en el Panel 1 que permite ocultar alumnos cuyos datos de encuesta cuatrimestral son de un período anterior al actual.

### Estado

Opcional. **No activo por defecto.**

### Por qué no es default

Un alumno que no completó la última encuesta puede estar en deserción activa y es exactamente el que más interesa ver en el panel. Filtrarlo por defecto lo ocultaría del radar del tutor justo cuando más lo necesita. El filtro tiene sentido como opción de limpieza visual, pero nunca como comportamiento predeterminado.

### Implementación

Agregar al panel de filtros expandido de Panel 1:

```
Encuesta cuatrimestral: (•) Todos   ( ) Solo completaron la última
```

La "última encuesta" se define como la encuesta con fecha de entrega dentro del cuatrimestre actual (configurable por rango de fechas o por lógica de cuatrimestre actual).

---

## O-2. Grupos Dinámicos de Moodle

### Descripción

Crear automáticamente grupos de Moodle con los alumnos que completaron la encuesta cuatrimestral en el período actual, para restringir el acceso a ciertas actividades solo a ese grupo.

### Lógica propuesta

1. El tutor hace clic en "Actualizar grupos".
2. El script hace scraping de todos los alumnos que completaron la encuesta cuatrimestral en el último período.
3. Busca si existe un grupo con el prefijo `"Grupo-"` + fecha del cuatrimestre actual.
4. Si no existe: lo crea.
5. Si existe: obtiene su lista actual de miembros y agrega solo los alumnos nuevos.

### Problema conocido

La creación y gestión de grupos en Moodle vía frontend requiere interceptar endpoints que aún no han sido identificados. Antes de planificar la implementación, es necesario:

1. Crear un grupo manualmente en Moodle con DevTools → Network abierto.
2. Capturar el POST de creación y el POST de adición de miembro.
3. Verificar que los parámetros no cambien entre sesiones.

### Estado

**Backlog.** No implementar hasta tener los endpoints confirmados. No incluir en el dashboard principal; es una feature de administración separada.

---

## O-3. Sistema de Notificaciones a Tutores

### Descripción

Notificar automáticamente a todos los tutores cuando un alumno envía una solicitud de asistencia.

### Opción A — Mensaje directo (endpoint confirmado)

Enviar un mensaje interno de Moodle a cada tutor usando `core_message_send_instant_messages`.

- Requiere mantener una lista de `userids` de tutores hardcodeada en el código.
- Extracción de `userid` desde el HTML de la tabla de feedback: `href="user/view.php?id=XXXX"`.
- Bajo costo de implementación una vez que se tienen los IDs.

**Problema:** la lista hay que actualizarla manualmente si cambia el equipo de tutores.

### Opción B — Post en foro de aula de profesores (preferida)

Postear en un foro de un aula exclusiva de profesores. Moodle notifica automáticamente a todos los suscriptores por email y campana interna.

- No hay que mantener lista de IDs.
- Queda historial de notificaciones en el foro.
- Requiere interceptar el endpoint `mod_forum_add_discussion` en `service.php`.

**Proceso para interceptar:**

1. DevTools → Network.
2. Crear un post manualmente en el foro.
3. Capturar el POST que se dispara.
4. Identificar parámetros: `forumid`, `subject`, `message`, `sesskey`.

### Estado

**Pendiente de implementar.** Opción B es la preferida. Requiere interceptar el endpoint del foro antes de codear.

---

## O-4. Indicador de Indicadores — Vista Detallada

### Descripción

Sección en el dashboard que muestra qué pregunta de las encuestas tiene mayor peso acumulado en el riesgo global del grupo, ordenada de mayor a menor.

### Cálculo

Durante el cálculo del IRD de todos los alumnos, se acumula:

```
pesoPregunta[i] = Σ (βᵢ × xᵢ) para todos los alumnos con dato en pregunta i
```

Al finalizar el cálculo, el array `pesosPreguntaOrdenados` ya está disponible (se calcula de todas formas en el plan principal). Esta feature solo agrega la vista que lo muestra.

### Vista propuesta

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

### Estado

**Bajo costo de implementar** ya que el cálculo ya existe en el plan principal. Solo falta la vista. Recomendado como segunda iteración del dashboard una vez que el panel principal esté funcionando.

---

## O-5. Indicadores por Cohorte — Vista Independiente

### Descripción

Panel separado (o sección del dashboard) que muestra los indicadores de deserción, actividad y eficiencia terminal por cohorte (año de ingreso).

### Indicadores

|Indicador|Fórmula|
|---|---|
|Deserción total|(desertores / ingresantes de la cohorte) × 100%|
|Alumnos activos|(activos / ingresantes de la cohorte) × 100%|
|Eficiencia terminal|(egresados / ingresantes de la cohorte) × 100%|

Los tres suman 100% de la cohorte.

### Fuentes de datos

- **Año de ingreso:** pregunta de la encuesta inicial.
- **Desertor:** no completó encuesta en `CUATRIMESTRES_DESERCION` períodos consecutivos. Se detecta comparando la fecha de última entrega con el período actual.
- **Egresado:** respondió `Sí` a la pregunta de egreso en la encuesta cuatrimestral.
- **Activo:** ninguna de las anteriores.

No requiere leer el histórico para calcular el estado actual. El histórico sirve para ver cómo evolucionaron estos indicadores en el tiempo.

### Vista propuesta

```
┌──────────────────────────────────────────────────────────────────────┐
│  🎓  Indicadores por Cohorte                                         │
├──────────────┬──────────────┬──────────────┬──────────────┬──────────┤
│  Cohorte     │  Ingresantes │  Activos     │  Egresados   │ Desertados│
├──────────────┼──────────────┼──────────────┼──────────────┼──────────┤
│  2022        │  200         │  101 (51%)   │  29 (14%)    │  70 (35%)│
│  2023        │  185         │  140 (76%)   │  5 (3%)      │  40 (22%)│
│  2024        │  210         │  195 (93%)   │  0 (0%)      │  15 (7%) │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────┘
```

### Estado

**Implementable** con los datos actuales del sistema. Depende de que las preguntas de año de ingreso y egreso estén bien identificadas en las encuestas.

---

## O-6. Ralentización Individual — Columna en Panel 1

### Descripción

Agregar una columna de "Ralentización" al Panel 1 que muestre el indicador de demora individual de cada alumno respecto al plan de estudios.

### Fórmula

```
Ralentización = (1 - (materias_aprobadas / materias_esperadas_segun_plan)) × 100%
```

- `materias_aprobadas`: materias reportadas con nota >= 6 en la encuesta cuatrimestral.
- `materias_esperadas_segun_plan`: extraído del `PLAN_DE_ESTUDIOS` hardcodeado, usando el `anio_ingreso` del alumno para determinar cuántos años lleva cursando.
- No aplica a alumnos sin encuesta cuatrimestral completada.
- No considera materias aprobadas de carreras anteriores.

### Plan de estudios requerido

```javascript
const PLAN_DE_ESTUDIOS = {
  anio1:  7,
  anio2: 14,
  anio3: 21,
  // completar con valores reales de la carrera
}
```

### Estado

**Pendiente de definición.** Requiere que el plan de estudios real esté cargado en el código. Una vez disponible, la implementación es directa.

---

## O-7. Log de Asistencias Integrado en el Dashboard

### Descripción

Vista de solo lectura del log de asistencias integrada directamente en el dashboard, con filtros por tutor y rango de fechas.

### Estado actual

La actividad Base de Datos de Moodle que almacena los logs ya provee vistas nativas con ordenamiento y filtros. El tutor puede consultarla directamente desde Moodle sin necesidad de código adicional.

### Cuándo implementar

Solo si el tutor reporta que la vista nativa de Moodle es insuficiente o incómoda. Agrega comodidad pero no funcionalidad nueva.

### Estado

**Complejidad baja.** Backlog de baja prioridad.

---

## Orden de prioridad sugerido para features opcionales

|Prioridad|Feature|Motivo|
|---|---|---|
|1|O-4 Indicador de indicadores (vista)|El cálculo ya existe, solo falta la vista. Muy bajo costo|
|2|O-5 Indicadores por cohorte|Alto valor analítico, datos ya disponibles|
|3|O-3 Notificaciones (opción B)|Útil operativamente, requiere interceptar endpoint|
|4|O-6 Ralentización en Panel 1|Requiere plan de estudios completo cargado|
|5|O-1 Filtro última encuesta|Baja prioridad, comportamiento cuestionable como default|
|6|O-7 Log integrado en dashboard|Moodle ya lo resuelve nativamente|
|7|O-2 Grupos dinámicos|Alta complejidad, endpoints desconocidos, valor incierto|
