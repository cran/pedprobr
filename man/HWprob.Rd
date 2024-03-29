% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{HWprob}
\alias{HWprob}
\title{Hardy-Weinberg probabilities}
\usage{
HWprob(allele1, allele2, afreq, f = 0)
}
\arguments{
\item{allele1, allele2}{Vectors of equal length, containing alleles in the
form of indices of \code{afreq}}

\item{afreq}{A numeric vector with allele frequencies}

\item{f}{A single number in \verb{[0, 1]}; the inbreeding coefficient}
}
\value{
A numeric vector of the same length as \code{allele1} and  \code{allele2}
}
\description{
Hardy-Weinberg probabilities
}
\examples{
p = 0.1; q = 1-p
hw = HWprob(c(1,1,2), c(1,2,2), c(p, q))
stopifnot(all.equal(hw, c(p^2, 2*p*q, q^2)))

}
