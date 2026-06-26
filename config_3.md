```json
{
  "_INFO": {
    "version": "1.0",
    "descripcion": "Configuracion del sistema de Indice de Riesgo de Desercion (IRD). Solo incluye preguntas que aportan al calculo (beta/X) o que el sistema necesita como anclas especiales.",
    "ultima_actualización": "25/06/2026"
  },
  "urls": {
    "base": "https://ingenieria.campus.mdp.edu.ar",
    "curso_id": 1732,
    "cmids": {
      "encuesta_inicial": 54062,
      "encuesta_cuatrimestral": 54284,
      "db_solicitudes": 54783,
      "db_logs": 54784,
      "db_historico": 54788,
      "db_1er_anio": 54789,
      "db_historico_1er_anio": 54791,
      "db_historico_general": 54862,
      "db_historial_asistencias": 54864,
      "db_control_encuestas": 54984
    },
    "dataids": {
      "db_solicitudes": 15,
      "db_logs": 16,
      "db_historico": 18,
      "db_1er_anio": 19,
      "db_historico_1er_anio": 20,
      "db_historico_general": 21,
      "db_historial_asistencias": 22,
      "db_control_encuestas": 24
    }
  },
  "umbrales": {
    "threshold_ird": 40,
    "threshold_ird_red": 80,
    "cooldown_actualizar_seg": 30,
    "cuatrimestres_desercion": 2,
    "historico_delay_ms": 500,
    "page_size_paneles": 30,
    "cooldown_control_encuestas_dias": 14
  },
  "encuesta_inicial": {
    "cmid": 54062,
    "preguntas": [
      {
        "id": "Orientación de tu colegio secundario",
        "tipo": "seleccion_unica",
        "beta": 0.5,
        "max_value": 0.2,
        "respuestas": { "Técnico": 0, "Bachiller": 0.2 }
      },
      {
        "id": "¿Cual es el máximo nivel académico alcanzado por alguno de tus Padres/Tutores?",
        "tipo": "seleccion_unica",
        "beta": 1,
        "max_value": 0.8,
        "respuestas": {
          "No posee": 0.8,
          "Primario completo": 0.6,
          "Secundario completo": 0.3,
          "Terciario - Universitario completo": 0.1
        }
      },
      {
        "id": "(CARRERA) ¿Es tu primera carrera universitaria dentro de la facultad?",
        "tipo": "si_no",
        "beta": 0.5,
        "max_value": 0.3,
        "respuestas": { "Si": 0.3, "No": 0 }
      },
      {
        "id": "¿Cuántas personas tenes a cargo?",
        "tipo": "seleccion_unica",
        "beta": 2,
        "max_value": 1,
        "respuestas": {
          "1": 0.25,
          "2": 0.5,
          "3": 0.75,
          "Ninguna": 0,
          "4 o mas": 1
        }
      },
      {
        "id": "(TRABAJO) ¿Trabaja actualmente?",
        "tipo": "si_no",
        "beta": 1.5,
        "max_value": 0.45,
        "respuestas": {
          "No": 0,
          "Sí": "calculado en código según subpregunta"
        },
        "subpreguntas": [
          {
            "id": "¿Cuántas horas semanales trabajas?",
            "tipo": "seleccion_unica",
            "condicion": "Sí",
            "respuestas": {
              "Menos de 5hs": 0,
              "Entre 6hs y 20hs": 0.1,
              "Entre 21hs y 40hs": 0.25,
              "Más de 40hs": 0.45
            }
          }
        ]
      },
      {
        "id": "Situación económica",
        "tipo": "seleccion_unica",
        "beta": 2,
        "max_value": 1,
        "respuestas": {
          "1 - Muy mala": 1,
          "2 - Mala": 0.5,
          "3 - Regular": 0.2,
          "4 - Buena": -0.2,
          "5 - Muy buena": -0.5
        }
      },
      {
        "id": "¿Con cuánta disponibilidad de tiempo posees para estudiar?",
        "tipo": "seleccion_unica",
        "beta": 2.5,
        "max_value": 0.9,
        "respuestas": {
          "1 - Muy poco tiempo": 0.9,
          "2 - Poco tiempo": 0.7,
          "3 - Tiempo regular": 0,
          "4 - Tiempo suficiente": -0.2,
          "5 - Mucho tiempo": -0.5
        }
      },
      {
        "id": "¿Cuánto tiempo tardas en llegar a la facultad?",
        "tipo": "seleccion_unica",
        "beta": 1,
        "max_value": 0.25,
        "respuestas": {
          "Menos de 20 minutos": 0,
          "Entre 20 y 40 minutos": 0.08,
          "Entre 41 y 60 minutos": 0.156,
          "Más de 60 minutos": 0.25
        }
      },
      {
        "id": "¿Cómo financiás económicamente tus estudios?",
        "tipo": "seleccion_unica",
        "beta": 1.8,
        "max_value": 1,
        "respuestas": {
          "Beca Estudiantil": -1,
          "Financiamiento Familiar": 0,
          "Financiamiento Propio": 0.5,
          "Otros": null
        }
      },
      {
        "id": "¿Por qué eligió la carrera?",
        "tipo": "seleccion_unica",
        "beta": 0.5,
        "max_value": 0.6,
        "respuestas": {
          "Vocación": 0.2,
          "Salida Laboral": 0.6,
          "Recomendación": 0.4,
          "Otro": null
        }
      }
    ]
  },
  "encuesta_cuatrimestral": {
    "cmid": 54284,
    "preguntas": [
      {
        "id": "(ABANDONAR_MATERIAS) En este cuatrimestre ¿Abandonó alguna materia?",
        "tipo": "si_no",
        "beta": 2,
        "max_value": 1,
        "respuestas": {
          "No": 0,
          "Si": "calculado en código según cantidad de materias abandonadas"
        },
        "subpreguntas": [
          {
            "id": "¿Cuantas materias dejó este cuatrimestre?",
            "tipo": "numerico",
            "condicion": "Si",
            "respuestas": null
          }
        ]
      },
      {
        "id": "Satisfacción con respecto al cuatrimestre cursado",
        "tipo": "seleccion_unica",
        "beta": 1,
        "max_value": 1,
        "respuestas": {
          "1 - No satisfactorio": 1,
          "2 - Poco satisfactorio": 0.5,
          "3 - Regular": 0,
          "4 - Satisfactorio": -0.5,
          "5 - Muy satisfactorio": -1
        }
      },
      {
        "id": "Nivel de estrés que sufrió durante el cuatrimestre",
        "tipo": "seleccion_unica",
        "beta": 1.5,
        "max_value": 0.7,
        "respuestas": {
          "1 - Sin estrés": 0,
          "2 - Estrés bajo": 0.2,
          "3 - Estrés moderado": 0.35,
          "4 - Estrés medio": 0.5,
          "5 - Estrés elevado": 0.7
        }
      },
      {
        "id": "¿Qué tan motivado está a continuar la carrera?",
        "tipo": "seleccion_unica",
        "beta": 2.5,
        "max_value": 1,
        "respuestas": {
          "1 - No estoy motivado": 1,
          "2 - Motivación baja": 0.5,
          "3 - Motivación moderada": 0,
          "4 - Motivación alta": -0.5,
          "5 - Muy motivado": -1
        }
      },
      {
        "id": "¿Qué tan al día estás con el plan de estudios?",
        "tipo": "seleccion_unica",
        "beta": 1.5,
        "max_value": 0.8,
        "respuestas": {
          "1 - Adelantado": -1,
          "2 - Al día": 0,
          "3 - Atrasado un cuatrimestre": 0.25,
          "4 - Atrasado un año": 0.5,
          "5 - Atrasado más de un año": 0.8
        }
      },
      {
        "id": "¿Tenés grupo de estudio/compañeros con los que estudiar?",
        "tipo": "si_no",
        "beta": 1,
        "max_value": 0.4,
        "respuestas": { "Sí": -0.1, "No": 0.4 }
      }
    ]
  },
  "preguntas_especiales": {
    "id_percepcion_riesgo": "(ABANDONAR_CARRERA) ¿Crees que estás en riesgo de abandonar la carrera?",
    "id_anio_ingreso": "¿En qué año ingresaste a la carrera? (Primer cuatrimestre cursado)",
    "id_cuat_ingreso": "¿En qué cuatrimestre?",
    "id_egreso": "(EGRESO) ¿Ha egresado?"
  }
}
```
