
((class_specifier
  body: (_) @class.inner) @class.outer
 (strip! @class.inner "(^\{?\s*)|(\s*\}?$)"))

((for_range_loop 
  (_)? @loop.inner) @loop.outer
 (strip! @loop.inner "(^\{?\s*)|(\s*\}?$)"))
