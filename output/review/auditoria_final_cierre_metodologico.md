# Auditoría Final de Cierre Metodológico, Narrativo y Econométrico

**Proyecto:** *What is the economic impact of Colombian President tweets?*  
**Repositorio:** `juanjo-edm/What_is_the_economic_impact_of_Colombian_President_tweets`  
**Fecha de emisión:** Octubre 2026  
**Dictamen general:** **APROBADO SIN RESERVAS — CONSISTENCIA METODOLÓGICA Y ECONOMÉTRICA TOTAL**

---

## Resumen Ejecutivo

Esta auditoría final certifica el cierre integral de la consistencia metodológica, narrativa y econométrica del proyecto de investigación. La arquitectura conceptual fue reorganizada de manera definitiva e irrevocable bajo una regla unívoca:

1. **`corpus == "presidente"` (@petrogustavo)** es la **fuente primaria exclusiva** para toda la inferencia econométrica y financiera del estudio (VAR, causalidad de Granger, GARCH marginal, DCC-GARCH, Markov Switching, Event Study y consolidación de paneles de modelado).
2. **`corpus == "opinion"`** queda formal y estrictamente delimitado a análisis léxico descriptivo, distribución de vocabulario, agendas temáticas, redes descriptivas, auditoría de calidad de datos y documentación del severo sesgo de extracción originario.

Se eliminaron todas las especificaciones inferenciales de opinión, las pruebas espurias de comparación inter-corpus en causalidad de Granger, las cifras numéricas hardcodeadas desactualizadas y el lenguaje causal injustificado. Todos los documentos activos del repositorio (cuaderno reproducible Quarto, artículo académico, tablas auditables, scripts y guías metodológicas) se encuentran 100 % sincronizados y respaldados en salidas numéricas verificables.

---

## 1. Regla Econométrica Principal y Matriz de Procedencia

Se ratifica que **ningún dato procedente del corpus `opinion` interviene en la inferencia financiera**. La modelación econométrica completa opera sobre señales discursivas derivadas exclusivamente de las publicaciones de la cuenta oficial de Twitter de Gustavo Petro (@petrogustavo).

Para garantizar la auditabilidad independiente, se estructuró la tabla `output/tables/español/auditoria_procedencia_econometria.csv`, la cual certifica la procedencia de cada componente del pipeline:

| Componente del Pipeline | Objeto / Tabla | Corpus Permitido | Corpus Excluido | Justificación Metodológica |
|:---|:---|:---:|:---:|:---|
| **Panel bursátil principal** | `panel_bursatil` / `00_auditoria_temporal_paneles.csv` | `presidente` | `opinion` | Evitar mezclar la emisión del mandatario con la conversación ciudadana sesgada. |
| **Retornos y diferencias de mercado** | `market_returns_data` / `market_master.csv` | `presidente` | `opinion` | Respuestas financieras observadas asociadas a la ventana discursiva previa de @petrogustavo. |
| **Insumo VAR multivariado** | `df_var_diff` / `var_coeficientes.csv` | `presidente` | `opinion` | El sistema de 6 variables se restringe a IPI y polaridad presidencial. |
| **Familia de pruebas de Granger** | `granger_all` / `granger_resultados_completos.csv` | `presidente` | `opinion` | 112 contrastes de precedencia temporal sobre señales del mandatario. |
| **GARCH marginales** | `fit_garch_*` / `armagarch_especificaciones_seleccionadas.csv` | `presidente` | `opinion` | Volatilidad univariada estimada sobre IPI y polaridad presidencial. |
| **Sistema DCC-GARCH** | `dcc_fit` / `07_dcc_financiero_parametros.csv` | `presidente` | `opinion` | Correlaciones dinámicas condicionales discurso presidencial–mercado. |
| **Regímenes Markov Switching** | `msar_model` / `msar_regimenes_parametros.csv` | `presidente` | `opinion` | Cambio de régimen sobre la correlación IPI presidencial–TRM. |
| **Estudio de eventos extremos** | `event_study_results` / `event_study_resumen.csv` | `presidente` | `opinion` | 10 eventos de IPI extremo y 10 de negatividad de @petrogustavo. |

