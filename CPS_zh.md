### Auto-CPS: A four-hour course.
四小时 CPS 教程。

这份教程试图说明什么是 CPS，以及如何写一个自动 CPS 变换的程序，其内容依据 EOPL-1st 第八章。我所做的，仅仅是对 EOPL-1st 的内容进行了组织，没有什么原创。如果你有所收获，那完全归功于你的努力和 Daniel Friedman 的善巧。

实际上我更推荐你直接去读 EOPL-1st，在[这里](https://github.com/siriusdemon/auto-cps)有其扫描版。

关于自动 CPS 变换，王垠曾在他的博客[GTF - Great Teacher Friedman](http://www.yinwang.org/blog-cn/2012/07/04/dan-friedman)这样写道：

> 第二个学期，当我去上 Friedman 的进阶课程 B621 的时候，他给我们出了同样的题目。两个星期下来，没有其它人真正的做对了。最后他对全班同学说：“现在请王垠给大家讲一下他的做法。你们要听仔细了哦。这个程序价值100美元！”

>下面就是我的程序对于 lambda calculus 的缩减版本。我怎么也没想到，这短短 30 行代码耗费了很多人 10 年的时间才琢磨出来。

```scheme
(define cps
  (lambda (exp)
    (letrec
        ([trivs '(zero? add1 sub1)]
         [id (lambda (v) v)]
         [C~ (lambda (v) `(k ,v))]
         [fv (let ((n -1))
               (lambda ()
                 (set! n (+ 1 n))
                 (string->symbol (string-append "v" (number->string n)))))]
         [cps1
          (lambda (exp C)
            (pmatch exp
              [,x (guard (not (pair? x))) (C x)]
              [(lambda (,x) ,body)
               (C `(lambda (,x k) ,(cps1 body C~)))]
              [(,rator ,rand)
               (cps1 rator
                     (lambda (r)
                       (cps1 rand
                             (lambda (d)
                               (cond
                                [(memq r trivs)
                                 (C `(,r ,d))]
                                [(eq? C C~)         ; tail call
                                 `(,r ,d k)]
                                [else
                                 (let ([v* (fv)])
                                   `(,r ,d (lambda (,v*) ,(C v*))))])))))]))])
      (cps1 exp id))))
```

### 内容组织

+ CPS 简介
+ CPS 转换规则
+ CPS 手动转换
+ CPS 自动转换程序

在你真正要开始阅读之前，建议你计时，然后看看你完全掌握这些内容共花了多少时间。计时没有别的意味，我只是希望你别跳过里面的练习。

#### 1. CPS 简介

CPS，全称 (continuation pass style) 续延传递风格，以这种风格写出来的函数，并不直接返回它的值，而是把它的值传递给它后续的函数。

比如，一个普通的函数及其调用。
```scheme
(define add
  (lambda (a b)
    (+ a b)))
(display (add 1 2))
(sub1 (add 1 2))
```
`add`返回计算结果，`display`进行显示，`sub1`进行减1。这是我们通常的写法。

如果用 CPS，就会是这样
```scheme
(define add-cps
  (lambda (a b k)
    (k (+ a b))))
(add-cps 1 2 display)
(add-cps 1 2 sub1)
```
在 `add-cps` 中，后续要执行的函数直接传递到了函数内部。

CPS 的作用是将所有函数都转换成尾调用的格式。

比如
```scheme
(define fact
  (lambda (n)
    (if (= n 0)
        1)
        (* n (fact (- n 1)))))
```
写成 CPS 就是
```scheme
(define fact-cps
  (lambda (n k)
    (if (= n 0)
        (k 0)
        (fact (- n 1) (lambda (v) (k (* n v)))))))
