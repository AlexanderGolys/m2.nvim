-- lua/m2repl/init.lua
local M = {}


--- @class ReplState
--- @field job_id integer|nil
--- @field output_buf integer|nil
--- @field output_win integer|nil
--- @field debug boolean
M.repl = {
    job_id = nil,
    output_buf = nil,
    output_win = nil,
    pending_code = nil, -- code waiting to be echoed
    debug_mode = false,
    namespace = vim.api.nvim_create_namespace("m2repl")
}


--- Apply tree-sitter highlighting to a range
function M.highlight_range(start_row, end_row, start_col)
    if not M.output_buf_valid() then return end
    local bufnr = M.repl.output_buf

    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "macaulay2")
    if not ok or not parser then return end

    local query_ok, query = pcall(vim.treesitter.query.get, "macaulay2", "highlights")
    if not query_ok or not query then return end

    parser:parse()
    for id, node in query:iter_captures(parser:parse()[1]:root(), bufnr, start_row, end_row) do
        local name = query.captures[id]
        local r1, c1, r2, c2 = node:range()
        c1 = start_col or c1
        if r1 >= start_row and r2 <= end_row then
            pcall(vim.api.nvim_buf_set_extmark, bufnr, M.repl.namespace, r1, c1, {
                end_row = r2,
                end_col = c2,
                hl_group = "@" .. name,
            })
        end
    end
end

--- Checks whether output buffer is valid
--- @return boolean
---
function M.output_buf_valid()
    return M.repl.output_buf ~= nil and vim.api.nvim_buf_is_valid(M.repl.output_buf)
end

function M.get_last_line()
    if not M.output_buf_valid() then return end
    if vim.api.nvim_buf_line_count(M.repl.output_buf) == 0 then return end
    local l = vim.api.nvim_buf_get_lines(M.repl.output_buf, -2, -1, false)[1]
    if vim.api.nvim_buf_line_count(M.repl.output_buf) > 1 and l == "" then 
        return vim.api.nvim_buf_get_lines(M.repl.output_buf, -3, -1, false)[1]
    else 
        return l
    end
end

--- Clean up output lines
--- @return string[]
local function process_output(data)
    local lines = {}
    for _, line in ipairs(data) do
        -- Remove ^M
        -- line = line:gsub("\r", "")
        -- Skip empty lines that are just echoed input
        -- if line ~= "" then
            table.insert(lines, line)
        -- end
    end
    return lines
end

--- Append lines to output buffer
function M.append_output_cell(lines)
    if not M.output_buf_valid() then return end

    local buf = M.repl.output_buf
    local prompt_content = M.get_last_line() or ""
    -- Filter out echoed input (lines that match what we just sent)
    local filtered = {}
    for i, line in ipairs(lines) do
        -- Skip lines that look like raw echoed input
        if i == 1 and prompt_content:match("^i%d+ :") then
            table.insert(filtered, prompt_content .. line)
        else 
            table.insert(filtered, line)
        end
    end

    if #filtered > 0 then
        -- table.insert(filtered, "")
        vim.api.nvim_buf_set_lines(buf, -2, -1, false, filtered)

    end

    -- Auto-scroll
    if M.repl.output_win and vim.api.nvim_win_is_valid(M.repl.output_win) then
        vim.api.nvim_win_set_cursor(M.repl.output_win, { vim.api.nvim_buf_line_count(buf), #M.get_last_line() })
    end
end

--- Send code to M2
local function send_to_m2(code)
    if not M.repl.job_id then
        vim.notify("M2 not running", vim.log.levels.ERROR)
        return
    end

    -- Store for when we see the prompt
    M.repl.pending_code = code

    vim.fn.chansend(M.repl.job_id, code .. "\n\r")
end

--- Handle <CR> in output buffer
local function handle_output_enter()
    local buf = M.repl.output_buf
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_nr = cursor[1]
    local line = vim.api.nvim_buf_get_lines(buf, line_nr - 1, line_nr, false)[1] or ""

    -- Check if we're on a prompt line
    local prompt, code = line:match("^(i%d+ :)(.*)$")
    if prompt and code and code ~= "" then
        send_to_m2(code)
    end
end

--- Start M2 and open output split
function M.start()
    if M.repl.job_id then
        M.stop()
    end

    -- Create output buffer
    M.repl.output_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.repl.output_buf, "[M2 REPL]")
    vim.bo[M.repl.output_buf].filetype = "macaulay2"
    vim.bo[M.repl.output_buf].buftype = "nofile"
    vim.bo[M.repl.output_buf].modifiable = true

    -- Start M2
    M.repl.job_id = vim.fn.jobstart({ "M2", "--no-readline" }, {
        pty = false,
        on_stdout = function(_, data)
            if data then
                vim.schedule(function()
                    local lines = process_output(data)
                    M.append_output_cell(lines)
                end)
            end
        end,
        on_stderr = function(_, data)
            if data then
                vim.schedule(function()
                    local lines = process_output(data)
                    M.append_output_cell(lines)
                end)
            end
        end,
        on_exit = function(_, code)
            vim.schedule(function()
                vim.notify("M2 exited with code " .. code, vim.log.levels.INFO)
                M.repl.job_id = nil
            end)
        end,
    })

    if not M.repl.job_id or M.repl.job_id <= 0 then
        vim.notify("Failed to start M2. Ensure it is installed and on PATH.", vim.log.levels.ERROR)
        if M.repl.output_buf and vim.api.nvim_buf_is_valid(M.repl.output_buf) then
            vim.api.nvim_buf_delete(M.repl.output_buf, { force = true })
        end
        M.repl.output_buf = nil
        M.repl.output_win = nil
        M.repl.job_id = nil
        return
    end

    -- Open split
    vim.cmd("vsplit")
    M.repl.output_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.repl.output_win, M.repl.output_buf)

    -- Keymap for executing from output buffer
    vim.keymap.set("n", "<CR>", handle_output_enter, {
        buffer = M.repl.output_buf,
        desc = "Execute M2 input line",
    })
    vim.keymap.set("i", "<CR>", function()
        vim.cmd("stopinsert")
        handle_output_enter()
    end, {
        buffer = M.repl.output_buf,
        desc = "Execute M2 input line",
    })

    vim.cmd("wincmd p") -- go back to original window

    vim.notify("M2 started", vim.log.levels.INFO)
