# Reporte de Cálculo de Índice de Riesgo de Deserción (IRD)

Este documento detalla el cálculo del IRD desde cero para **Gian Luca Arrigoni Carrara** y **Martin Esteban Girau**, contrastando el **Cálculo Teórico Puro** contra el **Cálculo Ejecutado por el Código Real** en [tablero_principal.html](scripts/tablero_principal.html) según [config_3.md](config_3.md).

---

## 1. Parámetros de Configuración y Puntaje Máximo Teórico ($Z_{max}$)

El valor de $Z_{max}$ se calcula dinámicamente como la suma de los aportes máximos posibles de todas las preguntas involucradas:

$$Z_{max} = \sum (\beta_i \times X_{max, i}) = \mathbf{17.625}$$

---

## 2. Análisis de Discrepancias (¿Por qué el código arroja resultados diferentes?)

Al examinar [tablero_principal.html](scripts/tablero_principal.html), se identificaron dos desajustes de texto exacto que hacen que el código web evalúe a `0` el aporte de dos preguntas en ambos alumnos:

1. **¿Cuántas personas tenes a cargo?**
   * **Respuesta en el CSV:** `"4 o más"` (con tilde)
   * **Clave en la Configuración:** `"4 o mas"` (sin tilde)
   * **Efecto en el código:** El código JS realiza `p.respuestas[valText]`. Al buscar `"4 o más"`, da `undefined` y se asigna **$X = 0$** (se pierde un aporte de **2.0** en $Z$).

2. **¿Cuánto tiempo tardas en llegar a la facultad?**
   * **Cabecera en el CSV de Moodle:** `"¿Cuánto tiempo tardas en llegar a la facultad? "` (con espacio al final)
   * **Identificador en la Configuración (`p.id`):** `"¿Cuánto tiempo tardas en llegar a la facultad?"` (sin espacio al final)
   * **Efecto en el código:** El código JS busca `rowInic[p.id]`. Al no haber coincidencia exacta de la cabecera, devuelve `undefined`, por lo que la pregunta se salta y se asigna **$X = 0$** (se pierde un aporte de **0.25** en $Z$).

Debido a esto, **en el código real ambos alumnos pierden $2.25$ puntos de su puntaje $Z$**.

---

## 3. Desglose y Comparativa de Resultados

### 3.1 Gian Luca Arrigoni Carrara

* **Se percibe en riesgo:** `No`
* **Semáforo Real:** 🟡 **Amarillo** (Seguimiento y tutoría)

| Pregunta / Variable | Cálculo Teórico | Código en `tablero_principal.html` | Razón del cambio / Estado |
| :--- | :---: | :---: | :--- |
| **Encuesta Inicial** | | | |
| 1. Orientación colegio | 0.100 | 0.100 | Coincide (`Bachiller` $\rightarrow 0.5 \times 0.2$) |
| 2. Nivel padres | 0.100 | 0.100 | Coincide (`Terciario...` $\rightarrow 1.0 \times 0.1$) |
| 3. Primera carrera | 0.150 | 0.150 | Coincide (`Si` $\rightarrow 0.5 \times 0.3$) |
| 4. Personas a cargo | **2.000** | **0.000** | **Discrepancia:** `"4 o más"` no coincide con `"4 o mas"` |
| 5. Horas de trabajo | 0.675 | 0.675 | Coincide (`Sí`, `Más de 40hs` $\rightarrow 1.5 \times 0.45$) |
| 6. Situación económica | 2.000 | 2.000 | Coincide (`1 - Muy mala` $\rightarrow 2.0 \times 1.0$) |
| 7. Disponibilidad | 2.250 | 2.250 | Coincide (`1 - Muy poco tiempo` $\rightarrow 2.5 \times 0.9$) |
| 8. Tiempo de viaje | **0.250** | **0.000** | **Discrepancia:** Espacio al final en cabecera CSV |
| 9. Financiamiento | -1.800 | -1.800 | Coincide (`Beca Estudiantil` $\rightarrow 1.8 \times -1.0$) |
| 10. Por qué eligió | 0.200 | 0.200 | Coincide (`Recomendación` $\rightarrow 0.5 \times 0.4$) |
| **Encuesta Cuatrimestral** | | | |
| 11. Abandonó materias | 2.000 | 2.000 | Coincide (`Si`, `4` materias dejadas $\rightarrow 2.0 \times 1.0$) |
| 12. Satisfacción | 1.000 | 1.000 | Coincide (`1 - No satisfactorio` $\rightarrow 1.0 \times 1.0$) |
| 13. Nivel de estrés | 1.050 | 1.050 | Coincide (`5 - Estrés elevado` $\rightarrow 1.5 \times 0.7$) |
| 14. Motivación | 1.250 | 1.250 | Coincide (`2 - Motivación baja` $\rightarrow 2.5 \times 0.5$) |
| 15. Al día con plan | 1.200 | 1.200 | Coincide (`5 - Atrasado más de un año` $\rightarrow 1.5 \times 0.8$) |
| 16. Grupo de estudio | 0.400 | 0.400 | Coincide (`No` $\rightarrow 1.0 \times 0.4$) |
| **Puntaje Bruto ($Z$)** | **12.825** | **10.575** | **Diferencia de -2.25 puntos** |
| **Resultado IRD** | **72.8%** | **60.0%** | $$IRD = (\frac{Z}{17.625}) \times 100$$ |

