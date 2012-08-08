#lang typed/racket

(require/typed typed/racket
               [integer-sqrt/remainder (Natural -> (Values Natural Natural))])
(require "list-operations.rkt")

(provide bezout
         bezout-binary
         coprime?
         divides?
         gcd
         pairwise-coprime?
         inverse
         with-modulus
         solve-chinese
         
         ; primes
         nth-prime
         next-prime 
         next-primes
         prev-prime
         prev-primes
         prime?
         odd-prime?
         factorize
         defactorize
         divisors
         prime-divisors
         
         
         ; roots
         integer-root
         integer-root/remainder         
         
         ; Powers
         max-dividing-power
         perfect-power
         perfect-power?
         prime-power
         prime-power?
         odd-prime-power?
         as-power
         perfect-square
         ; sum and product of lists:
         sum
         product
         ; number theoretic functions
         totient
         moebius-mu
         divisor-sum
         )

;;;
;;; Configuration
;;;

(define prime-strong-pseudo-certainty 1/10000000)
(define prime-strong-pseudo-trials (integer-length (assert (/ 1 prime-strong-pseudo-certainty) integer?)))

(define *SMALL-PRIME-LIMIT* 1000000)
; (define *SMALL-PRIME-LIMIT* 1000) ; use 1000 for coverage testing
; Determines the size of the pre-built table of small primes
(define *SMALL-FACORIZATION-LIMIT* *SMALL-PRIME-LIMIT*)
; Determines whether to use naive factorization or Pollards rho method.

;;;
;;; Types and Predicates
;;;

(define-type N  Natural)
(define-type N+ Exact-Positive-Integer)
(define-type Z  Integer)

(define-type Ns (Listof N))
(define-type Zs (Listof Z))

(define-type Base-Exponent (List N N))
(define-type BE Base-Exponent)
(define-type Factorization (List Base-Exponent))

(define-type Prime N) ; non-checked of course

