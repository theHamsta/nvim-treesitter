(identifier) @variable

[
  (triple_string)
  (string)
] @string

(string
  prefix: (identifier) @constant.builtin)

(macro_identifier) @function.macro
(macro_identifier (identifier) @function.macro) ; for any one using the variable highlight
(macro_definition
  name: (identifier) @function.macro
  ["macro" "end" @keyword])

(function_definition
  name: (identifier) @function)
(call_expression
  (identifier) @function)
(call_expression
  (field_expression (identifier) @method))
(broadcast_call_expression
  (identifier) @function)
(broadcast_call_expression
  (field_expression (identifier) @method))
(parameter_list
  (identifier) @parameter)
(parameter_list
  (optional_parameter .
    (identifier) @parameter))
(typed_parameter
  (identifier) @parameter
  (identifier) @type)
(typed_parameter
  (identifier) @parameter
  (parameterized_identifier) @type)
(function_expression
  . (identifier) @parameter)
(argument_list
  (typed_expression
    (identifier) @parameter
    (identifier) @type))

(type_argument_list
  (identifier) @type)
;((identifier) @type
;  (match? @type "^[A-Z]"))
(typed_expression
  (identifier) @variable
  (identifier) @type)

(field_expression
  (identifier)
  (identifier) @field)

(number) @number
(range_expression
    (identifier) @number
      (match? @number "end"))
(range_expression
  (_
    (identifier) @number
      (match? @number "end")))
(coefficient_expression
  (number)
  (identifier) @constant.builtin)

;[;
    ;(power_operator);
    ;(times_operator);
    ;(plus_operator);
    ;(arrow_operator);
    ;(comparison_operator);
    ;(assign_operator);
;] @operator ;

"end" @keyword

(if_statement
  ["if" "end"] @conditional)
(elseif_clause
  ["elseif"] @conditional)
(else_clause
  ["else"] @conditional)
(ternary_expression
  ["?" ":"] @operator)

(function_definition ["function" "end"] @keyword.function)

(comment) @comment

[
  "const"
  "return"
  "macro"
] @keyword

(compound_expression
  ["begin" "end"] @keyword)
(try_statement
  ["try" "end" ] @exception)
(finally_clause
  "finally" @exception)
(quote_statement
  ["quote" "end"] @keyword)
(let_statement
  ["let" "end"] @keyword)
(for_statement
  ["for" "end"] @repeat)
(while_statement
  ["while" "end"] @repeat)
(for_binding
  "in" @repeat)
(for_clause
  "for" @repeat)

(export_statement
  ["export"] @include)

[
  "using"
  "module"
  "import"
] @include

(((identifier) @constant.builtin) (match? @constant.builtin "^(nothing|Inf|NaN)$"))
(((identifier) @boolean) (eq? @boolean "true"))
(((identifier) @boolean) (eq? @boolean "false"))

