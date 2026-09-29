# Auditoría de fuentes y datos para el paper (septiembre de 2026)

**Ventana fija:** 1 de agosto de 2022 a 31 de mayo de 2026. **Fuente de resultados del paper:** los archivos raw versionados, con el `tweets_master.csv` regenerado tras corregir la fecha local. La nueva respuesta de XM se documenta como revisión de fuente y no se incorpora al panel ni a los resultados del cuaderno.

## Reconciliación del snapshot

La reconstrucción aislada con R 4.4.3 y los raw versionados reproduce **byte a byte** ambos maestros después de la corrección: `tweets_master.csv` SHA-256 `ba7519ccfd32549c7cd783b386e23ad1cd64b56436583d4321b74e81a24e1029`; `market_master.csv` SHA-256 `d6a7c4747d6c286f3902c3d4e362123f9d2a15cb0502cfa94cde00ca881f9b4b`. Los seis valores raw de mercado coinciden con el maestro en todas sus fechas observadas; no hay fechas duplicadas ni inconsistencias entre banderas de observación y arrastre. [El JSON](paper_2026_09_auditoria_datos.json) guarda hashes y conteos completos; [el script de auditoría](paper_2026_09_auditoria_datos.py) permite recalcularlos.

| Serie | Fechas observadas raw | Arrastre fin de semana | Faltantes lunes–viernes |
|---|---:|---:|---:|
| TRM | 1.400 | 0 | 0 |
| COLCAP | 935 | 400 | 65 |
| TES 1, 5 y 10 años (cada uno) | 935 | 400 | 65 |
| Precio spot XM | 1.400 | 0 | 0 |

El panel tiene 1.400 días calendario (1.000 lunes–viernes, 400 sábados/domingos). El arrastre de COLCAP y TES solo cubre fines de semana; los 65 faltantes entre semana siguen ausentes. El último dato **observado** de COLCAP/TES es 29 de mayo de 2026; el valor mostrado el 31 de mayo es una copia. La TRM aparece en todos los días del raw oficial y no debe describirse como una transacción bursátil diaria. XM conserva todos los días sin arrastre.

## Corrección de fecha de tweets

En la versión previa, `as.Date(parsed_time_bogota)` devolvía la fecha UTC por defecto aunque el timestamp visible ya estaba convertido a Bogotá. Por ejemplo, `2022-08-07T04:57:24Z` corresponde a `2022-08-06T23:57:24-0500`, pero se etiquetaba `2022-08-07`. El script ahora usa `as.Date(parsed_time_bogota, tz = "America/Bogota")` tanto para `date_bogota` como para `date`, antes del filtro temporal.

| Medida | Snapshot anterior | Master corregido |
|---|---:|---:|
| Tweets de opinión | 13.648 | 13.648 |
| Tweets presidenciales | 14.656 | 14.659 |
| Días de opinión con tweets | 1.349 | 1.348 |
| Días presidenciales con tweets | 1.331 | 1.313 |
| Fechas que contradicen `timestamp_bogota` | 2.936 | 0 |
| IDs duplicados por corpus | 0 | 0 |

Se corrigió la fecha de 2.935 IDs conservados (2.925 presidenciales, 10 de opinión). Además, un tweet sale del periodo presidencial porque ocurrió el 6 de agosto en Bogotá, y cuatro entran porque ocurrieron el 31 de mayo en Bogotá aunque ya era 1 de junio UTC. Los 2.940 cambios por ID están en [la tabla de transición](paper_2026_09_timezone_changes.csv). El hash previo era `a1097de8c79ec3e48e4c065f3e68e971c8c9e55f2e2f44a5fe3276e697b2691a`; su perfil se conserva en [la auditoría previa](paper_2026_09_auditoria_datos_pre_tz.json).

El maestro corregido tiene 28.307 tweets y 28.085 textos limpios no vacíos (13.648 opinión; 14.437 presidente). La cuenta presidencial conserva un solo `author_id`. El corpus de opinión conserva 46 archivos mensuales y 52 días sin tweets; 1.291 de los 1.348 días observados tienen exactamente diez registros y 13.305 de sus 13.648 tweets se publicaron durante la hora 18:00 de Bogotá. El código de extracción disponible utiliza una búsqueda de X con filtros de idioma y tipo de publicación, reparte un objetivo mensual en cupos diarios y detiene la paginación al alcanzar cada cupo. Sin los registros de ejecución de todos los archivos históricos, no se puede verificar que cada mes se haya obtenido exactamente con esa versión del código ni inferir selección aleatoria. El corpus observado está limitado por los topes de recuperación y su concentración horaria; ni su conteo diario ni el IPI basado en él miden el volumen total de conversación en X.

## Contraste con APIs oficiales

La ingesta aislada de las mismas fechas consultó Banco de la República y XM el 29 de septiembre de 2026 entre 02:18 y 02:19 UTC. TRM utilizó el graficador oficial como *fallback* tras un fallo de parseo SDMX. TRM, COLCAP y TES reprodujeron sus cinco raw versionados byte a byte, con idénticas fechas y valores. [El registro de fuentes](paper_2026_09_ingesta_fuentes.csv) conserva proveedor, identificador de serie, URL, estado y hora UTC de consulta; [la cobertura](paper_2026_09_ingesta_cobertura.csv) conserva los conteos de esa ejecución.

XM devolvió 1.400 fechas, pero revisó **90 valores** respecto del raw versionado: todos los días de diciembre de 2025 (31), febrero de 2026 (28) y mayo de 2026 (31). La mediana de la diferencia absoluta fue 0,049985 COP/kWh; la máxima, 4,73770 COP/kWh (1,749 % del valor versionado) el 27 de diciembre de 2025. El hash XM versionado es `48ae4702e0030c3c8b5f43112b6bda3d68129073fe9669d67ebbbc595fb20832` y el de la respuesta nueva, `0e278d425a37f9ad9c736caa184c5e9819d9e982a1a8368b14d6751ffae9c652`. [La tabla de revisiones](paper_2026_09_mercado_revisiones.csv) guarda fecha y ambos valores, lo que permite reconstruir el snapshot alternativo. No se identificó la causa de la revisión en el API.

## Protección de ingesta y límites

La versión anterior de `ingest_market.R` capturaba fallos de conexión, terminaba con código 0 y reescribía los seis raw con CSV vacíos. Se añadió una guarda mínima inmediatamente después de descargar las series: si cualquiera no tiene observaciones, el script se detiene **antes** de escribir. En una prueba aislada sin resolución DNS, la nueva versión salió con código 1 y conservó los seis hashes raw; [el registro de prueba](paper_2026_09_ingesta_offline_test.log) contiene comando, código, hashes y diagnóstico. La guarda evita la pérdida total; no valida revisiones parciales de una fuente que sí devuelve algunas filas.

Los raw CSV versionados no guardan una hora de extracción propia. El registro nuevo prueba la consulta aislada de septiembre de 2026, pero no fecha la descarga que produjo el snapshot versionado. Las cifras del manuscrito y del cuaderno deben recalcularse con el nuevo maestro de tweets; las tablas o figuras anteriores a la corrección de fecha no certifican la asignación diaria local.
