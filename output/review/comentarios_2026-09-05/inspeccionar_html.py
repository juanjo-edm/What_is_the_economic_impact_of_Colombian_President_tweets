"""Inspección estructural del HTML y comparación de contenido no documental."""
from pathlib import Path
from bs4 import BeautifulSoup
import sys,json,hashlib
from difflib import SequenceMatcher
before,after,out=map(Path,sys.argv[1:])
a,b=[BeautifulSoup(p.read_text(),'html.parser') for p in (before,after)]
def texts(s,selector):return [x.get_text() for x in s.select(selector)]
def images(s):return [hashlib.sha256(x.get('src','').encode()).hexdigest() for x in s.select('img')]
libs=b.select('pre.fold-show')
result={
 'inspection':'Estructura HTML y contenido; no medición visual del navegador',
 'library_blocks_unfolded':len(libs),
 'library_calls':sum(x.get_text().count('library(') for x in libs),
 'conflict_preferences':sum(x.get_text().count('conflict_prefer(') for x in libs),
 'images':len(b.select('img')),
 'images_identical':images(a)==images(b),
 'equations':len(b.select('.math')),
 'equations_identical':texts(a,'.math')==texts(b,'.math'),
 'tables':len(b.select('table')),
 'tables_identical':texts(a,'table')==texts(b,'table'),
 'headings_identical':texts(a,'h1,h2,h3,h4,h5,h6')==texts(b,'h1,h2,h3,h4,h5,h6'),
 'paragraphs_identical':texts(a,'p')==texts(b,'p'),
 'output_blocks_identical':texts(a,'pre:not(.sourceCode)')==texts(b,'pre:not(.sourceCode)'),
 'comment_spans':len(b.select('span.co')),
}
pa,pb=texts(a,'p'),texts(b,'p')
differences=[{'before':pa[i:j],'after':pb[k:l]} for tag,i,j,k,l in SequenceMatcher(None,pa,pb).get_opcodes() if tag!='equal']
result['paragraph_differences']=differences
result['paragraph_difference_preexisting']=len(differences)==1 and 'sutilizamos funciones establecidas' in differences[0]['after'][0] and 'sutilizamos funciones establecidas' in (out.parent/'referencia_antes.Rmd').read_text()
out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False,indent=2))
assert all(result[k] for k in result if k.endswith('_identical') and k!='paragraphs_identical')
assert result['paragraphs_identical'] or result['paragraph_difference_preexisting']
assert result['library_blocks_unfolded']==4 and result['library_calls']==39 and result['conflict_preferences']==14
