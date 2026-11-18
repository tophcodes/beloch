-- The id links of ADR-0054 and ADR-0062 in the rendered PDFs. pandoc reads
-- `[[ADR-0032]]` and `[[reference/model#def-sheet|the sheet]]` as
-- links of class `wikilink` when it runs with
-- `--from markdown+wikilinks_title_after_pipe`; this filter resolves the
-- target against _build/id-links.json, written by scripts/id-links.ts. An
-- anchor in a document that is among pandoc's input files becomes an
-- internal link; everything else becomes the absolute URL of the page on the
-- site, or of the file in the repository when the site does not serve it. A
-- link with no text after the pipe gets the same default text the site
-- gives it: the id for a record (`ADR-0032`), the anchor's label, or the page's
-- title. A target that resolves to nothing stops the render, naming it.
--
-- Known limit: pandoc numbers a heading's own id by its rules, which drop a
-- leading number ("1. Paper" is #paper here and #1-paper on the site), so
-- an internal link to such a heading misses in the PDF; links to the ids of
-- fenced blocks (#def-sheet) match on both.

local root = (PANDOC_SCRIPT_FILE or ""):match("^(.*)/scripts/[^/]+$") or "."

local index = nil

local function load_index()
  if index then return index end
  local path = os.getenv("BELOCH_ID_LINKS") or (root .. "/_build/id-links.json")
  local file = io.open(path, "r")
  if not file then
    error(path .. " is missing; run scripts/id-links.ts")
  end
  local ok, decoded = pcall(pandoc.json.decode, file:read("a"), false)
  file:close()
  if not ok then error(path .. " is not JSON: " .. tostring(decoded)) end
  index = decoded
  return index
end

-- Whether a document of the index is one of the files pandoc is rendering,
-- compared by suffix: the language pages reach pandoc as copies under a
-- build directory that keeps their path.
local function is_input(doc)
  local files = PANDOC_STATE and PANDOC_STATE.input_files or {}
  for _, f in ipairs(files) do
    if f == doc.path or f:sub(-#doc.path - 1) == "/" .. doc.path then return true end
  end
  return false
end

local function default_text(doc, anchor)
  if anchor then return doc.anchors[anchor] or anchor end
  if doc.id:match("^%u%u%u%-%d%d%d%d$") then return doc.id end
  return doc.title
end

function Link(el)
  if not el.classes:includes("wikilink") then return nil end
  local idx = load_index()
  -- `[[id\|text]]`, the form a table cell needs, reaches the filter with the
  -- backslash left on the target.
  local target = el.target:gsub("\\$", "")
  local id, anchor
  local prefix, number, rest = target:match("^(%a%a%a)%-(%d%d%d%d)(.*)$")
  local kind = prefix and prefix:upper()
  if (kind == "ADR" or kind == "BEP") and (rest == "" or rest:match("^#%S+$")) then
    id = kind .. "-" .. number
    anchor = rest ~= "" and rest:sub(2) or nil
  else
    local stem
    kind, stem, anchor = target:match("^(%a+)/([^#%s]+)#(%S+)$")
    if not kind then
      kind, stem = target:match("^(%a+)/([^#%s]+)$")
    end
    if not kind then
      error("[[" .. target .. "]] is no id; a link names kind/stem or a record such as ADR-0032, with #anchor after it")
    end
    id = (kind .. "/" .. stem):lower()
  end
  local doc = idx.documents[id]
  if not doc then
    error("[[" .. target .. "]] names no document; there is no " .. id .. " under docs/ or records/")
  end
  if anchor and not doc.anchors[anchor] then
    error("[[" .. target .. "]] names no anchor; " .. doc.path .. " has no #" .. anchor)
  end
  local url
  if anchor and is_input(doc) then
    url = "#" .. anchor
  else
    local site = doc.site
    if site == pandoc.json.null then site = nil end
    local base = site and (idx.site .. site) or (idx.repository .. "/" .. doc.path)
    url = anchor and (base .. "#" .. anchor) or base
  end
  local content = el.content
  if pandoc.utils.stringify(content) == target then
    content = { pandoc.Str(default_text(doc, anchor)) }
  end
  return pandoc.Link(content, url)
end
