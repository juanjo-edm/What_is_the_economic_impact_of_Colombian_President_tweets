# Trazabilidad metodológica y especificaciones del artículo

**Documento:** Informe de control metodológico y decisiones de especificación  
**Manuscrito asociado:** *Comunicación presidencial y mercados financieros en Colombia: evidencia textual y de series de tiempo*  

## Arquitectura de especificación analítica

El diagrama resume las decisiones metodológicas que articulan la preparación de datos, la clasificación de texto y los modelos de series temporales:

```mermaid
flowchart TD
    subgraph EstandarizacionDatos ["1. Estandarización de datos"]
        TZ_CHECK["Fecha en America/Bogota<br/>(Alineación con jornada local)"]
        PANEL_CHECK["Panel bursátil unificado<br/>(934 sesiones, 882 completas multivariadas)"]
    end

    subgraph ClasificacionTexto ["2. Clasificación temática"]
        NB_FIT["Clasificador Naive Bayes<br/>(Evaluación con expand_grid, soporte = 2.361)"]
        REASIGN["Reasignación conservadora de otros"]
    end

    subgraph EconometriaSeries ["3. Modelación econométrica"]
        VAR_CHOICE["VAR(1) parsimonioso (HQ/SC)<br/>Sensibilidad en VAR(3)"]
        GRANGER_FDR["112 contrastes presidenciales<br/>Corrección FDR Benjamini-Hochberg"]
        DCC_GARCH["DCC-GARCH (1,1) multivariado<br/>Estabilidad a + b = 0,934"]
        MS_SPEC["Modelo Markov-Switching<br/>Regímenes de dispersión condicional"]
        EVENT_SPEC["Estudio de eventos<br/>Horizontes de 1, 3, 5 y 7 días calendario"]
    end

    TZ_CHECK --> PANEL_CHECK
    PANEL_CHECK --> NB_FIT
    NB_FIT --> REASIGN
    REASIGN --> VAR_CHOICE
    PANEL_CHECK --> VAR_CHOICE
    VAR_CHOICE --> GRANGER_FDR
    VAR_CHOICE --> DCC_GARCH
    VAR_CHOICE --> MS_SPEC
    VAR_CHOICE --> EVENT_SPEC
```

## 1. Matriz de especificaciones metodológicas

| Componente | Especificación contractual | Criterio técnico | Salidas auditadas |
|---|---|---|---|
| **Fecha de publicaciones** | Hora local explícita en `America/Bogota` para asignación de fecha analítica. | Evita asignar mensajes nocturnos al día UTC posterior. | `tweets_master.csv`, tablas y figuras textuales, y serie IPI. |
| **Panel bursátil** | 934 sesiones de respuesta únicas; 882 completas en las 6 variables del VAR y DCC. | Cada retorno bursátil se incorpora una sola vez, sumando los tweets previos correspondientes. | `00_auditoria_temporal_paneles.csv`, VAR, Granger, GARCH y DCC. |
| **Métricas de clasificación** | Evaluación multiclase sobre 2.361 documentos con `expand_grid`. | Garantiza el cálculo correcto de métricas macro-ponderadas aun ante clases con soporte bajo. | `ml_metricas_temas.csv`, `ml_matriz_confusion_temas.png`. |
| **Modelo Markov** | Modelo de regímenes markovianos de media y varianza sin rezago autorregresivo. | Caracteriza estados de dispersión condicional sobre la correlación IPI-TRM. | `11_markov_regimenes.csv` y probabilidades suavizadas. |
| **Contraste de Granger** | 112 pruebas presidenciales evaluadas con corrección FDR de Benjamini-Hochberg. | Previene falsos descubrimientos derivados de comparaciones estadísticas múltiples. | `granger_resultados_completos.csv` y gráficos de valores p. |

## 2. Evaluación del clasificador temático supervisado

El modelo Naive Bayes evalúa la clasificación de textos presidenciales en agendas de reformas del gobierno:

<p align="center">
  <img src="../figures/español/ml_matriz_confusion_temas.png" alt="Matriz de confusión de clasificación temática" width="75%">
</p>

Las métricas comparadas de desempeño frente al modelo base de reglas léxicas confirman la consistencia de la clasificación:

<p align="center">
  <img src="../figures/español/ml_metricas_temas.png" alt="Métricas del clasificador temático" width="75%">
</p>

## 3. Decisiones econométricas preservadas y límites

- **Selección de rezagos VAR:** El VAR(1) se conserva como especificación central parsimoniosa respaldada por los criterios Hannan-Quinn y Schwarz/BIC, con evaluación de robustez en VAR(3). Portmanteau registra autocorrelación residual ($p = 6,00 \times 10^{-10}$).
- **Control de multiplicidad:** Los 112 contrastes de causalidad de Granger presidenciales se someten a control de tasa de falso descubrimiento. Ninguna prueba presenta valor $q$ inferior a 0,05 tras la corrección.
- **Convergencia y diagnósticos GARCH:** Los modelos univariados convergen numéricamente. La serie de polaridad neta queda libre de efectos ARCH residuales ($p = 0,175$), aunque polaridad, TRM y precio de energía registran autocorrelación remanente en la prueba de Ljung-Box.
- **Parámetros DCC:** El parámetro de reacción a innovaciones $a = 0,0119$ no resulta estadísticamente significativo al 5% ($p = 0,069$), mientras que el parámetro de persistencia $b = 0,9224$ es altamente significativo ($p < 10^{-10}$), con suma $a+b = 0,9343 < 1$.
- **Estudio de eventos:** Mide movimientos promedio acumulados en ventanas de 1, 3, 5 y 7 días calendario. Los activos bursátiles y la energía utilizan calendarios propios. Se reporta la cobertura efectiva de episodios disponibles por celda, evitando inferencias causales al carecer de distribución contrafactual.

## Enlaces relacionados

- **Manuscrito formal del artículo:** [`quarto-tandf.qmd`](../../paper/español/quarto-tandf.qmd)
- **Cuaderno computacional:** [`Cuaderno_Paper_Español.qmd`](../../notebooks/español/Cuaderno_Paper_Español.qmd)
- **Auditoría econométrica integral:** [`auditoria_final_cierre_metodologico.md`](auditoria_final_cierre_metodologico.md)
