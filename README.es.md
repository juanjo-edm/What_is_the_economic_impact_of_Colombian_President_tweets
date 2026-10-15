<p><strong>🌐 Leer en:</strong> <a href="README.md">English</a> | <a href="README.es.md">Español</a></p>

# Comunicación presidencial y mercados financieros en Colombia: evidencia textual y de series de tiempo

<p>
  <img src="https://img.shields.io/badge/R-4.x-276DC3?logo=r&logoColor=white" alt="R">
  <img src="https://img.shields.io/badge/Quarto-reproducible-447099?logo=quarto&logoColor=white" alt="Quarto">
  <img src="https://img.shields.io/badge/cuaderno-analisis%20autocontenido-2f7d50" alt="Cuaderno autocontenido">
  <img src="https://img.shields.io/badge/mercado-fuentes%20oficiales-bd5d38" alt="Fuentes oficiales de mercado">
  <img src="https://img.shields.io/badge/salidas-figuras%20%2B%20tablas%20gt-2a7a80" alt="Salidas">
</p>

Este repositorio contiene el artículo de investigación formal, la base de código computacional y el paquete de reproducibilidad que examina si la comunicación emitida por el presidente colombiano Gustavo Petro en Twitter/X (`@petrogustavo`) precede o se asocia con variaciones de corto plazo en los principales indicadores financieros de Colombia.

La ventana temporal comprende desde **agosto de 2022 hasta mayo de 2026** (1.400 días calendario). Metodológicamente, el análisis establece una separación estricta entre dos corpus:

1. **Corpus principal (`presidente`):** Publicaciones emitidas directamente por `@petrogustavo` en `data/raw/twitter/Tweets de Gustavo Petro/` (14.659 tweets en bruto; 14.437 textos limpios no vacíos). Constituye el insumo exclusivo para todo el procesamiento de lenguaje natural, los índices diarios de presión informacional ($IPI_d$) y los modelos econométricos de series de tiempo.
2. **Corpus complementario (`opinion`):** Mensajes públicos recuperados mediante la consulta sobre "Gustavo Petro" en `data/raw/twitter/Opinión sobre Petro/` (13.648 tweets). Se conserva para exploración textual descriptiva y auditoría de calidad de datos, pero queda estrictamente excluido de la econometría financiera debido a un artefacto de recolección documentado: el 97,49% de los registros se concentran a las 18:00 hora de Bogotá y existen topes diarios de 10 tweets por día.

El bloque financiero integra series oficiales diarias: tasa de cambio representativa del mercado (`TRM`), índice bursátil (`COLCAP`), rendimientos de bonos soberanos cero cupón (`TES` a 1, 5 y 10 años, junto a la pendiente 10Y-1Y) del Banco de la República, y el precio de bolsa nacional de energía de XM. Todos los insumos se consolidan en dos contratos de datos en `data/processed/` (`tweets_master.csv` y `market_master.csv`). El manuscrito académico formal sigue el estándar editorial de Taylor & Francis en [`paper/español/quarto-tandf.qmd`](paper/español/quarto-tandf.qmd), acompañado por el cuaderno computacional reproducible en [`notebooks/español/Cuaderno_Paper_Español.qmd`](notebooks/español/Cuaderno_Paper_Español.qmd).

## Tabla de Contenido

