#lang typed/racket/base

(require "bigfloat-struct.rkt")

(provide bflog* bflog/ bflog+ bflog-)

(: bflog* (Bigfloat Bigfloat -> Bigfloat))
(define (bflog* log-x log-y) (bf+ log-x log-y))

(: bflog/ (Bigfloat Bigfloat -> Bigfloat))
(define (bflog/ log-x log-y) (bf- log-x log-y))

(: bflog+ (Bigfloat Bigfloat -> Bigfloat))
(define (bflog+ log-x log-y)
  (let-values ([(log-x log-y)  (if (log-x . bf> . log-y)
                                   (values log-x log-y)
                                   (values log-y log-x))])
    (bf+ log-x (bflog1p (bfexp (bf- log-y log-x))))))

(: bflog- (Bigfloat Bigfloat -> Bigfloat))
(define (bflog- log-x log-y)
  (cond [(log-y . bf> . log-x)  +nan.bf]
        [else  (bf+ log-x (bflog1p (bf- (bfexp (bf- log-y log-x)))))]))