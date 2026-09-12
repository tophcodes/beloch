-- Typed cross-references for spec/MODEL.md, pandoc side.
--
-- Pandoc reads `::: {.definition #def-sheet name="sheet" uses="…"}` as a Div,
-- so this filter only has to number the statements, render the head and links
-- lines, and build the Terms glossary. It is the counterpart of
-- packages/www/src/lib/remark-model-blocks.ts and produces the same numbers,
-- the same wording and the same links; the RDFa attributes are web-only.
--
-- Numbers are `<section>.<n>`, counted per level-2 header and shared by all
-- statement classes. `[#some-id]` in prose becomes a link whose text is the
-- computed label.

local LABELS = {
  definition = "Definition",
  lemma = "Lemma",
  corollary = "Corollary",
  remark = "Remark",
  open = "Open",
}

local statements = {}  -- id -> {kind, label, name, order, defines, uses, usedBy, realizedBy}
local terms = {}       -- id -> {name, definedBy, content}
local termOrder = {}

local function class_of(div)
  if div.classes:includes("term") then return "term" end
  for _, c in ipairs(div.classes) do
    if LABELS[c] then return c end
  end
  return nil
end

local function ids(value)
  local out = {}
  for word in string.gmatch(value or "", "%S+") do out[#out + 1] = word end
  return out
end

local function contains(list, value)
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

-- Pass 1: number the statements, collect both kinds of block.
local function collect(blocks)
  local section = 0
  local seen = 0
  local counters = {}
  for _, block in ipairs(blocks) do
    if block.t == "Header" and block.level == 2 then
      section = section + 1
    elseif block.t == "Div" then
      local kind = class_of(block)
      if kind == "term" then
        local name = block.attributes.name or block.identifier
        terms[block.identifier] = {
          name = name,
          definedBy = block.attributes["defined-by"] or "",
          content = block.content,
        }
        termOrder[#termOrder + 1] = block.identifier
      elseif kind then
        counters[section] = (counters[section] or 0) + 1
        local number = counters[section]
        seen = seen + 1
        statements[block.identifier] = {
          kind = kind,
          order = seen,
          label = LABELS[kind] .. " " ..
            (section > 0 and (section .. "." .. number) or tostring(number)),
          name = block.attributes.name or "",
          defines = ids(block.attributes.defines),
          uses = ids(block.attributes.uses),
          usedBy = {},
          realizedBy = block.attributes["realized-by"] or "",
        }
      end
    end
  end
end

-- Resolve the written relations and derive their reverses.
local function relate()
  for id, s in pairs(statements) do
    local resolved = {}
    for _, entry in ipairs(s.defines) do
      -- `defines="table"` is accepted as shorthand for `defines="term-table"`.
      local target = terms[entry] and entry or ("term-" .. entry)
      if terms[target] then
        resolved[#resolved + 1] = target
        terms[target].definedBy = id
      end
    end
    s.defines = resolved
    for _, target in ipairs(s.uses) do
      local other = statements[target]
      if other then other.usedBy[#other.usedBy + 1] = id end
    end
  end
  for _, termId in ipairs(termOrder) do
    local owner = statements[terms[termId].definedBy]
    if owner and not contains(owner.defines, termId) then
      owner.defines[#owner.defines + 1] = termId
    end
  end
  -- `usedBy` is filled in hash order; document order keeps the PDF stable.
  for _, s in pairs(statements) do
    table.sort(s.usedBy, function(a, b) return statements[a].order < statements[b].order end)
  end
end

local function ref(id, label)
  return pandoc.Link(pandoc.Str(label), "#" .. id)
end

local function series(items)
  local out = {}
  for i, item in ipairs(items) do
    if i > 1 then out[#out + 1] = pandoc.Str(",") ; out[#out + 1] = pandoc.Space() end
    out[#out + 1] = item
  end
  return out
end

local function join(groups)
  local out = {}
  for i, group in ipairs(groups) do
    if i > 1 then
      out[#out + 1] = pandoc.Space()
      out[#out + 1] = pandoc.Str("·")
      out[#out + 1] = pandoc.Space()
    end
    for _, item in ipairs(group) do out[#out + 1] = item end
  end
  return out
end

local function group(title, items)
  local out = { pandoc.Str(title .. ":"), pandoc.Space() }
  for _, item in ipairs(series(items)) do out[#out + 1] = item end
  return out
end

local function links_line(s)
  local groups = {}
  if #s.defines > 0 then
    local items = {}
    for _, id in ipairs(s.defines) do items[#items + 1] = ref(id, terms[id].name) end
    groups[#groups + 1] = group("Defines", items)
  end
  if #s.uses > 0 then
    local items = {}
    for _, id in ipairs(s.uses) do
      if statements[id] then items[#items + 1] = ref(id, statements[id].label) end
    end
    if #items > 0 then groups[#groups + 1] = group("Uses", items) end
  end
  if #s.usedBy > 0 then
    local items = {}
    for _, id in ipairs(s.usedBy) do items[#items + 1] = ref(id, statements[id].label) end
    groups[#groups + 1] = group("Used by", items)
  end
  if s.realizedBy ~= "" then
    groups[#groups + 1] = {
      pandoc.Str("Realized by:"), pandoc.Space(), pandoc.Code(s.realizedBy),
    }
  end
  if #groups == 0 then return nil end
  return pandoc.Para(pandoc.Emph(join(groups)))
end

local function head_line(label, name)
  local inlines = { pandoc.Strong(pandoc.Str(label)) }
  if name ~= "" then
    inlines[#inlines + 1] = pandoc.Space()
    inlines[#inlines + 1] = pandoc.Emph(pandoc.Str(name))
  end
  return pandoc.Para(inlines)
end

local function statement_div(id, s, content)
  local blocks = { head_line(s.label, s.name) }
  for _, b in ipairs(content) do blocks[#blocks + 1] = b end
  local links = links_line(s)
  if links then blocks[#blocks + 1] = links end
  return pandoc.Div(blocks, pandoc.Attr(id, { "stmt", "stmt-" .. s.kind }))
end

local function term_div(id, t)
  local blocks = { pandoc.Para({ pandoc.Strong(pandoc.Str(t.name)) }) }
  for _, b in ipairs(t.content) do blocks[#blocks + 1] = b end
  local owner = statements[t.definedBy]
  if owner then
    blocks[#blocks + 1] = pandoc.Para(pandoc.Emph({
      pandoc.Str("Defined"), pandoc.Space(), pandoc.Str("in"), pandoc.Space(),
      ref(t.definedBy, owner.label),
    }))
  end
  return pandoc.Div(blocks, pandoc.Attr(id, { "term" }))
end

local function glossary()
  local sorted = {}
  for _, id in ipairs(termOrder) do sorted[#sorted + 1] = id end
  table.sort(sorted, function(a, b) return terms[a].name < terms[b].name end)
  local out = {}
  for _, id in ipairs(sorted) do out[#out + 1] = term_div(id, terms[id]) end
  return out
end

local function header_text(header)
  return pandoc.utils.stringify(header.content)
end

-- Pass 2: rewrite the blocks, then place the glossary in the Terms section.
local function rewrite(blocks)
  local out = {}
  for _, block in ipairs(blocks) do
    if block.t == "Div" and class_of(block) then
      local kind = class_of(block)
      if kind ~= "term" then
        out[#out + 1] = statement_div(block.identifier, statements[block.identifier], block.content)
      end
    else
      out[#out + 1] = block
    end
  end
  return out
end

local function place_glossary(blocks)
  local entries = glossary()
  if #entries == 0 then return blocks end

  local termsAt, refsAt
  for i, block in ipairs(blocks) do
    if block.t == "Header" and block.level == 2 then
      local title = header_text(block)
      if title == "Terms" and not termsAt then termsAt = i end
      if title == "References" and not refsAt then refsAt = i end
    end
  end

  local at
  if termsAt then
    at = #blocks + 1
    for i = termsAt + 1, #blocks do
      if blocks[i].t == "Header" and blocks[i].level <= 2 then at = i ; break end
    end
  else
    at = refsAt or (#blocks + 1)
    table.insert(blocks, at, pandoc.Header(2, pandoc.Str("Terms")))
    at = at + 1
  end

  for offset, entry in ipairs(entries) do
    table.insert(blocks, at + offset - 1, entry)
  end
  return blocks
end

-- `[#some-id]` reaches the filter inside a single Str, since there is no link
-- reference by that name. An id with no block behind it stays as written.
local function expand_sugar(elem)
  local text = elem.text
  if not text:find("[#", 1, true) then return nil end
  local out = {}
  local pos = 1
  while true do
    local first, last, id = text:find("%[#([%w%-_]+)%]", pos)
    if not first then break end
    local label = statements[id] and statements[id].label
      or (terms[id] and terms[id].name)
    if first > pos then out[#out + 1] = pandoc.Str(text:sub(pos, first - 1)) end
    if label then
      out[#out + 1] = ref(id, label)
    else
      out[#out + 1] = pandoc.Str(text:sub(first, last))
    end
    pos = last + 1
  end
  if #out == 0 then return nil end
  if pos <= #text then out[#out + 1] = pandoc.Str(text:sub(pos)) end
  return out
end

function Pandoc(doc)
  collect(doc.blocks)
  relate()
  local blocks = place_glossary(rewrite(doc.blocks))
  return pandoc.Pandoc(blocks, doc.meta):walk({ Str = expand_sugar })
end
