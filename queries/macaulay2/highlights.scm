; Comments
(line_comment) @comment
(block_comment) @comment

; Literals
(integer_literal) @number
(float_literal) @number.float
(exp_missing) @comment.error
(p_missing) @comment.error
(string_literal) @string
(escape_sequence) @string.escape
(boolean_literal) @boolean
(symbol) @variable

(locality_operator
  symbol: (resolved_symbol) @variable)

(builtin_constant) @constant.builtin

; Operators
(_ operator: _ @operator)


; Brackets
"(" @punctuation.bracket
")" @punctuation.bracket
"[" @punctuation.bracket
"]" @punctuation.bracket
"{" @punctuation.bracket
"}" @punctuation.bracket
"<|" @punctuation.bracket
"|>" @punctuation.bracket

; Delimiters
"," @punctuation.delimiter
";" @punctuation.delimiter

; Keywords
(if_statement "if" @keyword.conditional)
(if_statement "else" @keyword.conditional)
"then" @keyword.conditional
"for" @keyword.repeat
"while" @keyword.repeat
"return" @keyword.return
"break" @keyword.return
"continue" @keyword.return
"new" @keyword
"in" @keyword.repeat
"of" @keyword
"from" @keyword.repeat
"to" @keyword.repeat
"list" @keyword
"do" @keyword
"when" @keyword.conditional
"try" @keyword.exception
"catch" @keyword.exception
"throw" @keyword.exception
"global" @keyword.modifier
"local" @keyword.modifier
"symbol" @keyword.modifier
"threadVariable" @keyword.modifier
"threadLocal" @keyword.modifier
"time" @keyword.debug
"timing" @keyword.debug
"elapsedTime" @keyword.debug
"elapsedTiming" @keyword.debug
"profile" @keyword.debug
"shield" @keyword.exception
"TEST" @keyword.debug
"breakpoint" @keyword.debug
"and" @keyword.operator
"or" @keyword.operator
"xor" @keyword.operator
"not" @keyword.operator



; f x
(binary_expression
  left: (symbol) @function.call
  operator: (space))

