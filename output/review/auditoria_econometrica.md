# Auditoria econometrica

Fecha de auditoria: 2026-09-23

| Componente | Estado | Cambio realizado | Justificacion | Diagnostico | Limitacion restante |
|---|---|---|---|---|---|
| timezone | corregido | `tweets_master.csv` conserva `timestamp_utc` y agrega `timestamp_bogota`, `date_bogota`; `date` queda como alias compatible de `date_bogota`. | Evitar asignar tweets nocturnos colombianos al dia UTC siguiente. | Script `twitter_process_raw_data.R` ejecutado desde cero; CSV muestra UTC `Z` y Bogota `-0500`. | Revisar resultados historicos que se hayan calculado con la fecha UTC previa. |
| timing | corregido en notebook | Se agregan `date_sentiment` y `next_trading_date`; el panel bursatil principal usa `S_t -> R_(siguiente dia bursatil observado)`. | Evitar look-ahead bias entre sentimiento diario completo y cierre del mismo dia. | Se agrego tabla `00_auditoria_temporal_paneles`. | Falta render completo por ausencia de Pandoc en esta terminal. |
| calendario financiero | corregido | El panel bursatil filtra observaciones reales mediante banderas `*_observed`. | No usar precios arrastrados como nuevas observaciones de mercado. | `market_master.csv` incluye banderas observadas/carry-forward. | TRM aparece observada todos los dias segun insumo raw disponible; conviene auditar fuente si se requiere calendario estrictamente bursatil. |
| calendario XM | corregido parcialmente | `panel_electrico` separado, con retorno solo si precio XM observado y positivo. | XM no debe forzarse al calendario bursatil. | `energy_spot_price_observed` cubre calendario continuo y `energy_spot_price_carried_forward` es FALSE. | DCC-XM queda condicionado a diagnostico marginal posterior. |
| retornos | corregido | TRM/COLCAP usan diferencias log sobre fechas financieras observadas; TES usa diferencias de tasas; XM usa log solo con precios positivos. | Coherencia financiera por tipo de variable. | Transformaciones movidas a helpers del notebook. | Falta tabla consolidada nueva tras render. |
| TES | corregido | `diff_tes_10y` y `diff_tes_slope` usan diferencias simples, no log-return. | TES son tasas/rendimientos, no precios positivos. | Implementado en panel principal y contemporaneo. | Revisar unidades en interpretacion economica final. |
| ADF/KPSS | mantenido | Se conserva bloque ADF/KPSS, ahora alimentado por paneles corregidos. | Contrastar raiz unitaria y estacionariedad. | Tabla `estacionariedad_series` se regenerara al render. | Texto interpretativo aun contiene frases fuertes/hardcodeadas que deben dinamizarse. |
| Johansen | mantenido con cautela | Se conserva Johansen en niveles financieros. | Solo aplica a series en niveles razonablemente I(1). | Bloque existente se mantiene. | Falta condicionar automaticamente su ejecucion a clasificacion I(1). |
| Granger | corregido | Familia financiera excluye XM, usa timing `S_t -> R_(t+1)`, separa corpus y reporta `p_raw`/`p_fdr`. | Precedencia predictiva sin look-ahead y con FDR. | Bloques `granger_all` y `granger_by_corpus` actualizados. | Seleccion principal de rezago por criterio informativo queda pendiente. |
| multiples comparaciones | mejorado | Se agregan `p_raw`, `p_fdr`, `significant_raw`, `significant_fdr`. | No ocultar resultados no significativos. | Tabla completa de Granger conserva todos los contrastes. | Definir familias FDR mas finas si se amplian senales. |
| VAR | parcialmente corregido | VAR usa panel bursatil principal sin XM ni carry-forward financiero. | Frecuencia comun y variables estacionarias. | Diagnosticos existentes siguen en el cuaderno. | Falta hacer texto y p seleccionados completamente dinamicos. |
| VECM | documentado | Se conserva logica VECM solo si Johansen lo justificara. | No usar VECM sin cointegracion. | Actualmente el notebook descarta VECM segun Johansen existente. | Falta condicional programatico completo. |
| GARCH | parcialmente corregido | XM queda en marginal univariado separado de DCC financiero. | Marginales deben diagnosticarse antes de DCC. | Tabla ARMA-GARCH existente se mantiene. | Seleccion ARMA(p,q) por grilla todavia pendiente. |
| DCC financiero | corregido | DCC principal usa solo `ipi`, `polaridad`, `ret_trm`, `ret_colcap`, `diff_tes_10y`, `diff_tes_slope`; reutiliza `dist_map`. | No mezclar XM y no imponer especificacion generica completamente desconectada. | Nuevas salidas: `07_dcc_financiero_parametros`, `08_dcc_financiero_correlaciones`. | Los ordenes ARMA siguen fijos en este pase. |
| DCC XM | pendiente | No se estima automaticamente. | Debe depender de diagnostico aceptable del marginal XM. | XM separado en `panel_electrico`. | Implementar DCC-XM solo si energia supera diagnosticos. |
| Markov Switching | corregido en nomenclatura | El bloque se renombra como Markov-Switching de media/varianza. | El modelo estimado no incluye componente AR. | Salidas `11_markov_regimenes` y `11_markov_matriz_transicion`. | Estimar p=1 si se decide requerir MS-AR real. |
| corpus opinion | mantenido | Pipeline principal conserva opinion. | Mide conversacion publica. | `model_dataset` filtra `opinion`. | Revisar IPI tematico vs IPI por corpus. |
| corpus presidente | mejorado | Granger por corpus usa el mismo helper financiero. | No mezclar emisor presidencial con opinion publica. | `granger_by_corpus` separado. | Extender separacion a todos los modelos si se requiere simetria completa. |
| robustez | pendiente | No se agrego seccion completa nueva. | Debe separar principal vs sensibilidad. | Algunas grillas existentes se mantienen. | Construir tabla `12_robustez`. |
| causalidad | mejorado parcialmente | Se corrigieron frases del bloque Markov y timing; se mantiene advertencia de no causalidad en varias secciones. | Granger/VAR/DCC/MS no identifican causalidad estructural. | Paper aun contiene frases fuertes. | Requiere barrido editorial completo de README/paper/captions. |
| render | bloqueado | Se intento renderizar `Cuaderno_Paper_Español.Rmd`. | Validacion final exige render limpio. | Falla: `pandoc version 2.8 or higher is required and was not found`. | Instalar/configurar Pandoc o usar RStudio/Quarto con Pandoc disponible. |

## Que puede afirmarse

- Los tweets ahora tienen fecha analitica colombiana (`date_bogota`) y timestamp UTC preservado.
- El panel bursatil principal ya evita usar sentimiento del dia completo para explicar el cierre del mismo dia.
- Las variables financieras principales usan observaciones reales de mercado para retornos y diferencias.
- XM queda separado del calendario financiero y no entra al DCC bursatil principal.
- Las pruebas de Granger actualizadas reportan p-values crudos y ajustados por FDR.
- El modelo Markov ya no se presenta como MS-AR cuando no contiene rezago autorregresivo.

## Que NO puede afirmarse

- No puede afirmarse causalidad estructural de tweets o sentimiento sobre mercados.
- No puede afirmarse que XM este listo para DCC-XM hasta completar diagnosticos marginales.
- No puede afirmarse render limpio del notebook o paper en esta terminal porque falta Pandoc.
- No puede afirmarse que todos los textos estaticos del paper/README esten sincronizados; falta barrido editorial final.
