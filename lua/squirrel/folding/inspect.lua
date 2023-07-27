local ex = require("infra.ex")
local prefer = require("infra.prefer")

local exprs = require("squirrel.folding.exprs")

local api = vim.api

return function()
  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)

  local new_bufnr
  do
    local ft = prefer.bo(bufnr, "filetype")
    ---@type squirrel.folding.fold_expr
    local foldexpr = assert(exprs[ft], "unsupported ft")

    local line_count = api.nvim_buf_line_count(bufnr)
    new_bufnr = api.nvim_create_buf(false, true)
    prefer.bo(new_bufnr, "bufhidden", "wipe")
    local lines = {}
    for i = 0, line_count do
      local lv = foldexpr(i)
      table.insert(lines, string.format("%s|%d", string.rep(" ", lv), lv))
    end
    api.nvim_buf_set_lines(new_bufnr, 0, -1, false, lines)
  end

  local new_win_id
  -- setup new win & buf
  do
    ex("leftabove vsplit")
    new_win_id = api.nvim_get_current_win()
    api.nvim_win_set_width(new_win_id, 20)
    local wo = prefer.win(new_win_id)
    wo.number = true
    wo.relativenumber = false
    api.nvim_win_set_buf(new_win_id, new_bufnr)
  end

  -- scrollbind
  api.nvim_win_set_cursor(new_win_id, api.nvim_win_get_cursor(winid))
  prefer.wo(winid, "scrollbind", true)
  prefer.wo(new_win_id, "scrollbind", true)
end