; f_1 x
((binary_expression
   left: (binary_expression
           left: (symbol)
           operator: "_") @function.call
   operator: (space))
 (#set! priority 101))


; x -> expression
(function_expression
  parameters: (symbol) @variable.parameter)

; (x, y) -> ...
; (x) -> ...
; () -> ...
(function_expression
  parameters: (sequence 
                (symbol) @variable.parameter))


(function_expression
  parameters: (list 
                (symbol) @variable.parameter))

; f := x -> x
(assignment_expression
  left: (symbol) @function
  right: (function_expression))

(assignment_expression
  left: (symbol) @function
  right: (option_attachment 
           left: [(list
                   (option_assignment 
                     left: (symbol) @variable.member))
                  (symbol)]
           right: (function_expression
                    parameters: (symbol) @variable.member)))

(binary_expression
  operator: ["." ".?"] 
  right: (symbol) @variable.member)

; Options / Properties
(option_assignment
  left: (symbol) @property)

(binary_expression
  operator: (space)
  right: (sequence
           (option_assignment
             left: (symbol) @variable.member)))

(binary_expression
  left: (_) @type
  operator: (space)
  right: (array))



(array
  (option_assignment
    left: (symbol) @variable.parameter
    right: _ @variable.member))


; Types
(new_statement
  type: (_) @type
  (of_clause (_) @type)) 

(new_statement
  (from_clause "from" @keyword)) 

; Method Installations
; ZZ + ZZ := add
((assignment_expression
   left: (binary_expression
           left: (_) @type
           operator: _ @constructor
           right: (_) @type)
   operator: ["=" ":="] @constructor)
 (#not-any-of? @constructor "." ".?" "#" "_"))



; Method Installations
; f ZZ := add
((assignment_expression
   left: (binary_expression
           left: (symbol) @constructor
           operator: (space) 
           right: (symbol) @type))
 (#match? @constructor "[a-z].*"))

; Method Installations 
; ZZ ZZ := add
((assignment_expression
   left: (binary_expression
           left: (symbol) @constructor
           operator: (space) 
           right: (symbol) @type))
 (#match? @constructor "[a-z].*"))

; x_1 := 2   -- NOT installation
; A _ B := (x, y) -> x*y    -- closure as value: INSTALLATION
; A, B :: @type 
; _, := :: @constructor
(assignment_expression
  left: (binary_expression
          left: (_) @type
          operator: "_" @constructor
          right: (_) @type)
  operator: ["=" ":="] @constructor
  right: (function_expression))

; A op B := Y => f  -- specifying typical codomain as Y
(assignment_expression
  left: [(binary_expression) (prefix_expression) (postfix_expression)]
  right: (option_assignment
           left: (symbol) @type
           operator: "=>" @constructor))


; f ZZ := g
(assignment_expression
  left: (binary_expression
          left: (symbol) @constructor
          operator: (space)
          right: (sequence
                   "(" @constructor
                   [(symbol) @type
                             "," @constructor]*
                   ")" @constructor))
  operator: ["=" ":="] @constructor)


; ZZ ZZ := g


; - ZZ := x -> -x
(assignment_expression
  left: (prefix_expression
          operator: _ @constructor
          operand: (symbol) @type))

; ZZ ! := n -> if n > 0 then n*(n-1)! else 1
(assignment_expression
  left: (postfix_expression
          operand: (symbol) @type
          operator: _ @constructor)
  operator: ["=" ":="] @constructor)

((binary_expression
   left: (symbol) @function.builtin
   operator: (space)
   right: (sequence
            (locality_operator) .
            (_) @type .
            (_) @type))
 (#eq? @function.builtin "installAssignmentMethod"))


; ZZ ! := n -> if n > 0 then n*(n-1)! else 1
(assignment_expression
  left: (new_statement
          "new" @constructor
          (of_clause 
            "of"? @constructor)?
          (from_clause
            "from" @constructor
            [(symbol) @type
                      (sequence (symbol) @type)])?
)
  operator: ":=" @constructor)



; Builtin variables
((symbol) @variable.builtin
          (#match? @variable.builtin "^((o[1-9][0-9]*)|oo|ooo|oooo)$"))

((symbol) @variable.builtin
          (#any-of? @variable.builtin "allowableThreads" "debugLevel" "defaultPrecision" "engineDebugLevel" "errorDepth" "gbTrace" 
           "interpreterDepth" "lineNumber" "loadDepth" "maxAllowableThreads" "maxExponent" "minExponent" "numTBBThreads" 
           "printingAccuracy" "printingLeadLimit" "printingPrecision" "printingTimeLimit" "printingTrailLimit" 
           "printWidth" "recursionLimit" "typicalValues"))
; Special function args

(binary_expression
  left: (symbol) @function.builtin
  operator: (space)
  right: (sequence 
           (symbol) @type .)
  (#eq? @function.builtin "instance"))

(binary_expression
  left: (symbol) @function.builtin
  operator: (space)
  right: [(sequence 
            (symbol) @type)
          (symbol) @type]
  (#eq? @function.builtin "parent"))





; Special strings (URL/Regexp helpers)
((string_literal) @string.special.url
                  (#match? @string.special.url "^http[s]?://.*"))

((string_literal) @string.special.url
                  (#match? @string.special.url "^www\\..*"))

((binary_expression
   left: (symbol) @function.builtin
   operator: (space)
   right: [(string_literal) @string.special.url
                            (sequence . (string_literal) @string.special.url)])
 (#any-of? @function.builtin "splitWWW" "getWWW" "urlEncode"))

((binary_expression
   left: (symbol) @function.builtin
   operator: (space)
   right: [(string_literal) @string.regexp
                            (sequence . (string_literal) @string.regexp)])
 (#any-of? @function.builtin "match" "regex" "select"))

((binary_expression
   left: (symbol) @function.builtin
   operator: (space)
   right: (sequence 
            (string_literal) @string.regexp 
            (string_literal) @string.special
            (_)))
 (#eq? @function.builtin "replace"))



((binary_expression
   left: (symbol) @function.builtin
   operator: (space)
   right: (sequence 
            (string_literal) @string.regexp
            (_)+))
 (#eq? @function.builtin "separate"))


; packages
((binary_expression
   left: (symbol) @function.builtin
   operator: (space)
   right: [(symbol) @module.builtin
                    (sequence . (symbol) @module.builtin)
                    (string_literal) @string.special
                    (sequence . (string_literal) @string.special)])
 (#any-of? @function.builtin "loadPackage" "installPackage" "uninstallPackage" "needsPackage" 
  "export" "endPackage" "newPackage" "importFrom" "exportFrom"))

((binary_expression
   left: (symbol) @function.builtin
   operator: "_"
   right: (symbol) @module.builtin)
 (#any-of? @function.builtin "importFrom" "exportFrom")
)
