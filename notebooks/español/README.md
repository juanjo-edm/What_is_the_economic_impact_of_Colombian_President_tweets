# Guía de lectura y mantenimiento del cuaderno

El archivo `Cuaderno_Paper_Español.Rmd` documenta la relación entre el discurso presidencial, la conversación pública sobre Gustavo Petro y las series económicas colombianas. Su propósito es permitir que un par evaluador siga los datos, las transformaciones y las especificaciones del estudio hasta sus resultados y limitaciones. El HTML es la versión de lectura; el R Markdown es la fuente ejecutable y la referencia para revisar el código.

## Requisitos y dependencias

El entorno validado utiliza R 4.6.1. Los pipes nativos `|>` requieren R 4.1 o posterior; esto no garantiza por sí solo la compatibilidad de todos los paquetes. Para reproducir el estudio conviene conservar las versiones registradas en el informe de ejecución, además de los mismos datos y semillas.

Las dependencias directas están declaradas mediante `library(paquete)` al inicio del cuaderno, con un comentario sobre su función. Los bloques de librerías aparecen desplegados en el HTML. Esa sección es la lista operativa de paquetes; deben estar instalados antes de ejecutar el documento. Una dependencia ausente produce un error identificable. Las dependencias transitivas son gestionadas por R al instalar y cargar los paquetes.

| Finalidad | Paquetes declarados |
| --- | --- |
| Datos, fechas y texto básico | conflicted, readr, dplyr, tidyr, tibble, vctrs, forcats, lubridate, stringr, here |
| Figuras y redes | ggplot2, scales, ggwordcloud, ggrepel, igraph, tidygraph, ggraph, DiagrammeR, DiagrammeRsvg, rsvg, ragg, png, grid, graphics, grDevices |
| Análisis textual y matrices | quanteda, quanteda.textstats, quanteda.textmodels, quanteda.textplots, syuzhet, sentometrics, stm, spacyr, reticulate, Matrix |
| Econometría y presentación | stats, tseries, lmtest, vars, zoo, ca, methods, knitr, utils |

Para renderizar también se necesita `rmarkdown` y una instalación accesible de Pandoc. Pandoc puede proceder de Quarto o RStudio; `RSTUDIO_PANDOC` debe apuntar al directorio que contiene su ejecutable. El archivo `notebook-style.css` y la bibliografía relativa al proyecto forman parte de la presentación.

La anotación lingüística requiere Python, spaCy y el modelo español `es_core_news_sm`. El entorno validado utiliza Python 3.11, spaCy 3.8.16 y el modelo 3.8.0. La variable `SPACYR_PYTHON` permite indicar el ejecutable; si no está definida, el cuaderno usa el entorno de `reticulate` llamado `petro-spacyr`. Debe comprobarse que ese mismo Python pueda importar spaCy y cargar el modelo antes de comenzar. La instalación se realiza fuera del cuaderno.

El notebook consume únicamente `data/processed/tweets_master.csv` y `data/processed/market_master.csv` mediante `here()`. El primero conserva todos los tweets, incluidos aquellos cuyo `text_clean` queda vacío; el filtro de la muestra NLP y la clasificación temática se aplican dentro del cuaderno. Las redes se exportan como figuras estáticas reproducibles, sin widgets interactivos.

## Ejecución desde una sesión limpia

1. Conservar una copia del estado actual, incluidos los cambios sin confirmar y los insumos de `data/`. Registrar versiones y huellas de los archivos que se compararán.
2. Trabajar en una copia temporal del proyecto cuando se validen modificaciones: el script escribe los dos masters y el cuaderno escribe tablas, figuras y el HTML. No utilizar salidas anteriores como sustituto de los cálculos del notebook.
3. Abrir una terminal en la raíz que contiene `Paper_Twitter.Rproj`. Configurar las rutas del entorno y ejecutar una sesión nueva, sin restaurar un espacio de trabajo anterior.

