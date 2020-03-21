#' Genotype distribution for a single marker
#'
#' Computes the genotype probability distribution of one or several pedigree
#' members, possibly conditional on known genotypes for the marker.
#'
#' @param x A `ped` object.
#' @param ids A numeric with ID labels of one or more pedigree members.
#' @param partialmarker Either a `marker` object or the name (or index) of a
#'   marker attached to `x`.
#' @param loop_breakers (Only relevant if the pedigree has loops). A vector with
#'   ID labels of individuals to be used as loop breakers. If NULL (default)
#'   loop breakers are selected automatically. See [breakLoops()].
#' @param eliminate A non-negative integer, indicating the number of iterations
#'   in the internal genotype-compatibility algorithm. Positive values can save
#'   time if `partialmarker` has many alleles.
#' @param grid.subset (Optional; not relevant for most users.) A numeric matrix
#'   describing a subset of all marker genotype combinations for the `ids`
#'   individuals. The matrix should have one column for each of the `ids`
#'   individuals, and one row for each combination: The genotypes are described
#'   in terms of the matrix `M = allGenotypes(n)`, where `n` is the number of
#'   alleles for the marker. If the entry in column `j` is the integer `k`, this
#'   means that the genotype of individual `ids[j]` is row `k` of `M`.
#' @param verbose A logical.
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
#' genotype(m, id = 1) = c(1, NA)
#' oneMarkerDistribution(s, ids = 1, partialmarker = m)
#'
#' # Genotype distribution for a child of heterozygous parents
#' trio = nuclearPed(father = "fa", mother = "mo", child = "ch")
#' m1 = marker(trio, fa = 1:2, mo = 1:2)
#' oneMarkerDistribution(trio, ids = "ch", partialmarker = m1)
#'
#' # Joint distribution of the parents, given that the child is heterozygous
#' m2 = marker(trio, ch = 1:2, alleles = 1:2, afreq = c(0.5, 0.5))
#' oneMarkerDistribution(trio, ids = c("fa", "mo"), partialmarker = m2)
#'
#' # A different example: The genotype distribution of an individual (id = 5)
#' # whose half cousin (id = 9) is homozygous for a rare allele.
#' y = halfCousinPed(degree = 1)
#' snp = marker(y, `9` = "a", alleles = c("a", "b"), afreq = c(0.01, 0.99))
#' plot(y, snp)
#' oneMarkerDistribution(y, ids = 5, partialmarker = snp)
#'
#' @export
oneMarkerDistribution = function(x, ids, partialmarker, loop_breakers = NULL,
                                 eliminate = 0, grid.subset = NULL, verbose = TRUE) {
  if(!is.ped(x))
    stop2("Input is not a `ped` object")
  if(!isCount(eliminate, minimum = 0))
    stop2("`eliminate` must be a nonnegative integer")

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
    cat(sprintf("Partial marker (%s):\n", ifelse(onX, "X-linked", "autosomal")))
    print(m)
    cat("==============================\n")
    msg = "Computing the %sgenotype probability distribution for individual%s: %s\n"
    if(length(ids) == 1)
      cat(sprintf(msg, "", "", ids))
    else
      cat(sprintf(msg, "joint ", "s", toString(ids)))
  }

  starttime = Sys.time()

  # Compute grid before loop breaking (works better with eliminate2)
  if (is.null(grid.subset))
    grid.subset = genoCombinations(x, m, ids, make.grid = TRUE)
  else
    grid.subset = as.matrix(grid.subset)

  if (x$UNBROKEN_LOOPS) {
    x = breakLoops(setMarkers(x, m), loop_breakers = loop_breakers, verbose = verbose)
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

  ### Likelihood setup

  # Ensure peeling order is set (otherwise it is done multiple times)
  if(is.null(attr(x, "PEELING_ORDER")))
    attr(x, "PEELING_ORDER") = peelingOrder(x)

  # Precompute informative nucs
  mDummy = m
  mDummy[int.ids, ] = 1
  inform = informativeSubnucs(x, mDummy)
  setup = list(informativeNucs = inform$subnucs,
               treatAsFounder = inform$newfounders)

  # Compute marginal
  marginal = likelihood(x, marker1 = m, eliminate = eliminate)
  if (marginal == 0)
      stop2("Partial marker is impossible")

  probs[probs.subset] = apply(grid.subset, 1, function(allg_rows) {
      m[int.ids, ] = allgenos[allg_rows, ]
      likelihood(x, marker1 = m, eliminate = eliminate, setup = setup)
  })

  res = probs/marginal
  if (verbose) {
    cat("\nAnalysis finished in", round(Sys.time() - starttime, 2), " seconds\n")
  }

  res
}