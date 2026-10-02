# Informe de Auditoría y Reestructuración Metodológica: Transición al Corpus Presidencial (@petrogustavo)

**Fecha:** Octubre 2026  
**Proyecto:** *Comunicación presidencial y mercados financieros en Colombia: evidencia textual y de series de tiempo*  
**Autoría de revisión:** Equipo de investigación y auditoría econométrica  
**Repositorio:** `juanjo-edm/What_is_the_economic_impact_of_Colombian_President_tweets`

---

## 1. Justificación Metodológica del Cambio de Arquitectura

### 1.1 El problema empírico del corpus `opinion`
Durante la auditoría integral de los datos primarios de Twitter/X almacenados en `data/raw/twitter/` y consolidados en `data/processed/tweets_master.csv`, se identificó una anomalía estructural en el proceso histórico de recolección de los mensajes agrupados bajo la etiqueta `opinion` ("Conversación pública sobre Gustavo Petro"):

1. **Concentración horaria artificial:** De los 13.648 registros del corpus `opinion`, **13.305 tweets (97,49%)** registran exactamente la marca temporal de las 18:00 horas (hora local de Bogotá, `America/Bogota`).
2. **Topes diarios de extracción:** En **1.291 de los 1.348 días con datos (95,77%)**, la recolección contiene exactamente un tope de 10 tweets diarios.
3. **Ausencia de cobertura en el horario de negociación:** Al concentrarse masivamente a las 18:00 (después del cierre bursátil colombiano a las 13:00 / 16:00), la serie carece de representatividad sobre la dinámica intrasectorial o interdiaria.

Esta patología de recolección no invalida el contenido léxico de los mensajes para propósitos lingüísticos descriptivos (frecuencias, colocaciones, n-gramas), pero **invalida completamente cualquier métrica que involucre el tiempo o el volumen**:
* La intensidad diaria observada es un artefacto de la cuota de la API.
* El Índice de Presión Informacional (IPI) calculado sobre `opinion` no mide la atención pública real, sino la regularidad del scraper.
* Cualquier contraste de precedencia temporal (Granger), correlación dinámica (DCC-GARCH) o ventana de eventos (Event Study) construido sobre este corpus confunde el comportamiento del algoritmo de extracción con el pulso del mercado financiero.

### 1.2 Principio rector de la reestructuración
La arquitectura del proyecto se reestructuró bajo la siguiente regla estricta de separación:

$$\begin{aligned}
\text{ANTERIOR:} \quad & \text{presidente} + \text{opinion} \longrightarrow \text{señales agregadas} \longrightarrow \text{econometría financiera} \\
\text{ACTUAL:} \quad & \begin{cases} 
\mathbf{@petrogustavo} \longrightarrow \text{señales presidenciales} \longrightarrow \text{alineación temporal} \longrightarrow \text{mercados} \longrightarrow \mathbf{econometría} \\
\mathbf{opinion} \longrightarrow \text{auditoría de sesgo} + \text{descripción textual secundaria} + \text{documentación de límites}
\end{cases}
\end{aligned}$$

Se prohíbe de forma explícita el uso de `corpus == "opinion"` para VAR, Granger, GARCH, DCC-GARCH, Markov Switching, Event Study o inferencia financiera alguna.

---

## 2. Matriz Comparativa: Resultados Anteriores vs. Pipeline Presidencial

La siguiente tabla resume el impacto cuantitativo de reestimar todo el pipeline econométrico y financiero exclusivamente con la actividad de `@petrogustavo` (`corpus == "presidente"`), utilizando los contratos de datos auditados en `data/processed/`.

