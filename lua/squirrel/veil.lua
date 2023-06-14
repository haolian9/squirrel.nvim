local M = {}

local api = vim.api
local vsel = require("infra.vsel")
local jelly = require("infra.jellyfish")("squirrel.veil", vim.log.levels.INFO)
local prefer = require("infra.prefer")

---@type {[string]: string[]}
local blk_pairs = {
  lua = { "do", "end" },
  zig = { "{", "}" },
  c = { "{", "}" },
  go = { "{", "}" },
  sh = { "{", "}" },
}

--todo: exact as an api in infra.?
---@param bufnr number
---@param l0 number 0-based line number
---@return string,string,number
local function resolve_line_indent(bufnr, l0)
  local ispaces = api.nvim_buf_call(bufnr, function() return vim.fn.indent(l0 + 1) end)

  local bo = prefer.buf(bufnr)
  if bo.expandtab then
    local sw = bo.shiftwidth
    return string.rep(" ", ispaces), " ", sw
  else
    local sw = bo.shiftwidth
    return string.rep("\t", ispaces / sw), "\t", 1
  end
end

function M.cover(ft, bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  ft = ft or prefer.bo(bufnr, "filetype")

  local pair = blk_pairs[ft]
  if pair == nil then return jelly.warn("not supported filetype for squirrel.veil") end

  local range = vsel.range(bufnr)
  if range == nil then return jelly.info("no selection") end

  local lines
  do
    local indents, ichar, iunit = resolve_line_indent(bufnr, range.start_line)
    lines = api.nvim_buf_get_lines(bufnr, range.start_line, range.stop_line, false)
    do
      local add = string.rep(ichar, iunit)
      for i = 1, #lines do
        lines[i] = add .. lines[i]
      end
    end
    do
      local add = indents
      table.insert(lines, 1, add .. pair[1])
      table.insert(lines, add .. pair[2])
    end
  end

  api.nvim_buf_set_lines(bufnr, range.start_line, range.stop_line, false, lines)
end

function M.uncover(ft, bufnr)
  local _, _ = ft, bufnr
  error("not implemented")
end

return M
