; 1. Start indentation for the entire node when it spans multiple lines
[
  (sequence)
  (list)
  (array)
  (angle_bar_list)
] @indent.begin

; 2. Dedent the closing bracket ONLY (so it aligns with the opener)
(sequence ")" @indent.end)
(list "}" @indent.end)
(array "]" @indent.end)
(angle_bar_list "|>" @indent.end)
