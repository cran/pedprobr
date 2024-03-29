#' Set a mutation model
#'
#' ***NB: This function has been replaced by [pedtools::setMutmod()].***
#' This function attaches mutation models to a pedigree with marker data,
#' calling [pedmut::mutationModel()] for creating the models.
#'
#' Currently, the following models are handled:
#'
#' * `equal` :  All mutations equally likely; probability \eqn{1-rate} of no
#' mutation
#'
#' * `proportional` : Mutation probabilities are proportional to the target
#' allele frequencies
#'
#' * `onestep`: A mutation model for microsatellite markers, allowing mutations
#' only to the nearest neighbours in the allelic ladder. For example, '10' may
#' mutate to either '9' or '11', unless '10' is the lowest allele, in which case
#' '11' is the only option. This model is not applicable to loci with
#' non-integral microvariants.
#'
#' * `stepwise`: A common model in forensic genetics, allowing different
#' mutation rates between integer alleles (like '16') and non-integer
#' "microvariants" like '9.3'). Mutations also depend on the size of the
#' mutation if the parameter 'range' differs from 1.
#'
#' * `custom` : Allows any mutation matrix to be provided by the user, in the
#' `matrix` parameter
#'
#' * `random` : This produces a matrix of random numbers, where each row is
#' normalised so that it sums to 1
#'
#' * `trivial` : The identity matrix; i.e. no mutations are possible.
#'
#' @param x A `ped` object or a list of such.
#' @param markers A vector of names or indices referring to markers attached to
#'   `x`. (Default: All markers.)
#' @param model A model name implemented by [pedmut::mutationModel()] (see
#'   Details), or NULL.
#' @param ... Arguments forwarded to [pedmut::mutationModel()], e.g., `rate`.
#'
#' @return An object similar to `x`.
#'
#' @examples
#' ### Example requires the pedmut package ###
#' if (requireNamespace("pedmut", quietly = TRUE)){
#'
#' # A pedigree with data from a single marker
#' x = nuclearPed(1) |>
#'   addMarker(geno = c("a/a", NA, "b/b")) # mutation!
#'
#' # Set `equal` model
#' y = setMutationModel(x, marker = 1, model = "equal", rate = 0.01)
#'
#' # Inspect model
#' mutmod(y, 1)
#'
#' # Likelihood
#' likelihood(y, 1)
#'
#' # Remove mutation model
#' z = setMutationModel(y, model = NULL)
#' stopifnot(identical(z, x))
#' }
#'
#' @importFrom pedmut mutationModel
#' @export
setMutationModel = function(x, model, markers = NULL, ...) {
  if (!requireNamespace("pedmut", quietly = TRUE))
    stop2("Package `pedmut` must be installed in order to include mutation models")

  message("Note: `setMutationModel()` has been replaced with `pedtools::setMutmod()`. Please use this in new code.")

  opts = list(...)

  markers = markers %||% seq_len(nMarkers(x))

  mIdx = whichMarkers(x, markers)
  for(i in mIdx) {
    if(is.null(model))
      modi = NULL
    else {
      fr = afreq(x, i)
      args = c(list(model = model, alleles = names(fr), afreq = fr), opts)
      modi = do.call(pedmut::mutationModel, args)
    }
    mutmod(x, i) = modi
  }

  x
}
