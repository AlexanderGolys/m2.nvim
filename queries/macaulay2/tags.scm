; Function Definitions
(assignment_expression
  left: (symbol) @name
  operator: [":=" "="]
  right: (function_expression)) @definition.function

; Function with options (e.g., f = opts >> o -> x -> ...)
(assignment_expression
  left: (symbol) @name
  operator: [":=" "="]
  right: (option_attachment
           right: (function_expression))) @definition.function

(assignment_expression
  left: (symbol) @name
  operator: [":=" "="]
  right: (binary_expression
           left: (function_expression))) @definition.function

; Variable Definitions
(assignment_expression
  left: (symbol) @name
  operator: [":=" "="]) @definition.variable

; Method calls (for reference tracking)
(binary_expression
  left: (symbol) @name
  operator: (space)) @reference.call

(binary_expression
  left: (binary_expression
          left: (symbol) @name
          operator: "_")
  operator: (space)) @reference.call
