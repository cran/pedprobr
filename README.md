<!-- README.md is generated from README.Rmd. Please edit that file -->

pedprobr <img src="man/figures/logo.png" align="right" height=140 />
====================================================================

Introduction
------------

The main content of pedprobr is an implementation of the Elston-Stewart
algorithm for pedigree likelihoods. It is a reboot of the implementation
in [paramlink](https://CRAN.R-project.org/package=paramlink) which is no
longer actively developed.

pedprobr is part of the ped suite, a collection of packages for pedigree
analysis in R, based on [pedtools](https://github.com/magnusdv/pedtools)
for basic handling of pedigrees and marker data.

The workhorse of the pedprobr package is the `likelihood()` function,
which works in a variety of situations:

-   complex inbred pedigrees
-   pedigrees with inbred founders
-   autosomal and X-linked markers
-   a single marker or two linked markers
-   markers with mutation models (supported by
    [pedmut](https://github.com/magnusdv/pedmut))

Installation
------------

To get the latest version of pedprobr, install from GitHub as follows:

``` r
 # First install devtools if needed
if(!require(devtools)) install.packages("devtools")

# Install pedprobr from github
devtools::install_github("magnusdv/pedprobr")
```

Getting started
---------------

``` r
library(pedprobr)
#> Loading required package: pedtools
```

To set up a simple example, we first use `pedtools` utilities to create
a pedigree and attach to it a marker object. The marker has alleles `1`
and `2`, with frequencies 0.2 and 0.8 respectively, and both brothers
are heterozygous.

``` r
x = nuclearPed(nch = 2)
m = marker(x, '3' = 1:2, '4' = 1:2, alleles = 1:2, afreq = c(0.2, 0.8))

x = addMarkers(x, m) # attach the marker
x
#>  id fid mid sex <1>
#>   1   *   *   1 -/-
#>   2   *   *   2 -/-
#>   3   1   2   1 1/2
#>   4   1   2   1 1/2
```

``` r
plot(x, m)
```

![](man/figures/README-unnamed-chunk-6-1.png)

The pedigree likelihood, i,.e., the probability of observing these
genotypes given the pedigree, may now be obtained as follows:

``` r
likelihood(x, marker1 = 1)
#> [1] 0.1856
```

Genotype probability distributions
----------------------------------

Besides `likelihood()` the most important functions in pedprobr are:

-   `oneMarkerDistribution()` : for a subset of family members, compute
    their joint genotype distribution at a single marker
-   `twoMarkerDistribution()` : for a single family member, compute the
    joint genotype distribution at two linked markers

In both cases, the distributions are computed conditionally on any known
genotypes at the markers in question.

For an illustration of `oneMarkerDistribution()` we may continue our
example from above, and answer the following question: *Conditional on
the two heterozygous children, what is the joint distribution for the
parents?*

The answer is easily found as follows:

``` r
oneMarkerDistribution(x, ids = 1:2, partialmarker = 1, verbose = F)
#>            1/1       2/2        1/2
#> 1/1 0.00000000 0.1379310 0.01724138
#> 2/2 0.13793103 0.0000000 0.27586207
#> 1/2 0.01724138 0.2758621 0.13793103
```
