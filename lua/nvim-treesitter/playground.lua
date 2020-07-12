local api = vim.api
local ts = vim.treesitter
local parsers = require "nvim-treesitter.parsers"
local queries = require "nvim-treesitter.query"

local hl_namespace = api.nvim_create_namespace("nvim-treesitter.playground")

local M = {}

M.highlights = {}
local count =  1

local function new_highlight()
    count = count + 1
    local name = string.format("NvimTreesitterPlay%i", count)
    local rand = math.random(0, 0xFFFFFF)
    vim.cmd(string.format("highlight %s guifg=#%x guibg=#%x blend=0.2", name, rand, 0xFFFFFF - rand))
    return name
end

local function read_queries(ft, buf)
    local content = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local ok, result = pcall(ts.parse_query, ft, content)
    if ok then
        return result
    end
end

function M.update_highlights(query_buf)
    query_buf = query_buf or api.nvim_get_current_buf()
    for _, buf in pairs(api.nvim_list_bufs()) do
        if buf ~= query_buf then
            M.playon(buf, query_buf)
        end
    end
    api.nvim_buf_clear_namespace(query_buf, hl_namespace, 0, -1)
    for k, v in pairs(M.highlights) do
        for i, line in ipairs(api.nvim_buf_get_lines(query_buf, 0, -1, true)) do
            local start, end_ = string.find(line, '@'..k)
            if start then
                api.nvim_buf_add_highlight(query_buf, hl_namespace, v, i - 1, start - 1, end_)
            end
        end
    end
end

function M.play_with(query_buf)
    query_buf = query_buf or api.nvim_get_current_buf()
    M.update_highlights(query_buf)
  -- luacheck: push ignore 631
    --vim.cmd('autocmd TextChanged <buffer='..query_buf..'> :lua require"nvim-treesitter.playground".update_highlights('..query_buf..')')
    --vim.cmd('autocmd TextChangedI <buffer='..query_buf..'> :lua require"nvim-treesitter.playground".update_highlights('..query_buf..')')
  -- luacheck: pop
    vim.cmd('autocmd TextChanged  :lua require"nvim-treesitter.playground".update_highlights('..query_buf..')')
    vim.cmd('autocmd TextChangedI :lua require"nvim-treesitter.playground".update_highlights('..query_buf..')')
end

function M.highlight_node(node, buf, hl_group)
    local start_row, start_col, end_row, end_col = node:range()
    for i = start_row, end_row, 1 do
        api.nvim_buf_add_highlight(
            buf,
            hl_namespace,
            hl_group,
            i,
            (start_row == i and start_col or 0),
            (end_row == i and end_col or -1)
        )
    end
end

function M.playon(playbuf, querybuf)
    api.nvim_buf_clear_namespace(playbuf, hl_namespace, 0, -1)
    local ft = api.nvim_buf_get_option(playbuf, "ft")
    api.nvim_buf_set_option(playbuf, "syntax", "")
    if not ft then
        return
    end

    local query = read_queries(ft, querybuf)
    if not query then
        return
    end

    local parser = parsers.get_parser(playbuf, ft)
    if not parser then
        return
    end

    local root = parser:parse():root()
    local start_row, _, end_row, _ = root:range()

    local matches = {}

    for prepared_match in queries.iter_prepared_matches(query, root, playbuf, start_row, end_row) do
        table.insert(matches, prepared_match)
    end

    for _, elt in ipairs(matches) do
        for k, v in pairs(elt) do
            if v.node then
                if not M.highlights[k] then
                    M.highlights[k] = new_highlight()
                end
                M.highlight_node(v.node, playbuf, M.highlights[k])
            else
                for k2, v2 in pairs(v) do
                    if v2.node then
                        if not M.highlights[k .. "." .. k2] then
                            M.highlights[k .. "." .. k2] = new_highlight()
                        end
                        M.highlight_node(v2.node, playbuf, M.highlights[k .. "." .. k2])
                    end
                end
            end
        end
    end
    --print(vim.inspect(M.highlights))
end

function M.stop_playing()
    for _, buf in pairs(api.nvim_list_bufs()) do
        api.nvim_buf_clear_namespace(buf, hl_namespace, 0, -1)
    end
end

return M
