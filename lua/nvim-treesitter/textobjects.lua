local api = vim.api

local configs = require "nvim-treesitter.configs"
local parsers = require "nvim-treesitter.parsers"
local queries = require'nvim-treesitter.query'
local locals = require'nvim-treesitter.locals'
local ts_utils = require'nvim-treesitter.ts_utils'

local M = {}

function M.select_textobj(query_string)
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = api.nvim_buf_get_option(bufnr, "ft")
  if not ft then return end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1

  local matches = {}

  if string.match(query_string, '^@.*') then
    matches = locals.get_capture_matches(bufnr, query_string, 'textobjects')
  end

  local match_length
  local smallest_range

  for _, m in pairs(matches) do
    if ts_utils.is_in_node_range(m.node, row, col) then
      local length = ts_utils.node_length(m.node)
      if not match_length or length < match_length then
        smallest_range = m
        match_length = length
      end
    end
  end

  if smallest_range then
    ts_utils.update_selection(bufnr,
        smallest_range.process_range and smallest_range.process_range() or smallest_range.node)
  end
end

function M.attach(bufnr, lang)
  local buf = bufnr or api.nvim_get_current_buf()
  local config = configs.get_module("textobjects")
  local lang = lang or parsers.ft_to_lang(api.nvim_buf_get_option(bufnr, "ft"))

  for mapping, query in pairs(config.keymaps) do
    if type(query) == 'table' then
      query = query[lang]
    elseif not queries.get_query(lang, 'textobjects') then
      query = nil
    end
    if query then
      local cmd = ":lua require'nvim-treesitter.textobjects'.select_textobj('"..query.."')<CR>"
      api.nvim_buf_set_keymap(buf, "o", mapping, cmd, {silent = true})
      api.nvim_buf_set_keymap(buf, "v", mapping, cmd, {silent = true})
    end
  end
end

function M.detach(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()
  local config = configs.get_module("textobjects")
  local lang = parsers.ft_to_lang(api.nvim_buf_get_option(bufnr, "ft"))

  for mapping, query in pairs(config.keymaps) do
    if type(query) == 'table' then
      query = query[lang]
    elseif not queries.get_query(lang, 'textobjects') then
      query = nil
    end
    if query then
      api.nvim_buf_del_keymap(buf, "o", mapping)
      api.nvim_buf_del_keymap(buf, "v", mapping)
    end
  end
end

return M