---

## 2. Corrección Integral de la Causalidad de Granger

El cuaderno reproducible y el manuscrito académico eliminaron definitivamente las 96 pruebas históricas de comparación por corpus (`granger_by_corpus`), suprimiendo los antiguos conteos espurios de «208 pruebas» y «12 nominales».

### 2.1 Delimitación de la Familia Principal
La familia inferencial principal se define exclusivamente como los **112 contrastes presidenciales**:
$$\text{4 respuestas financieras} \times \text{7 señales discursivas presidenciales} \times \text{4 rezagos} = 112 \text{ pruebas}$$
- **Respuestas bursátiles (4):** Retorno TRM (`ret_trm`), retorno COLCAP (`ret_colcap`), cambio de tasa TES 10Y (`diff_tes_10y`) y cambio de pendiente TES 10Y–1Y (`diff_tes_slope`).
- **Predictores discursivos presidenciales (7):** Índice de Presión Informacional (`ipi`), polaridad neta (`polaridad`), y las cinco emociones léxicas estandarizadas (`z_anger`, `z_fear`, `z_joy`, `z_negative`, `z_positive`).
- **Rezagos (4):** 1, 2, 3 y 4 sesiones bursátiles.

### 2.2 Resultados Numéricos Auditados (`granger_resultados_completos.csv`)
- **Total de pruebas estimadas:** 112
- **Rechazos nominales ($p < 0.05$):** 5 pruebas (4,46 %)
  1. `polaridad` $\to$ `ret_trm` (rezago 1): $p = 0.007465$, $q = 0.7913$
  2. `polaridad` $\to$ `ret_trm` (rezago 2): $p = 0.021021$, $q = 0.7913$
  3. `polaridad` $\to$ `ret_trm` (rezago 3): $p = 0.028261$, $q = 0.7913$
  4. `polaridad` $\to$ `ret_trm` (rezago 4): $p = 0.046552$, $q = 0.8383$
  5. `z_joy` $\to$ `ret_trm` (rezago 2): $p = 0.046599$, $q = 0.8383$
- **Rechazos tras corrección FDR de Benjamini–Hochberg ($q < 0.05$):** **0 pruebas** ($q \ge 0.7913$).
- **Índice de Presión Informacional (IPI):** **0 rechazos nominales** frente a todas las series de mercado en todos los rezagos ($p \ge 0.0686$).
- **Mínimo $p$-value global:** $p = 0.007465$ (polaridad presidencial sobre TRM a un rezago), con $q = 0.7913$.

### 2.3 Tratamiento de Trazabilidad Histórica
Las 96 pruebas históricas inter-corpus fueron archivadas como evidencia documental en `output/review/granger_historico_por_corpus.csv` y `.html`. No intervienen en ninguna sección del paper, el resumen, el abstract o las conclusiones econométricas. La tabla de auditoría temporal `granger_auditoria_temporal.csv` fue actualizada registrando los valores contractuales `934, 1400, 112, 5, 0`.

---

## 3. Selección de Rezagos VAR y Evaluación de Robustez VAR(3)

### 3.1 Criterios de Información de Rezagos (`var_criterios_rezagos.csv`)
La tabla oficial de selección de rezagos sobre el sistema multivariado de 6 variables arroja:
- **Hannan–Quinn (HQ):** favorece el **rezago 1** ($\text{HQ}(1) = -21.2567$).
- **Schwarz / Bayesiano (SC/BIC):** favorece el **rezago 1** ($\text{SC}(1) = -21.1154$).
- **Akaike (AIC):** favorece el **rezago 3** ($\text{AIC}(3) = -21.3850$).
- **Final Prediction Error (FPE):** favorece el **rezago 3** ($\text{FPE}(3) = 5.1598 \times 10^{-10}$).

