local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("squirrel.whereami")
local prefer = require("infra.prefer")

local nuts = require("squirrel.nuts")
local facts = require("squirrel.whereami.facts")

local api = vim.api

local collect_stops
do
  local types = fn.toset({ "function_declaration", "function_definition" })
  ---collect 'stop's from inner to outer
  ---@param start_node TSNode
  ---@return TSNode[]
  function collect_stops(start_node)
    local stacks = {}
    ---@type TSNode?
    local node = start_node
    while node ~= nil do
      local ntype = node:type()
      if ntype == "chunk" then break end
      if types[ntype] then table.insert(stacks, 1, node) end
      node = node:parent()
    end
    return stacks
  end
end

---@param bufnr integer
---@param node TSNode
---@return string?
local function resolve_stop_name(bufnr, node)
  local fields = node:field("name")
  if #fields == 0 then return "()" end
  if #fields == 1 then
    local name = fields[1]
    local ntype = name:type()
    assert(ntype == "identifier" or ntype == "method_index_expression", ntype)
    return nuts.get_node_lines(bufnr, name)[1]
  end
  error("unreachable: multiple name field")
end

---@param winid integer
---@return string?
local function resolve_route(winid)
  local bufnr = api.nvim_win_get_buf(winid)

  local ft = prefer.bo(bufnr, "filetype")
  if ft ~= "lua" then return jelly.warn("not supported filetype: %s", ft) end

  local stops = { "" }
  for _, node in ipairs(collect_stops(nuts.get_node_at_cursor(winid))) do
    local stop = resolve_stop_name(bufnr, node)
    if stop ~= nil then table.insert(stops, stop) end
  end
  return table.concat(stops, "/")
end

return function()
  local route = resolve_route(api.nvim_get_current_win())
  if route == nil then return end

  local bufnr
  do
    bufnr = api.nvim_create_buf(false, true)
    local bo = prefer.buf(bufnr)
    bo.bufhidden = "wipe"
    api.nvim_buf_set_lines(bufnr, 0, -1, false, { route })
    bo.modifiable = false
  end

  local winid = api.nvim_open_win(bufnr, false, { relative = "cursor", row = -1, col = 0, width = #route, height = 1 })
  api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)

  vim.defer_fn(function()
    if api.nvim_win_is_valid(winid) then api.nvim_win_close(winid, false) end
  end, 1000 * 3)
end
