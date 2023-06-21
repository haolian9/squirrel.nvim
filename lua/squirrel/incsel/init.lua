-- design
-- * deinit will not clear the visual selection
-- * since there is only one state, no need to attach it to the WinClose

local M = {}

local api = vim.api

local jelly = require("infra.jellyfish")("squirrel.incsel")
local bufmap = require("infra.keymap.buffer")
local nuts = require("squirrel.nuts")
local startpoints = require("squirrel.incsel.startpoints")

---@class squirrel.incsel.state
local state = {
  started = false,
  winid = nil,
  bufnr = nil,
  ---@type TSNode[]
  path = nil,
}

function state:unmap(mode, lhs)
  assert(self.started)
  api.nvim_buf_del_keymap(self.bufnr, mode, lhs)
end

function state:deinit()
  assert(self.started)
  local ok, err = pcall(function()
    self:unmap("x", "m")
    self:unmap("x", "n")
    self:unmap("x", [[<esc>]])
    self:unmap("n", [[<esc>]])
  end)
  self.started = false
  self.winid = nil
  self.bufnr = nil
  self.path = nil
  jelly.info("squirrel.incsel deinited")
  if not ok then jelly.err("deinit failed with errors: %s", err) end
end

function state:increase()
  assert(self.started)
  local start = self.path[#self.path]
  local next = start:parent()
  while next ~= nil do
    local parent = next:parent()
    -- tip as highest node, not root
    if not nuts.same_range(next, start) and parent ~= nil then
      table.insert(self.path, next)
      nuts.vsel_node(self.winid, next)
      return
    end
    next = parent
  end
  jelly.info("reached tip node")
end

function state:decrease()
  assert(self.started)
  -- back to start node, do nothing
  if #self.path == 1 then return jelly.info("reached start node") end

  table.remove(self.path, #self.path)
  local next = assert(self.path[#self.path])
  nuts.vsel_node(self.winid, next)
end

---@param winid number
---@param startpoint_resolver fun(winid: number):TSNode
function state:init(winid, startpoint_resolver)
  assert(not self.started, "dirty incsel state, hasnt been deinited")
  assert(self.path == nil)

  self.winid = winid
  self.bufnr = api.nvim_win_get_buf(self.winid)
  self.started = true
  self.path = {}
  table.insert(self.path, startpoint_resolver(self.winid))

  -- stylua: ignore
  local ok, err = pcall(function()
    assert(nuts.vsel_node(self.winid, self.path[1]))
    local bm = bufmap.wraps(self.bufnr)
    bm.x("m", function() self:increase() end)
    bm.x("n", function() self:decrease() end)
    -- ModeChanged is not reliable, so we hijack the <esc>
    bm.x('<esc>', function() self:deinit() end)
    bm.n('<esc>', function() self:deinit() end)
  end)

  if not ok then
    self:deinit()
    error(err)
  end
end

function M.n()
  local pointer = startpoints.n()
  local winid = api.nvim_get_current_win()

  if not state.started then
    state:init(winid, pointer)
    return
  end

  if api.nvim_win_get_buf(winid) ~= state.bufnr then
    state:deinit()
    state:init(winid, pointer)
    return
  end
end

function M.m(filetype)
  local winid = api.nvim_get_current_win()
  local pointer = startpoints.m(filetype)

  if not state.started then
    state:init(winid, pointer)
    return
  end

  if api.nvim_win_get_buf(winid) ~= state.bufnr then
    state:deinit()
    state:init(winid, pointer)
    return
  end
end

return M
