El estado final en [editar_config.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/scripts/editar_config.html) queda así:

| Clave interna              | CMID      | DATAID | Base de datos Moodle                                          |
| -------------------------- | --------- | ------ | ------------------------------------------------------------- |
| `db_solicitudes`           | 54783     | 15     | Solicitudes de Asistencia                                     |
| `db_logs`                  | 54784     | 16     | Logs de Asistencias                                           |
| `db_historico`             | 54788     | 18     | **Historico-Alumno**                                          |
| `db_1er_anio`              | 54789     | 19     | Datos 1er Año-CSV                                             |
| `db_historico_1er_anio`    | 54791     | 20     | Historico 1er Año                                             |
| `db_historico_general`     | 54862     | 21     | Historico-Indicadores Generales                               |
| `db_historial_asistencias` | **54864** | **22** | **Historial de Asistencias-Alumno** _(nuevo, sin duplicados)_ |
| `db_control_encuestas`     | 54984     | 24     | Logs de Mensajes                                              |

Configuración (la BD donde se guarda el JSON) queda excluida intencionalmente, ya que es la fuente que el editor mismo lee. Todos los campos son únicos, sin duplicados.
