# Uso: Rscript --vanilla validar_comentarios.R ANTES_RMD ACTUAL_RMD REPORTE_CSV
args<-commandArgs(TRUE)
inventory<-function(path) {
 s<-readLines(path,warn=FALSE);r<-list()
 for(i in which(startsWith(s,'```{r'))) {
  j<-i+which(trimws(s[(i+1):length(s)])=='```')[1]
  label<-sub('^```\\{r ([^,}]+).*','\\1',s[i])
  p<-getParseData(parse(text=s[(i+1):(j-1)],keep.source=TRUE))
  r[[label]]<-p$text[p$token=='COMMENT']
 }
 r
}
a<-inventory(args[1]);b<-inventory(args[2])
rows<-lapply(names(a),function(n) {
 old<-table(a[[n]]);new<-table(b[[n]])
 preserved<-all(names(old) %in% names(new)) && all(new[names(old)]>=old)
 data.frame(chunk=n,comments_before=length(a[[n]]),comments_after=length(b[[n]]),
   comments_preserved=preserved,has_comments=length(b[[n]])>0)
})
r<-do.call(rbind,rows);write.csv(r,args[3],row.names=FALSE)
stopifnot(all(r$comments_preserved),all(r$has_comments))
cat(nrow(r),'chunks documentados; comentarios previos conservados.\n')
