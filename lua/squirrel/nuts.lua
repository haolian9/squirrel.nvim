-- extends of nvim.treesitter

local M = {}

local api = vim.api
local ts = vim.treesitter
local jelly = require("infra.jellyfish")("squirrel.nuts")
local ex = require("infra.ex")
local jumplist = require("infra.jumplist")

---@param winid number
---@return TSNode
function M.get_node_at_cursor(winid)
  local bufnr = api.nvim_win_get_buf(winid)
  local cursor = api.nvim_win_get_cursor(winid)
  return ts.get_node({ bufnr = bufnr, pos = { cursor[1] - 1, cursor[2] }, ignore_injections = true })
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

return M
