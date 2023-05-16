local M = {}

local api = vim.api

function M.attach(ft)
  local winid = api.nvim_get_current_win()

  if ft == nil then
    local bufnr = api.nvim_win_get_buf(winid)
    ft = api.nvim_buf_get_option(bufnr, "filetype")
  end

  local wo = vim.wo[winid]
  wo.foldmethod = "expr"
  wo.foldlevel = 1
  wo.foldexpr = string.format([[v:lua.require'squirrel.folding.exprs'.%s(v:lnum)]], ft)
end

return M
