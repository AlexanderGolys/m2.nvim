-- lua/m2_term.lua
-- Minimal Macaulay2 terminal helper: a real M2 process in a split, with
-- commands to send the tree-sitter cell, the current line, or a visual
-- selection. No external UI dependency.
local M = {}

--- @class TermSession
--- @field term_buf integer|nil  buffer hosting the M2 terminal
--- @field win integer|nil       window showing the terminal (when open)
--- @field job_id integer|nil    terminal channel / job id for sending input
local TermSession = {}
TermSession.__index = TermSession

--- @return TermSession
function TermSession.new()
    return setmetatable({}, TermSession)
end

--- Extract the tree-sitter `cell` node text under the cursor in `buf`.
--- Operates on whichever window is current when called.
--- @param buf integer
--- @return string|nil
local function cell_text_from_buf(buf)
    local ok, parser = pcall(vim.treesitter.get_parser, buf, "macaulay2")
    if not ok or not parser then return nil end
    local tree = parser:parse()[1]
    if not tree then return nil end
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local node = tree:root():named_descendant_for_range(row, col, row, col)
    while node do
        if node:type() == "cell" then
            local sr, sc, er, ec = node:range()
            local lines = vim.api.nvim_buf_get_text(buf, sr, sc, er, ec, {})
            return table.concat(lines, "\n")
        end
        node = node:parent()
    end
    return nil
end

--- @return boolean
function TermSession:is_open()
    return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

--- @return boolean
function TermSession:term_buf_valid()
    return self.term_buf ~= nil and vim.api.nvim_buf_is_valid(self.term_buf)
end

--- Start M2 in a new terminal buffer hosted in a vertical split.
function TermSession:start()
    local source_win = vim.api.nvim_get_current_win()
    vim.cmd("botright vsplit")
    self.win = vim.api.nvim_get_current_win()
    self.term_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(self.win, self.term_buf)
    self.job_id = vim.fn.jobstart({ "M2" }, {
        term = true,
        on_exit = function(_, code)
            vim.schedule(function()
                vim.notify("M2 exited (code " .. code .. ")", vim.log.levels.INFO)
                M._session = nil
            end)
        end,
    })
    if not self.job_id or self.job_id <= 0 then
        vim.notify("Failed to start M2. Is it installed and on PATH?", vim.log.levels.ERROR)
        if self:term_buf_valid() then
            vim.api.nvim_buf_delete(self.term_buf, { force = true })
        end
        self.term_buf, self.win, self.job_id = nil, nil, nil
        return
    end
    vim.api.nvim_set_current_win(source_win)
end

--- Show the existing terminal buffer in a split (without restarting M2).
function TermSession:show()
    if self:is_open() then return end
    local source_win = vim.api.nvim_get_current_win()
    vim.cmd("botright vsplit")
    self.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.win, self.term_buf)
    vim.api.nvim_set_current_win(source_win)
end

--- Open (or focus) the M2 terminal.
function TermSession:open()
    if self:is_open() then
        vim.api.nvim_set_current_win(self.win)
        return
    end
    if self:term_buf_valid() and self.job_id then
        self:show()
    else
        self:start()
    end
end

--- Hide the terminal window if open, otherwise show it. Keeps M2 running.
function TermSession:toggle()
    if self:is_open() then
        vim.api.nvim_win_close(self.win, false)
        self.win = nil
        return
    end
    if self:term_buf_valid() and self.job_id then
        self:show()
    else
        self:start()
    end
end

--- Stop M2 and tear down the terminal.
function TermSession:close()
    if self.job_id then
        vim.fn.jobstop(self.job_id)
    end
    if self:is_open() then
        vim.api.nvim_win_close(self.win, true)
    end
    if self:term_buf_valid() then
        vim.api.nvim_buf_delete(self.term_buf, { force = true })
    end
    M._session = nil
end

--- Send a string to the running M2 process, ensuring a trailing newline.
--- @param code string
function TermSession:send(code)
    if not self.job_id then
        vim.notify("M2 terminal not running", vim.log.levels.ERROR)
        return
    end
    if not code:sub(-1):match("\n") then
        code = code .. "\n"
    end
    vim.api.nvim_chan_send(self.job_id, code)
