# Cambios Realizados para Resolver el Guardado en Moodle (Firmas de Formulario y Redirección Manual)

Para solucionar el problema por el cual Moodle no guardaba las entradas en la base de datos (a pesar de que las peticiones HTTP retornaban éxito), se implementó una copia completa de todos los campos ocultos (`type="hidden"`) y de las firmas de formulario (`_qf__...`) que genera Moodle.

Asimismo, para evitar errores de validación de campos obligatorios en Moodle (como *"Debe proporcionar un valor aquí"*), se filtraron las consultas de campos para emparejar únicamente los campos principales (`field_XX`) e ignorar los sub-campos auxiliares generados para textareas (como `field_XX_itemid` o `field_XX_format`).

Adicionalmente, para solucionar fallos 404 (Not Found) provocados por redirecciones después de guardar (o bloqueos del servidor/WAF en la redirección), se configuró `redirect: "manual"` en las peticiones fetch de POST. De esta forma, si Moodle guarda con éxito y emite un código 302/303, la operación se procesa directamente como exitosa en el cliente sin intentar cargar la página de redirección. Si Moodle no redirige (retorna 200), se lee el HTML de error para capturar e informar fallos de validación específicos.

---

## 1. Helpers de Conexión Añadidos y Corregidos

Se agregaron funciones auxiliares en el script para clonar de manera dinámica los datos de los formularios originales de Moodle, filtrando inputs inactivos (como checkboxes/radios no seleccionados):

```js
      // ==========================================================
      // ★ HELPERS DE CONEXIÓN CON MOODLE (FORMULARIOS Y FIRMAS) ★
      // ==========================================================
      function buildMoodleFormData(docForm, fieldsValues) {
        const formData = new FormData();
        const inputs = docForm.querySelectorAll("input, textarea, select");
        inputs.forEach(input => {
          const name = input.getAttribute("name");
          if (!name) return;
          if (input.type === "submit" || input.type === "button") return;
          if ((input.type === "checkbox" || input.type === "radio") && !input.checked) return;
          const val = input.value || input.getAttribute("value") || "";
          formData.set(name, val);
        });
        for (let key in fieldsValues) {
          if (fieldsValues[key] !== undefined && fieldsValues[key] !== null) {
            formData.set(key, fieldsValues[key]);
          }
        }
        const submitBtn = docForm.querySelector('input[type="submit"]');
        if (submitBtn && submitBtn.name) {
          formData.set(submitBtn.name, submitBtn.value || "Guardar");
        } else {
          formData.set("saveandview", "Guardar");
        }
        return formData;
      }
```

---

## 2. Cambios en Mapeo y Guardado de `guardarHistorico`

Se agregaron logs de depuración detallados en el proceso de guardado y mapeo de campos históricos, y se configuró la redirección manual para evitar el error 404. Además, se eliminó el envío automático de `"rid": "0"` cuando no existe una entrada previa para el alumno (usando `formData.delete("rid")`). 

En línea con las restricciones de Moodle (punto 7 de `constraints.md`), se eliminó el parámetro `ridParam` de la query string en `postUrl`, de modo que todas las peticiones POST de creación o edición se dirigen directamente a la URL de creación general (`edit.php?d=XX`). Si se trata de una edición, Moodle procesará la actualización de manera interna mediante el parámetro `rid` incluido dentro del cuerpo del `FormData`:

```js
            // Mapear campos específicos a enviar
            const fieldsValues = {
              "d": systemConfig.urls.dataids.db_historico,
              "sesskey": sesskey
            };
            if (entradaExistente && entradaExistente.rid) {
              fieldsValues["rid"] = entradaExistente.rid;
            }
            fieldsValues[fieldsMapeo.email] = alumno.email;
            if (fieldsMapeo.nombre) fieldsValues[fieldsMapeo.nombre] = alumno.nombre;
            fieldsValues[fieldsMapeo.historial] = historialJsonText;
            
            console.log(`[DEBUG] Mapeo de campos histórico para ${alumno.nombre}:`, fieldsMapeo);
            console.log(`[DEBUG] Valores a enviar para ${alumno.nombre}:`, fieldsValues);
            
            const formData = buildMoodleFormData(docForm, fieldsValues);
            if (!entradaExistente || !entradaExistente.rid) {
              formData.delete("rid");
            }
            
            const postUrl = `${window.location.origin}/mod/data/edit.php`;
            
            console.log(`[DEBUG LOG] Realizando POST a: ${postUrl}`);
            console.log(`[DEBUG LOG] Datos enviados en FormData:`);
            for (let pair of formData.entries()) {
              console.log(`  - ${pair[0]}: ${typeof pair[1] === "string" ? pair[1].substring(0, 150) : pair[1]}`);
            }
            
            const postRes = await fetch(postUrl, { 
              method: "POST", 
              body: formData,
              redirect: "manual"
            });
            
            console.log(`[DEBUG LOG] Respuesta recibida de POST: Estado = ${postRes.status}, Tipo = ${postRes.type}`);
            
            const isRedirect = postRes.status === 302 || postRes.status === 303 || postRes.status === 0;
            
            if (postRes.status === 200) {
              const text = await postRes.text();
              const parser = new DOMParser();
              const doc = parser.parseFromString(text, "text/html");
              const errorEl = doc.querySelector('.errormsg, .error, .alert-danger');
              let errorMsg = "Fallo de validación en Moodle.";
              if (errorEl) {
                errorMsg += ` Detalle: ${errorEl.textContent.trim()}`;
              }
              throw new Error(errorMsg);
            }
            
            if (!postRes.ok && !isRedirect) {
              throw new Error(`Fallo al enviar datos de ${alumno.nombre} a Moodle (Estado: ${postRes.status})`);
            }
```

