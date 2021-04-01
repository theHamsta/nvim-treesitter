-- Functions to handle locals
-- Locals are a generalization of definition and scopes
-- its the way nvim-treesitter uses to "understand" the code

local ts_utils = require'nvim-treesitter.ts_utils'
local parsers = require'nvim-treesitter.parsers'
local api = vim.api
local caching = require'nvim-treesitter.caching'
local queries = require'nvim-treesitter.query'

local M = {}

local scope_tree = caching.create_buffer_cache()

local function update_scope_tree(cache, buf, parse_node, start_row, end_row)
  local parser = parsers.get_parser(buf)

  --TODO: do that in a refining manner only updating a specific region?
  cache.scopes = {}
  cache.references = {}
  parser:parse()
  parser:for_each_tree(function(tree, lang_tree)
    local lang = lang_tree:lang()

    local query = queries.get_query(lang, 'locals')

    local definitions = {}
    local root = tree:root()
    local root_id = root:id()
    cache.references[root_id] = {}
    local range = root and {root:range()}
    local matches = query
       and query:iter_matches(parse_node or tree:root(), buf, start_row or range[1], end_row or (range[3] + 1))
       or function() end
    for _, match in matches do
      for id, node in pairs(match) do
        local name = query.captures[id]
        if name == "scope" then
          local found = cache.scopes[node:id()]
          if found then
            found.node = node
          else
            cache.scopes[node:id()] = { node = node, definitions = {} }
          end
        elseif name:find("^definition") then
          local text = ts_utils.get_node_text(node, buf)[1]
          table.insert(definitions, {node = node, type = name, text = text})
        elseif name:find("^reference") then
          table.insert(cache.references[root_id], node)
        end
      end
    end

    for _, d in ipairs(definitions) do
      local parent = d.node:parent()
      local found
      while not found and parent do
        found = cache.scopes[parent:id()]
        parent = parent:parent()
      end
      if found then
        found.definitions[d.text] = d
      end
    end
  end)
end

function M.get_scope_tree_fast(buf)
  local buf = buf or api.nvim_get_current_buf()
  local cache = scope_tree.get('scopes', buf)
  local new_tick = api.nvim_buf_get_changedtick(buf)

  if not cache then
    cache = {}
    cache.scopes = {}
    cache.references = {}
  end
  if not cache.tick or new_tick > cache.tick then
    update_scope_tree(cache, buf)
    cache.tick = new_tick
    scope_tree.set('scopes', buf, cache)
  end
  return cache.scopes, cache.references
end

function M.find_definition_fast(node, buf)
  assert(type(node)=='userdata')
  local scopes = M.get_scope_tree_fast(buf)
  local search = ts_utils.get_node_text(node, buf)[1]
  local parent = node:parent()
  local found, found_scope
  while not found and parent do
    found_scope = scopes[parent:id()]
    if found_scope then
      found = found_scope.definitions[search]
    end
    parent = parent:parent()
  end
  return found, found_scope
end

function M.collect_locals(bufnr)
  return queries.collect_group_results(bufnr, 'locals')
end

-- Iterates matches from a locals query file.
-- @param bufnr the buffer
-- @param root the root node
function M.iter_locals(bufnr, root)
  return queries.iter_group_results(bufnr, 'locals', root)
end

function M.get_locals(bufnr)
  return queries.get_matches(bufnr, 'locals')
end

--- Creates unique id for a node based on text and range
-- @param scope: the scope node of the definition
-- @param bufnr: the buffer
-- @param node_text: the node text to use
-- @returns a string id
function M.get_definition_id(scope, node_text)
  -- Add a vaild starting character in case node text doesn't start with a valid one.
  return table.concat({ 'k', node_text or '', scope:range() }, '_')
end

function M.get_definitions(bufnr)
  local locals = M.get_locals(bufnr)

  local defs = {}

  for _, loc in ipairs(locals) do
    if loc.definition then
      table.insert(defs, loc.definition)
    end
  end

  return defs
end

function M.get_scopes(bufnr)
  local locals = M.get_locals(bufnr)

  local scopes = {}

  for _, loc in ipairs(locals) do
    if loc.scope and loc.scope.node then
      table.insert(scopes, loc.scope.node)
    end
  end

  return scopes
end

