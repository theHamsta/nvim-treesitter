[
  "enum"
  "return"
  "public"
  "private"
] @keyword

[
  "while"
  "for"
 ;"do"
  ;"continue"
  ;"break"
] @repeat

[
 "if"
 "else"
 "case"
 "switch"
 "default"
] @conditional

;[
  ;;"="

  ;;"-"
  ;;"*"
  ;;"/"
  ;;"+"
;;  "%"
  ;;"?"

  ;;"~"
  ;;"|"
  ;;"&"
  ;;"^"
  ;;"<<"
  ;;">>"

  ;;"<"
  ;;"<="
  ;;">="
  ;;">"
  ;;"=="
  ;;"!="

  ;;"!"
  ;;"&&"
  ;;"||"

;] @operator

[
 ;"try"
 "throws"
] @exception

[":"] @punctuation.delimiter

[(standard_type)] @type