- [Pregunta de investigación y alcance](#pregunta-de-investigación-y-alcance)
- [Flujo del proyecto](#flujo-del-proyecto)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Trazabilidad metodológica](#trazabilidad-metodológica)
- [Estándar pedagógico de código y documentación](#estándar-pedagógico-de-código-y-documentación)
- [Instalación](#instalación)
- [Guía de reproducción](#guía-de-reproducción)
- [Resumen metodológico](#resumen-metodológico)
- [Salidas principales y figuras empíricas](#salidas-principales-y-figuras-empíricas)
- [Procedencia y cobertura de datos](#procedencia-y-cobertura-de-datos)
- [Índice de documentación](#índice-de-documentación)
- [Solución de problemas](#solución-de-problemas)
- [Créditos](#créditos)

## Pregunta de investigación y alcance

**Pregunta de investigación:** ¿En qué medida el contenido, el tono emocional y la actividad observada en las publicaciones de `@petrogustavo` preceden o acompañan variaciones en la TRM, COLCAP, rendimientos TES y precio de bolsa de energía en Colombia durante el periodo presidencial 2022-2026?

La investigación empírica aborda:

- Distribución temporal y frecuencia de los mensajes presidenciales en agregaciones diarias, semanales y mensuales.
- Redes discursivas de hashtags, menciones entre cuentas, co-menciones y co-ocurrencias léxicas.
- Clasificación temática débilmente supervisada del discurso presidencial en agendas de reformas (tributaria, salud, pensional, laboral, transición energética, paz total e institucional).
- Análisis de sentimiento léxico NRC en español, polaridad neta y cálculo del Índice de Presión Informacional diario ($IPI_d$).
- Auditoría empírica que documenta las restricciones de recolección y concentración horaria del corpus secundario de opinión.
- Pruebas de estacionariedad (ADF y KPSS), contrastes de cointegración de Johansen, modelos VAR y contrastes de precedencia temporal de Granger con corrección FDR de Benjamini-Hochberg.
- Modelación de correlaciones condicionales dinámicas (DCC-GARCH) entre señales discursivas y series financieras.
- Modelos Markov-Switching para caracterizar transiciones de régimen en la relación discurso-mercado.
- Estudios de eventos sobre respuestas financieras acumuladas ante choques discursivos extremos bajo un marco observacional.

Toda la modelación econométrica se sustenta en series oficiales de Banco de la República y XM, utilizando de manera exclusiva el corpus presidencial.

## Flujo del proyecto

El siguiente diagrama presenta la arquitectura completa de datos, procesamiento analítico y compilación del artículo:

```mermaid
flowchart TD
    subgraph Ingesta ["1. Ingesta oficial en bruto"]
        T_RAW["Twitter Raw: @petrogustavo<br/>(14.659 tweets, Ago 2022 - May 2026)"]
        O_RAW["Twitter Raw: Opinión sobre Petro<br/>(13.648 tweets, sesgo 18:00 COT)"]
        M_BANREP["Banco de la República API / Graficador<br/>(TRM, COLCAP, TES 1Y, 5Y, 10Y)"]
        M_XM["XM SINERGOX API<br/>(Precio Bolsa Energía PPPrecBolsNaci)"]
    end

    subgraph Contratos ["2. Procesamiento y contratos de datos"]
        SCRIPT_T["scripts/data/twitter_process_raw_data.R"]
        SCRIPT_M["scripts/data/ingest_market.R"]
        T_MASTER["data/processed/tweets_master.csv<br/>(tz America/Bogota, IDs en texto)"]
        M_MASTER["data/processed/market_master.csv<br/>(Retornos financieros y banderas de observación)"]
    end

    subgraph Motor ["3. Motor computacional (Cuaderno_Paper_Español.qmd)"]
        NB_NLP["PLN y Sentimiento:<br/>Normalización, léxico NRC, IPI, STM"]
        NB_CORP["Auditoría de corpus:<br/>Documentación de sesgo en opinión"]
        NB_TS["Series financieras:<br/>Retornos log, diferencias TES, ADF/KPSS"]
        NB_ECON["Pipeline econométrico:<br/>Johansen, VAR(1), Granger FDR,<br/>DCC-GARCH, Markov-Switching, Event Study"]
    end

    subgraph Salidas ["4. Artefactos persistidos"]
        OUT_FIG["output/figures/español/<br/>(93 figuras de alta resolución)"]
        OUT_TAB["output/tables/español/<br/>(Tablas de auditoría en HTML y CSV)"]
    end

    subgraph Articulo ["5. Manuscrito académico (quarto-tandf.qmd)"]
        PAPER_SRC["paper/español/quarto-tandf.qmd<br/>(Plantilla Taylor & Francis)"]
        PAPER_PDF["paper/español/quarto-tandf.pdf<br/>(PDF listo para evaluación por pares)"]
        PAPER_HTML["paper/español/quarto-tandf.html<br/>(HTML autocontenido e interactivo)"]
        PAPER_DOCX["paper/español/quarto-tandf.docx<br/>(Versión Word editorial)"]
    end

    T_RAW --> SCRIPT_T
    O_RAW --> SCRIPT_T
    M_BANREP --> SCRIPT_M
    M_XM --> SCRIPT_M

    SCRIPT_T --> T_MASTER
    SCRIPT_M --> M_MASTER

    T_MASTER --> NB_NLP
    T_MASTER --> NB_CORP
    M_MASTER --> NB_TS

    NB_NLP --> NB_ECON
    NB_TS --> NB_ECON

    NB_ECON --> OUT_FIG
    NB_ECON --> OUT_TAB

    OUT_FIG --> PAPER_SRC
    OUT_TAB --> PAPER_SRC
    PAPER_SRC --> PAPER_PDF
    PAPER_SRC --> PAPER_HTML
    PAPER_SRC --> PAPER_DOCX
```

## Estructura del repositorio

La organización del proyecto separa datos en bruto, contratos procesados, motor analítico, manuscrito académico y salidas persistidas:

```text
What_is_the_economic_impact_of_Colombian_President_tweets/
|-- data/
|   |-- processed/                              # Contratos de datos estables para el cuaderno
|   |   |-- market_master.csv
|   |   `-- tweets_master.csv
|   `-- raw/
|       |-- market/                             # Series de mercado descargadas de BanRep y XM
|       `-- twitter/
|           |-- Opinión sobre Petro/            # Corpus secundario de conversación ciudadana
|           `-- Tweets de Gustavo Petro/        # Corpus primario presidencial (@petrogustavo)
|-- notebooks/
|   `-- español/
|       |-- Cuaderno_Paper_Español.qmd          # Motor computacional autocontenido del paper
|       |-- Cuaderno_Paper_Español.html         # Versión HTML renderizada
|       `-- README.md                           # Guía de ejecución del cuaderno
|-- paper/
|   |-- English/                                # Materiales de adaptación al inglés
|   |   `-- README.md
|   |-- español/                                # Manuscrito formal Quarto (Taylor & Francis)
|   |   |-- quarto-tandf.qmd                    # Fuente Quarto del artículo
|   |   |-- quarto-tandf.pdf                    # Manuscrito compilado en PDF
|   |   |-- quarto-tandf.html                   # Manuscrito compilado en HTML
|   |   |-- quarto-tandf.docx                   # Manuscrito compilado en Word
|   |   |-- bibliography.bib                    # Bibliografía verificada en BibTeX
|   |   `-- README.md                           # Guía del manuscrito
|   `-- figures/                                # Figuras portables del manuscrito
|       `-- español/
|-- Methodology_Supervision/                    # Módulo de supervisión metodológica y auditoría
|   |-- Supervision_Metodologica.qmd
|   |-- Supervision_Metodologica.html
|   `-- README.md
|-- output/
|   |-- figures/español/                        # 93 figuras generadas por el cuaderno
|   |-- tables/español/                         # Tablas persistidas en HTML y CSV
|   `-- review/                                 # Informes de auditoría econométrica y de datos
|-- scripts/
|   `-- data/
|       |-- ingest_market.R                     # Actualizador de series de BanRep y XM
|       `-- twitter_process_raw_data.R          # Valida y construye los contratos master CSV
|-- README.es.md                                # Documentación principal en español
|-- README.md                                   # Documentación principal en inglés
`-- What_is_the_economic_impact_of_Colombian_President_tweets.Rproj
```

| Ruta | Propósito | Consumidor principal |
|---|---|---|
| [`data/raw/twitter/Tweets de Gustavo Petro/`](data/raw/twitter/Tweets%20de%20Gustavo%20Petro/) | Corpus principal: CSVs de `@petrogustavo` | `scripts/data/twitter_process_raw_data.R` |
| [`data/raw/twitter/Opinión sobre Petro/`](data/raw/twitter/Opinión%20sobre%20Petro/) | Corpus complementario de opinión ciudadana | Auditoría textual del cuaderno |
| [`data/raw/market/`](data/raw/market/) | Descargas de series en bruto de BanRep y XM | `scripts/data/twitter_process_raw_data.R` |
| [`data/processed/`](data/processed/) | Dos contratos estables: `tweets_master.csv` y `market_master.csv` | `notebooks/español/Cuaderno_Paper_Español.qmd` |
| [`notebooks/español/`](notebooks/español/) | Cuaderno computacional reproducible en español | Pares evaluadores para réplica |
| [`paper/español/`](paper/español/) | Artículo académico formal (PDF, HTML, DOCX) | Evaluadores y comités editoriales |
| [`Methodology_Supervision/`](Methodology_Supervision/) | Módulo de supervisión metodológica y calidad | Auditoría metodológica independiente |
| [`output/figures/español/`](output/figures/español/) | Figuras de alta resolución exportadas por el cuaderno | Manuscrito y análisis visual |
| [`output/tables/español/`](output/tables/español/) | Tablas persistidas en formatos HTML y CSV | Comprobación numérica de estimaciones |

## Trazabilidad metodológica

### Ubicación de parámetros y fuentes

El proyecto no depende de archivos YAML externos. Los scripts de ingesta definen fechas muestrales, rutas, identificadores de series y URLs de consulta en la cabecera de cada archivo. En el cuaderno, cada parámetro o constante analítica precede directamente al bloque de código que la consume. La trazabilidad de mercado se guarda en [`output/tables/español/ingesta_mercado_fuentes.csv`](output/tables/español/ingesta_mercado_fuentes.csv).

### Función de `scripts/` y `notebooks/`

El motor de cálculo reside íntegramente en [`notebooks/español/Cuaderno_Paper_Español.qmd`](notebooks/español/Cuaderno_Paper_Español.qmd). Las rutinas de limpieza, clasificación temática, modelos de temas, métricas de sentimiento, redes discursivas y modelos econométricos se ejecutan en el cuaderno.

La carpeta `scripts/` alberga dos procesos preparatorios:
1. `scripts/data/ingest_market.R` descarga las series oficiales de BanRep y XM cuando se requiere renovar las fuentes de mercado.
2. `scripts/data/twitter_process_raw_data.R` unifica la zona horaria a `America/Bogota`, asegura identificadores de 64 bits como texto y genera los contratos `data/processed/tweets_master.csv` y `data/processed/market_master.csv`.

El cuaderno lee únicamente esos dos archivos CSV procesados. No utiliza llamadas a `source()` ni ejecuta scripts externos durante su renderizado.

## Estándar pedagógico de código y documentación

El repositorio implementa cinco criterios de calidad documental:

1. **Prueba humana:** Cada sección analítica declara previamente el problema substantive, los datos de entrada, la transformación o modelo estadístico, la salida generada y la decisión metodológica subsiguiente.
2. **Estructura en tres capas:** La exposición sigue el orden: contexto conceptual en Markdown, comentarios explicativos en el código, e interpretación académica inmediata tras cada resultado visual o tabular.
3. **Calibración del lenguaje inferencial:** Las afirmaciones se ajustan a la identificación empírica. Se diferencian rigurosamente descripción, correlación, predicción, precedencia temporal (Granger) y causalidad. No se emplean verbos causales al interpretar regresiones observacionales o modelos VAR.
4. **Resultados dinámicos:** Los estadísticos, tamaños muestrales y valores p derivan de las salidas reproducibles y no de valores fijos en el texto narrativo.
5. **Bloques modulares de código:** Cada bloque atiende una sola tarea analítica (aproximadamente 40 líneas internas), preservando la integridad de funciones y secuencias gráficas.

## Instalación

Instale R (versión 4.1 o superior) y los paquetes requeridos desde la raíz del proyecto:

```r
install.packages(c(
  "readr", "readxl", "dplyr", "tidyr", "stringr", "lubridate",
  "purrr", "ggplot2", "ggwordcloud", "httr2", "xml2", "jsonlite",
  "syuzhet", "lmtest", "zoo", "scales", "janitor", "tibble",
  "quanteda", "quanteda.textstats", "quanteda.textplots",
  "quanteda.textmodels", "sentometrics", "stm", "igraph",
  "ggraph", "tidygraph", "vars", "tseries", "urca", "sandwich",
  "forcats", "rmarkdown", "knitr", "here", "DiagrammeR",
  "DiagrammeRsvg", "rsvg", "ragg", "spacyr", "reticulate", "fs", "glue"
))

install.packages(
  "printtree",
  repos = c("https://cran.r-universe.dev", "https://cloud.r-project.org")
)
```

Para la anotación lingüística con spaCy, instale Python con spaCy y el modelo en español `es_core_news_sm`:

```bash
pip install spacy
python -m spacy download es_core_news_sm
```

## Guía de reproducción

Para reconstruir el artículo y los resultados empíricos desde una sesión limpia:

1. Verifique que los contratos de datos existan en `data/processed/` (`tweets_master.csv` y `market_master.csv`).
2. Renderice el cuaderno metodológico en español:

```bash
quarto render notebooks/español/Cuaderno_Paper_Español.qmd
```

3. Renderice el manuscrito formal del artículo:

```bash
quarto render paper/español/quarto-tandf.qmd
```

Esto generará las versiones en PDF, HTML y Word dentro de `paper/español/`.

## Resumen metodológico

- **Preprocesamiento textual:** Normalización léxica, filtrado de stopwords, estandarización de entidades y lematización mediante spaCy.
- **Clasificación temática supervisada:** Clasificador Naive Bayes sobre agendas de reformas, reasignando mensajes no clasificados únicamente ante umbrales calibrados de certidumbre.
- **Análisis de sentimiento:** Puntuación léxica de emociones NRC mediante `syuzhet`, cálculo de polaridad neta y estimación del Índice de Presión Informacional ($IPI_d$) como producto del sentimiento estandarizado y el logaritmo del volumen diario de publicaciones.
- **Series temporales y estacionariedad:** Pruebas ADF y KPSS fundamentan retornos logarítmicos en activos bursátiles y diferencias simples en tasas de interés TES.
- **Cointegración y modelos VAR:** El contraste de traza de Johansen ($27,85 < 34,91$, no se rechaza $r=0$) descarta vectores de cointegración en niveles, validando un VAR(1) estacionario en diferencias con raíz máxima de $0,281$.
- **Causalidad de Granger:** 112 pruebas bivariadas entre 4 respuestas financieras, 7 señales discursivas presidenciales y 4 rezagos. 5 pruebas muestran significancia nominal ($p < 0,05$), y ninguna se mantiene significativa tras aplicar la corrección FDR de Benjamini-Hochberg ($q \ge 0,791$).
- **Correlaciones condicionales dinámicas:** En el modelo DCC-GARCH, los parámetros son $a = 0,0119$ ($p = 0,069$) y $b = 0,9224$ ($p < 10^{-10}$), indicando alta persistencia pero sensibilidad inmediata estadísticamente débil de los mercados ante choques de tono presidencial.
- **Cambios de régimen de Markov:** Dos estados capturan regímenes de baja y alta volatilidad en la correlación entre el IPI presidencial y la TRM.
- **Estudio de eventos:** Respuestas acumuladas observadas a 1, 3, 5 y 7 días ante 10 eventos de IPI extremo y 10 eventos de negatividad extrema, interpretadas de manera observacional sin supuestos contrafactuales.

## Salidas principales y figuras empíricas

El cuaderno produce **93 figuras de alta resolución** y **7 tablas visibles**, acompañadas de interpretaciones analíticas inmediatas.

### Series financieras y dinámica discursiva presidencial

El siguiente panel presenta las series normalizadas de sentimiento presidencial, IPI y los indicadores de mercado financiero durante la ventana 2022-2026.

<p align="center">
  <img src="output/figures/español/serie_sentimientos_trm_colcap.png" alt="Sentimiento normalizado, IPI y series de mercado" width="90%">
</p>

### Fundamento léxico y clasificación emocional

La modelación de emociones discursivas se apoya en el modelo psicoevolutivo de Plutchik, adaptado al español mediante el léxico NRC.

<p align="center">
  <img src="paper/figures/español/figura1_plutchik.png" alt="Taxonomía emocional de Plutchik" width="60%">
</p>

### Rejilla de contrastes de Granger (Corpus Presidencial)

Valores p nominales de los 112 contrastes de precedencia temporal entre discurso presidencial y series de mercado para los rezagos 1 a 4. Las líneas punteadas rojas indican el umbral nominal $\alpha = 0,05$. Ningún contraste sobrevive al ajuste FDR de Benjamini-Hochberg.

<p align="center">
  <img src="output/figures/español/granger_presidencial_emociones.png" alt="Valores p de Granger para emociones presidenciales" width="85%">
</p>

### Correlaciones condicionales dinámicas (DCC-GARCH)

Correlaciones condicionales estimadas entre señales presidenciales (IPI, polaridad) y los activos financieros colombianos (TRM, COLCAP, TES 10Y y pendiente TES).

<p align="center">
  <img src="output/figures/español/econometria/dcc_correlaciones_dinamicas_panel.png" alt="Correlaciones dinámicas DCC-GARCH" width="90%">
</p>

### Probabilidades suavizadas del modelo Markov-Switching

Probabilidades de estado del modelo de regímenes markovianos entre el IPI presidencial y los retornos cambiarios de la TRM.

<p align="center">
  <img src="output/figures/español/econometria/msar_probabilidades_suavizadas.png" alt="Probabilidades suavizadas Markov-Switching" width="90%">
</p>

### Mapa de calor del estudio de eventos

Respuestas financieras promedio acumuladas tras 10 eventos de choque extremo de IPI y 10 de negatividad discursiva en horizontes de 1, 3, 5 y 7 días.

<p align="center">
  <img src="output/figures/español/event_study_respuestas_heatmap.png" alt="Mapa de calor de respuestas en estudio de eventos" width="80%">
</p>

## Procedencia y cobertura de datos

1. **Datos de Twitter:** Las publicaciones presidenciales provienen de `data/raw/twitter/Tweets de Gustavo Petro/petrogustavo_full.csv`. Las fechas se validan en hora local de Bogotá (`America/Bogota`), conservando los identificadores de 64 bits como texto para evitar truncamiento numérico.
2. **Datos de mercado:** TRM, COLCAP y curvas TES cero cupón provienen de APIs y del graficador oficial del Banco de la República. Los precios de energía provienen de la API de XM SINERGOX (`PPPrecBolsNaci`).
3. **Tablas de auditoría:** La cobertura y el estado de consulta se registran en:
   - [`output/tables/español/cobertura_mercado.html`](output/tables/español/cobertura_mercado.html)
   - [`output/tables/español/fuentes_mercado_auditadas.html`](output/tables/español/fuentes_mercado_auditadas.html)
   - [`output/tables/español/auditoria_comparada_dos_corpus.csv`](output/tables/español/auditoria_comparada_dos_corpus.csv)

## Índice de documentación

- **README en inglés:** [`README.md`](README.md)
- **Cuaderno computacional:** [`notebooks/español/Cuaderno_Paper_Español.qmd`](notebooks/español/Cuaderno_Paper_Español.qmd)
- **Guía del cuaderno:** [`notebooks/español/README.md`](notebooks/español/README.md)
- **Manuscrito formal (fuente Quarto):** [`paper/español/quarto-tandf.qmd`](paper/español/quarto-tandf.qmd)
- **Artículo compilado (PDF):** [`paper/español/quarto-tandf.pdf`](paper/español/quarto-tandf.pdf)
- **Artículo compilado (HTML):** [`paper/español/quarto-tandf.html`](paper/español/quarto-tandf.html)
- **Artículo compilado (DOCX):** [`paper/español/quarto-tandf.docx`](paper/español/quarto-tandf.docx)
- **Guía del manuscrito:** [`paper/español/README.md`](paper/español/README.md)
- **Paquete de adaptación al inglés:** [`paper/English/README.md`](paper/English/README.md)
- **Módulo de supervisión metodológica:** [`Methodology_Supervision/README.md`](Methodology_Supervision/README.md)
- **Datos de mercado en bruto:** [`data/raw/market/README.md`](data/raw/market/README.md)
- **Auditoría econométrica final:** [`output/review/auditoria_final_cierre_metodologico.md`](output/review/auditoria_final_cierre_metodologico.md)

## Solución de problemas

| Problema | Diagnóstico | Solución |
|---|---|---|
| Paquete R ausente | Error al cargar librería durante compilación | Ejecute el bloque en [Instalación](#instalación), incluyendo `printtree` desde R-universe. |
| Pandoc no encontrado | Error de compilación en Quarto | Instale Quarto CLI o configure `RSTUDIO_PANDOC` hacia el binario de Pandoc provisto por Quarto. |
| Falta el modelo spaCy | Error de inicialización en `spacyr` | Ejecute `python -m spacy download es_core_news_sm` en el entorno de Python activo. |
| Falla al descargar datos de mercado | Error de conexión con endpoints oficiales | Revise la conectividad a BanRep/XM; consulte `output/tables/español/ingesta_mercado_fuentes.csv`. |
| Figura faltante en salidas | Chunk no renderizado o archivo eliminado | Vuelva a renderizar `notebooks/español/Cuaderno_Paper_Español.qmd` desde una sesión limpia de R. |

## Créditos

Este trabajo utiliza librerías de código abierto de R para minería de texto, modelado temático, redes y econometría de series temporales, incluyendo `quanteda`, `stm`, `sentometrics`, `syuzhet`, `vars`, `urca`, `rmgarch` y `MSwM`.

Las series financieras provienen del Banco de la República y de XM SINERGOX. Los contratos de datos, scripts y cuadernos se estructuran para garantizar réplica computacional completa.