```

这部分可以看看 EOPL-1st 8.1 8.2 的内容。

#### 2. CPS 转换规则

在学习转换规则之前，首先要明确我们要转换的程序都有哪些结构。比如仅是对 lambda calculus 转换，还是对 scheme 程序转换。为了简单且不失实用，我们的目标语言介于两者之间：

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

术语：
+ 首位置（head position）：给定一个表达式，在得到整个表达式的结果之前，必须先进行求值的子表达式，处于首位置。
+ 尾位置（tail position）：给定一个表达式，如果它的子表达式的值同时作为整个表达式的值，则这些表达式处于尾位置。

就我们的目标语言来说，就是
```lisp
(lambda (v ... v) E)
(prim H ... H)
(H ... H)   ; application
(if H T T)
(let ([b H] ...) T)
```
其中`H`表示首位置，`T`表示尾位置，`v`是指函数的参数。`b`是绑定的变量。`E`表示 lambda 语句的主体，既不属于`H`也不属于`T`。

下面的函数，接受一个表达式，返回其所有处于尾位置的子表达式。

```lisp
(define tail-exprs
  (lambda (expr)
    (match expr
      [,x (guard (or (number? x) (symbol? x) (null? x))) '()]
      [(lambda (,v ...) ,body) '()]
      [(,op ,rands ...) (guard (prim? op)) '()]
      [(if ,test ,br1 ,br2) `(,br1 ,br2)]
      [(let ([,x ,y] ...)  ,body) `(,body)]
      [(,rator ,rands ...) '()]
      )))
```
> 注意；这里使用了 match，是 P523 中的 match.ss

*轮到你了*
+ 写一个函数，`head-exprs`, 接受一个参数 `expr`, 返回其所有处于首位置的子表达式。
+ 写一个函数，`binding-vars`, 接受一个参数 `expr`, 返回其所有的绑定变量。（注意，只有 `let` 有绑定变量）

术语：
简单表达式（simple expr）：简单表达式不能是函数调用；如果一个表达式的所有子表达式都是简单表达式，则该表达式也是简单表达式。lambda 表达式，数字，空列表和符号都是简单表达式。


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

*轮到你了*
+ 以下的表达式是简单表达式吗？在 scheme 中验证你的想法。
```scheme
  (simple? '(car x))
  (simple? '(if p x (car (cdr x))))
  (simple? '(f (car x)))
  (simple? '(car (f x)))
  (simple? '(if p x (f (cdr x))))
  (simple? '(if (f x) x (f (cdr x))))
  (simple? '(lambda (x) (f x)))
  (simple? '(lambda (x) (car (f x))))
```


要进行 CPS 转换，首先要给每个函数调用都加上一个额外的参数，即要接收函数调用结果的续延。
这个变换可以这样表示：
```lisp
    (lambda (x1 ... xn) E) => (lambda (x1 ... xn k) (k E))
```

为了进一步处理 `(k E)`，根据 E 的内容，有四种规则。

1. c-simple：如果 E 是一个简单表达式，则不需要再进一步处理。

例如：
```lisp
(k (cons 1 2))
(k y)
(k (zero? x))
```

2. c-eta：如果 E 是一个函数调用，(E1 ... En)，且 (E1 ... En) 全都是简单表达式，(k E) 变换为 (E1 ... En k)

例如：
```lisp
(k (f 1 2)) => (f 1 2 k)
(k (y)) => (y k)
```

剩下的两个场景稍微复杂一些。我们需要寻找一个最先被求值的表达式`I`（通常一个函数调用），称为初始表达式（initial expression），我们把初始表达式`I`提到最前，并为它分配一个新的续延，这个续延的参数表示初始表达式的值`v` ，续延的函数体中封装原来的表达式，并将原来表达式中的初始表达式`I`的位置用它的值`v`替代。

请仔细思考以下例子
```lisp
(k (* n (fact (- n 1)))) 
=> (fact (- n 1) (lambda (v) (k (* n v))))
(k (+ (f x) (g y)))
=> (f x (lambda (v) (k (+ v (g y)))))
=> (f x (lambda (v) (g y (lambda (w) (k (+ v w))))))
```

术语：
+ 初始表达式：给定个表达式 E，如果它存在某个非简单子表达式 NS，NS 的首位置表达式全是简单表达式，则 NS 称为 E 的一个初始表达式。NS 可以等于 E 本身。（类似子集的概念，集合 A 可以是自己的子集）

以下例子都是初始表达式：

```lisp
(f x y)
(f (+ x y) z)
(if (> x y) (f (g x)) (h (j x)))
```
最后一个表达式是初始表达式，因为它的首位置是 `(> x y)`，是一个简单表达式。

搜索初始表达式的算法是这样子的：如果表达式 E 不是简单表达式，但它的所有首位置表达式都是简单的，则这个表达式 E 本身是初始表达式。否则，则它至少有一个处于首位置的非简单表达式 SE，我们递归处理 SE 来获取 E 的初始表达式。

以下函数可以找到给定表达式的*一个*初始表达式：
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

*轮到你了*
+ 写一个函数 `initial-expr-list`，返回一个表达式中所有的初始表达式。


一旦我们找到了一个初始表达式，下一步变换取决于初始表达式的内容。它可以是: 1）一个函数调用 2）一个 special form。

如果是一个函数调用，要进一步判断，这个初始表达式是不是它本身？如果是，则应用 c-eta，如果不是，我们则必须将之提前，并创建一个新的续延来封装原来的表达式。

请思考以下的例子：
```lisp
(k (h (p x y)))
; initial expression: (p x y)
=> (p x y (lambda (v) (k (h v))))
; initial expression: (h v)
=> (p x y (lambda (v) (h v k))) ; according to rule2: c-eta

(k (+ (f x) (g y)))
; initial expression: (f x) (g y)
; the order is arbitrary
=> (f x (lambda (v) (k (+ v (g y)))))
=> (f x (lambda (v) (g y (lambda (w) (k (+ v w))))))
```


*轮到你了*

+ 对表达式`(k (+ (f x) (g y)))`进行 cps 变换，首先处理 `(g y)`。

一个更复杂的示例：
```lisp
(k (+ (f a b)
      (g (lambda (a k) (k (f a b))))))
```
有两个 `(f a b)`，但只有第一个是初始表达式。

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
在 `scheme` 中，以上两个 `(f a b)` 也是不相等的 (eq?)。试执行以下代码
```scheme
(define a '(+ (f a b) (f a b)))
(eq? (cadr a) (caddr a))   ;=> #f
```

为了公式化上述的操作，我们引入一个术语：位置性替换(positional substitution)。我们用 E{M/X}表示：在表达式 E 中，使用 M 代入 X 的位置。我们只替换某个位置上的 X，而不是所有的 X。我们将第三条规则总结如下：

3. c-app：如果 (k E) 有一个初始表达式 I，且 I 是一个函数调用 (E1 ... En)。则 (k E) 替换为 (E1 ... En (lambda (v) (k E{v/I})))。其中 v 是一个未被使用过的变量。


*轮到你了*
+ 对 `(k (p (+ 8 x) (q y)))` 进行 cps 变换。
+ 思考以下定义的函数 `positional-substitution`，它有两个参数 `expr`，`pairs`。其中的`pairs` 格式为 `((X1 . M1) (X2 . M2) ...)`。函数的功能是，将 `expr` 中的 `Xi` 替换成对应在的 `Mi`。请写一些用例来验证你的理解。

```lisp
; EPOL-1st chapter 8
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

如果初始表达式是一个 special form，根据我们的语言，有以下变换规则

```lisp
(k (anycontext (if test b1 b2))) => (if test (k (anycontext br1)) (k (anycontext br2)))
(k (anycontext (let ([b H] ...) body))) => (let ([b H] ...) (k (anycontext body)))
```

这里还有一点麻烦的。因为像 let 这样的 form 可以绑定变量，所以我们必须进行变量重名。例如，以下的变换是明显错误的：
```lisp
(k (g (let ([g 3])
        (f g x))))
=>  ; use c-special
(let ([g 3])
  (k (g (f g x))))
```
我们可以使用 alpha 变换来避免这样的问题。假设用户输入的变量不能带有冒号，则我们可以通过给绑定的变量加一个冒号后缀来避免变量捕获。
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

由此我们有最后一条转换规则：

4. c-special: 如果 (k E) 有一个初始表达式 I，且 b1, ..., bp 是 I 的绑定变量，我们做以下变换
    1. 对 I 进行 alpha 变换得到 I'
    2. 对于 (k E) 中每一处于尾位置的子表达式 Ti，用 (k E{Ti/I}) 代入。

以下是 alpha 变换的定义。


```scheme
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

*轮到你了*
+ 为 `alpha-convert` 写一些调用示例来验证你的理解。

#### CPS 手动转换

为了加深对以上规则有理解，做一些手动转换的练习是有必要的。

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

请做以下的练习：

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

请思考以下`final-valcont`的定义和使用

```lisp
(define final-valcont
  (lambda (v)
    (display "The answer is: ")
    (write v)
    (newline)))

(remove-cps 'b '(a b c d e) final-valcont)
; The answer is: (a c d e)
```

写几个程序：

1. map-cps：map 的 cps 版本，它的第一个参数也必须是一个用 cps 风格的函数。

```lisp
(map-cps
    (lambda (v k) (k (car v))
    '((1 2 3) (a b c) (x y z)))
    final-valcont)
; The answer is: (1 a x)
```

2. add>n：接受一个数字列表和一个数字ｎ，返回所有列表中大于ｎ的数字之和。

EOPL-1st 有更多练习，有需要者请参阅。

#### 自动 CPS 变换

有了以上基础，实现自动 CPS 变换已经相当直观了。你应该给自己一个机会！

<details>
  <summary>继续阅读</summary>

首先，我们的程序会忽略 `define` 语句，从 `lambda` 表达式开始。

当变换一个 lambda 时，我们只需要为它添加一个新的参数（表达它的续延），然后使用这个续延来对函数体进行变换。

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
这里，如果输入不是一个 lambda，我们不作任何处理。这样做的好处是，我们可以对处于首位置的 lambda 表达式进行处理。

`cps-with-cont` 接受一个表达式 E 以及它的续延 k，这等同于我们在处理 (k E)。那么，有四种情况。

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
        ...)))
```
我们首先计算初始表达式 init，对 init 分类处理。

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
        [(lambda (,v ...) ,body)
            `(,k ,(cps init))]))))
```
如果是 `lambda` 表达式，因为 `lambda` 本身也是简单表达式，这就说明 init 必定跟 e 相同。因此，我们只需要使用 k 来封装整个表达式，同时用 cps 处理 init 即可。


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
如果初始表达式是一个原生（primitive）操作。我们也同样使 ｋ 封装整个表达式，并用 cps 处理其参数。

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

如果初始表达式是一个 if 语句，则使用 c-special 规则。如果你对 `positional-substitution`写过测试，以上程序对你应该不难理解。


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

如果初始表达式是一个 `let`，则首先进行重命名，接着处理其主体。

接着，我们一鼓作气完成 `cps-with-cont`

```scheme
(define cps-with-cont
  (lambda (e k)
    (let ([init (initial-expr e)])
      (match init
        [,x (guard (or (number? x) (symbol? x))) `(,k ,x)]
        [(quote ()) `(k '())]
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
```

你会注意到，在 match 之后新增了两条规则。一条处理数字和符号，一条处理空列表。空列表放在前面是有必要的。因为它会被 scheme 的 parser 展开成 quote，而 quote 看起来像一个函数调用。但我们只想把空列表当成一个常量来处理。因此，有两种策略。一是像上面的，增加一条规则处理空列表，二是用一个符号取代空列表（如 `(define emtpylist '())`）。这里采用第一种，因为这样不需要修改那些要用来进行 cps 变换的函数。

好了，现在我们分析处理函数调用的情况。

首先，我们判断这个初始表达式是否为它本身，如果是，则应用 c-eta。否则，我们将初始表达式提到最前，用它的值 `v` 取代它原来在 `e` 中的位置，并继续进行处理。

至此，我们的自动 cps 转换程序已经完成了。

*轮到你了*
+ 为 `cps`, `cps-with-cont` 写一些调用示例。
+ 拓展我们的目标语言，依次新增 `letrec`, `cond`, `set!`, `begin`。这时候可以去读一读 EOPL 的相关内容。

如果你一开始有计时，现在应该检查一下花了多少时间。

</details>

验证你是否掌握了本教程的内容的方法：回头看看一开始的王垠的程序，那个程序实现的 CPS 比教程中实现的还要简单，因此，你应该能够完全理解。否则，那一定我的教程没写好……建议去看 EOPL……

如果你学习的效果已达标，可以看看以下链接列出的程序。

+ [王垠的40行代码](https://www.zhihu.com/question/20822815/answer/23890076)