"""Valida la estructura completa del cuaderno metodológico refactorizado.

Uso: python validar_estructura.py CUADERNO_RMD REPORTE_JSON
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

notebook, destination = map(Path, sys.argv[1:])
text = notebook.read_text(encoding="utf-8")
chunks = list(re.finditer(r"^```\{r ([^\n]+)\}\n([\s\S]*?)^```\s*$", text, re.M))
labels = [chunk[1].split(",")[0].strip() for chunk in chunks]
lengths = {label: len(chunk[2].splitlines()) for label, chunk in zip(labels, chunks)}

missing_prose = []
for chunk, label in zip(chunks, labels):
    previous = text[: chunk.start()].rstrip().splitlines()
    if not previous or previous[-1].startswith(("#", "```")):
        missing_prose.append(label)

headings = [int(value) for value in re.findall(r"^# (\d+)\.\s", text, re.M)]
reads = re.findall(r"\bread_csv\s*\(", "\n".join(chunk[2] for chunk in chunks))
old_inputs = re.findall(
    r"tweets_(?:all_|opinion_|presidente_|text_)?(?:normalized|cleaned)\.csv|"
    r"market_(?:daily|coverage|sources)\.csv",
    text,
)
forbidden = {
    "visNetwork": r"\bvisNetwork\b",
    "plotly": r"\b(?:plotly|ggplotly)\b",
    "htmlwidgets": r"\bhtmlwidgets\b",
    "requireNamespace": r"\brequireNamespace\s*\(",
    "exists": r"(?<!file\.)\bexists\s*\(",
}
forbidden_hits = {name: bool(re.search(pattern, text)) for name, pattern in forbidden.items()}

rscript = shutil.which("Rscript")
if rscript is None:
    windows_r = Path(r"C:\Program Files\R\R-4.6.1\bin\Rscript.exe")
    rscript = str(windows_r) if windows_r.exists() else None
r_code = r"""
Sys.setlocale("LC_CTYPE", ".UTF-8")
extracted <- knitr::purl(commandArgs(TRUE)[1], output=tempfile(fileext=".R"), quiet=TRUE)
invisible(parse(extracted))
"""
if rscript:
    ascii_notebook = destination.parent / "notebook-validation.tmp.Rmd"
    validation_script = destination.parent / "notebook-validation.tmp.R"
    ascii_notebook.write_text(text, encoding="utf-8")
    validation_script.write_text(r_code, encoding="utf-8")
    powershell = shutil.which("pwsh") or shutil.which("powershell")
    command = f'& "{rscript}" --vanilla "{validation_script}" "{ascii_notebook}"'
    parsed = subprocess.run(
        [powershell, "-NoProfile", "-Command", command],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    ascii_notebook.unlink(missing_ok=True)
    validation_script.unlink(missing_ok=True)
else:
    parsed = None

key_order = {
    name: text.find(name)
    for name in (
        "tweets_master_path <-",
        "market_master_path <-",
        "tweets_master <-",
        "tweets_all_normalized <-",
        "reform_theme = case_when",
        "tweets_text <-",
        "market_master <-",
        "market_daily <-",
    )
}
definitions_before_use = (
    min(key_order.values()) >= 0
    and key_order["tweets_master_path <-"] < key_order["tweets_master <-"]
    and key_order["tweets_master <-"] < key_order["tweets_all_normalized <-"]
    and key_order["tweets_all_normalized <-"] < key_order["tweets_text <-"]
    and key_order["tweets_text <-"] < key_order["reform_theme = case_when"]
    and key_order["market_master_path <-"] < key_order["market_master <-"]
    and key_order["market_master <-"] < key_order["market_daily <-"]
)

report = {
    "chunks_total": len(chunks),
    "unique_labels": len(labels) == len(set(labels)),
    "maximum_chunk_lines": max(lengths.values()),
    "oversized_chunks": {name: size for name, size in lengths.items() if size > 40},
    "chunks_without_previous_prose": missing_prose,
    "all_chunks_parse_independently": bool(parsed and parsed.returncode == 0),
    "syntax_returncode": parsed.returncode if parsed else None,
    "syntax_diagnostic": "" if parsed and parsed.returncode == 0 else "La extracción R no pudo analizarse",
    "numbered_sections": headings,
    "numbering_is_1_to_12": headings == list(range(1, 13)),
    "base_read_csv_calls": len(reads),
    "only_two_base_reads": len(reads) == 2,
    "uses_here": all(value in text for value in ('library(here)', 'repo_dir <- here()', 'here("data", "processed"')),
    "definitions_before_use": definitions_before_use,
    "old_processed_inputs": old_inputs,
    "forbidden_hits": forbidden_hits,
    "required_static_graph_libraries": all(
        f"library({package})" in text
        for package in ("DiagrammeR", "DiagrammeRsvg", "rsvg")
    ),
    "chunk_lengths": lengths,
}
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

assert report["unique_labels"] and not report["oversized_chunks"]
assert not missing_prose and report["all_chunks_parse_independently"]
assert report["numbering_is_1_to_12"] and report["only_two_base_reads"]
assert report["uses_here"] and report["definitions_before_use"]
assert not old_inputs and not any(forbidden_hits.values())
assert report["required_static_graph_libraries"]
print("Estructura, sintaxis, contratos, rutas y dependencias: verificadas.")
