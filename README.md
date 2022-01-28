# CPS | A Note about EOPL-1st chapter 8

#### Step1

target language
```lisp
expr = (lambda (var ...) expr)
     | (expr expr ...)
     | (prim expr ...)
     | (if expr expr expr)
     | (let ([var H] ...) expr)
     | var
     | number
prim = (+ - * / add1 sub1 car cdr cons pair? list null? eqv? eq? zero? > < = null?)
```

term:
+ head position and tail position: Given an expr, those subexpressions that may be evaluated first are said to be in head position. those subexpressions that are evaluated as the result of the whole expression are in tail position.

for our little language, those are
```lisp
(lambda (v ... v) E)
(prim H ... H)
(H ... H)   ; application
(if H T T)
(let ([b H] ...) T)
```
Those `v`, `b`, `E` are not in head position either in tail position.


This is a function `tail-exprs`, which take one argument `expr`, returns all the subexprs in tail position.

```lisp
(define tail-exprs
  (lambda (expr)
    (match expr
      [(lambda (,v ...) ,body) '()]
      [(,op ,rands ...) (guard (prim? op)) '()]
      [(if ,test ,br1 ,br2) `(,br1 ,br2)]
      [(let ([,x ,y] ...)  ,body) `(,body)]
      [(,rator ,rands ...) '()]
      [,x (guard (or (number? x) (symbol? x))) '()])))
```

It's your time: 
+ define a function `head-exprs`, which take one argument `expr`, returns all the subexprs in head position.

+ define a function `binding-vars`, which take one argument `expr`, return all the binding variables. Note that only `let` and `letrec` (no exist yet!) contain binding variables.


term:
+ simple expr: A simple expr is not an application. And all of its subexpressions (if any) are simple. Specially, the lambda expression, number and symbol are all simple.

```lisp
(define simple?
  (lambda (expr)
    (match expr
      [,x (guard (or (number? x) (symbol? x) (null? x))) #t]
      [(lambda (,v ...) ,body) #t]
      [(,op ,rands ...) (guard (prim? op)) (andmap simple? rands)]
      [(if ,test ,br1 ,br2) (andmap simple? `(,test ,br1 ,br2))]
      [(let ([,x ,y] ...) ,body) (andmap simple? `(,y ... ,body))]
      [(,rator ,rands ...) #f])))
```

term:
+ tail-form: Firstly, procedure calls always occur at the outermost level of a derivation of the result of a call. Thus the result of any procedure call is the result of the whole expression. A tail-form expression is one in which every subexpression in nontail position is simple.

```lisp
(define tail-form?
  (lambda (expr)
    (match expr
      [(lambda (,v ...) ,body) (tail-form? body)]
      [(,op ,rands ...) (guard (prim? op)) (andmap simple? rands)]
      [(if ,test ,br1 ,br2) (and (simple? test)
                                 (tail-form? br1)
                                 (tail-form? br2))]
      [(let ([,x ,y] ...) ,body) (and (andmap simple? y)
                                      (tail-form? body))]
      [(,rator ,rands ...) (andmap simple? `(,rator ,rands ...))]
      [,x (guard (or (number? x) (symbol? x))) #t])))
```

#### Step2 CPS by hand

The CPS transformation changes the procedure-calling convention so that every procedure takes an extra argument: the continuation to which the answer should be passed.

The transformation may be expressed as follows:
```lisp
    (lambda (x1 ... xn) E) => (lambda (x1 ... xn k) (k E))
```

The four transformation rules for unprocessed expressions of the form (k E), handle four cases. depending on the structure of E.

1. C-simple: If E is simple, we are done processing this k.

examples: 
```lisp
(k (cons 1 2))
(k y)
(k (zero? x))
```

2. c-eta: If E is a application of the form (E1 ... En), where E1, ..., En are all simple, the procedure call is converted to the new protocol by replacing (k E) by (E1 ... En k)

examples: 
```lisp
(k (f 1 2)) => (f 1 2 k)
(k (g (- n 1))) => (g (- n 1) k)
(k (h (zero? x))) => (h (zero? x) k)
```


The remaining two cases are more complicated. In each case, we must find an `innermost` expression to be evaluated first. This is usually an application, in which case we create a call with a new continuation that abstracts the context in which the innermost application appears.

examples:

```lisp
(k (* n (fact (- n 1)))) 
=> (fact (- n 1) (lambda (v) (k (* n v))))
(k (+ (f x) (g y)))
=> (f x (lambda (v) (k (+ v (g y)))))
=> (f x (lambda (v) (g y (lambda (w) (k (+ v w))))))
```

term:
+ initial expression: Given an expression E, its nonsimple subexpression (if any) whose immediate subexpressions in head position are all simple.

examples:
```lisp
(f x y)
(f (+ x y) z)
(if (> x y) (f (g x)) (h (j x)))
```
The last expression is initial expression because it has only one immediate subexpression in head position, (> x y), and it is simple.

Therefore, we search for an initial expression as follows: If the expression E is nonsimple, but all its subexpressions in head position are simple, then the expression is its own initial expression. Otherwise, we recursively search any one of the nonsimple immediate subexpression of E that are in head position.


The following program find one initial expression of a given `expr`
```lisp
; EOPL-1st
(define initial-expr
  (lambda (expr)
    (letrec ([loop (lambda (ls)
                      (cond
                        [(null? ls) expr]
                        [(simple? (car ls)) (loop (cdr ls))]
                        [else (initial-expr (car ls))]))])
      (loop (head-exprs expr)))))
```

It's your time: 
+ define a function `initial-expr-list` to return a list of initial expressions.

Once we find an initial expression, the next step depends on whether or not the initial expression is an application. There are three cases in our target language: 1) the expression itself, 2) application, 3) special form. 

If case 1, then we can apply c-simple if it is simple or c-eta if it is an application or c-special (see later) if it is a special form and we are done.

If case 2, the initial expression is an application, then the application must be performed first. We use a continuation to abstract the context of the application.

examples:
```lisp
(k (h (p x y)))
; initial expression: (p x y)
=> (p x y (lambda (v) (k (h v))))
=> (p x y (lambda (v) (h v k))) ; according to rule2: c-eta

(k (+ (f x) (g y)))
; initial expression: (f x) (g y)
; the order is arbitrary
; (f x) first
=> (f x (lambda (v) (k (+ v (g y)))))
=> (f x (lambda (v) (g y (lambda (w) (k (+ v w))))))
```

It's your time: 
+ cps `(k (+ (f x) (g y)))` with `(g y)` first.

A more complication example:
```lisp
(k (+ (f a b)
      (g (lambda (a k) (k (f a b))))))
```

there are two `(f a b)` in the expression above, but only the first one is initial expression.
```lisp
(k (+ (f a b)
      (g (lambda (a k) (k (f a b))))))
=> (f a b (lambda (v)
            (k (+ v (g (lambda (a k) (k (f a b))))))))
=> (f a b (lambda (v)
            (g (lambda (a k) (k (f a b)))
               (lambda (w) (k (+ v w))))))
=> (f a b (lambda (v)
            (g (lambda (a k) (f a b k))
               (lambda (w) (k (+ v w))))))
```

You may wonder how to distinguith two `(f a b)`, type the following program in scheme REPL.
```lisp
(define a '(+ (f a b) (f a b)))
(eq? (cadr a) (caddr a))   ;=> #f
```

To formalize these operation, we introduce the notion of `positional substitution`. We write {M/X} to denote the position substitution of M at the position of X in E. This means we substitude M for a particular occurence of the subexpression X, not for every occurence. We are now ready to state nornally the third CPS rule.

3. c-app: If (k E) has an initial expression I that is an application (E1, ..., En), replace (k E) by (E1, ..., En (lambda (v) (k E{v/I}))) where v is a previously unused variable.

It's your time: 
+ cps `(k (p (+ 8 x) (q y)))`.
+ Consider the function `positional-substitution` below, which takes two argument, `expr` and `pairs`. `pairs` in a form `((X1 . M1) (X2 . M2)) ...`. It replace `Xi` in `expr` with `Mi`. Write some test to validate your understanding.

```lisp
(define positional-substitution
  (lambda (expr pairs)
    (define helper 
      (lambda (expr)
        (let ([found-pair (assq expr pairs)])
          (if (pair? found-pair)
              (cdr found-pair)
              (match expr
                [(lambda (,x ...) ,body) `(lambda (,x ...) ,(helper body))]
                [(,op ,rands ...) (guard (prim? op)) `(,op ,@(map helper rands))]
                [(if ,test ,br1 ,br2) `(if ,(helper test) ,(helper br1) ,(helper br2))]
                [(let ([,x ,y] ...) ,[body]) `(let ([,x ,(helper y)] ...) ,(helper body))]
                [(,rator ,rands ...) `(,(helper rator) ,@(map helper rands))]
                [,x x])))))
    (helper expr)))
```

If case 3, the initial expression is a special form, then all its head expressions are simple. We have following rules:

```lisp
(k (anycontext (if test b1 b2))) => (if test (k (anycontext br1)) (k (anycontext br2)))
(k (anycontext (let ([b H] ...) body))) => (let ([b H] ...) (k (anycontext body)))
```

There is one further complication. Because special forms, such as let and letrec introduce bindings, we must be careful to avoid avaiable capture. For example, consider
```lisp
(k (g (let ([g 3])
        (f g x))))
=>  ; use c-special
(let ([g 3])
  (k (g (f g x))))
```
This is clearly wrong.

We can use alpha-convention to avoid such a problem.
```lisp
(k (g (let ([g 3])
        (f g x))))
=>  ; use alpha-convention
(k (g (let ([g: 3])
        (f g: x))))
=>  ; use c-special
(let ([g: 3])
  (k (g (f g: x))))
```
We presume that user variable naems do not end with a colon.

Final CPS transformation rule:

+ c-special: If (k E) has an initial expression I with n > 0 expressions in tail position, and b1, ..., bp are the binding variables of I that occur free in E, transform E as follows: 
1. Let I' = I (b1, ..., bp)
2. Then replace (k E) by I' with each tail position expresstion Ti of I' replace by (k E{Ti/I}). 

> Note about occur free.

If a variable `x` occur in a expr `E`, but x is not bound by all the binding form. (such as lambda, let, letrec) Then `x` is said `occur free` in E. 

examples:
```scheme
(lambda (lst) (if (car lst) 1 2))     
; occur free: car
(f x y)
; occur free: f x y
(let ([a (fact 4)])
  (cons a 10))
; occur free: fact cons
```

It's your time: 
+ define a function `free-vars`, takes a argument `E`, return all variables occur free in `E`


Here is the definition of `alpha-convert`

```lisp
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
```

It's your time: 
+ Write some tests for `alpha-convert` to validate your understanding.

#### Step3 CPS exercise

To obtain a feel for the CPS transformation rules, it is necessary to work through a number of examples. 

```scheme
(define remove
  (lambda (s los)
    (if (null? los)
        '()
        (if (eq? s (car los))
            (remove s (cdr los))
            (cons (car los) (remove s (cdr los)))))))
=>
(define remove
  (lambda (s los k)         ; add a k
    (k (if (null? los)      ; wrap the body with k
          '()
          (if (eq? s (car los))
              (remove s (cdr los))
              (cons (car los) (remove s (cdr los))))))))
=>
(define remove
  (lambda (s los k)  
    (if (null? los) 
        (k '())             ; c-special
        (k (if (eq? s (car los))
              (remove s (cdr los))
              (cons (car los) (remove s (cdr los))))))))
=>
(define remove
  (lambda (s los k)  
    (if (null? los) 
        (k '())           
        (if (eq? s (car los))
            (k (remove s (cdr los)))                        ; c-special
            (k (cons (car los) (remove s (cdr los))))))))   ; c-special
=>
(define remove
  (lambda (s los k)  
    (if (null? los) 
        (k '())           
        (if (eq? s (car los))
            (remove s (cdr los) k)                          ; c-eta 
            (remove s (cdr los) 
                (lambda (v) (k (cons (car los) v))))))))    ; c-app
```

CPS the following function. We will use these results to validate our auto-cps program

```scheme
(define subst
  (lambda (new old slst)
    (if (null? slst)
        '()
        (if (symbol? (car slst))
            (if (eq? (car alst) old)
                (cons new (subst new old (cdr slst)))
                (cons (car slst) (subst new old (cdr slst))))
            (cons (subst new old (car slst))
                  (subst new old (cdr slst)))))))

(define remove2
  (lambda (s los)
    (letrec ([loop (lambda (los)
                      (if (null? los) 
                          '()
                          (if (eq? s (car los))
                              (loop (cdr los))
                              (cons (car los) (loop (cdr los))))))])
        (loop los))))

(define depth-with-let
  (lambda (alst)
      (if (null? alst)
         1
         (let ([drest (depth-with-let (cdr alst))])
            (if (pair? (car alst))
                (let ([dfirst (+ (depth-with-let (car alst)) 1)])
                    (if (< dfirst drest) drest dfirst))
                drest)))))
```

consider the definition and use of final-valcont below
```lisp
(define final-valcont
  (lambda (v)
    (display "The answer is: ")
    (write v)
    (newline)))

(remove-cps 'b '(a b c d e) final-valcont)
; The answer is: (a c d e)
```

write some programs:

1. map-cps: the procedure map in CPS. Its first argument msut also be a procedure in CPS.

```lisp
(map-cps
    (lambda (v k) (k (car v))
    '((1 2 3) (a b c) (x y z)))
    final-valcont)
; The answer is: (1 a x)
```
2. add>n: take any list of numbers and a number n as argument. It returns the sum of all numebrs in the list that are greater than n.

see also more exercise in EOPL-1st

#### Step4 Auto-CPS

With all the helper functions and rules above, the implementation of the auto-cps program is obvious.

Firstly, cps will ignore the `define` part, starts with a `lambda` instead.

When transformation a `lambda`, we just add an extra argument (the continuation) to formal parameters and transform the function body.

If `e` is not a lambda, just return it. This will allow us to transform those lambda expressions in head position.

```lisp
(define cps
  (lambda (e)
    (match e
      [(lambda (,x ...) ,body)
        (let ([k (gensym "k")])
          `(lambda (,x ... ,k)
              ,(cps-with-cont body k)))]
      [,x x])))
```

`cps-with-cont` takes a expression and a continuation parameter. This is where our four cps rules will apply.

First of all, what we need to do is to find an initial expression.

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
        ...)))
```

the `initial-expr` can be any expression in our language. Let's start with some simple cases.

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
        [(lambda (,v ...) ,body)
            `(,k ,(cps init))]))))
```
If the initial expression is a `lambda`, recall that lambda is a simple expression, this means that the initial expression must be the same expression as `e`. So we just wrap it with `k`.

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
        [(lambda (,v ...) ,body)
            `(,k ,(cps init))]
        [(,op ,rands ...) (guard (prim? op))
          `(,k (,op ,(map cps rands) ...))]))))
```

If the initial expression is `primtive operation`, then all the rands are already simple. (If there is any rand is not simple, the initial expression would not be this primitive operation but its nonsimple subexpression). We use `cps` to check if there is any `lambda` expression. Finally, we wrap the whole expression with `k`.

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
        [(lambda (,v ...) ,body)
          `(,k ,(cps init))]
        [(,op ,rands ...) (guard (prim? op))
          `(,k (,op ,(map cps rands) ...))]
        [(if ,test ,br1 ,br2)
          (let ([pair1 (list (cons init br1))]
                [pair2 (list (cons init br2))])
            (let ([new-br1 (positional-substitution e pair1)]
                  [new-br2 (positional-substitution e pair2)])
                `(if ,test ,(cps-with-cont new-br1 k) ,(cps-with-cont new-br2 k))))]))))