```sh
export RSTUDIO_PANDOC="/Applications/quarto/bin/tools/aarch64"
export SPACYR_PYTHON="$HOME/.virtualenvs/petro-spacyr/bin/python"
"$SPACYR_PYTHON" -c 'import spacy; spacy.load("es_core_news_sm"); print(spacy.__version__)'
Rscript --vanilla -e 'library(rmarkdown); render("notebooks/español/Cuaderno_Paper_Español.Rmd", output_format="html_notebook", envir=new.env(parent=globalenv()))'
```

Las rutas anteriores corresponden al equipo de referencia y deben ajustarse al entorno del evaluador. En cada ejecución se recalculan los bloques pesados con sus muestras, semillas y parámetros existentes; no se leen resultados guardados como sustituto de esos cálculos.

4. Conservar el registro de errores, mensajes y advertencias por chunk. Un render terminado no demuestra, por sí solo, la validez de la inferencia. Ante un error, identificar el bloque, el insumo y la dependencia; no convertir el fallo en un resultado vacío presentado como exitoso.
5. Abrir `Cuaderno_Paper_Español.nb.html` y revisar portada, TOC, tablas, ecuaciones y figuras estáticas, incluidas todas las redes. Contrastar los productos con la referencia antes de incorporarlos al proyecto.

## Recorrido sugerido para el par evaluador

- **Datos y cobertura:** revisar las fechas, las fuentes, la separación entre tweets presidenciales y conversación pública, los identificadores, los filtros y los faltantes. Comprobar qué observaciones entran efectivamente en cada muestra.
- **Transformaciones:** seguir la construcción de corpus, temas, indicadores, sentimiento y redes. Revisar denominadores, unidades, ponderaciones y ventanas temporales antes de interpretar sus gráficos.
- **Modelos:** vincular cada referencia y pregunta con su ecuación, variables, muestra, código de estimación y resultado. La disponibilidad de una estimación no certifica los supuestos que permitirían interpretarla.
- **Resultados y límites:** contrastar magnitudes, signos, cobertura y diagnósticos con la interpretación escrita. Distinguir asociación descriptiva, capacidad predictiva y causalidad; un contraste de Granger no identifica por sí mismo un efecto causal ni su magnitud económica.

La revisión debe conservar las decisiones metodológicas pendientes: tratamiento de series no estacionarias, calendario después de eliminar faltantes, comparaciones múltiples y limitaciones del IPI heredado. En el VAR se mantienen la constante y el orden 2; no se calculan IRF. Los eventos son descriptivos, conservan sus horizontes y deben leerse junto a sus unidades y cobertura efectiva. No añadir diferencias, cointegración, controles, HAC o ajustes de significancia sin una decisión metodológica documentada.

## Convenciones de código y escritura

### Convención obligatoria para resultados visibles

Cada resultado final del cuaderno debe seguir la secuencia:

`contexto/objetivo → código → tabla o gráfico → interpretación`

Después de cada tabla o gráfico final visible debe aparecer inmediatamente un
párrafo de interpretación académica. Ese párrafo debe explicar qué muestra la
salida, destacar el patrón o magnitud principal, mencionar categorías, fechas,
unidades o relaciones relevantes y explicar su significado para la pregunta de
investigación. También debe señalar limitaciones importantes y evitar afirmar
causalidad cuando el resultado sea descriptivo, asociativo o de precedencia
temporal. Si no hay datos suficientes, debe explicarse explícitamente por qué
no existe evidencia interpretable.

Las interpretaciones deben derivarse de los valores efectivamente producidos en
la ejecución reproducible. Una tabla debe enfatizar magnitudes y resultados
numéricos; un gráfico debe enfatizar patrones visuales y comparaciones. El texto
debe explicar el resultado, no limitarse a narrar el código. Debe distinguirse
claramente entre descripción, asociación, predicción y causalidad.

