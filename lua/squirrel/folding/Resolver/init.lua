local C = require("squirrel.folding.Resolver.c")
local Lua = require("squirrel.folding.Resolver.lua")
local Python = require("squirrel.folding.Resolver.python")
local Zig = require("squirrel.folding.Resolver.zig")
local nuts = require("squirrel.nuts")

---@type squirrel.folding.TipWalkers
local tip_walkers = {
  --stylua: ignore start
  zig    = Zig.tip_walker,
  go     = Zig.tip_walker,
  json   = Zig.tip_walker,
  c      = C.tip_walker,
  glsl   = C.tip_walker,
  lua    = Lua.tip_walker,
  python = Python.tip_walker,
  --stylua: ignore end
}

---@type squirrel.folding.TreeWalkers
local tree_walkers = {
  --stylua: ignore start
  zig    = Zig.tree_walker,
  go     = Zig.tree_walker,
  json   = Zig.tree_walker,
  c      = C.tree_walker,
  glsl   = C.tree_walker,
  lua    = Lua.tree_walker,
  python = Python.tree_walker,
  --stylua: ignore end
}

--:h fold-expr
---@param ft string
---@return fun(bufnr: number): squirrel.folding.LineLevel?
return function(ft)
  local walk_tip = assert(tip_walkers[ft], ft)
  local walk_tree = assert(tree_walkers[ft], ft)

  return function(bufnr)
    local root = nuts.get_root_node(bufnr, ft)
    if root == nil then return end
    ---@type squirrel.folding.LineLevel
    local line_level = {}
    for i = 0, root:named_child_count() - 1 do
      walk_tip(walk_tree, line_level, assert(root:named_child(i)))
    end
    return line_level
  end
end
