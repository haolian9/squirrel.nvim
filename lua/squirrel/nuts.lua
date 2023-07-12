-- extends of nvim.treesitter

local M = {}

local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("squirrel.nuts", "debug")
local jumplist = require("infra.jumplist")
local unsafe = require("infra.unsafe")

local api = vim.api
local ts = vim.treesitter

---NB: when the cursor lays at the end of line, it will advance one char
---@param winid number
---@return TSNode
function M.get_node_at_cursor(winid)
  local bufnr = api.nvim_win_get_buf(winid)

  local lnum, col
  do
    lnum, col = unpack(api.nvim_win_get_cursor(winid))
    lnum = lnum - 1
    --todo: maybe advance to the last non-blank char
    local llen = assert(unsafe.linelen(bufnr, lnum))
    assert(col <= llen, "unreachable: col can not gte llen")
    if col > 0 and col == llen then col = col - 1 end
  end

  return ts.get_node({ bufnr = bufnr, pos = { lnum, col }, ignore_injections = true })
end

---@alias squirrel.nuts.goto_node fun(winid: number, node: TSNode)

---@type squirrel.nuts.goto_node
function M.goto_node_beginning(winid, node)
  jumplist.push_here()

  local r0, c0 = node:start()
  api.nvim_win_set_cursor(winid, { r0 + 1, c0 })
end

---@type squirrel.nuts.goto_node
function M.goto_node_end(winid, node)
  jumplist.push_here()

  local r1, c1 = node:end_()
  api.nvim_win_set_cursor(winid, { r1 + 1, c1 - 1 })
end

--should only to be used for selecting objects
---@param winid number
---@param node TSNode
---@return boolean
function M.vsel_node(winid, node)
  local mode = api.nvim_get_mode().mode
  if mode == "no" or mode == "n" then
    -- operator-pending mode
    M.goto_node_beginning(winid, node)
    ex("normal! v")
    M.goto_node_end(winid, node)
    return true
  elseif mode == "v" then
    -- visual mode
    M.goto_node_end(winid, node)
    ex("normal! o")
    M.goto_node_beginning(winid, node)
    return true
  else
    jelly.err("unexpected mode for vsel_node: %s", mode)
    return false
  end
end

---@param a TSNode
---@param b TSNode
---@return boolean
function M.same_range(a, b)
  -- since node:range() returns multiple values rather than a tuple,
  -- the following verbose code helps us to avoid the overhead of creating and looping tables
  local a_r0, a_c0, a_r1, a_c1 = a:range()
  local b_r0, b_c0, b_r1, b_c1 = b:range()
  return a_r0 == b_r0 and a_c0 == b_c0 and a_r1 == b_r1 and a_c1 == b_c1
end

---@param bufnr integer
---@param node TSNode
---@return string[]
function M.get_node_lines(bufnr, node)
  local start_line, start_col, stop_line, stop_col = node:range()

  --stolen from vim.treesitter.get_node_text for edge cases
  if stop_col == 0 then
    if start_line == stop_line then
      start_col = -1
      start_line = start_line - 1
    end
    stop_col = -1
    stop_line = stop_line - 1
  end

  return api.nvim_buf_get_text(bufnr, start_line, start_col, stop_line, stop_col, {})
end

---get the first char from the first line of a node
---@param bufnr integer
---@param node TSNode
---@return string
function M.get_node_first_char(bufnr, node)
  local start_line, start_col = node:range()
  local text = api.nvim_buf_get_text(bufnr, start_line, start_col, start_line, start_col + 1, {})
  assert(#text == 1)
  local char = text[1]
  assert(#char == 1)
  return char
end

---get the last char from the last line of a node
---@param bufnr integer
---@param node TSNode
---@return string
function M.get_node_last_char(bufnr, node)
  local _, _, stop_line, stop_col = node:range()
  local text = api.nvim_buf_get_text(bufnr, stop_line, stop_col - 1, stop_line, stop_col, {})
  assert(#text == 1)
  local char = text[1]
  assert(#char == 1)
  return char
end

---get <=n chars from the first line of a node
---@param bufnr integer
---@param node TSNode
---@param n integer
---@return string
function M.get_node_start_chars(bufnr, node, n)
  local start_line, start_col, stop_line, stop_col = node:range()
  local corrected_stop_col
  if start_line == stop_line then
    corrected_stop_col = math.min(start_col + n, stop_col)
  else
    corrected_stop_col = start_col + n
  end
  local text = api.nvim_buf_get_text(bufnr, start_line, start_col, start_line, corrected_stop_col, {})
  assert(#text == 1)
  return text[1]
end

---get <=n chars from the last line of a node
---@param bufnr integer
---@param node TSNode
---@param n integer
---@return string
function M.get_node_end_chars(bufnr, node, n)
  local start_line, start_col, stop_line, stop_col = node:range()
  local corrected_start_col
  if start_line == stop_line then
    corrected_start_col = math.max(stop_col - n, start_col)
  else
    corrected_start_col = math.max(stop_col - n, 0)
  end
  local text = api.nvim_buf_get_text(bufnr, stop_line, corrected_start_col, stop_line, stop_col, {})
  assert(#text == 1)
  return text[1]
end

return M
