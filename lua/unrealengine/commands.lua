local engine = require("unrealengine")
local helpers = require("unrealengine.helpers")

local M = {}

--- Generates the clangd LSP cache
--- @param opts Opts|nil Options table
function M.generate_lsp(opts)
    ---@type Opts Options table
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    local uproject = helpers.get_uproject_path_info()

    local script = helpers.get_build_script_path(opts)
    local args = ' -mode=GenerateClangDatabase -project="'
        .. uproject.path
        .. '" -game -engine '
        .. uproject.name
        .. "Editor "
        .. opts.platform
        .. " Development"

    helpers.execute_command(script .. args, opts)

    local compile_commands_json = "/compile_commands.json"
    helpers.copy_file(opts.engine_path .. compile_commands_json, vim.loop.cwd() .. compile_commands_json)
end

--- Builds the project
--- @param opts Opts|nil Options table
function M.build(opts)
    ---@type Opts Options table
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    local uproject = helpers.get_uproject_path_info()

    local script = helpers.get_build_script_path(opts)
    local args = ' "'
        .. uproject.path
        .. '" -game -engine '
        .. uproject.name
        .. "Editor "
        .. opts.platform
        .. " Development"

    helpers.execute_command(script .. args, opts)
end

return M
