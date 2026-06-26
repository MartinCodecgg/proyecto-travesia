# Plan de Ajustes de Gráficos (Histórico) - Copia de Respaldo

Este documento contiene el plan para ajustar los gráficos históricos de la pestaña **Análisis Visual** en [panel_historico.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/scripts/panel_historico.html) según el alcance original de multi-tiempo, preservando su estructura lo más posible.

## Aclaración de Diseño
Los gráficos deben mantenerse en su diseño original pero modificarse internamente para que puedan considerar datos multi-tiempo, es decir, todo el tiempo (acumulado/promedio), el cuatrimestre actual o cualquier otro cuatrimestre seleccionado por el usuario entre los disponibles. Si es muy complejo, se optará por un enfoque más sencillo.

---

## Propuesta de Cambios Original

1. **Gráficos en el Tiempo (Análisis Visual):**
   - El gráfico de **Retención de Cohortes** (`chart-cohortes`) se rediseña para mostrar la evolución temporal del porcentaje de alumnos activos para cada cohorte a lo largo de los cuatrimestres.
   - El gráfico de **Correlación: Atraso vs Riesgo** (`chart-dispersion`) incluye todos los registros históricos (todos los cuatrimestres) en la vista de "Todos los tiempos", en lugar de limitarse al último.
   - El gráfico de **Población Actual** (`chart-riesgo-actual`) se consolida para mostrar el acumulado total cuando se selecciona "Todos los tiempos".

2. **Filtro de Cuatrimestre en Dashboard:**
   - Añadir un desplegable con los cuatrimestres históricos y la opción "Todos los tiempos" en la pestaña de Análisis Visual.
   - Este filtro afectará a:
     - Población actual (`chart-riesgo-actual`).
     - Correlación (`chart-dispersion`).
     - Desaprobaciones por materia (`chart-materias-desaprobadas`).
   - Se agregará una línea divisora visual para separar los gráficos afectados por este filtro de los gráficos que son puramente evolutivos e históricos (`chart-riesgo-historico` y `chart-cohortes`).