---

## 3. Cambios en Registro de Asistencia (`form-asistencia`)

Se actualizó el envío del formulario de registro de logs de asistencia para utilizar la redirección manual y gestionar de forma limpia los códigos de respuesta del servidor. Al igual que en históricos, los logs son siempre inserciones nuevas y no deben llevar ID de registro. Por ende, se quitó `"rid"` de `fieldsValues` y se eliminó explícitamente del formulario inyectado llamando a `formData.delete("rid")` para evitar que Moodle intente resolver una edición sobre un registro ficticio:

```js
          const fieldsValues = {
            "d": systemConfig.urls.dataids.db_logs,
            "sesskey": sesskey
          };
          if (fieldsMapeo.nombre_alumno) fieldsValues[fieldsMapeo.nombre_alumno] = activeStudentName;
          if (fieldsMapeo.id_alumno) fieldsValues[fieldsMapeo.id_alumno] = activeStudentId;
          if (fieldsMapeo.nombre_tutor) fieldsValues[fieldsMapeo.nombre_tutor] = tutorNombre;
          if (fieldsMapeo.origen) fieldsValues[fieldsMapeo.origen] = origen;
          if (fieldsMapeo.mensaje) fieldsValues[fieldsMapeo.mensaje] = mensajeText;

          const formData = buildMoodleFormData(docForm, fieldsValues);
          formData.delete("rid");

          const postLogRes = await fetch(`${window.location.origin}/mod/data/edit.php`, {
            method: "POST",
            body: formData,
            redirect: "manual"
          });
          
          const isRedirectLog = postLogRes.status === 302 || postLogRes.status === 303 || postLogRes.status === 0;
          
          if (postLogRes.status === 200) {
            const text = await postLogRes.text();
            const parser = new DOMParser();
            const doc = parser.parseFromString(text, "text/html");
            const errorEl = doc.querySelector('.errormsg, .error, .alert-danger');
            let errorMsg = "Fallo de validación en Moodle.";
            if (errorEl) {
              errorMsg += ` Detalle: ${errorEl.textContent.trim()}`;
            }
            throw new Error(errorMsg);
          }
          
          if (!postLogRes.ok && !isRedirectLog) {
            throw new Error(`Fallo en la petición de red para registrar asistencia (Estado: ${postLogRes.status})`);
          }

---

## 4. Corrección del Bug de `get_in_or_equal` en `guardarHistorico`

Para solucionar el error interno de Moodle `moodle_database::get_in_or_equal() does not accept empty arrays` que se producía al guardar el histórico, se reemplazó la función `buildMoodleFormData` en `guardarHistorico` por una construcción de `FormData` selectiva y manual.

Esto previene el envío de valores de texto vacíos (`""`) en campos no utilizados (como `field_50` a `field_54`), mientras que asegura que se envíen de manera correcta los campos clave (`email`, `nombre`, `historial`) así como cualquier campo auxiliar indispensable (por ejemplo, `field_56_itemid` y `field_56_content1` para el editor de texto si estuvieran presentes en el formulario de Moodle).

La construcción del `FormData` selectivo se implementó de forma segura, evitando operadores prohibidos (`&&`, `<`, `>`) que pudiesen ser corrompidos por Moodle:

```js
            // Construir el FormData de forma selectiva para evitar enviar campos vacíos no deseados
            // que causan errores de base de datos en Moodle (ej. moodle_database::get_in_or_equal() does not accept empty arrays)
            const formData = new FormData();
            formData.append("d", systemConfig.urls.dataids.db_historico.toString());
            if (entradaExistente) {
              if (entradaExistente.rid) {
                formData.append("rid", entradaExistente.rid);
              }
            }
            formData.append("sesskey", sesskey);
            
            // Buscar si hay un botón submit en el formulario original para enviar su nombre y valor
            const submitBtn = docForm.querySelector('input[type="submit"]');
            if (submitBtn) {
              if (submitBtn.name) {
                formData.append(submitBtn.name, submitBtn.value || "Guardar");
              } else {
                formData.append("saveandview", "Guardar");
              }
            } else {
              formData.append("saveandview", "Guardar");
            }

            // Añadir campos mapeados y sus inputs auxiliares correspondientes
            const camposAEnviar = {
              [fieldsMapeo.email]: alumno.email,
              [fieldsMapeo.historial]: historialJsonText
            };
            if (fieldsMapeo.nombre) {
              camposAEnviar[fieldsMapeo.nombre] = alumno.nombre;
            }

            const entries = Object.entries(camposAEnviar);
            entries.forEach(pair => {
              const fieldName = pair[0];
              const value = pair[1];
              formData.append(fieldName, value);
              
              // Buscar en el formulario original si hay campos auxiliares asociados (ej. _itemid, _content1)
              const auxInputs = docForm.querySelectorAll('[name^="' + fieldName + '_"]');
              auxInputs.forEach(input => {
                const name = input.getAttribute("name");
                if (name) {
                  formData.append(name, input.value || "");
                }
              });
            });
```
```
