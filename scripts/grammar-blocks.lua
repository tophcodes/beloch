-- Grammar fragments of spec/BELOCH.md, pandoc side.
--
-- The parse is shared with the docs site through _build/grammar.json
-- (scripts/grammar-register.ts writes it; BELOCH_GRAMMAR_REGISTER overrides the
-- path). This filter renders and nothing else, so the PDF and the page carry
-- the same rules in the same order.
--
-- The rendering is duplicated rather than shared, because the typst writer
-- needs a different tree: a Code with a class becomes
-- `#raw(lang:"gr-keyword", "…")`, which preserves internal spacing and carries
-- the class as a language for scripts/typst-compat.typ to colour, and the
-- writer drops the id of a Code. So a rule becomes a Div of class
-- grammar-block holding one Para, one Code per span, pandoc.LineBreak between
-- lines; a nonterminal is wrapped in a Link, which the writer emits as
-- `#link(<rule-axis>)`, and a defining name in a Span carrying the id, which
-- the writer emits as the label `<rule-fold_item>`.
--
-- typst refuses a link to a label that does not exist and a link to a label
-- that occurs twice, which is why ids live at the definition site only and the
-- external entries carry ids of their own.
--
-- A count mismatch between the document's grammar blocks and the register's
-- fragments means the register is stale: the block is left verbatim and the
-- filter warns. A missing or unreadable register warns the same way, rather
-- than leaving the blocks verbatim in silence, whenever the document has a
-- grammar block to render.
--
-- packages/www/src/lib/remark-grammar.ts is the docs-site counterpart.

local root = (PANDOC_SCRIPT_FILE or ""):match("^(.*)/scripts/[^/]+$") or "."

local entry = nil
local fragment_index = 0

local function load_register()
  local path = os.getenv("BELOCH_GRAMMAR_REGISTER") or (root .. "/_build/grammar.json")
  local file = io.open(path, "r")
  if not file then return nil end
  local ok, decoded = pcall(pandoc.json.decode, file:read("a"), false)
  file:close()
  if not ok or type(decoded) ~= "table" or type(decoded.documents) ~= "table" then return nil end
  return decoded
end

local function entry_for(register, path)
  if not register then return nil end
  for _, document in ipairs(register.documents) do
    if path == document.path or path:sub(-#document.path - 1) == "/" .. document.path then
      return document
    end
  end
  return nil
end

local function stale()
  io.stderr:write("_build/grammar.json is stale; run scripts/grammar-register.ts\n")
end

local GRAMMAR_CLASSES = {
  grammar = true,
  ["grammar-external"] = true,
  ["grammar-planned"] = true,
  ["grammar-collected"] = true,
}

local function has_grammar_block(doc)
  local found = false
  doc:walk({ CodeBlock = function(block)
    if GRAMMAR_CLASSES[block.classes[1]] then found = true end
  end })
  return found
end

local function code(text, class)
  return pandoc.Code(text, pandoc.Attr("", { class }))
end

local function span_inline(span)
  if span.class == "gr-nonterminal" and span.ref then
    return pandoc.Link({ code(span.text, span.class) }, "#" .. span.ref)
  end
  return code(span.text, span.class)
end

local function head_inline(rule, span, collected)
  local name = code(span.text, "gr-rule")
  if collected then return pandoc.Link({ name }, "#" .. rule.id) end
  return pandoc.Span({ name }, pandoc.Attr(rule.id))
end

local function rule_blocks(rule, collected)
  local inlines = {}
  for i, line in ipairs(rule.lines) do
    if i > 1 then inlines[#inlines + 1] = pandoc.LineBreak() end
    for j, span in ipairs(line) do
      if i == 1 and j == 1 and span.class == "gr-rule" then
        inlines[#inlines + 1] = head_inline(rule, span, collected)
      else
        inlines[#inlines + 1] = span_inline(span)
      end
    end
  end
  return {
    pandoc.Div({ pandoc.Para(inlines) }, pandoc.Attr("", { "grammar-block" })),
  }
end

local function all_rules()
  local out = {}
  for _, fragment in ipairs(entry.fragments) do
    for _, rule in ipairs(fragment.rules) do out[#out + 1] = rule end
  end
  return out
end

local function entry_blocks(head, rows, id_key, name_key)
  if #rows == 0 then return {} end
  local width = 0
  for _, row in ipairs(rows) do
    if #row[name_key] > width then width = #row[name_key] end
  end
  local inlines = {}
  for i, row in ipairs(rows) do
    if i > 1 then inlines[#inlines + 1] = pandoc.LineBreak() end
    local name = code(row[name_key], id_key and "gr-rule" or "gr-keyword")
    if id_key then name = pandoc.Span({ name }, pandoc.Attr(row[id_key])) end
    inlines[#inlines + 1] = name
    if row.note and row.note ~= "" then
      inlines[#inlines + 1] = code(string.rep(" ", width - #row[name_key] + 3), "gr-plain")
      inlines[#inlines + 1] = code("; " .. row.note, "gr-comment")
    end
  end
  return {
    pandoc.Para({ pandoc.Emph({ pandoc.Str(head) }) }),
    pandoc.Div({ pandoc.Para(inlines) }, pandoc.Attr("", { "grammar-block" })),
  }
end

local function code_block(block)
  local class = block.classes[1]
  if class == "grammar" then
    fragment_index = fragment_index + 1
    local fragment = entry.fragments[fragment_index]
    if not fragment then
      stale()
      return nil
    end
    local blocks = {}
    for _, rule in ipairs(fragment.rules) do
      for _, b in ipairs(rule_blocks(rule, false)) do blocks[#blocks + 1] = b end
    end
    return blocks
  elseif class == "grammar-collected" then
    local blocks = {}
    for _, rule in ipairs(all_rules()) do
      for _, b in ipairs(rule_blocks(rule, true)) do blocks[#blocks + 1] = b end
    end
    return blocks
  elseif class == "grammar-external" then
    return entry_blocks("Defined elsewhere", entry.external, "id", "name")
  elseif class == "grammar-planned" then
    return entry_blocks("Not lexed yet", entry.planned, nil, "keyword")
  end
  return nil
end

function Pandoc(doc)
  local files = PANDOC_STATE and PANDOC_STATE.input_files or {}
  entry = entry_for(load_register(), files[1] or "")
  if not entry then
    if has_grammar_block(doc) then stale() end
    return nil
  end
  local walked = doc:walk({ CodeBlock = code_block })
  if fragment_index ~= #entry.fragments then stale() end
  return walked
end
