local buflines = require("infra.buflines")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("squirrel.insert_import.lua")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local puff = require("puff")
local facts = require("squirrel.insert_import.facts")
local nuts = require("squirrel.nuts")

local api = vim.api

local find_anchor
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

  ---@param bufnr integer
  ---@return TSNode?
  local function first_require(bufnr)
    local root = assert(nuts.get_root_node(bufnr))

    for idx in fn.range(root:named_child_count()) do
      local child = root:named_child(idx)
      if is_require_node(child) then return child end
    end
  end

  ---@return TSNode
  function find_anchor(bufnr) return first_require(bufnr) or facts.origin end
end

local resolve_require_stat
do
  local aliases = {
    ["infra.keymap.buffer"] = "bufmap",
    ["infra.keymap.global"] = "m",
    ["infra._strfmt"] = "strfmt",
  }

  ---@param line string
  ---@return string?
  local function resolve_as(line)
    local mod = string.match(line, '^require"(.+)"')
    if mod == nil then return end

    local alias = aliases[mod]
    if alias ~= nil then return alias end

    local start = strlib.rfind(mod, ".")
    if start == nil then return mod end

    return string.sub(mod, start + 1)
  end

  ---@param line string
  ---@return string?
  function resolve_require_stat(line)
    local as = resolve_as(line)
    if as == nil then return end
    return string.format("local %s = %s", as, line)
  end
end

return function()
  local host_bufnr = api.nvim_get_current_buf()
  local anchor = find_anchor(host_bufnr)

  puff.input({
    prompt = "import://lua",
    startinsert = "i",
    default = 'require""',
    bufcall = function(bufnr) prefer.bo(bufnr, "filetype", "lua") end,
  }, function(line)
    if line == nil then return end
    if #line <= #'require""' then return end

    local requires = resolve_require_stat(line)
    if requires == nil then return end

    buflines.append(host_bufnr, anchor:end_(), requires)
    jelly.info("'%s'", requires)
  end)
end
