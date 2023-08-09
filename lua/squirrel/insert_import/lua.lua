local bufrename = require("infra.bufrename")
local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("squirrel.import_import.lua")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local nuts = require("squirrel.nuts")

local api = vim.api
local ts = vim.treesitter

local find_first_require
do
  ---@param node TSNode
  local function is_require_node(node)
    if node:type() ~= "variable_declaration" then return false end
    local call = nuts.get_named_decendant(node, 0, "assignment_statement", 1, "expression_list", 0, "function_call")
    if call == nil then return false end
    local ident = call:named_child(0)
    if ident == nil then return false end
    if ident:type() ~= "identifier" then return false end
    return true
  end
  ---@return TSNode?
  function find_first_require(bufnr)
    local root = assert(ts.get_parser(bufnr):trees()[1]):root()
    for idx in fn.range(root:named_child_count()) do
      local child = root:named_child(idx)
      if is_require_node(child) then return child end
    end
  end
end

---@param line string
---@return string?
local function resolve_require_stat(line)
  if #line <= #'#require""' then return jelly.debug("canceled") end

  local as
  do
    local mod = string.match(line, '^require"(.+)"')
    assert(mod)
    as = mod
    local start = strlib.rfind(mod, ".")
    if start ~= nil then as = string.sub(mod, start + 1) end
  end

  return string.format("local %s = %s", as, line)
end

return function()
  local host_bufnr = api.nvim_get_current_buf()

  local anchor = find_first_require(host_bufnr)
  if anchor == nil then return jelly.debug("unable to find a place to add require") end

  local bufnr
  do
    bufnr = Ephemeral({ modifiable = true, undolevels = 1 }, { 'require""' })

    bufrename(bufnr, string.format("imports://buf/%d", host_bufnr))
    --NB: lsp completion will not work if this line is above the bufrename()
    prefer.bo(bufnr, "filetype", "lua")

    api.nvim_create_autocmd("bufwipeout", {
      buffer = bufnr,
      once = true,
      callback = function()
        local line = api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        local require_stat = resolve_require_stat(line)
        if require_stat == nil then return end

        local anchor_tail = anchor:end_() + 1
        api.nvim_buf_set_lines(host_bufnr, anchor_tail, anchor_tail, false, { require_stat })
        jelly.info("'%s'", require_stat)
      end,
    })

    local bm = bufmap.wraps(bufnr)
    handyclosekeys(bufnr)
    bm.i("<cr>", "<cmd>stopinsert<bar>q<cr>")
    bm.i("<c-c>", "<cmd>stopinsert<bar>q<cr>")
  end

  do
    local winid = api.nvim_open_win(bufnr, true, { relative = "cursor", width = 50, height = 1, row = -1, col = 0 })
    api.nvim_win_set_cursor(winid, { 1, #'require"' })
    ex("startinsert")
  end
end