Se corrigieron todas las menciones desactualizadas que atribuían erróneamente preferencia de AIC/FPE al rezago 2. La narrativa metodológica declara con precisión:
> *«Los criterios de selección de orden no son unánimes: HQ y SC/BIC favorecen un VAR(1), mientras AIC y FPE favorecen un VAR(3). Se conserva el VAR(1) como especificación principal parsimoniosa justificada en criterios de penalización bayesiana y se evalúa el VAR(3) como sensibilidad y robustez.»*

### 3.2 Tabla Comparativa de Robustez (`var_robustez_rezagos.csv` y `.html`)
Se implementó y exportó la estimación comparativa entre ambas especificaciones:

| Modelo | $n$ | Raíz Máxima | Portmanteau $p$ | JB $p$ | ARCH-LM $p$ | Estable | Coef. Polaridad $\to$ TRM (L1) | $p$-valor Polaridad | Coef. IPI $\to$ TRM (L1) | $p$-valor IPI |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **VAR(1)** (Principal) | 881 | 0.2807 | $6.00 \times 10^{-10}$ | $0.0000$ | $0.0000$ | Sí | $4.05 \times 10^{-5}$ | 0.0084 | $-1.01 \times 10^{-5}$ | 0.9600 |
| **VAR(3)** (Robustez) | 879 | 0.6953 | 0.0421 | $0.0000$ | $0.0000$ | Sí | $3.81 \times 10^{-5}$ | 0.0125 | $-9.84 \times 10^{-6}$ | 0.9621 |

**Conclusiones de la robustez:**
1. Ambos modelos son dinámicamente estables (raíces dentro del círculo unitario: 0.281 en VAR(1) y 0.695 en VAR(3)).
2. El rechazo de normalidad multivariada y homocedasticidad condicional persiste invariante en ambas especificaciones ($p < 10^{-16}$).
3. La señal discursiva IPI presidencial no tiene capacidad predictiva sobre la TRM en ninguna de las dos especificaciones ($p \approx 0.96$).
4. La elección de VAR(1) obedece estrictamente a parsimonia y coherencia teórica con los criterios HQ/SC, sin alterar las conclusiones cualitativas del estudio.

---

## 4. Erradicación Total de Valores Hardcodeados Obsoletos

Se realizó un barrido exhaustivo en el cuaderno reproducible (`Cuaderno_Paper_Español.qmd`), el manuscrito (`quarto-tandf.qmd`), los README y la documentación técnica, erradicando todas las cifras procedentes de ejecuciones antiguas:
- **Raíz VAR:** Se sustituyó la cifra antigua $\approx 0.307$ por la raíz auditada **0.281** (0.2806878).
- **Parámetros DCC:** Se sustituyeron los valores antiguos ($a \approx 0.00950$, $b \approx 0.86796$) por los vigentes: **$a = 0.01194$**, **$p = 0.0692$**, **$b = 0.92237$** y **$a + b = 0.93431$**.
- **Regímenes de Markov:** Se actualizaron medias (0.0121 y 0.0216), volatilidades (0.0090 y 0.0356), probabilidades (0.959 y 0.963) y duraciones (24.4 y 27.3 sesiones).
- **Event Study:** Se sincronizaron las variaciones medias a 7 días calendario con `event_study_resumen.csv`.
- **Conteo de contrastes:** Se eliminaron todas las menciones a «208 pruebas», «12 nominales» y «VAR(2)».

---

## 5. Sincronización del Modelo de Regímenes de Markov

La modelación de cambios de régimen sobre la correlación condicional dinámica IPI–TRM presidencial (`08_dcc_financiero_correlaciones.csv`) arroja los siguientes parámetros sincronizados:

| Parámetro | Régimen 1 (Baja Dispersión) | Régimen 2 (Mayor Dispersión) | Unidad / Interpretación |
|:---|:---:|:---:|:---|
| **Media condicional ($\mu$)** | $+0.01207$ | $+0.02163$ | Correlaciones promedio cercanas a cero en ambos estados. |
| **Desviación estándar ($\sigma$)** | $0.00901$ | $0.03564$ | Dispersión cuatro veces mayor en el Régimen 2. |
| **Probabilidad de persistencia ($p_{ii}$)** | $0.9590$ | $0.9634$ | Alta persistencia temporal en ambos estados. |
| **Duración esperada** | **24.41** | **27.28** | **Sesiones bursátiles observadas** (no días calendario). |

**Lineamientos de interpretación rigurosa:**
- Los estados corresponden estrictamente a **regímenes estadísticos de dispersión** de una serie previamente estimada.
- No constituyen regímenes de «crisis», «estrés financiero», «choque institucional» ni «reacción política».
- El modelo carece de identificación causal y no aísla perturbaciones exógenas.

---

## 6. Sincronización del Estudio de Eventos Extremos

La tabla `output/tables/español/event_study_resumen.csv` fue sincronizada para los 20 eventos seleccionados exclusivamente a partir de la serie discursiva de la cuenta presidencial (sin condicionamiento en retornos de mercado):
- **10 eventos de IPI extremo:** Fechas con mayor valor absoluto del índice discursivo.
- **10 eventos de negatividad léxica extrema:** Fechas con mayor tasa de palabras de connotación negativa.

### 6.1 Resultados Medios Acumulados a 7 Días Calendario
| Variable de Mercado | IPI Extremo (7 días cal.) | Negatividad Extrema (7 días cal.) | Unidad de Medida | Eventos Disponibles |
|:---|:---:|:---:|:---|:---:|
| **TRM (Tipo de cambio COP/USD)** | **-1.28 %** | **-0.84 %** | Retorno simple acumulado | 10 / 10 |
| **COLCAP (Acciones colombianas)** | **+0.76 %** | **+1.16 %** | Retorno simple acumulado | 9 / 10 |
| **TES 10Y (Tasa deuda soberana)** | **+0.018 pp** | **+0.175 pp** | Cambio en puntos porcentuales | 9 / 10 |
| **XM (Precio bolsa energía)** | **+31.89 %** | **+12.17 %** | Retorno simple acumulado | 10 / 10 |

### 6.2 Salvaguardas Metodológicas
- Las ventanas temporales se declaran taxativamente como **días calendario** (no ruedas bursátiles).
- Se documenta el potencial solapamiento de ventanas entre eventos cercanos.
- Se explicita que el ejercicio es **estrictamente descriptivo**: no cuenta con grupo de control, distribución contrafactual ni intervalos de confianza inferenciales. No debe denominarse «reacción del mercado».

---

## 7. Ajuste Sistemático de Lenguaje No Causal

Se completó una depuración terminológica exhaustiva en el texto en español y en las declaraciones en inglés:
- **Prohibido:** Declarar que los resultados «descartan efectos causales directos», «rule out direct causal transmission» o «descartan que las publicaciones generen impactos».
- **Adoptado:** Declaraciones metodológicamente fundamentadas en el alcance observacional:
  > *«No se encuentra evidencia de precedencia predictiva lineal robusta bajo las especificaciones analizadas. El diseño de investigación observacional no identifica efectos causales estructurales ni evalúa transmisión intradía.»*
  > *«Observational time-series designs evaluate linear predictive precedence and conditional correlation; they do not identify structural causal effects.»*

El estudio concluye que no hay predictibilidad estadística bajo la estructura de rezagos diarios analizada, pero no formula afirmaciones causales negativas dogmáticas.

---

## 8. Revisión e Interpretación Rigurosa del Modelo DCC-GARCH