function M.get_references(bufnr)
  local locals = M.get_locals(bufnr)

  local refs = {}

  for _, loc in ipairs(locals) do
    if loc.reference and loc.reference.node then
      table.insert(refs, loc.reference.node)
    end
  end

  return refs
end

--- Gets a table with all the scopes containing a node
-- The order is from most specific to least (bottom up)
function M.get_scope_tree(node, bufnr)
  local scopes = {}

  for scope in M.iter_scope_tree(node, bufnr) do
    table.insert(scopes, scope)
  end

  return scopes
end

--- Iterates over a nodes scopes moving from the bottom up
function M.iter_scope_tree(node, bufnr)
  local last_node = node
  return function()
    if not last_node then
      return
    end

    local scope = M.containing_scope(last_node, bufnr, false) or ts_utils.get_root_for_node(node)

    last_node = scope:parent()

    return scope
  end
end

-- Gets a table of all nodes and their 'kinds' from a locals list
-- @param local_def the local list result
-- @returns a list of node entries
function M.get_local_nodes(local_def)
  local result = {}

  M.recurse_local_nodes(local_def, function(def, node, kind)
    table.insert(result, vim.tbl_extend("keep", { kind = kind }, def))
  end)

  return result
end

-- Recurse locals results until a node is found.
-- The accumulator function is given
-- * The table of the node
-- * The node
-- * The full definition match `@definition.var.something` -> 'var.something'
-- * The last definition match `@definition.var.something` -> 'something'
-- @param The locals result
-- @param The accumulator function
-- @param The full match path to append to
-- @param The last match
function M.recurse_local_nodes(local_def, accumulator, full_match, last_match)
  if local_def.node then
    accumulator(local_def, local_def.node, full_match, last_match)
  else
    for match_key, def in pairs(local_def) do
      M.recurse_local_nodes(
        def,
        accumulator,
        full_match and (full_match..'.'..match_key) or match_key,
        match_key)
    end
  end
end

