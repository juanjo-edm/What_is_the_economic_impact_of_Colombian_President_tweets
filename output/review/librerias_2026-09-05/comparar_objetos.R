# Compara objetos analíticos y muestras con el entorno de la versión inmediatamente anterior.
# Uso: Rscript --vanilla comparar_objetos.R ANTES_RDS ACTUAL_RDS REPORTE_CSV
args <- commandArgs(TRUE)
stopifnot(length(args) == 3)
lines <- readLines('notebooks/español/Cuaderno_Paper_Español.Rmd', warn = FALSE)
for (i in which(startsWith(lines, '```{r librerias-'))) {
 j <- i + which(trimws(lines[(i+1):length(lines)]) == '```')[1]
 eval(parse(text=lines[(i+1):(j-1)]), envir=.GlobalEnv)
}
a <- readRDS(args[1]); b <- readRDS(args[2])
# Objetos tabulares y vectores numéricos, más estimaciones y muestras explícitas.
selected <- ls(a)[vapply(ls(a), function(n) {
 x <- a[[n]]
 is.data.frame(x) || is.matrix(x) || (is.numeric(x) && !is.object(x))
}, logical(1))]
selected <- unique(c(selected, 'fit_var', 'stm_fit', 'converted', 'spacy_sample',
                     'parsed_spacy', 'stats_filter'))
selected <- selected[vapply(selected, function(n) exists(n, envir=a, inherits=FALSE), logical(1))]
# Solo normalizar metadatos de ejecución identificados, conservando su comparación cruda.
normalize <- function(x) {
 if (inherits(x, 'igraph')) return(list(
   directed=igraph::is_directed(x),
   graph_attributes=igraph::graph_attr(x),
   vertices=igraph::as_data_frame(x, what='vertices'),
   edges=igraph::as_data_frame(x, what='edges')))
 if (inherits(x, c('dfm', 'fcm'))) {
   x@meta$system$directory <- '<raiz-del-proyecto>'
   return(x)
 }
 if (is.call(x)) {
   if (identical(x[[1]], as.name('::'))) return(as.name(as.character(x[[3]])))
   return(as.call(lapply(as.list(x), normalize)))
 }
 if (is.character(x)) {
   for (root in c(a$repo_dir, b$repo_dir)) {
     i <- which(!is.na(x) & startsWith(x, root))
     x[i] <- paste0('<raiz-del-proyecto>', substring(x[i], nchar(root)+1))
   }
   return(x)
 }
 if (is.list(x) && !is.object(x)) return(lapply(x, normalize))
 if (inherits(x, 'STM')) {
   x$time <- NULL
   x$settings$call <- normalize(x$settings$call)
   return(x)
 }
 if (is.data.frame(x) || inherits(x, 'varest')) {
   for (i in seq_along(x)) x[i] <- list(normalize(x[[i]]))
 }
 x
}
rows <- lapply(selected, function(n) {
 if (!exists(n, envir=b, inherits=FALSE)) return(data.frame(object=n,raw_passed=FALSE,passed=FALSE,detail='Ausente'))
 compared <- tryCatch(all.equal(a[[n]], b[[n]], tolerance=1e-10, check.attributes=TRUE),
                      error=function(e) conditionMessage(e))
 normalized <- if (isTRUE(compared)) TRUE else tryCatch(
   all.equal(normalize(a[[n]]), normalize(b[[n]]), tolerance=1e-10, check.attributes=TRUE),
   error=function(e) conditionMessage(e))
 data.frame(object=n, raw_passed=isTRUE(compared), passed=isTRUE(normalized),
   detail=if(isTRUE(compared)) '' else paste(compared,collapse='; '),
   normalized_detail=if(isTRUE(normalized)) '' else paste(normalized,collapse='; '))
})
result <- do.call(rbind,rows)
write.csv(result, args[3], row.names=FALSE)
print(table(result$passed))
print(result[!result$passed,], row.names=FALSE)

stopifnot(all(result$passed))