---

### 3.2 Martin Esteban Girau

* **Se percibe en riesgo:** `Sí`
* **Semáforo Real:** 🔴 **Rojo** (Intervención inmediata)

| Pregunta / Variable | Cálculo Teórico | Código en `tablero_principal.html` | Razón del cambio / Estado |
| :--- | :---: | :---: | :--- |
| **Encuesta Inicial** | | | |
| 1. Orientación colegio | 0.000 | 0.000 | Coincide (`Técnico` $\rightarrow 0.5 \times 0.0$) |
| 2. Nivel padres | 0.300 | 0.300 | Coincide (`Secundario completo` $\rightarrow 1.0 \times 0.3$) |
| 3. Primera carrera | 0.150 | 0.150 | Coincide (`Si` $\rightarrow 0.5 \times 0.3$) |
| 4. Personas a cargo | **2.000** | **0.000** | **Discrepancia:** `"4 o más"` no coincide con `"4 o mas"` |
| 5. Horas de trabajo | 0.675 | 0.675 | Coincide (`Sí`, `Más de 40hs` $\rightarrow 1.5 \times 0.45$) |
| 6. Situación económica | 2.000 | 2.000 | Coincide (`1 - Muy mala` $\rightarrow 2.0 \times 1.0$) |
| 7. Disponibilidad | 2.250 | 2.250 | Coincide (`1 - Muy poco tiempo` $\rightarrow 2.5 \times 0.9$) |
| 8. Tiempo de viaje | **0.250** | **0.000** | **Discrepancia:** Espacio al final en cabecera CSV |
| 9. Financiamiento | 0.900 | 0.900 | Coincide (`Financiamiento Propio` $\rightarrow 1.8 \times 0.5$) |
| 10. Por qué eligió | 0.100 | 0.100 | Coincide (`Vocación` $\rightarrow 0.5 \times 0.2$) |
| **Encuesta Cuatrimestral** | | | |
| 11. Abandonó materias | 2.000 | 2.000 | Coincide (`Si`, `4` materias dejadas $\rightarrow 2.0 \times 1.0$) |
| 12. Satisfacción | 1.000 | 1.000 | Coincide (`1 - No satisfactorio` $\rightarrow 1.0 \times 1.0$) |
| 13. Nivel de estrés | 1.050 | 1.050 | Coincide (`5 - Estrés elevado` $\rightarrow 1.5 \times 0.7$) |
| 14. Motivación | 2.500 | 2.500 | Coincide (`1 - No estoy motivado` $\rightarrow 2.5 \times 1.0$) |
| 15. Al día con plan | 1.200 | 1.200 | Coincide (`5 - Atrasado más de un año` $\rightarrow 1.5 \times 0.8$) |
| 16. Grupo de estudio | 0.400 | 0.400 | Coincide (`No` $\rightarrow 1.0 \times 0.4$) |
| **Puntaje Bruto ($Z$)** | **16.775** | **14.525** | **Diferencia de -2.25 puntos** |
| **Resultado IRD** | **95.2%** | **82.4%** | $$IRD = (\frac{Z}{17.625}) \times 100$$ |
