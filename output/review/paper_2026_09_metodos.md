# Trazabilidad de correcciones para el artículo español

## Regla de cambio

Se conservaron las elecciones originales de rezagos, dos familias FDR, diez eventos por criterio, horizontes de 1/3/5/7 días calendario y especificaciones AR(1)-sGARCH(1,1) y DCC(1,1). Los cambios de código responden a contradicciones comprobables entre la unidad declarada y los datos, métricas con denominador incorrecto o etiquetas equivocadas. La actualización de narrativas refleja las tablas regeneradas y no redefine modelos para obtener significación.

| Componente | Problema reproducido | Corrección mínima | Salidas afectadas |
|:--|:--|:--|:--|
| Fecha local de tweets | 2.936 fechas del master anterior diferían de su marca horaria en Bogotá. Por ejemplo, 2022-08-07 04:57 UTC era 2022-08-06 23:57 Bogotá. | Fecha explícita en America/Bogota en el script; reconstrucción desde raw. | Master, tablas y figuras textuales, IPI y modelos; transición por ID en paper_2026_09_timezone_changes.csv. |
| Panel bursátil | 1.397 filas de texto apuntaban a solo 934 sesiones; 463 retornos se repetían y 209 sesiones recibían 2–5 días textuales. | Sumar conteos previos por respuesta; recalcular tasas e IPI por intervalo; unir cada retorno una sola vez. | Panel de 934 filas y 898 completas; VAR, Granger, GARCH y DCC. Detalle en paper_2026_09_panel_comparacion.csv y sensibilidad en ipi_intervalo_sensibilidad.csv. |
| Métricas de clasificación | La matriz de confusión tenía 2.361 documentos, pero los soportes por clase sumaban 13 en el baseline y 84 en Naive Bayes. La función crossing eliminaba predicciones repetidas antes de contar. | expand_grid conserva cada predicción; clases no predichas reciben precisión/F1 cero en la macro media. Se exige que los soportes sumen 2.361 por modelo. | ml_metricas_temas.csv y su gráfico; sin cambio en entrenamiento, predicciones, exactitud ni reasignación de otros. |
| Tabla Markov | Las columnas de transMat eran estados de origen; la tabla anterior las rotulaba como destino. Sus filas sumaban 0,988 y 1,012. La etiqueta de co-movimiento moderado se asignaba al estado de media menor. | Transponer solo al exportar; comprobar suma por fila; usar nombres neutrales y duración en sesiones. | Matriz, tabla de regímenes y título del gráfico; parámetros del modelo intactos. |
| Resumen narrativo | El texto afirmaba unanimidad de rezago 1, 140 pruebas, 8 rechazos nominales, DCC con ambos parámetros significativos y GARCH sin ARCH residual; las tablas lo contradicen. | Redacción vinculada a cifras auditadas, diagnósticos adversos y resultados nulos. | Cuaderno HTML y manuscrito; sin reajustar rezagos, familias, distribuciones o eventos. |

La corrección conjunta de fecha y panel cambia resultados sustantivos. En el snapshot anterior, el panel tenía 1.397 filas, 11 de 208 pruebas Granger nominales y cero tras FDR; el parámetro DCC de reacción era 0,09078 (p = 2,81 × 10⁻¹³). Con ambos errores corregidos hay 934 sesiones, 19 de 208 pruebas nominales y cero tras FDR, y el parámetro DCC es 0,00441 (p = 0,201). El contraste demuestra que las cifras antiguas no deben usarse; no separa el efecto individual de cada corrección.

## Decisiones preservadas y límites

El VAR(1) se conserva aunque AIC y FPE favorezcan dos rezagos y HQ/SC favorezcan uno; seleccionar dos después de ver el resultado sería una decisión metodológica nueva. Portmanteau detecta autocorrelación residual (p = 5,80 × 10⁻⁶). Las 112 pruebas temáticas y las 96 por corpus mantienen dos ajustes Benjamini–Hochberg separados, tal como las dos llamadas originales a p.adjust(). Ninguna tiene q inferior a 0,05. Los GARCH convergen, pero polaridad conserva ARCH residual y polaridad, TRM y energía presentan autocorrelación según Ljung–Box. El parámetro de reacción DCC no es significativo al 5 %. No se ajustaron órdenes o distribuciones para eliminar esas señales.

El estudio de eventos continúa midiendo cambios a 1, 3, 5 y 7 días calendario. COLCAP y TES pueden mostrar niveles propagados en fin de semana y faltantes en festivos; se presenta el número de episodios válidos por celda. No hay errores estándar ni prueba de significación. XM y activos bursátiles usan calendarios y unidades distintas. El artículo evita inferir causalidad o ausencia universal de efecto a partir de estas medias.

Las declaraciones de ausencia de financiación y de conflicto de interés reproducen el contenido del Word histórico y se mantuvieron tras la confirmación recibida en esta conversación. No se redactaron declaraciones nuevas.

## Fuentes y verificaciones

paper_2026_09_auditoria_datos.md documenta reconstrucción byte a byte de masters, hashes, cobertura, ingesta aislada y revisión posterior de XM. La respuesta nueva de XM cambia 90 valores respecto del snapshot versionado; el estudio conserva este snapshot e informa la revisión sin promoverla silenciosamente. El cuaderno se ejecuta con R 4.4.3 y Quarto 1.7.32. Los avisos de citeproc del HTML metodológico se deben a nombres de cuentas con arroba en resultados textuales; no son citas del manuscrito editorial.
