"""QA de todo el Rmd; no ejecuta el análisis.
Uso: python3 validar_estructura.py ACTUAL_RMD REFERENCIA_RMD REPORTE_JSON
"""
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

notebook, reference, destination = map(Path, sys.argv[1:])
s = notebook.read_text()
old = reference.read_text()
pattern = r'^```\{r ([^\n]+)\}\n([\s\S]*?)^```[ \t]*$'
chunks = list(re.finditer(pattern, s, re.M))
labels = [c[1].split(',')[0].strip() for c in chunks]
lengths = {label: len(c[2].splitlines()) for label, c in zip(labels, chunks)}
missing = [label for label, c in zip(labels, chunks)
           if s[:c.start()].rstrip().splitlines()[-1].startswith(('#', '```'))]
# Compare all original Markdown paragraphs, excluding only the replaced library introduction.
markdown = re.sub(pattern, '', old, flags=re.M)
paragraphs = [p.strip() for p in re.split(r'\n\s*\n', markdown) if p.strip()]
removed = [p for p in paragraphs if p not in s]
allowed = []
r_code = r'''
s <- readLines(commandArgs(TRUE)[1], warn=FALSE)
found <- character()
for (i in which(startsWith(s, '```{r'))) {
 j <- i + which(trimws(s[(i+1):length(s)]) == '```')[1]
 p <- getParseData(parse(text=s[(i+1):(j-1)], keep.source=TRUE))
 ns <- p[p$token %in% c('NS_GET','NS_GET_INT'), ]
 if (nrow(ns)) found <- c(found, s[i + ns$line1])
}
writeLines(found, commandArgs(TRUE)[2])
'''
# R source passed directly, without shell interpolation.
with tempfile.TemporaryDirectory(prefix='notebook-structure-') as folder:
    namespaces = Path(folder) / 'namespaces.txt'
    parsed = subprocess.run(['Rscript', '--vanilla', '-e', r_code, str(notebook), str(namespaces)],
                            capture_output=True, text=True)
    namespace_lines = namespaces.read_text().splitlines() if namespaces.exists() else []
libraries = [c for c in chunks if c[1].startswith('librerias-')]
report = {
    'reference_sha256': hashlib.sha256(reference.read_bytes()).hexdigest(),
    'notebook_sha256': hashlib.sha256(notebook.read_bytes()).hexdigest(),
    'chunks_total': len(chunks),
    'unique_labels': len(labels) == len(set(labels)),
    'maximum_chunk_lines': max(lengths.values()),
    'oversized_chunks': {k: v for k, v in lengths.items() if v > 40},
    'chunks_without_previous_prose': missing,
    'all_chunks_parse_independently': parsed.returncode == 0,
    'syntax_diagnostic': parsed.stderr.strip(),
    'namespace_code_lines': namespace_lines,
    'only_agreed_namespace_exception': namespace_lines == ['stats_filter <- stats::filter'],
    'all_existing_markdown_preserved': removed == allowed,
    'removed_markdown_paragraphs': removed,
    'library_chunks_expanded': all('echo=TRUE' in c[1] and 'class.source="fold-show"' in c[1] for c in libraries),
    'chunk_lengths': lengths,
    'chunks_without_internal_comments': [c[1] for c in chunks if not re.search(r'^\s*#|\s+#',c[2],re.M)],
}
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
assert report['unique_labels'] and not report['oversized_chunks'] and not missing
assert parsed.returncode == 0, parsed.stderr
assert report['only_agreed_namespace_exception'], namespace_lines
assert report['all_existing_markdown_preserved'], removed
assert report['library_chunks_expanded']
print('Estructura completa, sintaxis, prosa, librerías y excepción de namespace: verificadas.')

assert not report['chunks_without_internal_comments']
