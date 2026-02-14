local M = {}

local w = vim.w
local a = vim.api
local wo = vim.wo
local fn = vim.fn
local uv = vim.uv
local hl = a.nvim_set_hl
local au = a.nvim_create_autocmd
local ag = a.nvim_create_augroup
local timer = uv.new_timer()

local DEFAULT_OPTIONS = {
  disable_filetypes = {},
  disable_buftypes = {},
  cursorline = {
    enable = true,
    timeout = 1000,
    number = false,
  },
  cursorword = {
    enable = true,
    min_length = 3,
    hl = { underline = true },
  },
}

local function clear_cursorword_match()
  if w.cursorword_id then
    fn.matchdelete(w.cursorword_id)
    w.cursorword_id = nil
  end
end

local function list_contains(list, target)
  for _, value in ipairs(list) do
    if value == target then
      return true
    end
  end
  return false
end

local function is_disabled_buffer()
  return list_contains(M.options.disable_filetypes, vim.bo.filetype)
    or list_contains(M.options.disable_buftypes, vim.bo.buftype)
end

local function matchadd()
  if is_disabled_buffer() then
    w.cursorword = nil
    clear_cursorword_match()
    return
  end

  local column = a.nvim_win_get_cursor(0)[2]
  local line = a.nvim_get_current_line()
  local cursorword = fn.matchstr(line:sub(1, column + 1), [[\k*$]])
    .. fn.matchstr(line:sub(column + 1), [[^\k*]]):sub(2)

  if cursorword == w.cursorword then
    return
  end
  w.cursorword = cursorword
  clear_cursorword_match()
  if
    cursorword == ""
    or #cursorword > 100
    or #cursorword < M.options.cursorword.min_length
    or string.find(cursorword, "[\192-\255]+") ~= nil
  then
    return
  end
  local pattern = [[\V\<]] .. fn.escape(cursorword, [[\]]) .. [[\>]]
  w.cursorword_id = fn.matchadd("CursorWord", pattern, -1)
end

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", DEFAULT_OPTIONS, options or {})
  local group_id = ag("nvim-cursorline", { clear = true })

  if M.options.cursorline.enable then
    wo.cursorline = not is_disabled_buffer()
    au("WinEnter", {
      group = group_id,
      callback = function()
        wo.cursorline = not is_disabled_buffer()
      end,
    })
    au("WinLeave", {
      group = group_id,
      callback = function()
        wo.cursorline = false
      end,
    })
    au({ "CursorMoved", "CursorMovedI" }, {
      group = group_id,
      callback = function()
        if is_disabled_buffer() then
          timer:stop()
          wo.cursorline = false
          return
        end
        if M.options.cursorline.number then
          wo.cursorline = false
        else
          wo.cursorlineopt = "number"
        end
        timer:start(
          M.options.cursorline.timeout,
          0,
          vim.schedule_wrap(function()
            if M.options.cursorline.number then
              wo.cursorline = true
            else
              wo.cursorlineopt = "both"
            end
          end)
        )
      end,
    })
  end

  if M.options.cursorword.enable then
    au("VimEnter", {
      group = group_id,
      callback = function()
        hl(0, "CursorWord", M.options.cursorword.hl)
        matchadd()
      end,
    })
    au({ "CursorMoved", "CursorMovedI" }, {
      group = group_id,
      callback = function()
        matchadd()
      end,
    })
  end
end

M.options = nil

return M
