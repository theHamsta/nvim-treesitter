; inherits: (jsx)

; Scopes
;-------

(statement_block) @scope
(function) @scope
(arrow_function) @scope
(function_declaration) @scope
(method_definition) @scope
(for_statement) @scope
(for_in_statement) @scope
(catch_clause) @scope

; Definitions
;------------

(variable_declarator
  name: (identifier) @definition.var)

(import_specifier
  (identifier) @definition.import)

(namespace_import
  (identifier) @definition.import)

(function_declaration
  ((identifier) @definition.var)
   (#set! definition.var.scope parent))

; References
;------------

(identifier) @reference
(shorthand_property_identifier) @reference
(required_parameter (identifier) @definition.parameter)
(optional_parameter (identifier) @definition.parameter)
