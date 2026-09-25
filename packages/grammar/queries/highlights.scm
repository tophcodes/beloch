(comment) @comment
(annotation_key) @annotation
(text) @text
(keyword) @keyword
(point) @point
(point_bracket) @point
(crease) @line
(crease_bracket) @line
(instance) @instance
(number) @number
(operator) @operator
(punct) @punct
(flap_bracket) @punct

(write_statement ["mark" "fold" "reverse" "flatten" "flip"] @keyword)
["(" ")" "[" "]"] @punct
(construction    ["align" "map" "through" "perp" "onto" "and"] @construction)
; the same word and the same job as the selection item, so the same colour
(construction    "toward" @selection)
(alignment       ["onto" "through" "perp"] @alignment)
(anchor_item     "moving" @anchor)
(depth_item      ["up" "to"] @depth)
(placement_item  ["over" "under"] @placement)
(kind_item       "outside" @kind)
(intent_item     ["mountain" "valley"] @intent)
(axis_item       ["mountain" "valley"] @intent)
(extent_item     ["between" "at"] @extent)
(layer_item      "on" @layer)
(flatten_element ["mountain" "valley"] @ray)
(order_item      "over" @order)
(stayer_item     "staying" @stayer)
(selection_item  "toward" @selection)
(output_clause   ["as" "into" "!"] @output)
