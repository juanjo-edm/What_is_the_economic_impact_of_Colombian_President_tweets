# Verificación de librerías y guía editorial — 5 de septiembre de 2026

La versión final completó los 395 chunks mediante `Rscript --vanilla`, en una copia temporal sin salidas precalculadas, y generó el HTML. La carga inicial resuelve `rescale` mediante `conflict_prefer("rescale", "scales")`; el controlador de validación no define un alias externo. Las 49 comprobaciones históricas pasaron y los 396 archivos comparados con la ejecución de referencia son idénticos byte por byte.

## Alcance y referencia

Se modificaron el Rmd y su HTML, se creó `notebooks/español/README.md` y se añadió este registro independiente. La revisión incluye el inicio por autorización del nuevo plan. Se conservaron las explicaciones sustantivas; únicamente se sustituyó la introducción antigua de librerías y se añadieron las introducciones de los nuevos bloques y una aclaración sobre la nota histórica de validación.

`referencia_antes.Rmd` conserva el estado de entrada, incluidos los cambios sin confirmar. Su SHA-256 es `ab5cf4e104b608ad44533801874c8d8e377289c58f8f340b1d4d62ba6e5d12a8`. Las huellas de los archivos existentes están en `huellas_antes.json`; las del Rmd final y el HTML están en `resumen.json`. Los informes históricos y los archivos de datos, tablas y figuras del repositorio permanecen sin cambios, comprobado contra esas huellas.

## Cambios y evidencia

| Comprobación | Resultado | Evidencia |
| --- | --- | --- |
| Librerías visibles | 39 `library()` y 14 preferencias, en cuatro bloques | Rmd; `html_verificado.json` |
| Estructura de todo el cuaderno | 395 etiquetas únicas; máximo 40 líneas; explicación previa en cada chunk; sintaxis independiente válida | `estructura.json` |
| Código analítico | Expresiones completas y orden idénticos al retirar exclusivamente los prefijos y las declaraciones de dependencias | `equivalencia_codigo.csv` |
| Sustituciones | 1.688 prefijos retirados de tokens de código; única excepción: `stats_filter <- stats::filter` | `estructura.json`; `validar_codigo.R` |
| Funciones | 219 enlaces antes calificados y 246 funciones previamente simples conservan su implementación | `funciones_calificadas.csv`; `funciones_sin_prefijo.csv` |
| Matrices | Seis comprobaciones sobre matrices densas y dispersas, incluyendo transposición y sumas | `despacho_matrices.csv` |
| Pruebas históricas | 49 de 49 correctas, con el cuerpo de las pruebas conservado | `verificaciones_49.csv`; `repetir_49.R` |
| Objetos y muestras | 360 objetos equivalentes con tolerancia numérica de 1e-10, separando metadatos identificados | `comparacion_objetos.csv` |
| Productos | 396 archivos idénticos: tablas, figuras y datos procesados | `comparacion_productos.csv` |
| HTML | Cuatro bloques de librerías desplegados; 57 elementos matemáticos; 92 imágenes sin roturas; siete tablas sin desbordamiento | `html_verificado.json` |

Las preferencias incluyen `filter`, `rescale`, `crossing`, `convert`, `colSums`, `rowSums` y `t`. También fijan `as.Date` y `plot`, cuyos enlaces podían cambiar al adjuntar paquetes adicionales. Las reexportaciones idénticas se verificaron sin añadir preferencias redundantes. Configuración, alias estadístico, declaraciones de variables y `save_audit_table()` quedaron separados. Los bloques iniciales largos se dividieron en límites entre expresiones, conservando el orden de las capas gráficas.

## Diferencias examinadas

De los 360 objetos, 350 coincidieron directamente. En diez se identificaron exclusivamente rutas de la copia temporal, metadatos de directorio de quanteda, identificadores internos de igraph, el prefijo retirado de llamadas guardadas por VAR/STM o el tiempo de cómputo de STM. La comparación adicional conservó vértices, aristas, atributos, muestras y estimaciones; normalizó únicamente esos metadatos. El reporte conserva tanto la comparación cruda como la normalizada.

La equivalencia de productos se refiere a las ejecuciones completas de la versión de entrada y de la versión final. La caché preexistente del repositorio ya presentaba diez archivos diferentes y 18 archivos adicionales respecto de la ejecución de referencia. Las diferencias incluyen redondeo de centralidad de eigenvector, el inventario de carpetas con salidas históricas frente a la copia vacía y tres figuras con sus copias para el paper. Quedan enumeradas en `comparacion_cache_repositorio.csv` y `figuras_cache_historico.csv`. Esas discrepancias preexistentes no se incorporaron ni se borraron; entre las dos ejecuciones comparadas no aparece ninguna diferencia de producto.

El primer intento de esta edición encontró un error de posiciones UTF-8 en tres líneas al retirar prefijos. Se corrigió el tratamiento de posiciones en bytes y se comprobó después la identidad de las expresiones analíticas. La ejecución final se hizo desde el principio. La inspección visual también llevó a mantener cada grupo de librerías en un bloque continuo y a ocultar la impresión auxiliar de las variables del linter, sin alterar su declaración.

## Advertencias y límites

La ejecución final registró cero errores, 41 mensajes y seis grupos de advertencias por chunk. Se conservan la deprecación heredada de `across()`, dos avisos de cuatro filas omitidas en gráficos de clasificación, 6.080 términos sin conteos descartados en la conversión para STM, el aviso de compatibilidad de lematización de spaCy y los avisos de p-values ADF acotados. El registro íntegro está en `condiciones_por_chunk.csv`; la captura usa los manejadores de condiciones de knitr y respeta las opciones de presentación del documento.

Esta revisión comprueba ejecución y equivalencia computacional. Se mantienen pendientes las decisiones sobre no estacionariedad, calendario tras eliminar faltantes, comparaciones múltiples y variantes del IPI, junto con las demás cautelas metodológicas ya documentadas. No se modificaron especificaciones ni se validó inferencia causal por el hecho de completar el render.

## Reproducción del control

El entorno está registrado en `entorno_R.txt`, `versiones_paquetes.csv` y `entorno_python.txt`. Se utilizó R 4.4.3, Pandoc de Quarto, Python 3.11.0, spaCy 3.8.14 y `es_core_news_sm` 3.8.0. El proyecto temporal fue `/private/tmp/petro-libraries-review/run`; `render_verificacion.R` conserva el controlador utilizado y `ejecucion_completa.log` termina con `FULL_RENDER_COMPLETED`.

Los validadores incluyen su sintaxis de uso al inicio. La referencia de resultados fue `/private/tmp/petro-notebook-review/delivery_run` y su entorno `delivery_environment.rds`, producidos por la revisión anterior de la versión de entrada. Para las 49 pruebas se utilizaron además `prefix.RData` y `original.Rmd` de esa revisión. Los entornos completos permanecen en las carpetas temporales; los resultados de las comprobaciones, las huellas y los scripts quedan conservados en este directorio. El README del cuaderno contiene la guía de lectura, ejecución y mantenimiento para el evaluador.
