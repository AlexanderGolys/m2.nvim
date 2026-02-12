local M = {}

M.repl_buf = nil
M.repl_win = nil
M.repl_job_id = nil

---@class ReplOpts
---@field cmd? string
---@field split? "vsplit" | "split" | "tabnew"

---Start or toggle the M2 REPL
---@param opts? ReplOpts
function M.toggle(opts)
  opts = opts or {}
  local cmd = opts.cmd or "M2"
  local split = opts.split or "vsplit"

  -- If REPL buffer exists and is valid
  if M.repl_buf and vim.api.nvim_buf_is_valid(M.repl_buf) then
    -- Check if it's already visible in a window
    local wins = vim.fn.win_findbuf(M.repl_buf)
    if #wins > 0 then
      -- If it's the current window, just close it or switch back?
      -- Usually toggle means close if open, open if closed.
      vim.api.nvim_win_close(wins[1], true)
      M.repl_win = nil
      return
    else
      -- Re-open the existing buffer in a new split
      vim.cmd(split)
      vim.api.nvim_set_current_buf(M.repl_buf)
      M.repl_win = vim.api.nvim_get_current_win()
      return
    end
  end

  -- Create a new REPL
  vim.cmd(split)
  M.repl_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(M.repl_buf)
  M.repl_win = vim.api.nvim_get_current_win()

  -- Start M2 in the terminal
  M.repl_job_id = vim.fn.termopen(cmd, {
    on_exit = function()
      M.repl_buf = nil
      M.repl_win = nil
      M.repl_job_id = nil
    end,
  })

  -- Set some buffer options
  vim.api.nvim_buf_set_name(M.repl_buf, "Macaulay2 REPL")
  vim.api.nvim_set_option_value("filetype", "macaulay2-repl", { buf = M.repl_buf })
end

---Send text to the REPL
---@param text string
function M.send_text(text)
  if not M.repl_job_id then
    M.toggle()
  end
  
  -- Ensure there's a trailing newline
  if not text:match("\n$") then
    text = text .. "\n"
  end
  
  vim.fn.chansend(M.repl_job_id, text)
  
  -- Scroll to the end of the REPL window if it's open
  if M.repl_win and vim.api.nvim_win_is_valid(M.repl_win) then
    local line_count = vim.api.nvim_buf_line_count(M.repl_buf)
    vim.api.nvim_win_set_cursor(M.repl_win, { line_count, 0 })
  end
end

---Send the current line to the REPL
function M.send_line()
  local line = vim.api.nvim_get_current_line()
  M.send_text(line)
end

---Send the visual selection to the REPL
function M.send_selection()
  -- Get the visual selection range
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  local start_line = start_pos[2] - 1
  local end_line = end_pos[2]
  
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  local text = table.concat(lines, "\n")
  M.send_text(text)
end

return M
