local fn = require("infra.fn")
local prefer = require("infra.prefer")

local nuts = require("squirrel.nuts")
local facts = require("squirrel.whereami.facts")

local api = vim.api

-- function_definition -> declarator: function_declarator -> declarator: identifier

local collect_stops
do
  local types = fn.toset({ "function_definition", "declaration" })

  ---@param start_node TSNode
  ---@return TSNode[]
  function collect_stops(start_node)
    local stops = {}
    ---@type TSNode?
    local node = start_node
    while node ~= nil do
      local ntype = node:type()
      if types[ntype] then table.insert(stops, 1, node) end
      node = node:parent()
    end
    return stops
  end
end

---@param bufnr integer
---@param node TSNode
---@return string?
local function resolve_stop_name(bufnr, node)
  local ident
  local decls = node:field("declarator")
  while #decls > 0 do
    assert(#decls == 1)
    if decls[1]:type() == "identifier" then
      ident = decls[1]
      break
    end
    decls = decls[1]:field("declarator")
  end
  if ident == nil then return end
  return nuts.get_node_lines(bufnr, ident)[1]
end

local function resolve_route(winid)
  local bufnr = api.nvim_win_get_buf(winid)

  local stops = { "" }
  for _, node in ipairs(collect_stops(nuts.get_node_at_cursor(winid))) do
    local stop = resolve_stop_name(bufnr, node)
    if stop ~= nil then table.insert(stops, stop) end
  end

  return table.concat(stops, "/")
end

do -- main
  local winid = api.nvim_get_current_win()
  print("whereami", resolve_route(winid))
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
