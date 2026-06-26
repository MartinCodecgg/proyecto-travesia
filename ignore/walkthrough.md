# Walkthrough: Filtro de Alumnos de 2do Año, Remoción de Pantallas Falsas, Formato de Porcentajes y Override de Periodo

Se completaron con éxito los cambios solicitados en el [panel_1er_anio.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/scripts/panel_1er_anio.html) y en el [panel_historico_1er_anio.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/scripts/panel_historico_1er_anio.html).

## Cambios Realizados

### 1. Panel de Primer Año (`panel_1er_anio.html`)
* **Remoción de Pantalla Falsa (Lorem Ipsum):**
  * Se eliminó el bloque `<div id="pantalla-falsa">` de la interfaz.
  * Se removió la propiedad `style="display: none"` de `<div id="tablero">` para hacerlo inmediatamente visible al cargar.
  * Se retiró el listener de eventos de click sobre el botón oculto `#btn-oculto`.
  * Se colocó la invocación directa `initPanel()` al final del IIFE para inicializar los datos de Moodle de forma inmediata.
* **Filtro de Exclusión de 2do Año:**
  * **Interfaz (HTML):** Se agregó un checkbox con ID `filter-exclude-2nd-year` etiquetado como "Ocultar alumnos de segundo año" que viene seleccionado (`checked`) por defecto.
  * **Variable de Estado (JS):** Se declaró la variable `filterExclude2ndYear` iniciada en `true`.
  * **Lógica de Filtrado (JS):** En `renderTable()`, se incorporó una condición para filtrar y omitir de la visualización a aquellos estudiantes que tengan un número de materias aprobadas mayor o igual a `MATERIAS_ESPERADAS_1ER_ANIO` (7 materias aprobadas).
  * **Manejador de Eventos (JS):** En `setupEventListeners()`, se conectó el evento `change` del checkbox para actualizar el estado de la variable `filterExclude2ndYear`, reiniciar la paginación a la página 1 y refrescar la tabla.
* **Constante `TEST_PERIODO_OVERRIDE`:**
  * **Constante (JS):** Se declaró la constante `const TEST_PERIODO_OVERRIDE = null;` en la sección de configuración.
  * **Lógica (JS):** Se adaptó `getCuatrimestreActual()` para que, en caso de que `TEST_PERIODO_OVERRIDE` tenga un valor no nulo, retorne este valor de forma inmediata, permitiendo a los desarrolladores o validadores probar el almacenamiento del histórico en diferentes cuatrimestres.

---

### 2. Panel Histórico de Primer Año (`panel_historico_1er_anio.html`)
* **Remoción de Pantalla Falsa (Lorem Ipsum):**
  * Se eliminó el bloque de HTML `<div id="pantalla-falsa">` y se removió la propiedad `style="display: none;"` de `<div id="tablero">` para cargar el tablero directamente.
  * Se eliminó la inicialización basada en el clic en `#btn-oculto` y se inyectó la llamada directa a `initPanel()` antes del cierre del script principal autoejecutable.
* **Formato de Porcentaje de Ralentización:**
  * Se modificó la función `badgeAlarg(raw)` para redondear el porcentaje de ralentización a un número entero sin decimales (`v.toFixed(0)` en lugar de `v.toFixed(1)`).
* **Alineación de Columnas:**
  * Se centró la alineación de las celdas (`td`) que contienen los badges de ralentización, tanto en las filas principales del listado de alumnos como en las sub-filas de cuatrimestres. Esto alinea la información de forma simétrica bajo la cabecera `Ult. Ralentización`.

---

## Pruebas de Validación
* **Carga Inicial de Paneles:** Al ingresar a ambos paneles, el tablero operativo y el histórico se dibujan directamente sin la pantalla falsa de prueba.
* **Comportamiento del Filtro en 1er Año:** Por defecto, los estudiantes con 7 materias aprobadas no se muestran en el listado. Al desmarcar el checkbox "Ocultar alumnos de segundo año", la tabla se vuelve a calcular mostrando a todos los estudiantes (incluidos los de 2do año). Al volver a marcarlo, la tabla los oculta de nuevo adecuadamente.
* **Porcentajes sin decimales:** El panel histórico ahora renderiza los badges de ralentización/alargamiento con valores enteros (ej. `57%`, `43%` o `0%`), asegurando una interfaz más limpia.
* **Simetría y Alineación:** Se comprobó visualmente que la columna de ralentización se encuentra perfectamente alineada respecto a su cabecera en el panel histórico de primer año.