```
If the initial expression is the special form `if`, we need to drive the context into its two branchs. We do this by replace the `if` expression with its two branch. Then we continue to process the two branches with `k`.

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
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
                      k))])]))))
```
If the initial expression is the special form `let`, to avoid variable capture, we perform `alpha-convert` firstly. Then we drive the context into its body by replacing the `let` expression with its `body` part. After that, we continue to process the body with `k`.

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
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
        [(quote ()) `(,k '())]    ; special
        [(,rator ,rands ...)
          (if (eq? init e)
              `(,rator ,(map cps rands) ... ,k)
              (let* ([v (gensym)]
                    [context (positional-substitution e (list (cons init v)))])
                  `(,rator ,(map cps rands) ... 
                      (lambda (,v)
                        ,(cps-with-cont context k)))))]))))
```
Now, we are ready to process procedure applications. But, as you see, we treat `'()` specially, because `'()` will be expanded into `(quote ())`, which may be recognized wrongly as procedure applications. There are several ways to handle this. We can define a symbol (such as  `(define emtpylist '())`) and replace every `'()` with that symbol. Or we just handle it in our `cps-with-cont` program. So we do not need to make any change to the procedure that will be transformed.

So, if the initial expression is an application, we check if it is the expression itself. If it is, we apply our second rule (c-eta) to transform it. If it is not, we apply our third rule (c-app) to transform it. We do this by replace the initial expression with a value `v` and wrap the whole context in a new lambda expression. We then continue processing the context with `k`.


```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
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
        [(quote ()) `(,k '())]    ; special
        [(,rator ,rands ...)
          (if (eq? init e)
              `(,rator ,(map cps rands) ... ,k)
              (let* ([v (gensym)]
                    [context (positional-substitution e (list (cons init v)))])
                  `(,rator ,(map cps rands) ... 
                      (lambda (,v)
                        ,(cps-with-cont context k)))))]
        [,x (guard (or (number? x) (symbol? x))) `(,k ,x)]))))
```

Finally, if the initial expression is a number or a symbol, we simply wrap it with `k`.


It's your time: 
+ Write some tests for `cps`, `cps-with-cont`.
+ Extend our language with `letrec`, `cond`, `set!` 