"""Compara productos del render de referencia con el render actual, sin modificarlos.
Uso: python3 comparar_productos.py REFERENCIA_PROYECTO ACTUAL_PROYECTO REPORTE_CSV
"""
import csv
import hashlib
import sys
from pathlib import Path

prior, current, report = map(Path, sys.argv[1:])
folders = ['output/tables/español', 'output/figures/español', 'paper/español/figures', 'data/processed']
def inventory(root):
    return {str(p.relative_to(root)): p for folder in folders for p in (root/folder).rglob('*') if p.is_file()}
a, b = inventory(prior), inventory(current)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path else ''
rows = []
for name in sorted(a.keys() | b.keys()):
    old, new = sha(a.get(name)), sha(b.get(name))
    rows.append(dict(path=name, reference_sha256=old, current_sha256=new,
                     status='identical' if old == new else 'added' if not old else 'missing' if not new else 'different'))
with report.open('w') as f:
    writer = csv.DictWriter(f, fieldnames=rows[0].keys()); writer.writeheader(); writer.writerows(rows)
from collections import Counter
print(dict(Counter(r['status'] for r in rows)))
for row in rows:
    if row['status'] != 'identical': print(row['status'], row['path'])