(define-syntax (cast stx) (syntax-case stx () [(_ . more) #'(assert . more)]))
; Note: (cast val predicate) is used in the code, where
; the math says predicate must be true, but the type system
; can prove it. Replace assert with a "proper" cast when
; it appears in Typed Racket.

(define-predicate natural?  N)  ; Note: 0 is natural
(define-predicate naturals? Ns)
(define-predicate Integer?  Z)
(define-predicate integers? Zs)

;;;
;;; DIVISIBILITY
;;;

(: divides? : Z Z -> Boolean)
; For b<>0:  ( a divides b <=> exists k s.t. a*k=b )
(define (divides? a b)
  (= (remainder b a) 0))

; THEOREM (Bezout's identity)
;  If a and b are integers (not both zero), then
;  there exists integers u and v such that
;    gcd(a,b) = au + bv
;  Note: u and v are not unique

; (bezout-binary a b) = (list u v)   <=>   gcd(a,b) = au + bv
(: bezout-binary : Z Z -> (List Z Z))
(define (bezout-binary a b)
  (: loop : Z Z Z Z Z Z -> (List Z Z))
  (define (loop a b ua va ub vb)  ; a>=b>0 , a = ua*a+ub*b,  b = ub*a+ub*b
    (let ([r (remainder a b)]
          [q (quotient a b)])
      (if (= r 0)
          (list ub vb)
          (loop b r ub vb (- ua (* q ub)) (- va (* q vb))))))
  (if (> a b)
      (loop a b 1 0 0 1)
      (loop b a 0 1 1 0)))

; (bezout a b c ...) -> (list u v w ...)    <=>  gcd(a,b,c,...) = au + bv + cw + ...
(: bezout : Z Z * -> Zs)
(define (bezout a . bs)
  (if (null? bs)
      (list 1)
      (let ([uvs (apply bezout bs)]
            [st  (bezout-binary (apply gcd bs) a)])
        (let ([s (first st)]
              [t (second st)])
          (cons t (map (lambda: ([u : Integer]) (* s u))
                       uvs))))))

; DEF (Coprime, relatively prime)
;  Two or more integers are called coprime, if their greatest common divisor is 1.
;     a, b and c coprime <=> gcd(a,b,c)=1

(: coprime? : Z Z * -> Boolean)
(define (coprime? a . bs)
  (= 1 (apply gcd (cons a bs))))

(: pairwise-coprime? : Z Z * -> Boolean)
(define (pairwise-coprime? a . bs)
  (or (null? bs)
      (and (andmap (λ: ([b : Integer]) (coprime? a b)) bs)
           (apply pairwise-coprime? bs))))

;;;
;;; Powers
;;;

(: max-dividing-power : Z Z -> N)
; (max-dividing-power p n) = m  <=> p^m | n  and  p^(m+1) doesn't divide n
;   In Mathematica this one is called IntegerExponent
(define (max-dividing-power p n)
  (: find-start : Z Z -> Z)
  (define (find-start p-to-e e)
    ;(display (list 'fs 'p-to-e p-to-e  'e e)) (newline)
    ; p-to-e divides n  and  p-to-e = p^e
    (let ([p-to-e2 (sqr p-to-e)])
      (cond [(= p-to-e2 n) (* 2 e)]
            [(> p-to-e2 n) (find-power p-to-e e)]
            [(divides? p-to-e2 n) (if (divides? p (quotient n p-to-e2))
                                      (find-start p-to-e2 (* 2 e))
                                      (* 2 e))]
            [else (find-power p-to-e e)])))
  (: find-power : Z Z -> Z)
  (define (find-power p-to-e e)
    ;(display (list 'fp 'p-to-e p-to-e  'e e)) (newline)
    ; p-to-e <= n < (square p-to-e)
    (+ e (max-dividing-power-naive p (quotient n p-to-e))))
  (cond [(= p 1)              1]
        [(not (divides? p n)) 0]
        [else                 (assert (find-start p 1) natural?)]))


(: max-dividing-power-naive : Z Z -> N)
(define (max-dividing-power-naive p n)
  ; sames as max-dividing-power but using naive algorithm
  (: loop : Z Z -> Z)
  (define (loop p-to-e e)
    (if (divides? p-to-e n)
        (loop (* p p-to-e) (+ e 1))
        (- e 1)))
  (if (= p 1)
      (error 'max-dividing-power "No maximal power of 1 exists")
      (assert (loop 1 0) natural?)))

;;;
;;; Random Integers
;;;

; Note: (random k) requires k in interval from 1 to 4294967087.

(: integer-log2 : N -> Z)
(define (integer-log2 n)
  (if (zero? n)
      (error 'integer-log2 "argument must be positive, got ~a" n)
      (assert (inexact->exact (ceiling (/ (log n) (log 2)))) integer?)))

(: big-random : N -> N)
(define (big-random n)
  ;;  return random integer in the interval [0;n[
  (let ([l 30])
    (let ([bits-needed (integer-log2 n)]
          [M           (expt 2 l)])
      (let loop ([blocks (quotient bits-needed l)]
                 [r      (random (assert (inexact->exact (expt 2 (remainder bits-needed l))) integer?))])
        (if (= blocks 0)
            (assert (remainder r n) natural?)
            (loop (- blocks 1) (+ (* r M) (random M))))))))

(define random-integer big-random)

(: random-integer-in-interval : Z Z -> Z)
(define (random-integer-in-interval from to)
  ; return random integer in the half-open
  ; interval [from;to)
  (+ from (random-integer (assert (- to from) natural?))))


;;;
;;; MODULAR ARITHMETIC
;;;

; THEOREM
;  If gcd(a,n)=1 then there exist b such that
;    ab=1 mod n
;  The number b is called an inverse of a modulo n.

(: inverse : Z Z -> (U Z False))
;   return b, where a*b=1 mod n and b in {0,...,n-1}
(define (inverse a n)
  (if (coprime? a n)
      (modulo (first (bezout a n)) n)
      #f))

; Within a (with-modulus n form1 ...) the return values of
; the arithmetival operations +, -, * and ^ are automatically
; reduced modulo n. Furthermore (mod x)=(modulo x n) and
; (inv x)=(inverse x n).

; Example: (with-modulus 3 (^ 2 4)) ==> 1

(define-syntax (with-modulus stx)
  (syntax-case stx ()
    [(with-modulus e form ...)
     (with-syntax ([+   (datum->syntax (syntax with-modulus) '+)]
                   [-   (datum->syntax (syntax with-modulus) '-)]
                   [*   (datum->syntax (syntax with-modulus) '*)]
                   [^   (datum->syntax (syntax with-modulus) '^)]
                   [mod (datum->syntax (syntax with-modulus) 'mod)]
                   [inv (datum->syntax (syntax with-modulus) 'inv)])
       (syntax (let* ([n e]
                      [mod    (λ: ([x : Integer]) (modulo x n))]
                      [inv    (λ: ([x : Integer]) (inverse x n))]
                      [+      (λ: ([x : Integer] [y : Integer]) (mod (+ x y)))]
                      [-      (λ: ([x : Integer] [y : Integer]) (mod (- x y)))]
                      [*      (λ: ([x : Integer] [y : Integer]) (mod (* x y)))]
                      [square (λ: ([x : Integer]) (* x x))]
                      [^      (letrec: ([^ : (Integer Integer -> Integer)
                                           (λ (a b)
                                             (cond
                                               [(= b 0)   1]
                                               [(even? b) (square (^ a (quotient b 2)))]
                                               [else      (* a (^ a (sub1 b)))]))])
                                ^)])
                 form ...)))]))

; THEOREM (The Chinese Remainder Theorem)
;   Let n1,...,nk be positive integers with gcd(ni,nj)=1 whenever i<>j,
;   and let a1,...,ak be any integers. Then the solutions to
;     x=a1  mod n1,  ...,  x=ak  mod nk
;   has a single solution in {0,...,n-1}, where n=n1*...nk.

; Example : (solve-chinese '(2 3 2) '(3 5 7)) = 23

(: solve-chinese : Zs (Listof N+) -> N)
(define (solve-chinese as ns)
  ; the ns should be coprime
  (let* ([n  (product ns)]
         [cs (map (λ: ([ni : Z]) (quotient n ni)) ns)]
         [ds (map inverse cs ns)]
         [es (cast ds integers?)])
    (cast (modulo (sum (map * as cs es)) n) natural?)))

;;;
;;; PRIMES
;;;

(: odd-prime? : Natural -> Boolean)
(define (odd-prime? n)
  (and (odd? n) (prime? n)))

;;; PRIMALITY TESTS

; THEOREM (Fermat's little theorem) [MCA,p.75]
;                        p
;  p prime, a in Z  =>  a  = a mod p
;                        p-1
;  (not p|a)        =>  a  = a mod p

; [MCA, p.507  -  Fermat test]
(: prime-fermat? : Integer -> (U Boolean 'possibly-prime))
; The Fermat test answers 
;   #t                if n=2 or n=3
;   'possibly-prime   if n is a prime
;   'possibly-prime   if Carmichael number with gcd(a,n)=1.
;   #f otherwise
(define (prime-fermat? n)
  (let ([n (abs n)])
    (cond
      [(= n 2)   #t]
      [(zero? n) #f]
      [(= n 1)   #f]
      [(= n 3)   #t]
      [else    
       (let* ([a (random-integer-in-interval 2 (- n 1))]
              [b (with-modulus n (^ a (- n 1)))])
         (if (= b 1)
             'possibly-prime
             #f))])))

; Strong pseudoprimality test
; The strong test returns one of:
;   'probably-prime                                        if n is a prime
;   'composite            (with at least probability 1/2)  if n is a composite non-Carmichael number
;   a proper divisor of n (with at least probability 1/2)  if n is a Carmichael number
; [MCA, p.509 - Algorithm 18.5]
(: prime-strong-pseudo-single? : Natural -> (U 'probably-prime 'composite N))
(define (prime-strong-pseudo-single? n)
  (cond
    [(< n 4) (error 'prime-strong-pseudo-single? "n must be 4 or greater, got ~a" n)]
    [else    
     (define a (random-integer-in-interval 2 (- n 1)))
     (define g (gcd a n))
     (cond
       [(> g 1) g] ; factor found
       [else
        ; 3. write n-1 = 2^ν * m , m odd
        (let loop ([ν 0] [m (- n 1)])
          (cond 
            [(even? m) (loop (add1 ν) (quotient m 2))]
            [else ; 4. for i=1,...,ν do bi <- b_{i-1}^2 rem N
             (define b (with-modulus n (^ a m)))
             (cond 
               [(= b 1) 'probably-prime]
               [else    
                (let loop ([i 0] [b b] [b-old b])
                  (if (and (< i ν) (not (= b 1)))
                      (loop (add1 i)
                            (with-modulus n (* b b))
                            b)
                      (if (= b 1)
                          (let ([g (gcd (+ b-old 1) n)])
                            (if (or (= g 1) (= g n))
                                'probably-prime
                                g))
                          'composite)))])]))])]))

(define-type Strong-Test-Result         (U 'very-probably-prime 'composite N))

(: prime-strong-pseudo/explanation : N -> Strong-Test-Result)
(define (prime-strong-pseudo/explanation n)
  ; run the strong test several times to improve probability
  (: loop : Z (U Strong-Test-Result 'probably-prime) -> Strong-Test-Result)
  (define (loop trials result)
    (cond [(= trials 0)                 'very-probably-prime]
          [(eq? result 'probably-prime) (loop (sub1 trials) (prime-strong-pseudo-single? n))]
          [else                         result]))
  (loop prime-strong-pseudo-trials (prime-strong-pseudo-single? n)))

(: prime-strong-pseudo? : N -> Boolean)
(define (prime-strong-pseudo? n)
  (let ([explanation (prime-strong-pseudo/explanation n)])
    (or (eq? explanation 'very-probably-prime)
        (eq? explanation #t))))


(: prime? : Integer -> Boolean)
(define prime?
  (let ()
    ; TODO: Only store odd integers in this table
    (define N *SMALL-PRIME-LIMIT*)
    (define ps (make-vector (+ N 1) #t))
    (define ! vector-set!)
    (! ps 0 #f)
    (! ps 1 #f)
    (for ([n (in-range 2 (+ N 1))])
      (when (vector-ref ps n)
        (for ([m (in-range (+ n n) (+ N 1) n)])
          (! ps m #f))))
    (lambda (n)
      (if (< n N)
          (vector-ref ps n)
          (prime-strong-pseudo? n)))))

(: next-prime : (case-> (N -> N) (Z -> Z)))
(define (next-prime n)
  (cond
    [(negative? n) (- (prev-prime (abs n)))]
    [(= n 0) 2]
    [(= n 1) 2]
    [(= n 2) 3]
    [(even? n) (let ([n+1 (add1 n)])
                 (if (prime? n+1)
                     n+1
                     (next-prime n+1)))]
    [else      (let ([n+2 (+ n 2)])
                 (if (prime? n+2)
                     n+2
                     (next-prime n+2)))]))

(: prev-prime : Z -> Z)
(define (prev-prime n)
  (cond
    [(negative? n) (- (next-prime (abs n)))]
    [(= n 3)   2]
    [(< n 3)   -2]
    [(even? n) (let ([n-1 (sub1 n)])
                 (if (prime? n-1)
                     n-1
                     (prev-prime n-1)))]
    [else      (let ([n-2 (- n 2)])
                 (if (prime? n-2)
                     n-2
                     (prev-prime n-2)))]))


(: next-primes : Z N -> Zs)
(define (next-primes m primes-wanted)
  (: loop : Z Z -> Zs)
  (define (loop n primes-wanted)
    (if (= primes-wanted 0)
        '()
        (let ([next (next-prime n)])
          (if next
              (cons next (loop next (sub1 primes-wanted)))
              '()))))
  (loop m primes-wanted))

(: prev-primes : Z N -> Zs)
(define (prev-primes m primes-wanted)
  (: loop : Z Z -> Zs)
  (define (loop n primes-wanted)
    (if (= primes-wanted 0)
        '()
        (let ([prev (prev-prime n)])
          (if prev
              (cons prev (loop prev (sub1 primes-wanted)))
              '()))))
  (loop m primes-wanted))

(: nth-prime : N -> Prime)
(define (nth-prime n)
  (define: p : Prime 2)
  (for ([m (in-range n)])
    (set! p (next-prime p)))
  p)


;;;
;;; FACTORIZATION
;;;

(: factorize : N -> (Listof (List N N)))
(define (factorize n)
  (if (< n *SMALL-PRIME-LIMIT*)   ; NOTE: Do measurement of best cut
      (factorize-small n)
      (factorize-large n)))

(: defactorize : (Listof (List N N)) -> N)
(define (defactorize bes)
  (cond [(empty? bes) 1]
        [else (define be (first bes))
              (* (expt (first be) (second be))
                 (defactorize (rest bes)))]))

(: factorize-small : N -> (Listof (List N N)))
(define (factorize-small n)
  ; fast for small n, but works correctly for large n too
  (small-prime-factors-over n 2))

(: small-prime-factors-over : N Prime -> (Listof (List N N)))
; Factor a number n without prime factors below the prime p.
(define (small-prime-factors-over n p) ; p prime
  (cond
    [(< n p)         '()]
    [(= n p)         (list (list p 1))]
    [(prime? n)      (list (list n 1))]
    [(divides? p n)  (let ([m (max-dividing-power p n)])
                       (cons (list p m)
                             (small-prime-factors-over 
                              (quotient n (expt p m))
                              (next-prime p))))]
    [else            (small-prime-factors-over n (next-prime p))]))


;;; ALGORITHM 19.6  Floyd's cycle detection trick
; [MCA, p. 536]

; Let α = {0,...,p-1} be a finite set.
; A function f : α -> α and x0 in α generates an infinite sequence:
;    x0, x1=f(x0), x2=f(x1), ...
; An infinite sequence in a finite set will repeat.

; Floyd-detect-cycle returns an index i>0 s.t. x_i = x_2i
(: floyd-detect-cycle : ((Z -> Z) Z -> Z))
(define (floyd-detect-cycle f x0)
  (do ([xi x0 (f xi)]
       [yi x0 (f (f yi))]
       [i  0  (add1 i)])
    [(= xi yi) i]))


;;; ALGORITHM 19.8  Pollard's rho method
; INPUT   n>=3 neither a prime nor a perfect power
; OUTPUT  Either a proper divisor of n or #f
(: pollard : N -> (U N False))
(define (pollard n)
  (let ([x0 (big-random n)])
    (do ([xi x0 (remainder (+ (* xi xi) 1) n)]
         [yi x0 (remainder (+ (sqr (+ (* yi yi) 1)) 1) n)]
         [i  0  (add1 i)]
         [g  1  (gcd (- xi yi) n)])
      [(or (< 1 g n) (> i (sqrt n)))
       (if (< 1 g n)
           (cast g natural?)
           #f)])))

(: pollard-factorize : Natural -> (Listof (List Natural Natural)))
(define (pollard-factorize n)
  (if (< n *SMALL-FACORIZATION-LIMIT*)
      (factorize-small n)
      (cond
        [(= n 1)        '()]
        [(prime? n)     `((, n 1))]
        [(even? n)      `((2 1) ,@(pollard-factorize (quotient n 2)))]
        [(divides? 3 n) `((3 1) ,@(pollard-factorize (quotient n 3)))]
        [(simple-perfect-power n)
         => (λ: ([base-and-exp : (List N N)]) 
              (cond
                [(prime? (car base-and-exp)) (list base-and-exp)]
                [else (map (λ: ([b-and-e : (List Natural Natural)])
                             (list (car b-and-e) 
                                   (* (cadr base-and-exp) (cadr b-and-e))))
                           (pollard-factorize (car base-and-exp)))]))]
        [else                 
         (let loop ([divisor (pollard n)])
           (if divisor
               (append (pollard-factorize divisor)
                       (pollard-factorize (quotient n divisor)))
               (loop (pollard n))))])))

(: factorize-large : N -> (Listof (List N N)))
(define (factorize-large n)
  (combine-same-base
   (sort (pollard-factorize n) base-and-exponent<?)))

(: base-and-exponent<? : (U N (List N N)) (U N (List N N)) -> Boolean)
(define (base-and-exponent<? x y)
  (let ([id-or-first 
         (λ: ([x : (U Integer (List Integer Integer))])
           (if (number? x) x (first x)))])
    (<= (id-or-first x) (id-or-first y))))

(: combine-same-base : (Listof (List N N)) -> (Listof (List N N)))
(define (combine-same-base list-of-base-and-exponents)
  ; list-of-base-and-exponents must be sorted
  (let ([l list-of-base-and-exponents])
    (cond
      [(null? l)        '()]
      [(null? (cdr l))  l]
      [else             
       (define b1 (first  (first l)))
       (define e1 (second (first l)))
       (define b2 (first  (second l)))
       (define e2 (second (second l)))
       (define more (cddr l))
       (if (= b1 b2)
           (combine-same-base (cons (list b1 (+ e1 e2))
                                    (cdr (cdr list-of-base-and-exponents))))
           (cons (car list-of-base-and-exponents)
                 (combine-same-base (cdr list-of-base-and-exponents))))])))


; find-tail pred clist -> pair or false
; Return the first pair of clist whose car satisfies pred. If no pair does, return false.
(: find-tail : (Z -> Boolean) Zs -> (U False Zs))
(define (find-tail pred xs)
  (cond [(empty? xs) #f]
        [(pred (car xs)) xs]
        [else (find-tail pred (cdr xs))]))


;;;
;;; Powers
;;;

(: as-power : N+ -> (Values N N))
;   Write a>0 as b^r with r maximal. Return b and r.
(define (as-power a)    
  (let ([r (apply gcd ((inst map N (List N N)) second (factorize a)))])
    (values (integer-root a r) r)))


(: prime-power : N -> (U (List Prime N) False))
;   if n is a prime power, return list of prime and exponent in question,
;   otherwise return #f
(define (prime-power n)
  (let ([factorization (prime-divisors/exponents n)])
    (if (= (length factorization) 1)
        (first (prime-divisors/exponents n))
        #f)))

(: prime-power? : N -> Boolean)
;   Is n of the form p^m, with p is prime?
(define (prime-power? n)
  (and (prime-power n) #t))

(: odd-prime-power? : N -> Boolean)
(define (odd-prime-power? n)
  (let ([p/e (prime-power n)])
    (and p/e
         (odd? (first p/e)))))

(: perfect-power? : N -> Boolean)
(define (perfect-power? a)
  (and (not (zero? a))
       (let-values ([(base n) (as-power a)])
         (and (> n 1) (> a 1)))))

(: simple-perfect-power : N -> (U (List N N) False))
(define (simple-perfect-power a)
  ; simple-perfect-power is used by pollard-fatorize
  (and (not (zero? a))
       (let-values ([(base n) (simple-as-power a)])
         (if (and (> n 1) (> a 1))
             (list base n)
             #f))))

(: perfect-power : N -> (U (List N N) False))
;   if a = b^n with b>1 and n>1
(define (perfect-power a)
  (and (not (zero? a))
       (let-values ([(base n) (as-power a)])
         (if (and (> n 1) (> a 1))
             (list base n)
             #f))))

(: perfect-square : N -> (U N False))
(define (perfect-square n)
  (let ([sqrt-n (integer-sqrt n)])
    (if (= (* sqrt-n sqrt-n) n)
        sqrt-n
        #f)))

(: powers-of : N N -> (Listof N))
;   returns a list of numbers: a^0, ..., a^n
(define (powers-of a n)
  (let: loop : (Listof N)
    ([i   : N 0] 
     [a^i : N 1])
    (if (<= i n)
        (cons a^i (loop (+ i 1) (* a^i a)))
        '())))

(define prime-divisors/exponents factorize)

(: prime-divisors : N -> (Listof Prime))
;   return list of primes in a factorization of n
(define (prime-divisors n)
  (map (inst car N (Listof N))
       (prime-divisors/exponents n)))

(: prime-exponents : N -> (Listof N))
;   return list of exponents in a factorization of n
(define (prime-exponents n)
  (map (inst cadr N N (Listof N)) 
       (prime-divisors/exponents n)))


;;; ALGORITHM 9.22  p-adic Newton Iteration  [MCA, p.264]
; INPUT phi in Z[y] (represented a normal function f : Z -> Z)
;       p in Z, l>0,
;       g0 in Z with phi(g)=0 mod p,  phi'(go) invertible mod p
;       and a modular inverse s0 of phi'(g0) mod p
; OUTPUT
;       g in R with phi(g)=0 mod p^l  and  g=g0 mod p

(: p-adic-newton-iteration : (N -> N) (N -> N) N N N N -> N)
(define (p-adic-newton-iteration phi Dphi p l g0 s0)
  (let ([r (integer-length l)])
    (let: loop : N ([i  : N 1]
                    [gi : N g0]
                    [si : N s0])
      (cond
        [(< i r) (let ([g_i+1 (modulo (- gi (* (phi gi) si))
                                      (expt p (expt 2 i)))])
                   (loop (+ i 1)
                         g_i+1
                         (modulo (- (* 2 si) (* (Dphi g_i+1) si si)) 
                                 (expt p (expt 2 i)))))]
        [else    (modulo (- gi (* (phi gi) si)) 
                         (expt p l))]))))

;(= (p-adic-newton-iteration (lambda (y) (- (* y y y y) 1))
;                            (lambda (y) (* 4 (* y y y)))
;                            5
;                            4
;                            2
;                            3)
;   182)


(: is-nth-root : N N N -> (U N False))
;    Return candidate if it's the nth root of a, otherwise #f
(define (is-nth-root a n candidate)
  (if (= (expt candidate n) a)
      candidate
      #f))

(: integer-root/odd-odd : N N -> (U N False))
(define (integer-root/odd-odd a n)
  ; INPUT   a odd, n odd
  ; OUTPUT  The n'th root of a, if it's an integer, #f otherwise
  (unless (and (odd? a) (odd? n))
    (error "integer-root/odd-odd: Both a and n must be odd; given " a n))
  ; Newton iteration with phi(y)=y^n-a and initial guess g0=1         
  (let ([candidate 
         ; Newton iteration with phi(y)=y^n-a and initial guess g0=1         
         (let* ([k (do: : N ([k : N 1 (add1 k)])
                     [(> (expt 2 (* n k)) a) k])]
                [r (integer-length k)])
           (let: loop : N
             ([i  : N 1] [gi : N 1] [si : N 1] [ti : N 1])
             ; (display `((k ,k) (r ,r) (i ,i) (gi ,gi) (si ,si) (ti ,ti)))   (newline)
             (cond
               [(< i r) (let* ([g_i+1 (modulo (- gi (* (- (* gi ti) a) si)) 
                                              (expt 2 (expt 2 i)))]
                               [t_i+1 (modulo (expt g_i+1 (assert (- n 1) natural?))
                                              (expt 2 (expt 2 (+ i 1))))])
                          (loop (+ i 1)
                                g_i+1
                                (modulo (- (* 2 si) (* n t_i+1 si si))
                                        (expt 2 (expt 2 i)))
                                t_i+1))]
               [else    (modulo (- gi (* (- (* gi ti) a) si))
                                (expt 2 (expt 2 i)))])))])
    (is-nth-root a n candidate)))

#;(define (integer-root/power-of-two  a n)
    ; INPUT   n a power of 2
    ;          gcd(6,a)=1
    ; OUTPUT 
    ;        
    (let ([phi  (lambda (y) (- (expt y n) a))]
          [Dphi (lambda (y) (* n (expt y (- n 1))))])
      (let ([candidate1 (p-adic-newton-iteration phi Dphi 3 11 1 (inverse (Dphi 1) 3))])
        (if (= (expt candidate1 n) a)
            candidate1
            (let ([candidate2 (p-adic-newton-iteration phi Dphi 3 11 2 (inverse (Dphi 2) 3))])
              (is-nth-root a n candidate2))))))

(: integer-root/power-of-two : N N -> (U N False))
(define (integer-root/power-of-two a n)
  ; INPUT    n = 2^d
  ; OUTPUT   an n'th root of a, or #f
  (let: loop : (U N False)
    ([d : Z (- (integer-length n) 1)]
     [b : N a])
    (if (= d 0)
        b
        (let-values ([(s r) (integer-sqrt/remainder b)])
          (if (not (zero? r))
              #f
              (loop (- d 1) s))))))

(: integer-root-factor : N N -> (List N N N N))
(define (integer-root-factor a n)
  ; factor a = 2^d 3^e b^r  , where gcd(6,b)=1
  (let* ([d      (max-dividing-power 2 a)]
         [e      (max-dividing-power 3 a)]
         [b-to-r (quotient a (* (expt 2 d) (expt 3 e)))]
         ; factor n = 2^f c , where gcd(2,c)=1
         [f         (max-dividing-power 2 n)]
         [two-to-f  (expt 2 f)]
         [c         (quotient n two-to-f)]
         [x (integer-root/odd-odd b-to-r c)]
         ;
         [b (if x
                (integer-root/power-of-two x two-to-f)
                (error 'integer-root-factor "internal error - send bug report"))]
         [b1 (if b b (error 'integer-root-factor "internal error - send bug report"))]
         [r (max-dividing-power b1 b-to-r)])
    (list d e b1 r)))




(: integer-root/remainder : N N -> (Values N N))
(define (integer-root/remainder a n)
  (let ([i (integer-root a n)])
    (values i (assert (- a (expt i n)) natural?))))

(: integer-root : N N -> N)
(define (integer-root x y)
    ; y'th root of x
    (cond 
      [(eq? x 0) 0]
      [(eq? x 1) 1]
      [(eq? y 1) x]
      [(eq? y 2) (integer-sqrt x)]
      [(not (integer? y))
       (error 'integer-root "internal error - (used to return 1 here - why?) todo: remove this error after testing")]
      [else
       (define length (integer-length x))
       ;; (expt 2 (- length l 1)) <= x < (expt 2 length)
       (assert
        (cond [(<= length y) 1]
              ;; result is >= 2
              [(<= length (* 2 y))
               ;; result is < 4
               (if (< x (expt 3 y)) 2 3)]
              [(even? y) (integer-root (integer-sqrt x) (quotient y 2))]
              [else
               (let* ([length/y/2 ;; length/y/2 >= 1 because (< (* 2 y) length)
                       (quotient (quotient (- length 1) y) 2)])
                 (let ([init-g
                        (let* ([top-bits          (arithmetic-shift x (- (* length/y/2 y)))]
                               [nth-root-top-bits (integer-root top-bits y)])
                          (arithmetic-shift (+ nth-root-top-bits 1) length/y/2))])
                   (let: loop : Z ([g : Z init-g])
                     (let* ([a (expt g (assert (- y 1) natural?))]
                            [b (* a y)]
                            [c (* a (- y 1))]
                            [d (quotient (+ x (* g c)) b)])
                       (let ([diff (- d g)])
                         (cond [(not (negative? diff))
                                g]
                               [(< diff -1)
                                (loop d)]
                               [else
                                ;; once the difference is one, it's more
                                ;; efficient to just decrement until g^y <= x
                                (let loop ((g d))
                                  (if (not (< x (expt g y)))
                                      g
                                      (loop (- g 1))))]))))))])
        natural?)]))

#;(define (integer-root a n)
  ; factor a = 2^d 3^e b^r  , where gcd(6,b)=1
  (cond
    [(= n 1) a]
    [(= n 2) (let-values ([(s r) (integer-sqrt/remainder a)])
               (if (zero? r)
                   s
                   #f))]
    [else
     (let ([d (max-dividing-power 2 a)])
       (if (not (divides? n d))
           #f
           (let ([e (max-dividing-power 3 a)])
             (if (not (divides? n e))
                 #f
                 (let* ([b-to-r (quotient a (* (expt 2 d) (expt 3 e)))]
                        ; factor n = 2^f c , where gcd(2,c)=1
                        [f         (max-dividing-power 2 n)]
                        [two-to-f  (expt 2 f)]
                        [c         (quotient n two-to-f)])
                   ;
                   (cond
                     [(integer-root/odd-odd b-to-r c) 
                      => (lambda (cth-root--of--b-to-r)
                           (cond
                             [(integer-root/power-of-two cth-root--of--b-to-r two-to-f)
                              => (lambda (nth-root--of--b-to-r)
                                   (* (expt 2 (quotient d n))
                                      (expt 3 (quotient e n))
                                      nth-root--of--b-to-r))]
                             [else #f]))]
                     [else #f]))))))]))

(: simple-as-power : N+ -> (Values N N))
;    For a>0 write it as a = b^r where r maximal
;    return (values b r)
(define (simple-as-power a)
  ; (displayln (list 'simple-as-power a))
  ; Note: The simple version is used by pollard-factorize
  (let: loop : (Values N N)
    ([n : N (integer-length a)])
    (let-values ([(root rem) (integer-root/remainder a (add1 n))])
      (if (zero? rem)
          (values root (assert (add1 n) natural?))
          (if (positive? n)
              (loop (sub1 n))
              (error 'simple-as-power "internal error"))))))

(: prime-power? : N -> Boolean)

;;;
;;; DIVISORS
;;;

(: divisors : Z -> (Listof N))
;   return the positive divisorts of n
(define (divisors n)
  (cond [(zero? n) '()]
        [else (define n+ (if (positive? n) n (- n)))
              (factorization->divisors (factorize n+))]))

(: factorization->divisors : (Listof (List N N)) -> (Listof N))
(define (factorization->divisors f)
  (cond
    [(null? f) '(1)]
    [else (let ([p (first (first f))]
                [n (second (first f))]
                [g (rest f)])
            ; f = p^n * g
            (let ([divisors-of-g (factorization->divisors g)])
              (apply append
                     ((inst map (Listof N) N)
                      (λ: ([p^i : N]) (map (λ: ([d : N]) (* p^i d)) divisors-of-g))
                      (powers-of p n)))))]))

;;;
;;; Number theoretic functions
;;;

; DEFINITION (Euler's phi function  aka  totient)
;  phi(n) is the number of integers a=1,2,... such that gcd(a,n)=1

; THEOREM
;   If m and n are coprime then
;     phi(mn) = phi(m) phi(n) 

; THEOREM (Euler's phi function)
;  If the prime power factorization of p is
;           e1     ek
;     n = p1 ... pk     , where pi is prime and ei>0
;  then
;                   k          1
;   phi(n) = n * product (1 - ---- )
;                  i=1         pi

(: totient : N -> N)
(define (totient n)
  (let ((ps (prime-divisors n)))
    (assert (* (quotient n (product ps))
               (product (map (λ: ([p : N]) (sub1 p)) ps)))
            natural?)))

(: every : (All (A) (A -> Boolean) (Listof A) -> Boolean))
(define (every pred xs)
  (or (empty? xs)
      (and (pred (car xs))
           (every pred (cdr xs)))))


; moebius-mu : natural -> {-1,0-1}
;   mu(n) =  1  if n is a product of an even number of primes
;         = -1  if n is a product of an odd number of primes
;         =  0  if n has a multiple prime factor
(: moebius-mu : N -> (U -1 0 1))
(define (moebius-mu n)
  (: one? : Z -> Boolean)
  (define (one? x) (= x 1))
  (define f         (factorize n))
  (define exponents ((inst map N (List N N)) second f))
  (cond 
    [(every one? exponents)
     (define primes ((inst map N (List N N)) first f))
     (if (even? (length primes))
         1 -1)]
    [else 0]))


(: divisor-sum : (case-> (N -> N) (N N -> N)))                   
(define divisor-sum 
  ; returns the sum of the kth power of all divisors of n
  (let ()
    (case-lambda 
      [(n)   (divisor-sum n 1)]
      [(n k) (let* ([f  (factorize n)]
                    [ps ((inst map N (List N N)) first f)]
                    [es ((inst map N (List N N)) second f)])
               (: divisor-sum0 : Any N -> N)
               (define (divisor-sum0 p e) (+ e 1))
               (: divisor-sum1 : N N -> N)
               (define (divisor-sum1 p e)
                 (let: loop : N 
                   ([sum    : N 1]
                    [n      : N 0]
                    [p-to-n : N 1])
                   (cond [(= n e) sum]
                         [else (let ([t (* p p-to-n)])
                                 (loop (+ t sum) (+ n 1) t))])))
               (: divisor-sumk : N N -> N)
               (define (divisor-sumk p e)
                 (let ([p-to-k (expt p k)])
                   (let: loop : N
                     ([sum     : N 1]
                      [n       : N 0]
                      [p-to-kn : N 1])
                     (cond [(= n e) sum]
                           [else (let ([t (* p-to-k p-to-kn)])
                                   (loop (+ t sum) (+ n 1) t))]))))
               (cast
                (product
                 (map (cond [(= k 0) divisor-sum0]
                            [(= k 1) divisor-sum1]
                            [else    divisor-sumk])
                      ps es))
                natural?))])))


; These tests are for un-exported functions.
#;(begin
    (require typed/rackunit)
    
    (check-equal? (max-dividing-power-naive 3 27) 3)
    (check-equal? (max-dividing-power-naive 3 (* 27 2)) 3)
    
    (check-true   (<= 4 (random-integer-in-interval 4 5) 4))
    
    (check-false (prime-fermat? 0))
    (check-false (prime-fermat? 1))
    (check-false (prime-fermat? 4))
    (check-false (prime-fermat? 6))
    (check-false (prime-fermat? 8))
    
    (check-equal? (prime-fermat? 2)   #t)
    (check-equal? (prime-fermat? 3)   #t)
    (check-equal? (prime-fermat? 5)   'possibly-prime)
    (check-equal? (prime-fermat? 7)   'possibly-prime)
    (check-equal? (prime-fermat? 11)  'possibly-prime)
    (check-true   (member? (prime-fermat? 561) '(#f possibly-prime))) ; Carmichael number
    
    (check-equal? (prime-strong-pseudo-single? 4) 2)
    (check-true  (member? (prime-strong-pseudo-single? 6) '(2 3)))
    (check-true  (member? (prime-strong-pseudo-single? 8) '(2 4 composite)))
    
    (check-equal? (prime-strong-pseudo-single? 5)   'probably-prime)
    (check-equal? (prime-strong-pseudo-single? 7)   'probably-prime)
    (check-equal? (prime-strong-pseudo-single? 11)  'probably-prime)
    (check-true   (member? (prime-strong-pseudo-single? 561) (cons 'probably-prime (divisors 561)))) ; Carmichael number
    
    )