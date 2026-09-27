
<p><strong>🌐 Leer en:</strong> <a href="README.md">English</a> | <a href="README.es.md">Español</a></p>

# Impacto económico de los tweets del presidente Petro

<p>
  <img src="https://img.shields.io/badge/R-4.x-276DC3?logo=r&logoColor=white" alt="R">
  <img src="https://img.shields.io/badge/R%20Markdown-reproducible-75AADB?logo=r&logoColor=white" alt="R Markdown">
  <img src="https://img.shields.io/badge/cuaderno-analisis%20autocontenido-2f7d50" alt="Cuaderno autocontenido">
  <img src="https://img.shields.io/badge/mercado-actualizacion%20manual-bd5d38" alt="Actualizacion manual de mercado">
  <img src="https://img.shields.io/badge/salidas-figuras%20%2B%20tablas%20gt-2a7a80" alt="Salidas">
</p>

Este repositorio actualiza el paper **`Impacto_discurso_petro__ENG_`**
para estudiar si la conversación en Twitter/X alrededor del presidente
colombiano Gustavo Petro se asocia con movimientos de corto plazo en
indicadores financieros de Colombia.

El proyecto está organizado como un flujo reproducible en R para los
snapshots mensuales de tweets entre **agosto de 2022 y mayo de 2026**.
El diseño actual distingue dos corpus: `opinion`, con conversación
pública sobre Petro en `data/raw/twitter/Opinión sobre Petro/`, y
`presidente`, con tweets escritos por `@petrogustavo` en
`data/raw/twitter/Tweets de Gustavo Petro/`. El bloque financiero usa
`TRM` como serie cambiaria, `COLCAP` como proxy bursátil principal,
tasas cero cupón `TES` en pesos como bloque de renta fija soberana y el
precio diario ponderado nacional de energía de XM como serie del mercado
eléctrico. Esas series se descargan como CSV oficiales en bruto en
`data/raw/market/`. El script de procesamiento consolida después todos
los insumos en dos contratos estables en `data/processed/`, y las
auditorías de descarga y procedencia quedan en `output/tables/español/`.
El paper original de 2023 se conserva como referencia conceptual e
histórica en
[`docs/paper/Impacto_discurso_petro__ENG_.pdf`](docs/paper/Impacto_discurso_petro__ENG_.pdf).
La versión activa del paper está en Quarto y actualiza la narrativa con
redes estilo `quanteda`, EDA de frecuencia de tweets presidenciales,
sentimientos, tópicos y diagnósticos financieros exploratorios.

## Tabla de Contenido

