# Comparativa de Bases de Datos: Normal vs. Histórica (1er Año)

Este documento explica las diferencias fundamentales entre las dos bases de datos que utiliza el archivo [panel_1er_anio.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/scripts/panel_1er_anio.html) para gestionar la información de los alumnos de primer año en Moodle.

---

## 1. Base de Datos Normal (DB 1er Año)
* **ID en Moodle (`DATAID_DB_1ER_ANIO`):** `19`
* **Propósito:** Almacenar el estado actual, activo y único de cada estudiante matriculado en el cuatrimestre vigente.
* **Comportamiento Clave:**
  * **Deduplicación Estricta:** El sistema realiza una deduplicación automática basada en el DNI (`id_alumno`). No se permiten múltiples registros activos para un mismo estudiante.
  * **Actualización en Tiempo Real:** 
    * Se alimenta inicialmente con el **CSV de Alta** para dar de alta a nuevos alumnos.
    * Se actualiza al importar el **CSV de Notas**, lo que recalcula inmediatamente las materias aprobadas, el porcentaje de ralentización y sobreescribe/añade materias en la propiedad `materias` (JSON).
  * **Vista Operativa:** Representa "la foto del momento" o el estado actual del alumno en el periodo lectivo en curso.

---

## 2. Base de Datos Histórica (DB Histórico 1er Año)
* **ID en Moodle (`DATAID_DB_HIST_1ER_ANIO`):** `20`
* **Propósito:** Almacenar capturas temporales ("snapshots") del rendimiento académico de los estudiantes al finalizar o transcurrir cada cuatrimestre.
* **Comportamiento Clave:**
  * **Sin Deduplicación por DNI:** Un alumno puede tener múltiples filas en esta base de datos a lo largo de su carrera universitaria (un registro por cada cuatrimestre evaluado).
  * **Clave de Búsqueda Compuesta:** La unicidad e identificación para actualizaciones se basa en la combinación `DNI | Cuatrimestre` (por ejemplo, `12345678|2026-1`).
  * **Campos Específicos Adicionales:** 
    * `cuatrimestre`: El periodo académico al que corresponden los datos capturados (calculado dinámicamente, ej. `2026-1` o `2026-2`).
    * `fecha_snapshot`: La fecha exacta del calendario en la que se realizó el guardado del registro.
  * **Acción Manual (Sincronización):** Se alimenta cuando el usuario presiona el botón **💾 Guardar Histórico 1er Año**. Este proceso recorre los alumnos activos de la base de datos normal, verifica si ya existe una foto histórica de ese alumno en el cuatrimestre actual, y crea un nuevo registro o actualiza el existente con los datos vigentes.

---

## Cuadro Comparativo Resumido

| Característica | Base de Datos Normal (ID: 19) | Base de Datos Histórica (ID: 20) |
| :--- | :--- | :--- |
| **Unicidad** | Un registro único por DNI (`id_alumno`). | Múltiples registros por DNI (uno por cada cuatrimestre). |
| **Estructura temporal** | Representa el estado actual/vigente. | Serie temporal de instantáneas académicas. |
| **Campos Clave** | `id_alumno`, `alumno`, `materias` (JSON), `aprobadas`, `ralentizacion`. | Los mismos campos + `cuatrimestre` + `fecha_snapshot`. |
| **Origen de Datos** | Carga de CSV de Alta y CSV de Notas. | Copiado de datos desde la DB Normal al presionar "Guardar Histórico". |
| **Uso Principal** | Operación diaria, seguimiento en tiempo real y actualización de notas. | Análisis evolutivo, estadísticas históricas y reportes cuatrimestrales. |
