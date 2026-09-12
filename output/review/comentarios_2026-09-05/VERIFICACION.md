# Verificación de comentarios internos — 5 de septiembre de 2026

Se añadieron 2.841 comentarios en español a la versión actual del cuaderno, incluidos los comentarios recientes del autor. Hay 2.984 comentarios R distribuidos entre los 395 chunks. El README incorpora la convención editorial y un ejemplo. No se modificaron cálculos, parámetros, semillas, dependencias ni especificaciones.

## Evidencia

- `referencia_antes.Rmd` y `huellas_antes.json` conservan la referencia previa. Los informes históricos permanecen intactos.
- `expresiones.csv`: sintaxis independiente válida y secuencia de expresiones analizadas por R exactamente idéntica, incluidos argumentos y literales.
- `estructura.json`: 395 etiquetas únicas, máximo de 40 líneas interiores, explicación Markdown previa en todos los chunks y única excepción `stats_filter <- stats::filter`. El Markdown original se conserva íntegro; no fue necesario dividir chunks.
- `cobertura_comentarios.csv`: todos los chunks contienen comentarios y conservan los comentarios anteriores. `comentarios_agregados.json` identifica las adiciones; `revision_editorial.csv` registra las familias de operaciones revisadas.
- `render.log`: ejecución completa con `Rscript --vanilla`, en una copia temporal sin productos posteriores al punto 4 reutilizados. Los bloques pesados se recalcularon. El registro termina en `FULL_RENDER_COMPLETED`; se guardó el entorno final. `sessionInfo.txt` y `entorno_python.txt` documentan R 4.4.3, Python 3.11.0, spaCy 3.8.14 y el modelo español 3.8.0. Pandoc se configuró externamente desde Quarto.
- `verificaciones_49.csv`: 49 de 49 comprobaciones aprobadas.
- `comparacion_productos.csv`: los 396 productos comparados con la ejecución anterior de librerías son idénticos byte por byte, incluidos datos procesados, tablas y gráficos.
- `html.json`: 92 imágenes, 57 ecuaciones, 7 tablas, encabezados y bloques de resultados idénticos a la referencia. Las cuatro secciones de librerías conservan `fold-show`, 39 llamadas `library()` y 14 preferencias explícitas. Los comentarios aparecen en el código HTML.
- Una diferencia de párrafo respecto del HTML anterior corresponde a la redacción «sutilizamos funciones establecidas», ya presente en la referencia inicial de esta revisión (línea 3221). Se conservó, conforme a la instrucción de no cambiar las explicaciones. No es una diferencia introducida por estos comentarios.
- `archivos_modificados.json`: entre los archivos inventariados al inicio solo cambiaron el Rmd, el README y el HTML. Los resultados originales y los informes anteriores no se sobrescribieron. `huellas_entrega.json` identifica la entrega; el Rmd entregado es idéntico al ejecutado.

## Advertencias e incidencias

La ejecución final registró 395 inicios de chunk, 41 mensajes, seis grupos de advertencias y ningún error. Se conservan en `chunk_conditions.csv`:

1. Deprecación heredada de argumentos adicionales en `across()`, al agregar NRC diario.
2. Exclusión de cuatro filas en un gráfico de supervisión débil por faltantes o límites de escala.
3. La misma exclusión en el segundo gráfico correspondiente.
4. Eliminación de 6.080 características con conteo cero al preparar STM.
5. Aviso de compatibilidad de lematización de spacyr con `es_core_news_sm`.
6. Tres avisos de ADF agrupados: valores p fuera del límite de impresión. No deben interpretarse como valores p exactos.

No se corrigieron estas operaciones porque el alcance autorizado es exclusivamente documental. Se mantienen las decisiones pendientes sobre estacionariedad, calendario efectivo, comparaciones múltiples y limitaciones del IPI; aprobar la ejecución no valida por sí mismo la inferencia ni establece causalidad.

El primer intento se interrumpió al escribir el Markdown intermedio por falta de espacio. Se conservaron su log y condiciones como `primer_intento_*`, se liberaron archivos temporales de ejecuciones intermedias anteriores y se repitió todo en una copia limpia. Los insumos, entornos de referencia necesarios e informes del proyecto se preservaron. Solo el segundo intento sustenta la certificación de ejecución completa.

La inspección del HTML fue estructural y de contenido, incluida la identidad de imágenes, ecuaciones, tablas y resultados. No se certifica una nueva inspección visual en navegador: el navegador automatizado no estuvo disponible en el entorno de cierre. Los atributos de despliegue de librerías se comprobaron en el HTML, sin medir su disposición en pantalla.

## Reproducción de las verificaciones

Los scripts `validar_documentacion.R`, `validar_estructura.py`, `validar_comentarios.R`, `render_verificacion.R`, `repetir_49.R` e `inspeccionar_html.py` conservan las comprobaciones. El driver de render utiliza rutas temporales de esta sesión; para reproducirlo en otra máquina deben ajustarse las rutas de la copia y del entorno, sin alterar el código del cuaderno. El comparador de productos se conserva en el informe anterior de librerías.
