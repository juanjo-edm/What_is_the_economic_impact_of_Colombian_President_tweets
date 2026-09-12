# Uso: Rscript --vanilla validar_documentacion.R ANTES_RMD ACTUAL_RMD REPORTE_CSV
args<-commandArgs(TRUE)
read_code<-function(path) {
 s<-readLines(path,warn=FALSE);result<-list()
 for(i in which(startsWith(s,'```{r'))) {
  j<-i+which(trimws(s[(i+1):length(s)])=='```')[1]
  result<-c(result,as.list(parse(text=s[(i+1):(j-1)],keep.source=FALSE)))
 }
 result
}
a<-read_code(args[1]);b<-read_code(args[2])
r<-data.frame(check=c('Sintaxis válida de todos los chunks','Expresiones R y orden idénticos, incluidos argumentos y literales'),passed=c(TRUE,identical(a,b)))
write.csv(r,args[3],row.names=FALSE);print(r,row.names=FALSE);stopifnot(all(r$passed))