Los objetos auxiliares no requieren interpretación. Solo las tablas y figuras
finales que aparecen visibles en el cuaderno la requieren; no se deben imprimir
auxiliares ni duplicar productos finales. Toda figura final debe ser
autocontenida y poder entenderse sin inspeccionar el código que la genera:
título, ejes, unidades, leyendas, escalas, facetas, categorías, fechas y reglas
de etiquetado deben ser suficientes para su lectura. En redes, si no es viable
etiquetar todos los nodos, se debe documentar una regla reproducible y conservar
una tabla asociada con todos los nodos.

La validación distingue explícitamente 6 tablas generadas por R y 1 tabla
Markdown de revisión: en total son 7 tablas visibles finales. También exige
92 gráficos generados, 92 impresos y 92 interpretaciones inmediatas, con una
fila por gráfico en la lista de control y `estado_final = OK` en todas ellas.

- Escribir en español académico, con títulos informativos, nombres descriptivos y términos consistentes. Explicar las decisiones para un economista que pueda no conocer cada paquete de R.
- Utilizar pipes nativos `|>`. Conservar las especificaciones, semillas, filtros, muestras, nombres de salidas, rutas y estilo gráfico salvo que el cambio correspondiente haya sido autorizado y documentado.
- Dar a cada chunk una etiqueta única y descriptiva. Ninguno puede superar **40 líneas interiores**, contando comentarios y líneas vacías, sin contar las dos líneas de delimitación.
- Mantener expresiones R completas en cada chunk. Dividir en límites entre preparación, transformación, estimación, exportación y visualización. No cortar una llamada, una función, un condicional o una secuencia de capas gráficas a la mitad.
- Aplicar el patrón obligatorio **explicación Markdown → código → interpretación cuando corresponda**. Un título o un comentario dentro del código no sustituye el párrafo previo.
- Indicar en cada introducción el insumo, el propósito, la transformación, el objeto producido y su conexión con la etapa siguiente. Evitar explicaciones genéricas que solo anuncien que se ejecutará código.
- En resultados de modelos, documentar la correspondencia **referencia → pregunta → ecuación → datos y muestra → código → resultado → interpretación**. Separar la especificación ejecutada, los diagnósticos válidos y las decisiones pendientes.

### Plantilla breve

El siguiente ejemplo muestra la estructura editorial; los nombres y la operación deben adaptarse al análisis real.

````markdown
El bloque recibe `datos_diarios`, cuya unidad es una fecha y un corpus.
Para describir la cobertura observada, cuenta las fechas disponibles por corpus
y produce `cobertura_corpus`. Esta tabla permite evaluar la muestra antes de
interpretar las estimaciones de la sección siguiente.

```{r cobertura-por-corpus}
cobertura_corpus <- datos_diarios |>
  group_by(corpus) |>
  summarise(fechas_observadas = n_distinct(date), .groups = "drop")
```

La interpretación debe informar los conteos obtenidos y las diferencias de
cobertura relevantes, sin atribuirles efectos que este resumen no estima.
````

### Comentarios dentro del código

Cada paso relevante debe llevar un comentario en español que explique la operación: qué observaciones se seleccionan, qué variable se transforma, qué calcula el modelo o qué producto se guarda. Los comentarios internos complementan el párrafo Markdown previo y la interpretación; no los sustituyen. Evitar describir paréntesis, repetir únicamente el nombre de una función o atribuir propiedades que el código no comprueba.

Conservar los comentarios existentes que sigan describiendo correctamente la operación. En cálculos estadísticos, indicar denominadores, unidades, ventanas y condiciones de insuficiencia cuando sean necesarios para entender el resultado. Distinguir una comprobación de disponibilidad de una validación de supuestos.

````markdown
El bloque normaliza entidades para comparar variantes de escritura. El vector
resultante se utilizará al identificar las menciones correspondientes.

