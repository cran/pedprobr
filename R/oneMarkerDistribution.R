#' Genotype distribution for a single marker
#'
#' Computes the genotype probability distribution of one or several pedigree
#' members, possibly conditional on known genotypes for the marker.
#'
#' @param x A `ped` object or a list of such.
#' @param ids A numeric with ID labels of one or more pedigree members.
#' @param partialmarker Either a `marker` object or the name (or index) of a
#'   marker attached to `x`. If `x` has multiple components, only the latter is
#'   allowed.
#' @param loopBreakers (Only relevant if the pedigree has loops). A vector with
#'   ID labels of individuals to be used as loop breakers. If NULL (default)
#'   loop breakers are selected automatically. See [breakLoops()].
#' @param eliminate Deprecated, not used.
#' @param grid.subset (Optional; not relevant for most users.) A numeric matrix
#'   describing a subset of all marker genotype combinations for the `ids`
#'   individuals. The matrix should have one column for each of the `ids`
#'   individuals, and one row for each combination: The genotypes are described
#'   in terms of the matrix `M = allGenotypes(n)`, where `n` is the number of
#'   alleles for the marker. If the entry in column `j` is the integer `k`, this
#'   means that the genotype of individual `ids[j]` is row `k` of `M`.
#' @param verbose A logical.
#'
#' @return A named `k`-dimensional array, where `k = length(ids)`, with the
#'   joint genotype distribution for the `ids` individuals. The probabilities
#'   are conditional on the known genotypes and the allele frequencies of
#'   `partialmarker`.
#' @author Magnus Dehli Vigeland
#' @seealso [twoMarkerDistribution()]
#'
#' @examples
#'
#' # Trivial example giving Hardy-Weinberg probabilities
#' s = singleton(id = 1)
#' m = marker(s, alleles = 1:2) # equifrequent SNP
#' oneMarkerDistribution(s, ids = 1, partialmarker = m)
#'
#' # Conditioning on a partial genotype
#' genotype(m, id = 1) = "1/-"
#' oneMarkerDistribution(s, ids = 1, partialmarker = m)
#'
#' # Genotype distribution for a child of heterozygous parents
#' trio = nuclearPed(father = "fa", mother = "mo", child = "ch")
#' m1 = marker(trio, fa = "1/2", mo = "1/2")
#' oneMarkerDistribution(trio, ids = "ch", partialmarker = m1)
#'
#' # Joint distribution of the parents, given that the child is heterozygous
#' m2 = marker(trio, ch = "1/2", afreq = c("1" = 0.5, "2" = 0.5))
#' oneMarkerDistribution(trio, ids = c("fa", "mo"), partialmarker = m2)
#'
#' # A different example: The genotype distribution of an individual (id = 8)
#' # whose half cousin (id = 9) is homozygous for a rare allele.
#' y = halfCousinPed(degree = 1) |>
#'   addMarker("9" = "a/a", afreq = c(a = 0.01, b = 0.99))
#'
#' oneMarkerDistribution(y, ids = 8, partialmarker = 1)
#'
#' @export
oneMarkerDistribution = function(x, ids, partialmarker, loopBreakers = NULL,
                                 eliminate = 0, grid.subset = NULL, verbose = TRUE) {

  if(is.pedList(x)) {
    if(is.marker(partialmarker))
      stop2("When `x` has multiple components, `partialmarker` cannot be an unattached marker object")

    pednr = getComponent(x, ids, checkUnique = TRUE)
    if(all(pednr == pednr[1]))
      x = x[[pednr[1]]]
    else
      stop2("Individuals from different pedigree components are not implemented yet")
  }

  if(!is.ped(x))
    stop2("Input is not a pedigree")

  m = partialmarker

  if (!is.marker(m)) {
    if(length(m) != 1)
      stop2("`partialmarker` must have length 1")
    m = getMarkers(x, markers = m)[[1]]
  }

  if (!is.null(x$LOOP_BREAKERS))
    stop2("`ped` objects with pre-broken loops are not allowed as input to `oneMarkerDistribution()`")

  alleles = alleles(m)
  onX = isXmarker(m)

  if (verbose) {
    cat("Known genotypes:\n")
    print(m)
    cat("\nChromosome type    :", ifelse(onX, "X-linked", "autosomal"))
    cat("\nTarget individuals :", toString(ids), "\n")
  }

  starttime = Sys.time()

  # Compute grid before loop breaking (works better with eliminate2)
  if (is.null(grid.subset))
    grid.subset = genoCombinations(x, m, ids, make.grid = TRUE)
  else
    grid.subset = as.matrix(grid.subset)

  if (x$UNBROKEN_LOOPS) {
    x = breakLoops(setMarkers(x, m), loopBreakers = loopBreakers, verbose = verbose)
    m = x$MARKERS[[1]]
  }

  int.ids = internalID(x, ids)
  allgenos = allGenotypes(nAlleles(m))

  # Character with genotype labels
  gt.strings = paste(alleles[allgenos[, 1]], alleles[allgenos[, 2]], sep = "/")
  if(onX) {
    sx = getSex(x, ids)
    geno.names =  list(alleles, gt.strings)[sx]
  }
  else {
    geno.names = rep(list(gt.strings), length(ids))
  }

  # Create output array. Will hold likelihood of each genotype combo
  probs = array(0, dim = lengths(geno.names, use.names = FALSE), dimnames = geno.names)

  # Subset of `probs` that is affected by grid.subset
  probs.subset = grid.subset

  # Needs adjustment for X (in male colums)
  if(onX) {
    homoz = which(allgenos[,1] == allgenos[,2])
    probs.subset[, sx == 1] = match(probs.subset[, sx == 1], homoz)
  }

  nr = nrow(grid.subset)

  # Compute marginal
  marginal = likelihood(x, markers = m)
  if (marginal == 0)
      stop2("Partial marker is impossible")

  if(verbose) {
    cat("Marginal likelihood:", marginal, "\n")
    cat("Calculations needed:", nr, "\n")
  }

  # Create list of all markers
  mlist = lapply(seq_len(nr), function(i) {
    r = grid.subset[i,]
    m[int.ids, ] = allgenos[r, ]; m})

  # Calculate likelihoods and insert in result array
  probs[probs.subset] = likelihood(x, mlist)

  # Timing
  totalTime = format(Sys.time() - starttime, digits = 3)
  if(verbose)
    cat("\nAnalysis finished in", totalTime, "\n")

  probs/marginal
}
