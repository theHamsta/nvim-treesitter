;; TODO: supported by official Tree-sitter  if (_)* is more than one node
;; Neovim: will only match if (_) is exactly one node
;(function_definition
  ;body:  (compound_statement
                          ;("{" (_)* @function.inner "}"))?) @function.outer

((function_definition
  body:  (compound_statement) @function.inner) @function.outer
 (strip! @function.inner "(^\{?\s*)|(\s*\}?$)" "\s*"))

((struct_specifier
  body: (_) @class.inner) @class.outer
 (strip! @class.inner "(^\{?\s*)|(\s*\}?$)" "\s*"))

; conditional
((if_statement
  consequence: (_)? @conditional.inner
  alternative: (_)? @conditional.inner
  ) @conditional.outer
 (strip! @conditional.inner "(^\{?\s*)|(\s*\}?$)" "\s*"))

((if_statement
  condition: (_) @conditional.inner)
 (strip! @conditional.inner "(^\{?\s*)|(\s*\}?$)" "\s*"))

; loops
((for_statement 
  (_)? @loop.inner) @loop.outer
 (strip! @loop.inner "(^\{?\s*)|(\s*\}?$)" "\s*"))
((while_statement
  (_)? @loop.inner) @loop.outer
 (strip! @loop.inner "(^\{?\s*)|(\s*\}?$)" "\s*"))
((do_statement
  (_)? @loop.inner) @loop.outer
 (strip! @loop.inner "(^\{?\s*)|(\s*\}?$)" "\s*"))


(compound_statement) @block.outer
((compound_statement) @block.inner
  (strip! @block.inner "(^\{?\s*)|(\s*\}?$)" "\s*"))
(comment) @comment.outer

((comment) @comment.inner
  (strip! @comment.inner "(^((//)|(/\*))\s*)|(\s*\*/$)" "\s*"))

(call_expression) @call.outer
(call_expression (_) @call.inner)

; Statements

;(expression_statement ;; this is what we actually want to capture in most cases (";" is missing) probaly 
  ;(_) @statement.inner) ;; the otther statement like node type is declaration but declaration has a ";"

(compound_statement
  (_) @statement.outer)

(field_declaration_list
  (_) @statement.outer)

(preproc_if
  (_) @statement.outer)

(preproc_elif
  (_) @statement.outer)

(preproc_else
  (_) @statement.outer)