```{r ejemplo-normalizacion-entidades}
entidades_limpias <- entidades |>
  # Unificar mayúsculas y minúsculas antes de comparar nombres.
  str_to_lower() |>
  # Retirar espacios exteriores y reducir los espacios interiores repetidos.
  str_squish()
```
````

Los comentarios y las líneas vacías cuentan dentro del máximo de 40 líneas. Usar comentarios breves al final de línea cuando permitan conservar una expresión completa. Si hace falta dividir un chunk, hacerlo entre expresiones completas, conservar el orden y añadir una explicación Markdown antes del nuevo bloque. Una revisión exclusivamente documental debe demostrar que las expresiones analizadas por R son idénticas antes y después, incluidos argumentos y literales.

### Dependencias y conflictos

Añadir cada dependencia directa en la sección inicial mediante `library(nombre)`, con un comentario breve que explique su uso en el estudio, antes de su primera utilización. Los chunks de esa sección contienen únicamente comentarios, `library()` y `conflict_prefer()`: no incluyen instalaciones, condicionales, bucles, comprobaciones ni funciones auxiliares. Deben mantener `echo=TRUE` y `class.source="fold-show"`, además del límite de 40 líneas y el párrafo introductorio.

Cuando varios paquetes comparten un nombre, comprobar la implementación necesaria y declarar allí `conflict_prefer("funcion", "paquete")`. La preferencia afecta a todo el cuaderno: no basta con resolver el primer error encontrado. Verificar también las llamadas que ya carecían de prefijo y el despacho de clases, especialmente con matrices dispersas y gráficos. Las reexportaciones idénticas no requieren nuevas preferencias.

En el código analítico se usan nombres simples, sin `paquete::funcion`. La única excepción acordada es `stats_filter <- stats::filter`, definida en su propio chunk auxiliar y explicada antes del código. `stats_filter()` conserva el filtro estadístico del promedio móvil; `filter()` selecciona filas con dplyr. No reemplazar uno por otro. Las opciones globales, declaraciones de variables y `save_audit_table()` permanecen en chunks independientes de las librerías.

## Procedimiento para futuros cambios

1. Registrar la referencia del estado actual antes de editar. Conservar los informes históricos: sus huellas y conclusiones describen versiones concretas, no todas las versiones posteriores.
2. Delimitar el cambio y mantener las explicaciones sustantivas y la secuencia analítica. Si se corrige una inconsistencia, registrar evidencia, ajuste y resultados afectados; si cambia una especificación, documentar su justificación por separado.
3. Verificar automáticamente todo el Rmd: etiquetas únicas, sintaxis independiente, explicación anterior, máximo de 40 líneas y ausencia de llamadas calificadas salvo el alias acordado. Comparar también las expresiones analíticas para detectar cambios involuntarios.
4. Ejecutar la versión completa mediante `Rscript --vanilla` en una copia temporal. Repetir las 49 comprobaciones numéricas existentes y las verificaciones de funciones; comparar muestras, identificadores, fechas, indicadores, resultados deterministas y gráficos con la referencia.
5. Revisar el HTML: librerías desplegadas, ecuaciones legibles, tablas completas y figuras disponibles. Conservar y explicar advertencias sustantivas. Separar un aviso técnico de un problema de datos o de validez econométrica; no ocultar estos últimos para obtener una ejecución aparentemente limpia.
6. Incorporar únicamente los productos previstos y entregar un registro breve con el alcance, el entorno, las comprobaciones, las diferencias y las limitaciones. No declarar equivalencia mientras existan diferencias inesperadas sin explicar.

La revisión anterior se conserva en `../../output/review/`. La revisión de dependencias y estilo tiene su registro propio en `../../output/review/librerias_2026-09-05/`; cada informe debe leerse junto con la versión y el entorno que verificó.

La revisión de comentarios internos se registra por separado en `../../output/review/comentarios_2026-09-05/`. Su comparación de expresiones permite distinguir cambios documentales de cambios de implementación.