--- Get a single dimension table to look definition nodes.
-- Keys are generated by using the range of the containing scope and the text of the definition node.
-- This makes looking up a definition for a given scope a simple key lookup.
--
-- This is memoized by buffer tick. If the function is called in succession
-- without the buffer tick changing, then the previous result will be used
-- since the syntax tree hasn't changed.
--
-- Usage lookups require finding the definition of the node, so `find_definition`
-- is called very frequently, which is why this lookup must be fast as possible.
--
-- @param bufnr: the buffer
-- @returns a table for looking up definitions
M.get_definitions_lookup_table = ts_utils.memoize_by_buf_tick(function(bufnr)
  local definitions = M.get_definitions(bufnr)
  local result = {}

  for _, definition in ipairs(definitions) do
    for _, node_entry in ipairs(M.get_local_nodes(definition)) do
      local scopes = M.get_definition_scopes(node_entry.node, bufnr, node_entry.scope)
      -- Always use the highest valid scope
      local scope = scopes[#scopes]
      local node_text = ts_utils.get_node_text(node_entry.node, bufnr)[1]
      local id = M.get_definition_id(scope, node_text)

      result[id] = node_entry
    end
  end

  return result
end)

--- Gets all the scopes of a definition based on the scope type
-- Scope types can be
--
-- "parent": Uses the parent of the containing scope, basically, skipping a scope
-- "global": Uses the top most scope
-- "local": Uses the containg scope of the definition. This is the default
--
-- @param node: the definition node
-- @param bufnr: the buffer
-- @param scope_type: the scope type
function M.get_definition_scopes(node, bufnr, scope_type)
  local scopes = {}
  local scope_count = 1

  -- Definition is valid for the containing scope
  -- and the containing scope of that scope
  if scope_type == 'parent' then
    scope_count = 2
    -- Definition is valid in all parent scopes
  elseif scope_type == 'global' then
    scope_count = nil
  end

  local i = 0
  for scope in M.iter_scope_tree(node, bufnr) do
    table.insert(scopes, scope)
    i = i + 1

    if scope_count and i >= scope_count then break end
  end

  return scopes
end

function M.find_definition(node, bufnr)
  local def_lookup = M.get_definitions_lookup_table(bufnr)
  local node_text = ts_utils.get_node_text(node, bufnr)[1]

  for scope in M.iter_scope_tree(node, bufnr) do
    local id = M.get_definition_id(scope, node_text)

    if def_lookup[id] then
      local entry = def_lookup[id]

      return entry.node, scope, entry.kind
    end
  end

  return node, ts_utils.get_root_for_node(node), nil
end

-- Finds usages of a node in a given scope.
-- @param node the node to find usages for
-- @param scope_node the node to look within
-- @returns a list of nodes
function M.find_usages(node, scope_node, bufnr)
  local bufnr = bufnr or api.nvim_get_current_buf()
  local node_text = ts_utils.get_node_text(node, bufnr)[1]

  if not node_text or #node_text < 1 then return {} end

  local scope_node = scope_node or ts_utils.get_root_for_node(node)
  local usages = {}

  for match in M.iter_locals(bufnr, scope_node) do
    if match.reference
      and match.reference.node
      and ts_utils.get_node_text(match.reference.node, bufnr)[1] == node_text
    then
      local def_node, _, kind = M.find_definition(match.reference.node, bufnr)

      if kind == nil or def_node == node then
        table.insert(usages, match.reference.node)
      end
    end
  end

  return usages
end

-- Finds usages of a node in a given scope.
-- @param node the node to find usages for
-- @param scope_node the node to look within
-- @returns a list of nodes
function M.find_usages_fast(node, scope_node, bufnr)
  if not node then return end
  local bufnr = bufnr or api.nvim_get_current_buf()
  local node_text = ts_utils.get_node_text(node, bufnr)[1]

  if not node_text or #node_text < 1 then return {} end

  local usages = {}

  local _, references = M.get_scope_tree_fast(bufnr)
  local root = ts_utils.get_root_for_node(node)

  -- TODO: probably better to just run "(identifier) @reference" on scope_node
  for _, r in ipairs(references[root:id()] or {}) do
    if ts_utils.get_node_text(r, bufnr)[1] == node_text
    then
      local ref_range = {r:range()}
      if ts_utils.is_in_node_range(scope_node, ref_range[1], ref_range[3]) then
        local def = M.find_definition_fast(r, bufnr)

        if def and def.node == node then
          table.insert(usages, r)
        end
      end
    end
  end

  return usages
end

function M.containing_scope(node, bufnr, allow_scope)
  local bufnr = bufnr or api.nvim_get_current_buf()
  local allow_scope = allow_scope == nil or allow_scope == true

  local scopes = M.get_scopes(bufnr)
  if not node or not scopes then return end

  local iter_node = node

  while iter_node ~= nil and not vim.tbl_contains(scopes, iter_node) do
    iter_node = iter_node:parent()
  end

  return iter_node or (allow_scope and node or nil)
end

function M.nested_scope(node, cursor_pos)
  local bufnr = api.nvim_get_current_buf()

  local scopes = M.get_scopes(bufnr)
  if not node or not scopes then return end

  local row = cursor_pos.row
  local col = cursor_pos.col
  local scope = M.containing_scope(node)

  for _, child in ipairs(ts_utils.get_named_children(scope)) do
    local row_, col_ = child:start()
    if vim.tbl_contains(scopes, child) and ((row_+1 == row and col_ > col) or row_+1 > row) then
      return child
    end
  end
end

function M.next_scope(node)
  local bufnr = api.nvim_get_current_buf()

  local scopes = M.get_scopes(bufnr)
  if not node or not scopes then return end

  local scope = M.containing_scope(node)

  local parent = scope:parent()
  if not parent then return end

  local is_prev = true
  for _, child in ipairs(ts_utils.get_named_children(parent)) do
    if child == scope then
      is_prev = false
    elseif not is_prev and vim.tbl_contains(scopes, child) then
      return child
    end
  end
end

function M.previous_scope(node)
  local bufnr = api.nvim_get_current_buf()

  local scopes = M.get_scopes(bufnr)
  if not node or not scopes then return end

  local scope = M.containing_scope(node)

  local parent = scope:parent()
  if not parent then return end

  local is_prev = true
  local children = ts_utils.get_named_children(parent)
  for i=#children,1,-1 do
    if children[i] == scope then
      is_prev = false
    elseif not is_prev and vim.tbl_contains(scopes, children[i]) then
      return children[i]
    end
  end
end

return M
