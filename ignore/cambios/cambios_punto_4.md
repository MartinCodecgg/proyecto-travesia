# Cambios Realizados para el Punto 4 (Logs de Asistencia y Actualización en Caliente)

Este documento registra los cambios implementados para corregir el registro de asistencia en la base de datos de logs de asistencia de Moodle y evitar la recarga pesada del tablero, permitiendo la actualización en caliente.

## 1. Corrección en el Mapeo de Campos de Asistencia (Detección de ID de Alumno)
Se detectó un conflicto crítico de colisión en la lógica de mapeo dinámico de campos:
* Dado que `"id_alumno"` contiene la subcadena `"alumno"`, la primera evaluación `labelText.includes("alumno")` se adueñaba del campo del ID, mapeándolo erróneamente como `nombre_alumno`.
* Esto provocaba que tanto el campo del ID de Moodle (`field_44`) como el del Nombre del Alumno (`field_43`) fuesen enviados con el valor de texto del nombre (ej: `"MARTIN ESTEBAN GIRAU"`), resultando en un error de validación silencioso en el backend de Moodle PHP que impedía que la asistencia se guardara.

**Solución aplicada:** Se reordenó la prioridad de las comprobaciones de texto en ambos algoritmos de mapeo (etiquetas y contenedores) para evaluar primero los patrones específicos (`id_alumno` / `id alumno`) antes de evaluar el patrón general (`alumno`):

```javascript
          labelElements.forEach(label => {
            const text = normLabel(label.textContent);
            const inputId = label.getAttribute("for");
            const inputEl = docForm.getElementById(inputId) || docForm.querySelector('[name="' + inputId + '"]');
            if (inputEl) {
              const fieldName = inputEl.getAttribute("name");
              if (fieldName) {
                if (text.includes("id_alumno") || text.includes("id alumno")) {
                  fieldsMapeo.id_alumno = fieldName;
                } else if (text.includes("nombre_alumno")) {
                  fieldsMapeo.nombre_alumno = fieldName;
                } else if (text.includes("nombre_tutor") || text.includes("tutor")) {
                  fieldsMapeo.nombre_tutor = fieldName;
                } else if (text.includes("origen")) {
                  fieldsMapeo.origen = fieldName;
                } else if (text.includes("mensaje") || text.includes("orientacion") || text.includes("orientación")) {
                  fieldsMapeo.mensaje = fieldName;
                } else if (text.includes("alumno")) {
                  fieldsMapeo.nombre_alumno = fieldName;
                }
              }
            }
          });
```

## 2. Validación Activa del Retorno del Formulario (verifyMoodlePost)
Se integró el helper `verifyMoodlePost` en el flujo de registro de la asistencia. Moodle responde con un código HTTP `200` tanto si el guardado fue exitoso como si falló la validación y renderizó nuevamente el formulario de edición con un mensaje de error PHP.

Ahora, el flujo analiza activamente el DOM del documento HTML devuelto y, si detecta la presencia del formulario de edición o algún mensaje de alerta/error, lanza un error con el detalle correspondiente en la UI en caliente en lugar de asumir el éxito.

```javascript
          // Verificar si Moodle devolvió el formulario de nuevo con un error
          const verify = await verifyMoodlePost(postLogRes, activeStudentName);
          if (!verify.success) {
            throw new Error(verify.error);
          }
```

## 3. Resolución del Bug de Desaparición de Alumnos de la Memoria RAM
**Origen del Bug:** Al actualizar los datos en caliente, se le asignaba a la propiedad `ultimaAsistencia` del alumno la fecha en formato `"17 de junio de 2026, 16:50"`. Durante el renderizado de la UI, la función local `parseDate(str)` intentaba parsear esta fecha asumiendo de manera rígida la estructura de Moodle que incluye el día de la semana al principio (ej: `"sábado, 13 de junio de 2026, 13:47"`). Como el día de la semana no estaba presente en la fecha formateada en caliente, se provocaba una excepción de JS `TypeError: Cannot read properties of undefined (reading 'split')` al intentar acceder a la porción de la hora, deteniendo por completo el dibujo del tablero y dejando la tabla vacía.

**Solución aplicada:**
1. Se movió y unificó la declaración de `parseDate` al inicio de `renderDashboard()` para evitar re-declararla de forma ineficiente en cada iteración y poder reutilizarla globalmente.
2. Se reescribió `parseDate` para tolerar de manera dinámica la presencia o ausencia del día de la semana mediante `isNaN(parseInt(parts[0], 10))`, eliminándolo con `.shift()` si corresponde:
```javascript
        const parseDate = (str) => {
          if (!str) return 0;
          try {
            const clean = str.replace(/de/g, "").replace(/,/g, "").replace(/\s+/g, " ").trim();
            const parts = clean.split(" ");
            if (isNaN(parseInt(parts[0], 10))) {
              parts.shift();
            }
            const dia = parseInt(parts[0], 10);
            const mesIndex = meses.indexOf(parts[1].toLowerCase());
            const anio = parseInt(parts[2], 10);
            const h = parts[3].split(":");
            return new Date(anio, mesIndex, dia, parseInt(h[0], 10), parseInt(h[1], 10)).getTime();
          } catch (e) {
            console.error("Error al parsear fecha en UI:", str, e);
            return 0;
          }
        };
```
3. Se protegió la función con un bloque `try/catch` para que retorne `0` ante cualquier formato inesperado en lugar de romper el renderizado de la UI.

## 4. Consistencia de la Lógica "Asistido" en Ambas Pestañas
Para que la lógica de asistencia sea 100% coherente:
1. Se modificó la renderización de la pestaña de Solicitudes de Ayuda (Panel 2) para buscar al alumno en `alumnosCalculados` y evaluar si su última asistencia es más reciente que su última solicitud de ayuda. De cumplirse esta condición, en la tabla se muestra el texto `"✅ Asistido"` en lugar del botón *"Asistir"*, garantizando la misma visualización en ambas pestañas.
2. Se ajustó el flujo en caliente para no eliminar de forma destructiva los datos de solicitud del alumno (`solicitudFecha`, `solicitudText`) ni de la lista `solicitudesPendientes`. Al actualizar la fecha de última asistencia a la hora actual, la comparación de fechas (`parseDate(solicitud) < parseDate(asistencia)`) hace de forma natural que el botón se actualice automáticamente a *"✅ Asistido"* en ambas pestañas en el instante de hacer clic en guardar.
