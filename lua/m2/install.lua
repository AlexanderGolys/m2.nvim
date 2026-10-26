local M = {}

local parser_repository = "https://github.com/AlexanderGolys/tree-sitter-macaulay2"
local parser_release = "v6.3.2"
local data_directory = vim.fn.stdpath("data") .. "/m2.nvim"
local parser_directory = data_directory .. "/" .. parser_release
local cargo_directory = data_directory .. "/cargo"
local executable_suffix = vim.fn.has("win32") == 1 and ".exe" or ""
local server_path = cargo_directory .. "/bin/m2-ls" .. executable_suffix
local running = {}
local options = {}
local server_configured = false

local function has_external_server()
  for _, name in ipairs({ "m2-ls", "m2_ls" }) do
    if (name ~= "m2_ls" or not server_configured) and vim.lsp.config[name] then
      return true
    end
  end
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name ~= "m2_ls" or not server_configured then
      local command = client.config.cmd
      if client.name == "m2-ls" or client.name == "m2_ls"
        or (type(command) == "table" and type(command[1]) == "string"
          and vim.fs.basename(command[1]):gsub("%.exe$", "") == "m2-ls") then
        return true
      end
    end
  end
  return false
end

---@param message string
local function report_error(message)
  vim.notify("m2.nvim: " .. message, vim.log.levels.ERROR)
end

---@param command string[]
---@param callback fun(success: boolean)
local function run(command, callback)
  local ok, err = pcall(vim.system, command, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        report_error(table.concat(command, " ") .. " failed:\n" .. (result.stderr or ""))
      end
      callback(result.code == 0)
    end)
  end)
  if not ok then
    report_error(tostring(err))
    callback(false)
  end
end

local function enable_server()
  if not options.lsp or has_external_server() then
    if server_configured then
      vim.lsp.enable("m2_ls", false)
    end
    return false
  end
  local config = type(options.lsp) == "table" and options.lsp or {}
  local executable = vim.fn.executable(server_path) == 1 and server_path or "m2-ls"
  config = vim.tbl_deep_extend("force", {
    cmd = { executable },
    filetypes = { "macaulay2" },
    root_markers = { ".git" },
    settings = { ["m2-ls"] = {} },
  }, config)
  vim.lsp.config("m2_ls", config)
  server_configured = true
  if type(config.cmd) == "function" or vim.fn.executable(config.cmd[1]) == 1 then
    vim.lsp.enable("m2_ls")
  end
  return true
end

local function start_highlighting()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].filetype == "macaulay2" then
      pcall(vim.treesitter.start, buffer)
    end
  end
end

--- Load the installed parser before source highlighting starts.
---@return boolean loaded
function M.load_parser()
  if vim.fn.filereadable(parser_directory .. "/installed") == 1
    and vim.fn.filereadable(parser_directory .. "/parser/macaulay2.so") == 1
    and vim.fn.filereadable(parser_directory .. "/queries/macaulay2/highlights.scm") == 1 then
    vim.opt.runtimepath:prepend(parser_directory)
    return true
  end
  return false
end

local function install_parser()
  if M.load_parser() then
    start_highlighting()
    return
  end
  if not options.install or running.parser then
    return
  end
  for _, executable in ipairs({ "git", "tree-sitter" }) do
    if vim.fn.executable(executable) == 0 then
      report_error("Install " .. executable .. " and a C compiler, then run :M2Install")
      return
    end
  end

  running.parser = true
  local source_directory = vim.fn.tempname()
  local function finish()
    vim.fn.delete(source_directory, "rf")
    running.parser = nil
  end
  vim.notify("m2.nvim: installing Macaulay2 parser " .. parser_release)
  run({ "git", "clone", "--depth", "1", "--branch", parser_release, parser_repository, source_directory }, function(cloned)
    if not cloned then
      finish()
      return
    end
    vim.fn.mkdir(parser_directory .. "/parser", "p")
    vim.fn.mkdir(parser_directory .. "/queries/macaulay2", "p")
    run({ "tree-sitter", "build", "--output", parser_directory .. "/parser/macaulay2.so", source_directory }, function(built)
      if built then
        for name, kind in vim.fs.dir(source_directory .. "/queries") do
          if kind == "file" and name:match("%.scm$") then
            local copied, err = vim.uv.fs_copyfile(
              source_directory .. "/queries/" .. name,
              parser_directory .. "/queries/macaulay2/" .. name
            )
            if not copied then
              report_error(tostring(err))
              finish()
              return
            end
          end
        end
        vim.fn.writefile({ parser_release }, parser_directory .. "/installed")
        M.load_parser()
        start_highlighting()
        vim.notify("m2.nvim: Macaulay2 parser installed")
      end
      finish()
    end)
  end)
end

local function install_server()
  if not enable_server() or not options.install or running.server then
    return
  end
  local config = type(options.lsp) == "table" and options.lsp or {}
  if config.cmd or vim.fn.executable(server_path) == 1 or vim.fn.executable("m2-ls") == 1 then
    return
  end
  if vim.fn.executable("cargo") == 0 then
    report_error("Install Rust and Cargo, then run :M2Install")
    return
  end
  running.server = true
  vim.notify("m2.nvim: installing m2-ls from crates.io")
  run({ "cargo", "install", "--locked", "--root", cargo_directory, "m2-ls" }, function(installed)
    running.server = nil
    if installed then
      enable_server()
      vim.notify("m2.nvim: m2-ls installed")
    end
  end)
end

---@param opts M2Opts
function M.setup(opts)
  options = opts
  if options.parser then
    install_parser()
  end
  install_server()
end

return M
