--
-- annotation flavor: * https://github.com/sumneko/lua-language-server/wiki/Annotations
--
-- generate documents for
-- * annotations of function signature
--

local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("squirrel.docgen", "INFO")
local jumplist = require("infra.jumplist")
local nvimkeys = require("infra.nvimkeys")
local vsel = require("infra.vsel")

local nuts = require("squirrel.nuts")

local ts = vim.treesitter
local api = vim.api

local function find_fn_node_around_cursor(winid)
  local start = nuts.get_node_at_cursor(winid)

  ---@type TSNode?
  local node = start
  while node ~= nil do
    local itype = node:type()
    if itype == "function_declaration" or itype == "function_definition" then return node end
    node = node:parent()
  end
end

---@param fn_node TSNode
---@return TSNode?
local function find_params_node(fn_node)
  if fn_node:type() == "function_declaration" then
    return assert(fn_node:named_child(1))
  elseif fn_node:type() == "function_definition" then
    return assert(fn_node:named_child(0))
  else
    jelly.err("unable to find params child node: %s", fn_node:sexpr())
    error("unreachable")
  end
end

---@param fn_node TSNode
local function resolve_return_type(fn_node)
  local body_node = fn_node:field("body")[1]
  if body_node == nil then return end
  local return_nil = false
  local return_any = false
  ---@type TSNode[]
  local stack = { body_node }
  while #stack > 0 do
    ---@type TSNode
    local node = table.remove(stack, 1)
    local itype = node:type()
    if not (itype == "function_declaration" or itype == "function_definition") then
      if itype == "return_statement" then
        -- only itself
        if node:child_count() == 1 then
          return_nil = true
        else
          return_any = true
        end
      else
        for child in node:iter_children() do
          table.insert(stack, child)
        end
      end
    end
  end
  if return_nil then
    if return_any then
      return "any?"
    else
      return
    end
  else
    if return_any then
      return "any"
    else
      return
    end
  end
end

return function()
  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)

  local fn_node = find_fn_node_around_cursor(winid)
  if fn_node == nil then return end
  local params_node = assert(find_params_node(fn_node))

  local anns = {}
  do
    -- todo: respect indent
    for i in fn.range(params_node:named_child_count()) do
      local node = params_node:named_child(i)
      local text = ts.get_node_text(node, bufnr)
      table.insert(anns, string.format("---@param %s any", text))
    end
    local return_type = resolve_return_type(fn_node)
    if return_type then table.insert(anns, string.format("---@return " .. return_type)) end
    if #anns == 0 then return end
  end

  jumplist.push_here()

  local start_line = fn_node:range()
  api.nvim_buf_set_lines(bufnr, start_line, start_line, false, anns)

  -- search `any` in generated annotation for easier editing
  do
    -- todo: move to infra.vsel
    vsel.select_lines(start_line, start_line + #anns + 1)
    vim.fn.setreg("/", [[\%Vany$]])
    api.nvim_feedkeys(nvimkeys([[<esc>/<cr>]]), "n", false)
  end
end