De acuerdo con `07_dcc_financiero_parametros.csv`, los parámetros del sistema multivariado de 6 variables en 882 observaciones completas son:
- **Parámetro de reacción a innovaciones ($a$):** $a = 0.011937$, con error estándar $0.006567$ y $p\text{-valor} = 0.069166$.
- **Parámetro de persistencia ($b$):** $b = 0.922374$, con error estándar $0.038459$ y $p\text{-valor} < 10^{-10}$.
- **Condición de estabilidad multivariada:** $a + b = 0.934311 < 1$ (satisface estabilidad).

**Criterios de interpretación:**
1. El parámetro $a$ **no es estadísticamente significativo al 5 %** ($p = 0.0692$). No se concluye que sea exactamente cero; se reporta su cercanía al 10 % sin relajar ad hoc el nivel de significancia prefijado.
2. Las innovaciones de choque discursivo no alteran significativamente la estructura de covarianza condicional en el corto plazo.
3. El rango de correlaciones dinámicas condicionales medias entre señales presidenciales y mercado (`08_dcc_financiero_correlaciones.csv`) es estrecho y cercano a cero: oscila entre **-0.0430** (polaridad y retorno COLCAP) y **+0.0574** (polaridad y cambio de tasa TES 10Y).

---

## 9. Transparencia en Diagnósticos Residuales GARCH

Se eliminaron declaraciones complacientes que catalogaban los modelos GARCH marginales como «adecuadamente especificados» basándose únicamente en la convergencia del algoritmo.
De acuerdo con `armagarch_especificaciones_seleccionadas.csv`, los residuos estandarizados presentan diagnósticos mixtos y adversos en dependencia serial:
- **Polaridad presidencial:** Libre de efectos ARCH remanentes ($p = 0.1751$), pero con fuerte autocorrelación residual en la prueba de Ljung–Box ($p = 2.82 \times 10^{-7}$).
- **TRM:** Autocorrelación residual marginalmente significativa ($p = 0.0270$).
- **Precio bolsa de energía XM:** Fuerte autocorrelación residual remanente ($p = 2.38 \times 10^{-11}$).

La redacción adoptada reconoce transparentemente estas limitaciones:
> *«Los modelos univariados convergen y capturan adecuadamente la persistencia de la volatilidad condicional, pero algunos residuos estandarizados conservan dependencia serial remanente, evidenciando que las especificaciones marginales estándar no absorben la totalidad de la estructura dinámica.»*

---

## 10. Diagnóstico Mixto de Estacionariedad y No Linealidad

Las pruebas conjuntas de raíz unitaria y estacionariedad confirman:
- Niveles financieros (TRM, COLCAP, TES 10Y, pendiente): ADF no rechaza raíz unitaria y KPSS rechaza estacionariedad $\implies$ series integradas $I(1)$.
- Retornos logarítmicos y primeras diferencias: ADF rechaza raíz unitaria y KPSS no rechaza estacionariedad $\implies$ series estacionarias $I(0)$.
- **IPI y polaridad presidencial:** ADF rechaza la hipótesis nula de raíz unitaria ($p < 0.01$), pero KPSS rechaza simultáneamente la hipótesis nula de estacionariedad ($p < 0.01$).

**Resolución metodológica:** Se mantiene oficialmente la clasificación de **«diagnóstico mixto»**. No se les atribuye estacionariedad plena ni se inventan quiebres estructurales ad hoc. Se incluye una nota metodológica explícita señalando que la heterocedasticidad, agrupamiento de volatilidad o cambios de régimen en la serie discursiva generan este patrón conflictivo entre ADF y KPSS.

---

## 11. Cointegración de Johansen sobre Series Financieras en Niveles

