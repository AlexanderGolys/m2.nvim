; extends

(fenced_code_block
  (info_string (language) @_m2_language)
  (code_fence_content) @injection.content
  (#any-of? @_m2_language "m2" "macaulay2")
  (#set! injection.language "macaulay2")
  (#set! injection.include-children))
