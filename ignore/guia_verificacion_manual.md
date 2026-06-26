# Guía de Verificación Manual: Panel de 1er Año

Esta guía describe paso a paso cómo comprobar que el panel de primer año funciona correctamente de principio a fin, utilizando los nuevos archivos CSV de prueba ubicados en la carpeta [CSV-pruebas](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/CSV-pruebas).

---

## Preparativos Iniciales
1. Abre Moodle en la sección donde esté inyectado el script del [panel_1er_anio.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/scripts/panel_1er_anio.html).
2. Comprueba que el panel se cargue **directamente sin ninguna pantalla falsa** de Lorem Ipsum.
3. Asegúrate de tener a mano los tres archivos de prueba creados:
   * [1_alta_alumnos_prueba.csv](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/CSV-pruebas/1_alta_alumnos_prueba.csv)
   * [2_notas_iniciales_prueba.csv](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/CSV-pruebas/2_notas_iniciales_prueba.csv)
   * [3_notas_promocion_prueba.csv](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/CSV-pruebas/3_notas_promocion_prueba.csv)

---

## Caso de Prueba 1: Alta de Alumnos Nuevos
**Objetivo:** Verificar que se crean correctamente nuevos alumnos en la base de datos operativa de Moodle.
1. En la sección **Cargar Alumnos (CSV de Alta)**, presiona `📁 Seleccionar CSV Alta`.
2. Selecciona el archivo [1_alta_alumnos_prueba.csv](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/CSV-pruebas/1_alta_alumnos_prueba.csv).
3. Verifica que la previsualización indique: **"Detectados: 3 alumnos para dar de alta."**
4. Presiona el botón `Confirmar Alta`.
5. Espera a que la barra de progreso finalice e indique: **"Finalizado. Exitosos: 3. Fallidos: 0."**
6. Busca en la tabla inferior y comprueba que aparecen los tres alumnos:
   * `TEST ALUMNO UNO` (DNI: 49999991)
   * `TEST ALUMNO DOS` (DNI: 49999992)
   * `TEST ALUMNO TRES` (DNI: 49999993)
7. Nota que al no tener notas, sus materias figuran como *Sin notas cargadas*, sus materias aprobadas son `0` y su ralentización figura como `-`.

---

## Caso de Prueba 2: Carga de Notas y Modificación de Datos
**Objetivo:** Comprobar que se cargan y vinculan las notas correctamente, actualizando el conteo de aprobadas y recalculando la ralentización.
1. En la sección **Cargar Notas (CSV de Notas)**, presiona `📁 Seleccionar CSV Notas`.
2. Selecciona el archivo [2_notas_iniciales_prueba.csv](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/CSV-pruebas/2_notas_iniciales_prueba.csv).
3. Verifica que la previsualización indique: **"Detectados: 13 materias/notas registradas."**
4. Presiona el botón `Confirmar Notas`.
5. Espera a que finalice el proceso de carga.
6. Verifica que en el listado de alumnos los datos se actualizaron correctamente:
   * `TEST ALUMNO UNO` tiene **4 aprobadas** y su Ralentización es **42.9%** (4 de 7 materias).
   * `TEST ALUMNO DOS` tiene **3 aprobadas** y su Ralentización es **57.1%** (3 de 7 materias).
   * `TEST ALUMNO TRES` tiene **6 aprobadas** y su Ralentización es **14.3%** (6 de 7 materias).

---

## Caso de Prueba 3: Funcionamiento del Filtro de Alumnos de Segundo Año
**Objetivo:** Confirmar que los alumnos de 2do año se ocultan por defecto y se muestran al desactivar el filtro.
1. Nota que los tres alumnos siguen viéndose en la lista porque ninguno tiene aún las 7 materias aprobadas (el filtro por defecto está activo).
2. Ahora, en la sección **Cargar Notas (CSV de Notas)**, selecciona e importa el archivo [3_notas_promocion_prueba.csv](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/CSV-pruebas/3_notas_promocion_prueba.csv).
3. Tras finalizar la carga:
   * `TEST ALUMNO UNO` sube a **5 aprobadas** y sigue visible en la tabla.
   * `TEST ALUMNO TRES` alcanza las **7 aprobadas (100% de primer año)**.
4. **Verificación clave (Ocultación):** Verifica que `TEST ALUMNO TRES` ha **desaparecido** de la tabla de visualización actual (ya que tiene 7 aprobadas y el filtro "Ocultar alumnos de segundo año" está activado por defecto).
5. **Verificación clave (Desactivar Filtro):** Desmarca el checkbox de la fila de filtros: **"Ocultar alumnos de segundo año"**.
6. Comprueba que `TEST ALUMNO TRES` vuelve a aparecer en la tabla de forma instantánea mostrando **7 aprobadas** y Ralentización **0.0%**.

---

## Caso de Prueba 4: Guardado en la Base de Datos Histórica
**Objetivo:** Verificar que se almacena una instantánea cuatrimestral completa en la base de datos histórica.
1. En la tarjeta **Historial del Cuatrimestre**, presiona el botón `💾 Guardar Histórico 1er Año`.
2. Espera a que finalice el progreso. El estado debe mostrar: **"Nuevos: X | Actualizados: Y | Fallidos: 0"**.
3. Para comprobar que se guardó correctamente, puedes acceder directamente a la base de datos histórica de Moodle (ID `20`) en el Campus y corroborar que existen registros correspondientes a la fecha actual para `TEST ALUMNO UNO`, `TEST ALUMNO DOS` y `TEST ALUMNO TRES` con sus aprobadas y materias correspondientes bajo el cuatrimestre correspondiente (ej: `2026-1`).
4. Nota que el botón se desactiva por 30 segundos (cooldown temporal configurado) para evitar dobles clics accidentales.

---

## Caso de Prueba 5: Pruebas Avanzadas con Override de Cuatrimestre
**Objetivo:** Validar que se pueden almacenar registros históricos en un cuatrimestre diferente.
1. Abre el archivo [panel_1er_anio.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/scripts/panel_1er_anio.html) en tu editor.
2. Modifica la constante `TEST_PERIODO_OVERRIDE` asignándole un cuatrimestre ficticio de prueba, por ejemplo:
   ```javascript
   const TEST_PERIODO_OVERRIDE = "2025-2";
   ```
3. Guarda el archivo y recarga el panel en tu navegador Moodle.
4. Presiona el botón `💾 Guardar Histórico 1er Año`.
5. Ve a la base de datos histórica de Moodle (ID `20`) y verifica que los registros de los alumnos se hayan guardado/actualizado bajo el cuatrimestre `"2025-2"` en lugar del cuatrimestre calculado por la fecha del sistema (`"2026-1"`).
6. Una vez validado, recuerda volver a dejar la constante en `null` para el funcionamiento productivo normal:
   ```javascript
   const TEST_PERIODO_OVERRIDE = null;
   ```