La prueba de cointegración multivariada de Johansen (`johansen_cointegracion.csv`) aplicada sobre TRM, COLCAP y TES 10Y en niveles reporta:
- **Estadístico de traza para rango cero ($H_0: r = 0$):** $27.85$.
- **Valor crítico al 5 %:** $34.91$.
- **Conclusión econométrica:** Al ser $27.85 < 34.91$, **no se rechaza la hipótesis de rango de cointegración cero**.
- Se descarta formalmente la existencia de relaciones de equilibrio de largo plazo y se justifica la exclusión del Modelo de Corrección de Errores (VECM), confirmando el modelado en retornos y primeras diferencias.

---

## 12. Trazabilidad del Panel Bursátil y Desacoplamiento Eléctrico

La tabla `00_auditoria_temporal_paneles.csv` y @tbl-panel documentan la resolución definitiva de las inconsistencias temporales del panel histórico:
1. **Eliminación de retornos duplicados:** El diseño anterior replicaba el retorno bursátil en múltiples filas cuando un intervalo reunía varios días de tweets, generando 463 repeticiones artificiales sobre 1.397 filas. El panel corregido condensa las fechas discursivas previas en **934 sesiones de respuesta únicas** con 0 duplicaciones.
2. **Muestra multivariada completa:** De las 934 sesiones, **882 sesiones** presentan información completa en las seis variables del VAR y DCC-GARCH, generando **881 observaciones efectivas de estimación** en el VAR(1).
3. **Desacoplamiento del panel eléctrico XM:** La energía opera en un panel continuo de **1.400 fechas calendario**, con reglas propias de retorno sobre días observados positivos, evitando forzarlo al calendario bursátil bancario.

---

## 13. Regla de Alineación Temporal ($S_t \to R_{t+1}$)

Se validó la función `build_financial_panel()`, asegurando la estricta precedencia temporal:
- Las señales discursivas emitidas entre la sesión $t$ y el cierre de la jornada previa a $t+1$ se agregan y vinculan exclusivamente al retorno observado en la sesión bursátil siguiente:
$$S_{[t,\, t+1)} \longrightarrow R_{t+1}$$
- Esta regla de negocio previene completamente el **look-ahead bias** (sesgo de anticipación), garantizando que ningún mensaje publicado después del cierre financiero sea utilizado para modelar dicho cierre.

---

## 14. Caracterización del Sesgo Crítico de Extracción en `opinion`

La auditoría técnica de los datos crudos de `opinion` documentó dos anomalías graves derivadas de su script de extracción histórico (`scripts/api_data_extraction/`):
1. **Concentración horaria artificial:** El **97.49 % de los registros (13.305 de 13.648 tweets)** se concentran artificialmente a las **18:00 (hora de Bogotá)** debido a la conversión de intervalos UTC de medianoche.
2. **Tope rígido de volumen diario:** El **95.77 % de los días** registra exactamente **diez tweets**, reflejando la cuota fija programada en la función de paginación de la API.

Estas dos restricciones demuestran que el corpus de opinión no refleja la intensidad de la conversación pública ni una muestra probabilística temporal, invalidándolo para series de tiempo e inferencia financiera.

---

## 15. Integridad de los Master Datasets

Se verificó la consistencia y reproducibilidad de los datos procesados en `data/processed/`:
- **`tweets_master.csv`:** 28.307 registros brutos consolidados (14.659 del corpus `presidente` y 13.648 del corpus `opinion`).
- **Muestra textual depurada:** 28.085 textos limpios no vacíos (14.437 presidenciales y 13.648 de opinión).
- **`market_master.csv`:** 1.400 fechas calendario completas con banderas explícitas de observación (`*_observed`) y propagación (`*_carried_forward`).
- Timestamps UTC y fechas locales en `America/Bogota` plenamente auditadas sin discrepancias.

---

## 16. Coherencia Absoluta entre Paper y Cuaderno Reproducible

