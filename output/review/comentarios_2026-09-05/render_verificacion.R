# Render limpio; captura las condiciones antes de que knitr aplique las opciones de presentación.
setwd('/private/tmp/petro-comments-review/run')
Sys.setenv(RSTUDIO_PANDOC='/Applications/quarto/bin/tools/aarch64')
review_env <- new.env(parent=globalenv())
review_log <- '/private/tmp/petro-comments-review/chunk_conditions.csv'
write.csv(data.frame(chunk=character(),type=character(),text=character()),review_log,row.names=FALSE)
record_condition <- function(label,type,text) {
 write.table(data.frame(chunk=label,type=type,text=paste(text,collapse='\n')),review_log,
   sep=',',row.names=FALSE,col.names=FALSE,append=TRUE,qmethod='double')
}
knitr::opts_chunk$set(auditar_chunk=TRUE)
knitr::opts_hooks$set(auditar_chunk=function(options) {
 label <- options$label
 record_condition(label,'start',format(Sys.time()))
 options$calling.handlers <- c(options$calling.handlers, list(
  warning=function(e) record_condition(label,'warning',conditionMessage(e)),
  message=function(e) record_condition(label,'message',conditionMessage(e)),
  error=function(e) record_condition(label,'error',conditionMessage(e))))
 options$error <- FALSE
 options
})
options(warn=1)
rmarkdown::render('notebooks/español/Cuaderno_Paper_Español.Rmd',
 output_format='html_notebook',envir=review_env,clean=FALSE,quiet=FALSE)
saveRDS(review_env,'/private/tmp/petro-comments-review/delivery_environment.rds')
writeLines(capture.output(sessionInfo()),'/private/tmp/petro-comments-review/sessionInfo.txt')
cat('\nFULL_RENDER_COMPLETED\n')