| Dimensión Analítica | Modelo Anterior (Centrado en Opinión / Mixto) | Modelo Actual (Exclusivamente @petrogustavo) | Justificación e Interpretación Económica |
| :--- | :--- | :--- | :--- |
| **Objeto de estudio principal** | Conversación pública y mensajes presidenciales indistintos | Comunicación directa y verificable de `@petrogustavo` | Elimina la contaminación del sesgo horario y delimita la responsabilidad discursiva al mandatario. |
| **Casos completos modelables** | $N = 898$ sesiones bursátiles | $N = 882$ sesiones bursátiles ($N = 881$ en VAR) | Reducción debida a días hábiles sin publicaciones presidenciales registradas en la ventana empírica. |
| **Índice discursivo (IPI)** | IPI opinión ($\bar{x} = 0,037$, $\sigma = 1,054$, rango $[-3,72; 5,28]$) | IPI presidencial ($\bar{x} = 0,005$, $\sigma = 1,226$, rango $[-11,47; 10,68]$) | Estandarizado estrictamente dentro del universo presidencial ($z(\bar{s}_d) \cdot z(\log(1+n_d^{pres}))$). |
| **Cointegración (Johansen)** | Traza $= 29,83 < 34,91$ ($r=0$ no rechazado) | Traza $= 27,8548 < 34,91$ ($r=0$ no rechazado) | Sistema financiero (TRM, COLCAP, TES 10Y en niveles): sin vectores de cointegración que justifiquen VECM. |
| **Estabilidad VAR(1)** | Raíz máxima $= 0,3060$; Portmanteau $p = 2,45 \times 10^{-12}$ | Raíz máxima $= 0,2807$; Portmanteau $p = 6,00 \times 10^{-10}$ | El sistema en diferencias es estrictamente estable (raíz máxima $< 1$). En robustez, VAR(3) mantiene estabilidad (raíz $= 0,695$). |
| **Causalidad de Granger (Total)** | 208 contrastes (incluyendo 96 de opinión): 19 nominales | 112 contrastes presidenciales puros: 5 nominales ($p < 0,05$), **0 significativos tras FDR** ($q < 0,05$) | Se eliminó la familia de 96 pruebas de opinión del pipeline inferencial. El resultado descarta precedencia lineal robusta. |
| **Granger: Familia Presidencial** | 11 nominales / 0 FDR en subconjunto temático | 5 nominales / 0 FDR (mínimo $p = 0,007465$, $q = 0,791$) | Específicamente, el IPI presidencial no rechaza la hipótesis nula frente a ningún activo bursátil. |
| **Modelos GARCH Marginales** | 7 modelos convergentes; ARCH-LM residual polaridad $p = 0,354$ | 7 modelos convergentes; polaridad libre de ARCH ($p = 0,1751$) | Convergencia numérica lograda, pero persiste dependencia serial en residuos de polaridad, TRM y energía (Ljung-Box). |
| **DCC-GARCH Discurso-Mercado** | $a = 0,00938$ ($p = 0,165$), $b = 0,86903$ ($p < 10^{-8}$) | $a = 0,01194$ ($p = 0,069$), $b = 0,92237$ ($p < 10^{-10}$) | Parámetro $a$ no significativo al 5% ($a+b = 0,93431$). Correlaciones condicionales medias entre $-0,0430$ y $+0,0574$. |
| **Markov Switching (IPI-TRM)** | Régimen 1: $\mu_1 = 0,006$, dur. $= 28,9$ ses; Régimen 2: $\mu_2 = 0,022$, dur. $= 16,0$ ses | Régimen 1: $\mu_1 = 0,0121$, dur. $= 24,4$ ses; Régimen 2: $\mu_2 = 0,0216$, dur. $= 27,3$ ses | Dos regímenes estadísticos persistentes con medias cercanas a cero y diferencia en dispersión condicional. |
| **Event Study: IPI Extremo (7d)** | TRM: $+0,55\%$; COLCAP: $-1,14\%$; TES 10Y: $+0,111$ pp; XM: $+17,34\%$ | TRM: $-1,28\%$; COLCAP: $+0,76\%$; TES 10Y: $+0,018$ pp; XM: $+31,89\%$ | Respuestas acumuladas medias a 7 días calendario sobre 10 eventos presidenciales extremos sin contrafactual. |
| **Event Study: Negatividad (7d)** | TRM: $-0,42\%$; COLCAP: $+0,86\%$; TES 10Y: $+0,038$ pp; XM: $+23,39\%$ | TRM: $-0,84\%$; COLCAP: $+1,16\%$; TES 10Y: $+0,175$ pp; XM: $+12,17\%$ | Movimientos observacionales promedio sin significación causal ni distribución contrafactual. |

---

## 3. Calibración del Lenguaje Inferencial y Epistemología del Estudio

Siguiendo las pautas de supervisión metodológica y las directrices editoriales para publicaciones en revistas indexadas (e.g., Taylor & Francis / Applied Economics), se ha depurado cualquier afirmación causal:

1. **Rechazo explícito de afirmaciones causales:** Queda terminantemente descartado afirmar que las publicaciones de Gustavo Petro "causan", "impactan", "afectan" o "mueven" los mercados financieros colombianos, así como afirmar que se haya "descartado la causalidad" en términos absolutos.
2. **Uso riguroso de terminología observacional:** Las asociaciones evaluadas se denominan exclusivamente:
   - *Precedencia predictiva lineal estadística* (en el sentido de Wiener-Granger).
   - *Contenido predictivo marginal* (evaluado respecto al conjunto de información autorregresiva de mercado).
   - *Covariación condicional de segundo orden* (en el contexto DCC-GARCH).
3. **Control estricto de comparaciones múltiples:** La familia de contrastes de Granger se restringe exclusivamente a las 112 pruebas presidenciales, sometidas a control de tasa de falso descubrimiento (FDR) mediante Benjamini-Hochberg (1995). El hecho de que se observen 5 significancias nominales y **exactamente 0 tras corrección FDR** es el resultado empírico central del documento: no existe evidencia econométrica robusta de que la actividad en Twitter de `@petrogustavo` proporcione capacidad predictiva sistemática sobre los precios de los activos colombianos.

---

## 4. Archivos de Auditoría Generados

* `output/tables/español/auditoria_procedencia_econometria.csv`: Certificación de uso exclusivo del corpus presidencial en los 8 componentes econométricos.
* `output/tables/español/auditoria_sesgo_horario_opinion.csv`: Desglose horario completo del corpus `opinion` frente a `presidente`.
* `output/tables/español/auditoria_sesgo_horario_opinion_resumen.csv`: Resumen cuantitativo del sesgo (97,49% a las 18:00; 95,77% días con 10 tweets).
* `output/tables/español/var_robustez_rezagos.csv`: Evaluación de sensibilidad y comparación econométrica VAR(1) vs VAR(3).
* `output/review/reestructuracion_corpus_presidencial.md`: El presente informe comprensivo.