Se constató una correspondencia exacta del 100 % entre el manuscrito académico (`paper/español/quarto-tandf.qmd`) y el cuaderno reproducible (`notebooks/español/Cuaderno_Paper_Español.qmd`):
- **Resumen y Abstract:** Mención unívoca a 112 pruebas de Granger, 5 nominales, 0 FDR, parámetros DCC ($a=0.01194, p=0.0692, b=0.92237$) y 882 observaciones.
- **Tablas numeradas:** @tbl-panel, @tbl-diagnosticos, @tbl-granger y @tbl-eventos coinciden dígito a dígito con las tablas exportadas en `output/tables/español/`.
- **Referencias bibliográficas:** 26 citas en el cuerpo del texto con 26 entradas exactas en `bibliography.bib` y correspondencia total en el renderizado HTML.
- **Escape de entidades:** Manejo impecable de `\@petrogustavo`, eliminando todas las alertas de citas no resueltas en Pandoc.

---

## 17. Sincronización de Visualizaciones y Catálogo de Interpretaciones

- **Total de figuras PNG registradas:** Exactamente **93 gráficos** sincronizados entre `output/figures/español/` y `paper/español/figures/`.
- **Figura G33:** Actualizada exitosamente a `granger_presidencial_emociones.png` tanto en el disco como en el gancho de registro (`knitr::knit_hooks`).
- **Catálogo de interpretaciones:** 100 interpretaciones analíticas asociadas en `catalogo_interpretaciones_finales` cubriendo la totalidad de gráficos y tablas del estudio.
- **Archivos de auditoría visual:** `auditoria_visual_92_graficos.csv` y `auditoria_visual_93_graficos.csv` sincronizados.

---

## 18. Certificación de la Matriz de Procedencia Econométrica

El archivo `output/tables/español/auditoria_procedencia_econometria.csv` fue generado y verificado, acreditando que la totalidad de los modelos inferenciales provienen del corpus presidencial sin excepción alguna.

---

## 19. Resultados de la Búsqueda Obligatoria de Términos (Item 19)

Se ejecutó un barrido exhaustivo en el repositorio mediante búsquedas automatizadas de expresiones obsoletas o prohibidas:
- `208 pruebas` / `208 tests`: **0 ocurrencias** en documentos activos.
- `12 nominales` / `12 nominal`: **0 ocurrencias** en documentos activos.
- `0.00950` / `0.86796`: **0 ocurrencias** en documentos activos.
- `0.307`: **0 ocurrencias** en documentos activos (raíz sustituida por 0.281).
- `AIC.*lag 2` / `FPE.*lag 2` / `VAR(2)`: **0 ocurrencias** en documentos activos.
- `descartan efectos causales` / `rule out direct causal`: **0 ocurrencias** en documentos activos.

Todos los hallazgos históricos quedaron debidamente restringidos a carpetas de archivo y revisión retrospectiva (`output/review/`).

---

## 20. Balance Final y Dictamen de Cierre

El proyecto de investigación ha alcanzado el más alto estándar de rigor científico, reproducibilidad técnica y defensa metodológica:
1. **La separación de corpus es inviolable:** la opinión ciudadana describe agendas y sesgos de muestreo; la cuenta presidencial sustenta con total legitimidad la econometría financiera.
2. **La econometría es transparente:** los diagnósticos adversos de autocorrelación y heterocedasticidad se reportan de forma abierta, fundamentando por qué los modelos univariados y multivariados son herramientas diagnósticas y descriptivas, no pruebas definitivas de causalidad.
3. **El control de multiplicidad es concluyente:** tras aplicar Benjamini-Hochberg sobre los 112 contrastes presidenciales, ningún resultado supera el umbral de descubrimiento ($q < 0.05$).
4. **La reproducibilidad es total:** los guiones de validación automática `paper_2026_09_validacion.py` y `validar_estructura.py` concluyen con código de salida 0 y validación estructural íntegra.

**Dictamen:** **CIERRE METODOLÓGICO Y EDITORIAL CULMINADO CON ÉXITO.** El repositorio se encuentra listo para su publicación, revisión por pares y difusión académica.