- [Descripción del Proyecto](#descripción-del-proyecto)
- [Flujo del Proyecto](#flujo-del-proyecto)
- [Estructura del Repositorio](#estructura-del-repositorio)
- [Trazabilidad metodológica](#trazabilidad-metodológica)
- [Instalación](#instalación)
- [Reproducir el Análisis](#reproducir-el-análisis)
- [Metodología](#metodología)
- [Salidas y Resultados](#salidas-y-resultados)
- [Datos, Cobertura y Credenciales](#datos-cobertura-y-credenciales)
- [Documentación](#documentación)
- [Solución de Problemas](#solución-de-problemas)
- [Créditos](#créditos)

## Descripción del Proyecto

**Pregunta de investigación.** ¿Los tweets presidenciales y la
conversación pública relacionada producen movimientos medibles de corto
plazo en los mercados financieros colombianos?

El análisis actualizado se concentra en:

- frecuencia diaria de tweets y calidad de metadata;
- frecuencia diaria, semanal y mensual de tweets emitidos por
  `@petrogustavo`;
- hashtags, menciones, co-menciones y redes de co-ocurrencia léxica;
- redes de hashtags y menciones con el estilo visual del ejemplo de
  Twitter de `quanteda`;
- nubes de palabras por corpus, tiempo, temas, sentimientos, tópicos y
  comunidades;
- evolución temporal TF-IDF como apoyo reproducible al word stream;
- clasificación temática con supervisión débil y evaluación holdout;
- sentimiento NRC en español, polaridad y sentimiento diario ponderado;
- minería de texto con `quanteda`, `quanteda.textstats` y
  `quanteda.textplots`;
- escalamiento Wordfish con `quanteda.textmodels`;
- modelado de tópicos con `stm`;
- diagnósticos de estacionariedad, pruebas de Granger y diagnósticos VAR
  para `TRM`, `COLCAP`, `TES 10Y`, la pendiente `TES 10Y - TES 1Y` y el
  precio de energía XM.

El flujo actual usa series oficiales de BanRep para `TRM`, `COLCAP` y
`TES`, además del precio oficial de energía de XM; el análisis activo ya
no depende del proxy accionario antiguo usado en el estudio de caso
original.

## Flujo del Proyecto

Las fuentes del README generan este diagrama con `DiagrammeR` y lo
exportan como imagen estática para que se vea correctamente en GitHub.

<img src="docs/assets/readme_project_flow_es.png" alt="" width="100%" />

## Estructura del Repositorio

El árbol siguiente se produce desde el repositorio actual con
`printtree::print_rtree()` o con `printree::print_rtree()` si ese
namespace existe en su instalación local de R.

``` text
What_is_the_economic_impact_of_Colombian_President_tweets/
|-- data/
|   |-- Archive/
|   |-- processed/
|   `-- raw/
|-- docs/
|   |-- assets/
|   `-- paper/
|-- notebooks/
|   `-- español/
|-- paper/
|   |-- English/
|   |-- español/
|   `-- figures/
|-- scripts/
|   |-- api_data_extraction/
|   `-- data/
|-- README 2.Rmd
|-- README.es.md
|-- README.es.Rmd
|-- README.html
|-- README.md
|-- README.Rmd
`-- What_is_the_economic_impact_of_Colombian_President_tweets.Rproj
```

| Ruta | Propósito |
|----|----|
| `data/raw/twitter/Opinión sobre Petro/` | Corpus `opinion`: CSV mensuales de conversación pública sobre Gustavo Petro. |
| `data/raw/twitter/Tweets de Gustavo Petro/` | Corpus `presidente`: `petrogustavo_full.csv` consolidado con tweets escritos por `@petrogustavo`. |
| `data/raw/market/` | Series oficiales de mercado en bruto actualizadas por el script de ingesta. |
| `data/processed/` | Exactamente dos insumos estables del cuaderno: `tweets_master.csv` y `market_master.csv`. |
| `scripts/data/ingest_market.R` | Actualizador manual de mercado raw; sus auditorías quedan en `output/tables/español/`. |
| `notebooks/español/` | Cuaderno metodológico principal en español para actualizar el paper. |
| `paper/español/` | Paper Quarto activo en español con template Taylor & Francis y figuras portables. |
| `paper/English/` | Carpeta reservada para la futura versión en inglés del paper. |
| `output/figures/español/` | Figuras persistidas por el cuaderno. |
| `output/tables/español/` | Tablas HTML persistidas, más copias CSV para auditoría. |
| `docs/paper/` | PDF del paper original usado como referencia metodológica. |

## Trazabilidad metodológica

### ¿Dónde se definen los parámetros y las fuentes?

El proyecto ya no usa un archivo YAML de configuración separado. Los
scripts de datos definen fechas, rutas, IDs de fuente, endpoints y URLs
de referencia de forma explícita al inicio de cada archivo, mientras el
cuaderno ubica cada constante analítica junto a su primer bloque
consumidor. La procedencia de cada actualización de mercado se persiste
bajo `output/tables/español/`.

### ¿Cuál es el papel de `scripts/`?

El análisis principal está autocontenido en
`notebooks/español/Cuaderno_Paper_Español.qmd`. Las funciones de
limpieza, clasificación, visualización, NLP, redes, series, econometría
y validación de modelos viven dentro del cuaderno.

Dos scripts se ejecutan antes de renderizar cuando se deban refrescar
insumos: `scripts/data/ingest_market.R` descarga las series oficiales de
mercado en bruto, y `scripts/data/twitter_process_raw_data.R` valida y
escribe `tweets_master.csv` y `market_master.csv`. El cuaderno lee
únicamente esos dos contratos; no ejecuta scripts externos.

Orden de ejecución recomendado:

1.  Actualice manualmente datos de mercado sólo cuando haga falta.
2.  Ejecute `Rscript scripts/data/twitter_process_raw_data.R` para
    preparar Twitter y mercado raw.
3.  Confirme que los CSV requeridos existen en `data/processed/`.
4.  Renderice `notebooks/español/Cuaderno_Paper_Español.qmd`.
5.  Revise figuras y tablas generadas bajo `output/`.

### ¿El cuaderno depende de `source()`?

No. El cuaderno define en su chunk de setup los helpers que necesita y
consume los CSV preparados bajo `data/processed/`. Puede recalcular
análisis textuales, tablas, figuras, redes y diagnósticos econométricos
para trazabilidad, pero no llama scripts externos.

### ¿Cómo se extraen los datos de mercado y cómo se diferencian raw y processed?

Las series principales de mercado se extraen con el actualizador manual
`scripts/data/ingest_market.R`, que puede ejecutarse con
`Rscript scripts/data/ingest_market.R`. Ese script consulta servicios
del Banco de la República para TRM, COLCAP y tasas cero cupón TES, y la
API diaria SINERGOX de XM para `PPPrecBolsNaci`. Los endpoints, IDs de
serie y URLs de referencia se definen como constantes del script y se
registran en `output/tables/español/ingesta_mercado_fuentes.csv`. Por
eso `data/raw/market/` contiene las series oficiales en bruto
(`*_raw.csv`), mientras `data/processed/market_master.csv` contiene el
panel diario validado.

La trazabilidad de mercado queda en:

- `data/processed/market_master.csv`: series diarias usadas en modelos.
- `output/tables/español/ingesta_mercado_fuentes.csv`: `retrieved_at`,
  `source_url`, `source_series_id`, `source_series_name`, `status` y
  mensajes de extracción.
- `output/tables/español/ingesta_mercado_cobertura.csv`: días esperados,
  días observados, `coverage_ratio` y estado de cobertura.

Si se necesita congelar una extracción exacta para réplica cerrada,
deben conservarse ambos master junto con los insumos raw y las
auditorías de ingesta.

## Instalación

Instale R y los paquetes usados por el actualizador manual de mercado,
el cuaderno y la generación de los README. Desde la raíz del
repositorio:

``` r
install.packages(c(
  "readr", "readxl", "dplyr", "tidyr", "stringr", "lubridate",
  "purrr", "ggplot2", "ggwordcloud", "httr2", "xml2", "jsonlite", "syuzhet", "lmtest", "zoo", "scales",
  "janitor", "tibble", "quanteda", "quanteda.textstats",
  "quanteda.textplots", "quanteda.textmodels", "sentometrics", "stm",
  "igraph", "ggraph", "tidygraph", "vars", "tseries", "urca", "sandwich",
  "forcats", "rmarkdown", "knitr", "here", "DiagrammeR", "DiagrammeRsvg", "rsvg",
  "ragg", "spacyr", "reticulate", "fs", "glue"
))

install.packages(
  "printtree",
  repos = c("https://cran.r-universe.dev", "https://cloud.r-project.org")
)
```

La solicitud del README menciona `printree`. El paquete disponible
actualmente en R es `printtree`; el Rmd busca primero `printree` y luego
usa `printtree` como implementación compatible.

## Reproducir el Análisis

El cuaderno es la superficie principal del análisis. Antes de
renderizar, confirme que estos dos contratos existan bajo
`data/processed/`; actualice datos de mercado manualmente sólo cuando
las series BanRep lo requieran:

- `data/processed/tweets_master.csv`
- `data/processed/market_master.csv`
- figuras en `output/figures/español/`
- tablas HTML y CSV en `output/tables/español/`

`data/processed/` excluye intencionalmente productos analíticos como
sentimiento diario, comparaciones de corpus, datasets de modelos y
diagnósticos de Granger. Esos objetos se construyen dentro del cuaderno
y se persisten como tablas o figuras bajo `output/`.

Renderice el cuaderno metodológico en español:

``` bash
quarto render notebooks/español/Cuaderno_Paper_Español.qmd
```

Renderice el paper Quarto activo:

``` bash
quarto render paper/español/quarto-tandf.qmd
```

Renderice los README bilingües desde sus fuentes R Markdown:

``` bash
Rscript -e 'rmarkdown::render("README.Rmd", output_file = "README.md")'
Rscript -e 'rmarkdown::render("README.es.Rmd", output_file = "README.es.md")'
```

## Metodología

El artefacto académico principal es el cuaderno:
[`notebooks/español/Cuaderno_Paper_Español.qmd`](notebooks/español/Cuaderno_Paper_Español.qmd).
Está escrito en español y organizado en secciones numeradas que explican
cada bloque antes de ejecutar el código.

El flujo incluye:

- **Diseño de datos.** Snapshots mensuales de tweets, datos de mercado,
  auditorías de cobertura y parámetros explícitos dentro del cuaderno.
- **Limpieza y preprocesamiento.** Normalización de fechas, filtro de
  idioma, control de duplicados, limpieza de texto, tokens y etiquetas
  de temas de reforma.
- **Supervisión temática débil.** Un clasificador Naive Bayes
  transparente evalúa etiquetas derivadas de reglas, se compara contra
  un modelo base y sólo reasigna `otros` con confianza conservadora.
- **Exploración político-discursiva.** Frecuencia de tweets
  presidenciales, hashtags, menciones, co-menciones, nubes de palabras,
  evolución temporal de términos y redes estilo `quanteda`.
- **Corpus y modelos textuales.** Corpus `quanteda`, dfm, frecuencias,
  keyness, colocaciones, co-ocurrencias léxicas y Wordfish.
- **Modelado de tópicos.** Tópicos `stm` con prevalencia, coherencia
  semántica y exclusividad.
- **Sentimiento.** Emociones NRC y polaridad en español con `syuzhet`;
  medidas diarias ponderadas con `sentometrics`.
- **Econometría.** Diagnósticos de estacionariedad, pruebas de Granger y
  diagnósticos VAR con `lmtest`, `vars`, `tseries`, `urca` y `sandwich`.

## Salidas y Resultados

Todo resultado relevante del cuaderno queda persistido. El proyecto no
depende de figuras o tablas que sólo existan dentro de una sesión
interactiva.

Figuras generadas seleccionadas:

| Salida | Descripción |
|----|----|
| [`output/figures/español/serie_sentimientos_trm_colcap.png`](output/figures/español/serie_sentimientos_trm_colcap.png) | Series normalizadas de sentimiento, IPI, `TRM`, `COLCAP`, `TES` y precio de energía XM. |
| [`output/figures/español/tes_curva_cero_cupon.png`](output/figures/español/tes_curva_cero_cupon.png) | Tasas cero cupón `TES` oficiales a 1, 5 y 10 años. |
| [`output/figures/español/tes_pendiente_10y_1y.png`](output/figures/español/tes_pendiente_10y_1y.png) | Pendiente soberana `TES 10Y - TES 1Y`. |
| [`output/figures/español/eda_petro_tweets_diarios.png`](output/figures/español/eda_petro_tweets_diarios.png) | Serie diaria de frecuencia de tweets emitidos por `@petrogustavo`. |
| [`output/figures/español/eda_petro_tweets_mensuales.png`](output/figures/español/eda_petro_tweets_mensuales.png) | Agregación mensual de actividad presidencial en Twitter/X. |
| [`output/figures/español/eda_petro_calendario_actividad.png`](output/figures/español/eda_petro_calendario_actividad.png) | Calendario de actividad de tweets presidenciales. |
| [`output/figures/español/red_hashtags_quanteda.png`](output/figures/español/red_hashtags_quanteda.png) | Red global de hashtags con estilo `quanteda`. |
| [`output/figures/español/red_menciones_quanteda.png`](output/figures/español/red_menciones_quanteda.png) | Red global de menciones con estilo `quanteda`. |
| [`output/figures/español/red_hashtags_quanteda_por_corpus.png`](output/figures/español/red_hashtags_quanteda_por_corpus.png) | Redes de hashtags separadas por corpus. |
| [`output/figures/español/red_menciones_quanteda_por_corpus.png`](output/figures/español/red_menciones_quanteda_por_corpus.png) | Redes de menciones separadas por corpus. |
| [`output/figures/español/wordcloud_corpus_general.png`](output/figures/español/wordcloud_corpus_general.png) | Nubes de palabras por corpus, ponderadas por TF-IDF acumulado. |
| [`output/figures/español/wordcloud_temporal_periodos.png`](output/figures/español/wordcloud_temporal_periodos.png) | Nubes semestrales de palabras distintivas como word stream reproducible. |
| [`output/figures/español/wordstream_tfidf_temporal.png`](output/figures/español/wordstream_tfidf_temporal.png) | Heatmap temporal TF-IDF usado como apoyo matricial al word stream. |
| [`output/figures/español/wordcloud_temas_tfidf.png`](output/figures/español/wordcloud_temas_tfidf.png) | Nubes de términos distintivos por tema, ponderadas por TF-IDF. |
| [`output/figures/español/wordcloud_sentimientos_nrc.png`](output/figures/español/wordcloud_sentimientos_nrc.png) | Nubes de palabras asociadas a emociones y polaridad NRC. |
| [`output/figures/español/wordcloud_topicos_stm.png`](output/figures/español/wordcloud_topicos_stm.png) | Nubes de palabras principales por tópico STM. |
| [`output/figures/español/wordcloud_redes_comunidades.png`](output/figures/español/wordcloud_redes_comunidades.png) | Nubes de nodos relevantes por comunidad de red. |
| [`output/figures/español/ml_matriz_confusion_temas.png`](output/figures/español/ml_matriz_confusion_temas.png) | Matriz de confusión del clasificador temático con supervisión débil. |
| [`output/figures/español/ml_confianza_temas.png`](output/figures/español/ml_confianza_temas.png) | Distribución de confianza del clasificador y umbral de reasignación. |
| [`output/figures/español/ml_reduccion_otros.png`](output/figures/español/ml_reduccion_otros.png) | Cambio de la categoría `otros` después de la reasignación ML conservadora. |
| [`output/figures/español/limpieza_retencion_textos.png`](output/figures/español/limpieza_retencion_textos.png) | Retención de textos a través de limpieza, reglas y clasificación final. |
| [`output/figures/español/red_menciones.png`](output/figures/español/red_menciones.png) | Red de co-menciones entre cuentas. |
| [`output/figures/español/red_coocurrencias_corpus.png`](output/figures/español/red_coocurrencias_corpus.png) | Red de co-ocurrencias léxicas del corpus. |
| [`output/figures/español/red_menciones_centralidad.png`](output/figures/español/red_menciones_centralidad.png) | Ranking de centralidad por grado ponderado en la red de menciones. |
| [`output/figures/español/stm_topicos_reformas.png`](output/figures/español/stm_topicos_reformas.png) | Prevalencia estimada de tópicos STM. |
| [`output/figures/español/wordfish_reformas.png`](output/figures/español/wordfish_reformas.png) | Escalamiento Wordfish por tema de reforma. |
| [`output/figures/español/event_study_respuestas_heatmap.png`](output/figures/español/event_study_respuestas_heatmap.png) | Heatmap de respuestas promedio por horizonte y serie financiera. |

Tablas generadas seleccionadas:

| Salida | Descripción |
|----|----|
| [`output/tables/español/cobertura_mercado.html`](output/tables/español/cobertura_mercado.html) | Estado de cobertura de `TRM`, `COLCAP`, `TES` y precio de energía XM. |
| [`output/tables/español/fuentes_mercado_auditadas.html`](output/tables/español/fuentes_mercado_auditadas.html) | Proveedores, URLs, fecha de consulta, filas y estado de las fuentes financieras. |
| [`output/tables/español/keyness_reformas.html`](output/tables/español/keyness_reformas.html) | Términos distintivos por tema de reforma. |
| [`output/tables/español/ml_metricas_temas.html`](output/tables/español/ml_metricas_temas.html) | Accuracy, precision, recall y F1 del modelo base y Naive Bayes temático. |
| [`output/tables/español/ml_matriz_confusion_temas.html`](output/tables/español/ml_matriz_confusion_temas.html) | Matriz de confusión por clase para la supervisión temática débil. |
| [`output/tables/español/modelos_ml_descartados.html`](output/tables/español/modelos_ml_descartados.html) | Modelos NLP/ML considerados pero descartados, con justificación. |
| [`output/tables/español/red_centralidad_nodos.html`](output/tables/español/red_centralidad_nodos.html) | Diagnósticos de grado ponderado, componente y comunidad por nodo. |
| [`output/tables/español/stm_topicos_reformas.html`](output/tables/español/stm_topicos_reformas.html) | Tópicos STM y términos principales. |
| [`output/tables/español/sentometrics_resumen.html`](output/tables/español/sentometrics_resumen.html) | Resumen de sentimiento diario ponderado. |
| [`output/tables/español/granger_trm_colcap_tes.html`](output/tables/español/granger_trm_colcap_tes.html) | Diagnósticos Granger para respuestas cambiarias, bursátiles, TES y precio de energía XM. |
| [`output/tables/español/eda_frecuencia_tweets_petro.html`](output/tables/español/eda_frecuencia_tweets_petro.html) | Frecuencia diaria, semanal y mensual de tweets de `@petrogustavo`. |

Ejemplo visual:

<figure>
<img src="output/figures/español/wordstream_continuo_corpus.png"
alt="Wordstream Plot" />
<figcaption aria-hidden="true">Wordstream Plot</figcaption>
</figure>

## Datos, Cobertura y Credenciales

Los snapshots mensuales de tweets se tratan como la fuente reproducible
de verdad. Algunos snapshots son parciales; revise
[`output/tables/español/auditoria_tweets.html`](output/tables/español/auditoria_tweets.html)
antes de interpretar dinámicas mensuales.

Las carpetas de tweets se organizan por corpus.
`data/raw/twitter/Opinión sobre Petro/` contiene conversación pública
sobre Petro; `data/raw/twitter/Tweets de Gustavo Petro/` contiene tweets
emitidos por la cuenta presidencial en `petrogustavo_full.csv`. Futuras
búsquedas deben usar carpetas paralelas como
`data/raw/twitter/@OtraQuery/`, sin mezclar CSV de emisores, consultas u
objetivos metodológicos distintos en una carpeta genérica.

La cobertura de mercado se audita explícitamente. Las fuentes operativas
son servicios del Banco de la República: SDMX/graficador para `TRM`,
metadata BanRep/BVC para `COLCAP`, tasas cero cupón `TES` en pesos a 1,
5 y 10 años, y la API diaria SINERGOX de XM para `PPPrecBolsNaci`. MSCI
y BVC quedan como referencias metodológicas del índice COLCAP, no como
alimentación diaria. Cada actualización manual registra `retrieved_at`,
`source_url`, `source_series_id`, `status` y `coverage_ratio` en las
auditorías de `output/tables/español/`. Granger/VAR se marca como
**diagnóstico, no conclusión causal**, porque evalúa precedencia
temporal y no identificación estructural.

Ningún script activo del repositorio lee credenciales de la API de X.
Los snapshots de tweets se tratan como insumos preparados, y cualquier
recolección futura debe permanecer manual y fuera del cuaderno
principal. No se deben versionar credenciales reales; cualquier token
expuesto previamente debe rotarse antes de volver a usar la API de X.

## Documentación

- Fuente del README en inglés: [`README.Rmd`](README.Rmd)
- Fuente del README en español: [`README.es.Rmd`](README.es.Rmd)
- README en inglés: [`README.md`](README.md)
- README en español: [`README.es.md`](README.es.md)
- Paper original de referencia:
  [`docs/paper/Impacto_discurso_petro__ENG_.pdf`](docs/paper/Impacto_discurso_petro__ENG_.pdf)
- Cuaderno metodológico en español:
  [`notebooks/español/Cuaderno_Paper_Español.qmd`](notebooks/español/Cuaderno_Paper_Español.qmd)
- Paper Quarto activo:
  [`paper/español/quarto-tandf.qmd`](paper/español/quarto-tandf.qmd)
- PDF renderizado del paper:
  [`paper/español/quarto-tandf.pdf`](paper/español/quarto-tandf.pdf)

## Solución de Problemas

| Síntoma | Qué revisar |
|----|----|
| Error por paquete faltante | Vuelva a ejecutar el bloque de instalación, incluyendo `printtree` desde R-universe. |
| `pandoc` no aparece | Instale RStudio/Positron o configure `RSTUDIO_PANDOC` apuntando al Pandoc de Quarto; por ejemplo `/Applications/quarto/bin/tools/aarch64`. |
| Falta cobertura de mercado | Revise la conexión a internet, el actualizador manual de BanRep, la referencia de endpoints/IDs y `output/tables/español/ingesta_mercado_fuentes.csv`; actualice datos de mercado manualmente si hace falta. |
| Faltan tablas o figuras | Renderice de nuevo el cuaderno después de confirmar que existen los CSV requeridos en `data/processed/`. |
| Falta el diagrama del README | Renderice `README.es.Rmd`; esto regenera `docs/assets/readme_project_flow_es.png`. |

## Créditos

Este proyecto actualiza y extiende el paper original
`Impacto_discurso_petro__ENG_`. Usa paquetes abiertos de R para minería
de texto, sentimiento, tópicos, visualización, tablas y econometría,
entre ellos `quanteda`, `stm`, `sentometrics`, `ggwordcloud`,
`DiagrammeR` y `printtree`.

Las series financieras provienen del Banco de la República, mientras el
precio de energía proviene de XM SINERGOX. Los IDs de fuente, endpoints
y URLs de referencia se documentan en los scripts y en las auditorías
bajo `output/tables/español/` para separar procedencia de datos y
metodología.
