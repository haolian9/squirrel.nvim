local api = vim.api
local nuts = require("squirrel.nuts")
local treewalker = require("squirrel.jumps.zigspec.treewalker")
local nodeops = require("squirrel.jumps.zigspec.nodeops")
local jelly = require("infra.jellyfish")("squirrel.jumps.zigspec")

local M = {
  objects = {},
  motions = {},
  -- not available, treesitter-zig generates nonsense ast
  goto_peer = nil,
}

do
  ---@param finder fun(start: TSNode) TSNode
  ---@param vseler fun(winid: number, target: TSNode)
  ---@return fun(winid: number?)
  local function vsel_object(finder, vseler)
    ---@param winid number?
    return function(winid)
      winid = winid or api.nvim_get_current_win()
      local target = finder(nuts.get_node_at_cursor(winid))
      if target == nil then return jelly.info("no objects available") end
      vseler(winid, target)
    end
  end

  --parent function
  M.objects["if"] = vsel_object(treewalker.find_tip_fn, nodeops.vsel_node_body)
  M.objects.af = vsel_object(treewalker.find_tip_fn, nodeops.vsel_node)

  --function call
  M.objects["ic"] = vsel_object(treewalker.find_parent_call, nodeops.vsel_node)
  M.objects["ac"] = vsel_object(treewalker.find_parent_call, nodeops.vsel_node)
end

do
  ---@param finder fun(start: TSNode) TSNode
  ---@param gotoer fun(winid: number, target: TSNode)
  ---@return fun(winid: number?)
  local function goto_object(finder, gotoer)
    return function(winid)
      winid = winid or api.nvim_get_current_win()
      local target = finder(nuts.get_node_at_cursor(winid))
      if target == nil then return jelly.info("no objects available") end
      gotoer(winid, target)
    end
  end

  --beginning of previous/next sibling top level function
  M.motions["[f"] = goto_object(treewalker.find_prev_tip_sibling_fn, nodeops.goto_node_beginning)
  M.motions["]f"] = goto_object(treewalker.find_next_tip_sibling_fn, nodeops.goto_node_beginning)
end

return M