# Proyecto Travesía — Sistema de Seguimiento Estudiantil en Moodle

Este repositorio contiene el código fuente, las estructuras de base de datos y la documentación para el **Proyecto Travesía**, un sistema web embebido diseñado para ejecutarse dentro del entorno virtual de aprendizaje Moodle (campus de Ingeniería de la UNMDP).

El objetivo principal del sistema es facilitar a los tutores y docentes el seguimiento del riesgo de deserción de los estudiantes, la gestión de solicitudes de asistencia y el análisis longitudinal de la trayectoria académica de los alumnos de primer año y cohortes generales.

## Características Principales

*   **Arquitectura sin Frameworks (Vanilla JS):** Todo el sistema se implementa mediante bloques independientes de HTML, CSS y JavaScript nativo incrustados en actividades de tipo **Página** de Moodle. No utiliza dependencias externas para asegurar la máxima compatibilidad y portabilidad en el campus.
*   **Cálculo del Índice de Riesgo de Deserción (IRD):** Algoritmo que calcula dinámicamente un puntaje de riesgo para cada estudiante basándose en encuestas iniciales y cuatrimestrales, aplicando pesos ponderados ($\beta$) a preguntas clave.
*   **Persistencia basada en Moodle:** Los datos se guardan y leen directamente desde actividades de tipo **Base de Datos** de Moodle emulando peticiones HTTP del usuario autenticado (*scraping* vía `fetch`), resolviendo el almacenamiento sin necesidad de un backend propio.
*   **Módulos del Sistema:**
    *   **Dashboard Principal (Tutor):** Visualización del listado de estudiantes, ordenados por nivel de riesgo, con acceso directo para registrar asistencias y gestionar solicitudes de ayuda.
    *   **Panel del Alumno:** Vista individualizada para que cada estudiante consulte su estado y envíe solicitudes de asistencia a los tutores de manera privada.
    *   **Panel Histórico:** Herramienta para realizar capturas temporales (*snapshots*) del estado académico general de la cohorte y exportar datos históricos.
    *   **Panel de 1er Año:** Gestión específica orientada a estudiantes ingresantes, controlando materias aprobadas, reprobadas y el indicador de alargamiento de carrera mediante carga de archivos CSV.
    *   **Editor de Configuración:** Interfaz para que los administradores y tutores modifiquen los parámetros del sistema (umbrales de alerta, cmids, dataids, valores de pesos $\beta$) sin necesidad de editar el código fuente HTML/JS.

## Estructura del Repositorio

*   `scripts/`: Contiene los archivos HTML con los módulos del sistema listos para ser incrustados en Moodle.
*   `ignore/`: Archivos con detalles técnicos sobre las estructuras internas de las bases de datos de Moodle y el mapeo de claves.
*   `Plan de Implementacion V3.1 Completo.md`: Plan maestro obligatorio detallado con la arquitectura, flujos de datos y especificaciones técnicas.
*   `constraints.md`: Reglas del negocio, restricciones técnicas y soluciones específicas aplicadas para Moodle.
*   `config_3.md`: Configuración de cmids, dataids y parámetros del sistema.