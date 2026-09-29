#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
python_bin="${PYTHON_BIN:-python3}"
output="Paper_Mensajes_Presidenciales_Mercados_Colombia_ES.docx"

"$python_bin" make_reference_doc.py
quarto render quarto-tandf.qmd --to docx --output "$output"
"$python_bin" postprocess_docx.py "$output"
mv "$output" "../English/$output"
printf 'Word generado: %s\n' "../English/$output"
