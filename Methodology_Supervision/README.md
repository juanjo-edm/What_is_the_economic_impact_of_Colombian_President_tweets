# Módulo de Supervisión Metodológica

Esta carpeta contiene el entorno de supervisión, auditoría de datos y control metodológico para la investigación sobre el impacto del discurso de Gustavo Petro en los mercados financieros colombianos (2022–2026). Su objetivo es validar la consistencia empírica de las señales textuales y documentar las decisiones de diseño previas a su incorporación en el manuscrito formal del paper (`paper/español/quarto-tandf.qmd`).

---

## 1. Documentos y estructura de la carpeta

| Archivo | Formato | Descripción |
|---|---|---|
| `Supervision_Metodologica.qmd` | Quarto (`.qmd`) | Cuaderno metodológico ejecutable y reproducible que centraliza las cuatro revisiones de control de calidad. |
| `Supervision_Metodologica.html` | HTML auto-contenido | Versión compilada para lectura interactiva y revisión de pares evaluadores. |
| `README.md` | Markdown | Esta guía descriptiva del módulo, requisitos y convenciones. |

---

## 2. Contenido de las cuatro tareas de supervisión

El documento `Supervision_Metodologica.qmd` aborda sistemáticamente cuatro componentes clave:

### A. Auditoría empírica de los dos corpus
* **Objetivo:** Evaluar la integridad, unicidad y cobertura temporal diferenciada entre la conversación ciudadana (`opinion`) y la emisión presidencial directa (`presidente`).
* **Insumo:** Contrato contractual `data/processed/tweets_master.csv` (importando identificadores como `col_character()` para preservar los enteros de 64 bits sin pérdida de precisión).
* **Resultados auditados:**
  * **Corpus `opinion`:** 13.648 tweets, 13.648 IDs únicos, 0 duplicados, 0 textos vacíos tras limpieza, cubriendo 1.349 días entre el 2022-08-01 y el 2026-05-31.
  * **Corpus `presidente`:** 14.656 tweets, 14.656 IDs únicos, 0 duplicados, 222 textos vacíos en `text_clean` (mensajes compuestos exclusivamente por hipervínculos multimedia o menciones aisladas retiradas en el preprocesamiento), cubriendo 1.331 días a partir del 2022-08-07 (posesión presidencial).
* **Salida persistida:** `output/tables/español/auditoria_comparada_dos_corpus.csv`.

### B. Revisión de temas/keyness, sentimiento e IPI
* **Temas y Keyness:** Diagnóstico de participación relativa (institucionalidad 34,5% en opinión vs 20,1% en presidente; seguridad 22,9% en presidente; salud 11,4%; internacional 10,4%; laboral 9,7%). Confirmación de distintividad léxica mediante estadístico $\chi^2$ de Keyness ($p < 0,001$).
* **Sentimiento NRC y polaridad:** Identificación del sesgo léxico positivo intrínseco de los diccionarios (polaridad media de +3,07 en opinión y +6,05 en presidente). Se fundamenta la necesidad de evaluar variaciones relativas y no niveles absolutos.
* **Índice de Presión Informacional (IPI):** Distribución centrada en cero ($\mu = 0,0388$, $\sigma = 1,1390$, rango $[-10,41, +11,12]$) con 69 días de alta presión ($|IPI| > 2$). Se ratifica el control estricto de *look-ahead bias* ($S_t \to R_{t+1}$) al contrastar con series de mercado.

### C. Propuesta técnica para figuras F1–F5 del paper
Especificación de cinco figuras compuestas en paneles complementarios para el cuerpo principal del artículo:
1. **F1 (Volumen y cobertura comparada):** Panel A (volumen mensual agrupado) + Panel B (días observados por mes).
2. **F2 (Actividad temporal presidencial):** Panel A (serie diaria con media móvil a 7 días) + Panel B (calendario estacional / mapa de calor).
3. **F3 (Estructura temática y Keyness):** Panel A (participación porcentual por tema) + Panel B (ranking $\chi^2$ de términos distintivos).
4. **F4 (Red de menciones por corpus):** Panel A (red de opinión ciudadana) + Panel B (red institucional presidencial en estilo `quanteda`).
5. **F5 (Polaridad diaria e IPI):** Panel A (serie de polaridad neta) + Panel B (serie IPI estandarizada con umbrales de días extremos).

### D. Matriz de literatura y mecanismos de transmisión macrofinanciera
Matriz analítica organizada en cuatro bloques rigurosos:
1. *Comunicación presidencial y redes sociales* (Pérez & Llorente, 2020; Prada & Espinel, 2018; Casallas, 2020).
2. *Sentimiento y atención de inversores* (Bollen et al., 2011; Da et al., 2011; Ardia et al., 2021).
3. *Política económica colombiana e incertidumbre institucional* (Sandoval & Marín, 2022; Echeverry, 2023; Alonso & Berggrun, 2015; García & Soto, 2021).
4. *Métodos computacionales y econometría de series de tiempo* (Roberts et al., 2019; Engle, 2002; Benjamini & Hochberg, 1995; Hamilton, 1989 / Krolzig, 1997).
* Cada entrada explicita el canal de transmisión específico hacia la TRM, el índice COLCAP, los títulos TES y el precio spot de energía en la bolsa de XM.

---

## 3. Convenciones de código y redacción

El documento `Supervision_Metodologica.qmd` cumple cabalmente con las normas del proyecto:

1. **Límite de líneas por chunk:** Ningún bloque de código excede las **40 líneas interiores**.
2. **Secuencia de presentación obligatoria:**
   $$\text{Explicación previa en Markdown} \longrightarrow \text{Código reproducible} \longrightarrow \text{Salida tabular o gráfica} \longrightarrow \text{Interpretación académica inmediata}$$
3. **Paquetes prohibidos:** Cero dependencias de visualizaciones interactivas no reproducibles (`visNetwork`, `plotly`, `htmlwidgets`, `exists`, `requireNamespace`).
4. **Tratamiento numérico seguro:** Preservación de identificadores de Twitter como cadenas de caracteres (`col_character()`) para evitar el truncamiento por desbordamiento de enteros de 64 bits.
5. **Pipes y rutas:** Uso exclusivo del pipe nativo `|>` y resolución de rutas relativas con `here::here()`.

---

## 4. Instrucciones de reproducción y compilación

Para renderizar el documento completo desde la raíz del repositorio:

```bash
quarto render Methodology_Supervision/Supervision_Metodologica.qmd
```

El proceso compila el documento en HTML auto-contenido (`embed-resources: true`) con tabla de contenido flotante, plegado de código (`code-fold: true`) y estilos tipográficos limpios.
