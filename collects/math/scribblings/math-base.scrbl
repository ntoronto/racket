#lang scribble/manual

@(require scribble/eval
          racket/sandbox
          (for-label racket/base
                     math/base
                     math/flonum
                     math/bigfloat
                     (only-in typed/racket/base Real Boolean Integer Natural Number Listof
                              Positive-Flonum))
          "utils.rkt")

@(define untyped-eval (make-untyped-math-eval))

@title[#:tag "base"]{Constants and Elementary Functions}
@(author-neil)

@defmodule[math/base]

For convenience, @racketmodname[math/base] re-exports @racketmodname[racket/math]
as well as providing the values document below.

@section{Constants}

If you need more accurate approximations than the following flonums, see, for example,
@racket[phi.bf] and @racket[bigfloat->rational].

@defthing[phi.0 Positive-Flonum]{
An approximation of φ, the @hyperlink["http://en.wikipedia.org/wiki/Golden_ratio"]{golden ratio}.
@interaction[#:eval untyped-eval phi.0]
}

@defthing[euler.0 Positive-Flonum]{
An approximation of @italic{e}, or @hyperlink["http://en.wikipedia.org/wiki/E_(mathematical_constant)"]{Euler's number}.
@interaction[#:eval untyped-eval euler.0 (exp 1)]
}

@defthing[gamma.0 Positive-Flonum]{
An approximation of γ, the @hyperlink["http://en.wikipedia.org/wiki/Euler-Mascheroni_constant"]{Euler-Mascheroni constant}.
@interaction[#:eval untyped-eval gamma.0]
}

@defthing[catalan.0 Positive-Flonum]{
An approximation of @italic{G}, or @hyperlink["http://en.wikipedia.org/wiki/Catalan's_constant"]{Catalan's constant}.
@interaction[#:eval untyped-eval catalan.0]
}

@section{Functions}

@defproc[(power-of-two? [x Real]) Boolean]{
Returns @racket[#t] when @racket[x] is an integer power of 2.
@examples[#:eval untyped-eval
                 (power-of-two? 1.0)
                 (power-of-two? 1/2)
                 (power-of-two? (flnext 2.0))]
}

@deftogether[(@defproc[(asinh [z Number]) Number]
              @defproc[(acosh [z Number]) Number]
              @defproc[(atanh [z Number]) Number])]{
The inverses of @racket[sinh], @racket[cosh], and @racket[tanh], which are
defined in @racketmodname[racket/math] (and re-exported by @racketmodname[math/base]).
}

@defproc[(sum [xs (Listof Real)]) Real]{
Like @racket[(apply + xs)], but incurs rounding error only once when adding inexact numbers.
(In fact, the inexact numbers in @racket[xs] are summed separately using @racket[flsum].)
}

@section{Random Number Generation}

@defproc[(random-natural [k Integer]) Natural]{
Returns a random natural number less than @racket[k], which must be positive.
Use @racket[(random-natural k)] instead of @racket[(random k)] when @racket[k]
could be larger than @racket[4294967087].
}

@defproc[(random-integer [a Integer] [b Integer]) Integer]{
Returns a random integer @racket[n] such that @racket[(a . <= . n)] and @racket[(n . < . b)].
}

@defproc[(random-bits [num Integer]) Natural]{
Returns a random natural smaller than @racket[(expt 2 num)]; @racket[num] must be positive.
For powers of two, this is faster than using @racket[random-natural], which
is implemented in terms of @racket[random-bits], using biased rejection sampling.

As an example of use, the significands of the numbers returned by @racket[bfrandom]
are chosen by @racket[(random-bits (bf-precision))].
}


@section{Measuring Error}

@defproc[(absolute-error [x Real] [r Real]) Real]{
Generally computes @racket[(abs (- x r))] using exact rationals, but handles non-rational
values such as @racket[+inf.0] specially.

@examples[#:eval untyped-eval
                 (absolute-error 1/2 1/2)
                 (absolute-error #i1/7 1/7)
                 (absolute-error +inf.0 +inf.0)
                 (absolute-error +inf.0 +nan.0)
                 (absolute-error 1e-20 0.0)
                 (absolute-error (- 1.0 (fl 4999999/5000000)) 1/50000)]
}

@defproc[(relative-error [x Real] [r Real]) Real]{
Measures how close an approximation @racket[x] is to a correct value @racket[r],
relative to the magnitude of @racket[r].

This function generally computes @racket[(abs (/ (- x r) r))] using exact rationals,
but handles non-rational values such as @racket[+inf.0] specially and avoids dividing
by zero.

@margin-note*{This is not strictly true when the function's output is subnormal, because
              subnormal flonums are considerably less dense than normal flonums. The
              correct way to measure a subnormal flonum's error is to use @racket[flulp-error].}
Roughly, a flonum function with maximum relative error @racket[(* 0.5 epsilon.0)], or about
@racket[1e-16], exhibits only rounding error; it is @italic{correct}. A flonum
function with maximum relative error no greater than a few epsilons is @italic{accurate}.

@examples[#:eval untyped-eval
                 (relative-error 1/2 1/2)
                 (relative-error #i1/7 1/7)
                 (relative-error +inf.0 +inf.0)
                 (relative-error +inf.0 +nan.0)
                 (relative-error 1e-20 0.0)
                 (relative-error (- 1.0 (fl 4999999/5000000)) 1/50000)]
}

@(close-eval untyped-eval)
