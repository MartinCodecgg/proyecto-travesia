# Restricciones y Lecciones Aprendidas (Constraints)

## 1. Gestión de Base de Datos Histórica (d=20) vs. DB Activa (d=19)

- **NO deduplicar por DNI en el histórico:** La base de datos histórica almacena el progreso de un alumno a lo largo de múltiples cuatrimestres (una fila por cada cuatrimestre). Al leer el histórico (`d=20`), desduplicar únicamente por `rid` (ID de registro en Moodle). La deduplicación por DNI solo debe aplicarse en la DB de alumnos activos (`d=19`).

## 2. Regla de Aprobación de Materias

- **Nota mínima de aprobación:** La nota mínima es **5**.
- **Cálculo de aprobadas:** Al procesar notas, contar como aprobadas únicamente las materias donde `nota >= 5`.

## 3. Mapeo Dinámico de Campos en Moodle

- Los IDs de campos de formulario (`field_XX`) en Moodle cambian según la instancia de base de datos.
- **Mapeo flexible:** Resolver siempre los campos dinámicamente utilizando búsquedas tolerantes e insensibles a mayúsculas, minúsculas y acentos sobre los labels. Los labels son dato y si no lo tienes el agente debe pedirlos.

## 4. Comparación de Documentos (DNI)

- **Limpieza de strings:** Al cruzar datos del CSV con la DB, limpiar siempre los DNI eliminando caracteres no numéricos: `dni.toString().replace(/[^\d]/g, '')`. Evita fallos por formatos con puntos, espacios o guiones.

## 5. Conflictos de Estilos con Moodle (CSS)

- Moodle inyecta sus propios estilos y puede forzar textos de botones en color blanco.
- **Botones de paginación legibles:** Para evitar botones invisibles en estados deshabilitados (texto blanco sobre fondo claro), forzar el color de texto de `.page-btn` con `!important` y definir explícitamente el estado `:disabled`.

## 6. Estructura HTML y Auto-cierre de Encabezados

- **NO anidar elementos de bloque (`div`) dentro de encabezados (`h3`, `h4`, etc.):** El navegador o Moodle auto-cerrarán el encabezado prematuramente antes de renderizar el bloque interno. Esto rompe el flujo, anula los estilos de contenedor del encabezado y desalinea los elementos. En su lugar, envolver ambos en un contenedor padre `div` con flexbox para la alineación horizontal.

## 7. Moodle Autolinks, Espacios Unicode y Mapeo en Creación

- **Evasión de Autolink en Moodle:** Moodle convierte automáticamente cadenas que coincidan con nombres de actividades en enlaces. Para evitarlo en textos de interfaz sin alterar el nombre visual, romper el texto inyectando la entidad `&zwnj;` (zero-width non-joiner) o un tag vacío: `Encuesta &zwnj;Inicial`.
- **Limpieza de JSON Unicode (\u00a0):** Al extraer un JSON de un campo de Moodle usando `textContent`, los espacios de no separación HTML (`&nbsp;`) se convierten en el carácter Unicode `\u00a0`. Esto provoca fallos en `JSON.parse`. Reemplazar siempre antes de parsear: `rawText.replace(/\u00a0/g, " ")`.
- **Resolución de Mapeo de Campos sin RID:** Evitar hacer fetch a URLs de edición con rid (`edit.php?d=XX&rid=YY`) si `rid` puede ser 0 o inexistente (provoca 404). Realizar siempre el fetch a la URL de creación general (`edit.php?d=XX`), dado que contiene el mismo formulario y mapeo de campos, y siempre está disponible.
