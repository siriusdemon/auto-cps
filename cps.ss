(load "match.ss")
(import (match match))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; println
(define for-each
  (lambda (proc lst)
    (if (null? lst)
        'done
        (begin
          (proc (car lst))
          (for-each proc (cdr lst))))))

(define println
  (lambda lst
    (begin
      (for-each (lambda (x) (display x) (newline)) lst))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CPS
(define prim-op '(+ - * / add1 sub1 car cdr cons list null? pair? eqv? eq? zero? > < = null? symbol? append number?))
(define prim?
  (lambda (op)
    (memv op prim-op)))

(define tail-exprs
  (lambda (expr)
    (match expr
      [,x (guard (or (number? x) (symbol? x) (null? x))) '()]
      [(lambda (,v ...) ,body) '()]
      [(,op ,rands ...) (guard (prim? op)) '()]
      [(if ,test ,br1 ,br2) `(,br1 ,br2)]
      [(let ([,x ,y] ...)  ,body) `(,body)]
      [(,rator ,rands ...) '()])))

(define head-exprs
  (lambda (expr)
    (match expr
      [,x (guard (or (number? x) (symbol? x) (null? x))) '()]
      [(lambda (,v ...) ,body) '()]
      [(,op ,rands ...) (guard (prim? op)) rands]
      [(if ,test ,br1 ,br2) `(,test)]
      [(let ([,x ,y] ...) ,body) y]
      [(,rator ,rands ...) `(,rator ,rands ...)])))

(define binding-vars
  (lambda (expr)
    (match expr
      [(let ([,x ,y] ...) ,body) x]
      [,x '()])))

(println 
  "test tail-exprs"
  (tail-exprs '(lambda (x y) (cons x y)))
  (tail-exprs '(if (x y) (cons x y) (+ 1 2)))
  (tail-exprs '(x y z))
  (tail-exprs '(+ x (- y 10)))
  (tail-exprs '(let ([x 10] [y 20]) (+ x y)))
  (tail-exprs 'x)
  (tail-exprs '10))

(println 
  "test head-exprs"
  (head-exprs '(lambda (x y) (cons x y)))
  (head-exprs '(if (x y) (cons x y) (+ 1 2)))
  (head-exprs '(x y z))
  (head-exprs '(+ x (- y 10)))
  (head-exprs '(let ([x 10] [y 20]) (+ x y)))
  (head-exprs 'x)
  (head-exprs '10))

(println 
  "test binding-vars"
  (binding-vars '(lambda (x y) (cons x y)))
  (binding-vars '(if (x y) (cons x y) (+ 1 2)))
  (binding-vars '(x y z))
  (binding-vars '(+ x (- y 10)))
  (binding-vars '(let ([x 10] [y 20]) (+ x y)))
  (binding-vars 'x)
  (binding-vars '10))


; simple
(define simple?
  (lambda (expr)
    (match expr
      [,x (guard (or (number? x) (symbol? x) (null? x))) #t]
      [(lambda (,v ...) ,body) #t]
      [(,op ,rands ...) (guard (prim? op)) (andmap simple? rands)]
      [(if ,test ,br1 ,br2) (andmap simple? `(,test ,br1 ,br2))]
      [(let ([,x ,y] ...) ,body) (andmap simple? `(,y ... ,body))]
      [(,rator ,rands ...) #f])))

(println 
  "test simple?"
  (simple? '(lambda (x y) (cons x y)))
  (simple? '(if (x y) (cons x y) (+ 1 2)))
  (simple? '(x y z))
  (simple? '(+ x (- y 10)))
  (simple? '(let ([x 10] [y 20]) (+ x y)))
  (simple? 'x)
  (simple? '10))

; from EOPL-1st
(println
  "test simple? EOPL-1st"
  (simple? '(car x))
  (simple? '(if p x (car (cdr x))))
  (simple? '(f (car x)))
  (simple? '(car (f x)))
  (simple? '(if p x (f (cdr x))))
  (simple? '(if (f x) x (f (cdr x))))
  (simple? '(lambda (x) (f x)))
  (simple? '(lambda (x) (car (f x))))
)


; EOPL-1st 8.3.3
(define a '(car (f (cdr x))))
(define b '(f (car (cdr x))))
(define c '(if (zero? x) (car y) (car (cdr y))))
(define e '(let ([f (lambda (x) x)]) (f 3)))
(println
  "test simple?"
  (simple? a)
  (simple? b)
  (simple? c)
  (simple? e)
)


; EOPL-1st
(define initial-expr
  (lambda (expr)
    (letrec ([loop (lambda (ls)
                      (cond
                        [(null? ls) expr]
                        [(simple? (car ls)) (loop (cdr ls))]
                        [else (initial-expr (car ls))]))])
      (loop (head-exprs expr)))))

(println
  "find one initial expr"
  "Note that a single expression may have more than one initial expression"
  (initial-expr '(k (a (+ 1 b))))
  (initial-expr '(k (+ (f (g (h 3))) (a (+ 1 b)))))
  (initial-expr '(k (f (if (zero? x) (g 3) (g 4)) (g 5))))
  (initial-expr '(k (f (if (zero? x) 3 4) (if (p x) 3 4))))
  (initial-expr '(k (let ([x 3] [y (fact 4)]) (p x b))))
  (initial-expr '(k (f (if 1 (let ([x 3]) (g x)) 4))))
)


(define positional-substitution
  (lambda (expr pairs)
    (define helper 
      (lambda (expr)
        (let ([found-pair (assq expr pairs)])
          (if (pair? found-pair)
              (cdr found-pair)
              (match expr
                [,x (guard (or (number? x) (symbol? x) (null? x))) x]
                [(lambda (,x ...) ,body) `(lambda (,x ...) ,(helper body))]
                [(,op ,rands ...) (guard (prim? op)) `(,op ,@(map helper rands))]
                [(if ,test ,br1 ,br2) `(if ,(helper test) ,(helper br1) ,(helper br2))]
                [(let ([,x ,y] ...) ,body) `(let ([,x ,(helper y)] ...) ,(helper body))]
                [(,rator ,rands ...) `(,(helper rator) ,@(map helper rands))]
              )))))
    (helper expr)))

(define a '(f (g x)))
(define b '(let ([x 10] [y (fact 4)]) (cons x y)))
(define c '(if (c y) (fact 4) (h (g (f)))))

(println 
  "test positional substitution"
  (positional-substitution a (list (cons (initial-expr a) 'v)))
  (positional-substitution b (list (cons (initial-expr b) 'v)))
  (positional-substitution c (list (cons (initial-expr c) 'v)))
)


(define alpha-convert
  (lambda (expr vars)
    (let ([table (let ([pairs (map (lambda (var)
                                      (cons var (next-symbol-right var)))
                                  vars)])
                    (lambda (sym)
                      (let ([found-pair (assq sym pairs)])
                        (if (pair? found-pair)
                            (cdr found-pair)
                            sym))))])
      (match expr
        [(let ([,x ,y] ...) ,body)
              `(let ([,(map table x) ,y] ...) ,(beta body table))]
        [,x x]))))

(define beta
  (lambda (expr table)
    (match expr
      [,x (guard (number? x)) x]
      [,x (guard (null? x)) x]
      [,x (guard (symbol? x)) (table x)]
      [(lambda (,x ...) ,body) 
        `(lambda (,x ...)
          ,(beta body (lambda (var) (if (memq var x) var (table var)))))]
      [(,op ,rands ...) (guard (prim? op)) 
        `(,op ,@(map (lambda (rand) (beta rand table)) rands))]
      [(if ,test ,br1 ,br2) 
        `(if ,(beta test table) ,(beta br1 table) ,(beta br2 table))]
      [(let ([,x ,y] ...) ,body) 
        `(let ([,x ,(beta y table)] ...) 
          ,(beta body (lambda (var) (if (memq var x) var (table var)))))]
      [(,rator ,rands ...) 
        `(,(beta rator table) ,@(map (lambda (rand) (beta rand table)) rands))])))

(define next-symbol-right
  (lambda (var)
    (string->symbol
      (string-append (symbol->string var) ":"))))

(define d '(let ([g 3]) (f g x)))
(define e '(let ([g 3]) 
              (let ([g g])
                (f g x))))

(println
  "test alpha-convert"
  (alpha-convert d (binding-vars d))
  (alpha-convert e (binding-vars e))
)



(define cps
  (lambda (e)
    (match e
      [(lambda (,x ...) ,body)
        (let ([k (gensym "k")])
          `(lambda (,x ... ,k)
              ,(cps-with-cont body k)))]
      [,x x])))

(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
        [,x (guard (or (number? x) (symbol? x))) `(,k ,x)]
        [(quote ())  `(k '())]
        [(lambda (,v ...) ,body)
          `(,k ,(cps init))]
        [(,op ,rands ...) (guard (prim? op))
          `(,k (,op ,(map cps rands) ...))]
        [(if ,test ,br1 ,br2)
          (let ([pair1 (list (cons init br1))]
                [pair2 (list (cons init br2))])
            (let ([new-br1 (positional-substitution e pair1)]
                  [new-br2 (positional-substitution e pair2)])
                `(if ,test ,(cps-with-cont new-br1 k) ,(cps-with-cont new-br2 k))))]
        [(let ([,x ,y] ...) ,body) 
          (match (alpha-convert init (binding-vars init))
            [(let ([,x ,y] ...) ,body)
              `(let ([,x ,(map cps y)] ...) 
                  ,(cps-with-cont 
                      (positional-substitution e (list (cons init body))) 
                      k))])]
        [(,rator ,rands ...)
          (if (eq? init e)
              `(,rator ,(map cps rands) ... ,k)
              (let* ([v (gensym)]
                    [context (positional-substitution e (list (cons init v)))])
                  `(,rator ,(map cps rands) ... 
                      (lambda (,v)
                        ,(cps-with-cont context k)))))]))))


(println
  (cps '(lambda (x) x))
  (cps '(lambda (x) (if (zero? x) 10 20)))
  (cps '(lambda (s los)
            (if (null? los)
                '()
                (if (eq? s (car los))
                    (remove s (cdr los))
                    (cons (car los) (remove s (cdr los)))))))
  (cps ' (lambda (new old slst)
            (if (null? slst)
                '()
                (if (symbol? (car slst))
                    (if (eq? (car alst) old)
                        (cons new (subst new old (cdr slst)))
                        (cons (car slst) (subst new old (cdr slst))))
                    (cons (subst new old (car slst))
                          (subst new old (cdr slst)))))))
  (cps '(lambda (alst)
          (if (null? alst)
              1
              (let ([drest (depth-with-let (cdr alst))])
                (if (pair? (car alst))
                    (let ([dfirst (+ (depth-with-let (car alst)) 1)])
                      (if (< dfirst drest) drest dfirst))
                    drest)))))
  (cps-with-cont '(+ (f x) (g y)) 'k)
  (cps-with-cont '(+ (f a b) (g (lambda (a) (f a b)))) 'k)
  (cps-with-cont '(+ (lambda (f) (f a b)) 1) 'k)
  (cps-with-cont '(if (zero? a) '() 10) 'k)
  (cps '(lambda (a )(if (zero? a) '() 10)))
)