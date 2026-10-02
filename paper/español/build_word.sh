#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
output="Paper_Mensajes_Presidenciales_Mercados_Colombia_ES.docx"

quarto render quarto-tandf.qmd --to docx --output "$output"
cp "$output" "../English/$output"
printf 'Word generado: %s\n' "../English/$output"
