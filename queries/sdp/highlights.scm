[
 (port_number)
 (number_of_ports)
 (number)
 (format)
 (sess_id)
 (sess_version)
 (time)
] @number

[
 ":"
] @punctuation.delimiter

[
 "v="
 "s="
 "o="
 "i="
 "b="
 "r="
 "t="
 "z="
 "c="
 "k="
 "e="
 "p="
 "a="
 "m="
 (attribute_name)
] @field

[
  (username)
  (attribute_value)
  (media_type)
  (proto)
  (line_value)
] @string

[
 (nettype)
 "IP4"
 "IP6"
] @keyword

(ip) @text.uri
