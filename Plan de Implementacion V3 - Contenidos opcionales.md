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