end

function M.stop()
    if M.repl.job_id then
        vim.fn.jobstop(M.repl.job_id)
        M.repl.job_id = nil
    end
    if M.repl.output_buf and vim.api.nvim_buf_is_valid(M.repl.output_buf) then
        vim.api.nvim_buf_delete(M.repl.output_buf, { force = true })
    end
    M.repl = { job_id = nil, output_buf = nil, output_win = nil,
        pending_code = nil, debug_mode = M.repl.debug_mode }
end

--- Get cell at cursor using tree-sitter
local function get_cell_at_cursor()
    local ok, parser = pcall(vim.treesitter.get_parser, 0, "macaulay2")
    if not ok or not parser then return nil end

    local tree = parser:parse()[1]
    if not tree then return nil end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local node = tree:root():named_descendant_for_range(row, col, row, col)

    while node do
        if node:type() == "cell" then
            return node
        end
        node = node:parent()
    end
    return nil
end

function M.send_cell()
    local cell = get_cell_at_cursor()
    if not cell then
        vim.notify("No cell at cursor", vim.log.levels.WARN)
        return
    end

    local start_row, start_col, end_row, end_col = cell:range()
    local lines = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
    local code = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

    send_to_m2(code .. "\n")
end

function M.clear()
    if M.repl.output_buf and vim.api.nvim_buf_is_valid(M.repl.output_buf) then
        vim.api.nvim_buf_set_lines(M.repl.output_buf, 0, -1, false, {})
        M.repl.prompt_line = nil
    end
end

function M.restart()
    M.stop()
    M.start()
end

function M.debug_toggle()
    M.repl.debug_mode = not M.repl.debug_mode
end

function M.setup(opts)
    opts = opts or {}

    vim.api.nvim_create_user_command("M2Start", M.start, {})
    vim.api.nvim_create_user_command("M2Stop", M.stop, {})
    vim.api.nvim_create_user_command("M2SendCell", M.send_cell, {})
    vim.api.nvim_create_user_command("M2Clear", M.clear, {})


    -- @@@keymaps.M2
    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "macaulay2", "m2" },
        callback = function(ev)
            vim.keymap.set("n", "<leader>ms", M.start, { buffer = ev.buf, desc = "M2 REPL: [S]tart M2" })
            vim.keymap.set("n", "<leader>mc", M.send_cell, { buffer = ev.buf, desc = "M2 REPL: Send [C]ell" })
            vim.keymap.set("n", "<leader>mq", M.stop, { buffer = ev.buf, desc = "M2 REPL: [Q]uit" })
            vim.keymap.set("n", "<leader>mx", M.clear, { buffer = ev.buf, desc = "M2 REPL: Clear output" })
            vim.keymap.set("n", "<leader>mr", M.restart, { buffer = ev.buf, desc = "M2 REPL: [R]estart" })
            vim.keymap.set("n", "<leader>md", M.debug_toggle, { buffer = ev.buf, desc = "M2 REPL: Toggle [D]ebug mode" })
        end,
    })
end

return M