end

-- ---------------------------------------------------------------------------
-- Module-level singleton session + public API
-- ---------------------------------------------------------------------------

--- @type TermSession|nil
M._session = nil

--- @return TermSession
local function get_session()
    if not M._session then
        M._session = TermSession.new()
    end
    return M._session
end

function M.open()
    get_session():open()
end

function M.toggle()
    get_session():toggle()
end

function M.close()
    if M._session then M._session:close() end
end

--- Send the tree-sitter cell under the cursor to M2 (opening it if needed).
function M.send_cell()
    local buf = vim.api.nvim_get_current_buf()
    local text = cell_text_from_buf(buf)
    if not text then
        vim.notify("No M2 cell at cursor", vim.log.levels.WARN)
        return
    end
    local session = get_session()
    session:open()
    session:send(text)
end

--- Send the current line to M2.
function M.send_line()
    local line = vim.api.nvim_get_current_line()
    if line:match("^%s*$") then return end
    local session = get_session()
    session:open()
    session:send(line)
end

--- Send the last visual selection (linewise) to M2.
function M.send_visual()
    local start_row = vim.fn.line("'<")
    local end_row = vim.fn.line("'>")
    if start_row == 0 or end_row == 0 then return end
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
    local session = get_session()
    session:open()
    session:send(table.concat(lines, "\n"))
end

-- ---------------------------------------------------------------------------
-- Setup: commands + keymaps
-- ---------------------------------------------------------------------------

--- Default keymaps, keyed by action. Override any entry (or set it to `false`
--- to drop just that mapping) via `opts.keys`; pass `opts.keys = false` to
--- register no keymaps at all.
--- @type table<string, string|false>
local default_keys = {
    open        = "<leader>mo",
    toggle      = "<leader>mt",
    close       = "<leader>mq",
    send_cell   = "<leader>mc",
    send_line   = "<leader>ml",
    send_visual = "<leader>mc",
}

--- Action -> (handler, mode, description), in registration order.
local key_actions = {
    { name = "open",        rhs = M.open,        mode = "n", desc = "M2 Term: [O]pen" },
    { name = "toggle",      rhs = M.toggle,      mode = "n", desc = "M2 Term: [T]oggle window" },
    { name = "close",       rhs = M.close,       mode = "n", desc = "M2 Term: [Q]uit" },
    { name = "send_cell",   rhs = M.send_cell,   mode = "n", desc = "M2 Term: Send [C]ell" },
    { name = "send_line",   rhs = M.send_line,   mode = "n", desc = "M2 Term: Send [L]ine" },
    { name = "send_visual", rhs = M.send_visual, mode = "x", desc = "M2 Term: Send selection" },
}

--- @class M2TermOpts
--- @field keys? table<string, string|false>|false Keymap overrides (see `default_keys`), or false to disable all.

--- @param opts? M2TermOpts
function M.setup(opts)
    opts = opts or {}

    vim.api.nvim_create_user_command("M2TermOpen",     function() M.open() end,        { desc = "Open M2 terminal" })
    vim.api.nvim_create_user_command("M2TermToggle",   function() M.toggle() end,      { desc = "Toggle M2 terminal window" })
    vim.api.nvim_create_user_command("M2TermClose",    function() M.close() end,       { desc = "Close M2 terminal" })
    vim.api.nvim_create_user_command("M2TermSendCell", function() M.send_cell() end,   { desc = "Send M2 cell under cursor" })
    vim.api.nvim_create_user_command("M2TermSendLine", function() M.send_line() end,   { desc = "Send current line to M2" })
    vim.api.nvim_create_user_command("M2TermSend",     function() M.send_visual() end, { desc = "Send selection to M2", range = true })

    if opts.keys == false then return end
    local keys = vim.tbl_extend("force", default_keys, opts.keys or {})
    for _, action in ipairs(key_actions) do
        local lhs = keys[action.name]
        if lhs then
            vim.keymap.set(action.mode, lhs, action.rhs, { desc = action.desc })
        end
    end
end

return M
