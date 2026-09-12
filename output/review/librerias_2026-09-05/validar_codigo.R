# Compara expresiones completas: solo permite reorganizar dependencias y quitar prefijos.
# Uso: Rscript --vanilla validar_codigo.R REFERENCIA_RMD ACTUAL_RMD REPORTE_CSV
args <- commandArgs(TRUE)
stopifnot(length(args) == 3)
read_chunks <- function(path) {
  s <- readLines(path, warn = FALSE)
  result <- list()
  for (i in grep('^```\\{r', s)) {
    j <- i + which(trimws(s[(i + 1):length(s)]) == '```')[1]
    label <- sub('^```\\{r ([^,}]+).*', '\\1', s[i])
    result[[label]] <- parse(text = s[(i + 1):(j - 1)], keep.source = FALSE)
  }
  result
}
normalize <- function(x) {
  if (is.call(x) && identical(x[[1]], as.name('::'))) {
    if (identical(x, quote(stats::filter))) return(x)
    return(as.name(as.character(x[[3]])))
  }
  if (is.call(x)) return(as.call(lapply(as.list(x), normalize)))
  if (is.pairlist(x)) return(as.pairlist(lapply(x, normalize)))
  x
}
collect <- function(chunks) {
  result <- list()
  for (label in names(chunks)) {
    if (startsWith(label, 'librerias-')) next
    for (x in chunks[[label]]) {
      if (label == 'setup-librerias' &&
          as.character(x[[1]]) %in% c('library', 'conflict_prefer', 'if')) next
      result[[length(result) + 1]] <- normalize(x)
    }
  }
  result
}
a <- read_chunks(args[1]); b <- read_chunks(args[2])
old <- collect(a); current <- collect(b)
checks <- data.frame(
  check = c('Sintaxis independiente en todos los chunks',
            'Número de expresiones analíticas conservado',
            'Expresiones y orden idénticos salvo prefijos y dependencias',
            'Librerías: únicamente library y conflict_prefer'),
  passed = c(TRUE, length(old) == length(current), identical(old, current),
    all(vapply(b[startsWith(names(b), 'librerias-')], function(xs)
      all(vapply(xs, function(x) is.call(x) &&
        as.character(x[[1]]) %in% c('library', 'conflict_prefer'), logical(1))), logical(1))))
)
write.csv(checks, args[3], row.names = FALSE)
if (!identical(old, current)) {
  for (i in seq_len(min(length(old), length(current)))) {
    if (!identical(old[[i]], current[[i]])) {
      cat('Primera diferencia, expresión', i, '\n'); print(old[[i]]); print(current[[i]])
      break
    }
  }
}
print(checks, row.names = FALSE)
stopifnot(all(checks$passed))
