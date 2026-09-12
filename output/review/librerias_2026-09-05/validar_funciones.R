# Verificación de enlaces; no ejecuta cálculos del estudio.
# Uso: Rscript --vanilla validar_funciones.R REFERENCIA_RMD ACTUAL_RMD DIRECTORIO_REPORTE
args <- commandArgs(TRUE)
stopifnot(length(args) == 3)
read_blocks <- function(path) {
  s <- readLines(path, warn = FALSE); out <- list()
  for (i in grep('^```\\{r', s)) {
    j <- i + which(trimws(s[(i + 1):length(s)]) == '```')[1]
    label <- sub('^```\\{r ([^,}]+).*', '\\1', s[i])
    out[[label]] <- s[(i + 1):(j - 1)]
  }
  out
}
old <- read_blocks(args[1]); current <- read_blocks(args[2])
eval(parse(text = old[['setup-librerias']]), envir = .GlobalEnv)
qualified <- list(); bare <- character()
for (code in old) {
  p <- getParseData(parse(text = code, keep.source = TRUE))
  ns <- p[p$token == 'NS_GET', ]
  for (i in seq_len(nrow(ns))) {
    siblings <- p[p$parent == ns$parent[i] & p$terminal, ]
    pkg <- siblings$text[siblings$token == 'SYMBOL_PACKAGE']
    fun <- siblings$text[siblings$token %in% c('SYMBOL_FUNCTION_CALL', 'SYMBOL', 'STR_CONST')]
    stopifnot(length(pkg) == 1, length(fun) == 1)
    qualified[[length(qualified) + 1]] <- data.frame(pkg = pkg, fun = fun)
  }
  bare <- c(bare, p$text[p$token == 'SYMBOL_FUNCTION_CALL' & !p$parent %in% ns$parent])
}
lookup <- function(n) tryCatch(get(n, envir = .GlobalEnv), error = function(e) NULL)
bare <- unique(bare)
prior_bindings <- setNames(lapply(bare, lookup), bare)
for (code in current[startsWith(names(current), 'librerias-')]) {
  eval(parse(text = code), envir = .GlobalEnv)
}
qualified <- unique(do.call(rbind, qualified))
qualified <- qualified[!(qualified$pkg == 'stats' & qualified$fun == 'filter'), ]
qualified$passed <- vapply(seq_len(nrow(qualified)), function(i)
  identical(lookup(qualified$fun[i]), getExportedValue(qualified$pkg[i], qualified$fun[i])), logical(1))
known <- names(prior_bindings)[vapply(prior_bindings, is.function, logical(1))]
unchanged <- data.frame(fun = known, passed = vapply(known, function(n)
  identical(lookup(n), prior_bindings[[n]]), logical(1)))
m <- matrix(c(0, 2, 3, 0, 5, 6), nrow = 2)
sparse <- Matrix::Matrix(m, sparse = TRUE)
matrix_checks <- data.frame(check = c('colSums dispersa', 'rowSums dispersa', 't dispersa',
                                     'colSums densa', 'rowSums densa', 't densa'),
  passed = c(identical(colSums(sparse), Matrix::colSums(sparse)),
    identical(rowSums(sparse), Matrix::rowSums(sparse)),
    identical(t(sparse), Matrix::t(sparse)), identical(colSums(m), base::colSums(m)),
    identical(rowSums(m), base::rowSums(m)), identical(t(m), base::t(m))))
write.csv(qualified, file.path(args[3], 'funciones_calificadas.csv'), row.names = FALSE)
write.csv(unchanged, file.path(args[3], 'funciones_sin_prefijo.csv'), row.names = FALSE)
write.csv(matrix_checks, file.path(args[3], 'despacho_matrices.csv'), row.names = FALSE)
packages <- sub('^library\\(([^)]+)\\).*', '\\1',
  grep('^library\\(', unlist(current[startsWith(names(current), 'librerias-')]), value = TRUE))
write.csv(data.frame(package = packages, version = vapply(packages, function(p)
  as.character(packageVersion(p)), character(1))), file.path(args[3], 'versiones_paquetes.csv'), row.names = FALSE)
stopifnot(all(qualified$passed), all(unchanged$passed), all(matrix_checks$passed))
cat(nrow(qualified), 'enlaces antes calificados,', nrow(unchanged),
    'funciones previamente simples y', nrow(matrix_checks), 'despachos matriciales: correctos.\n')
