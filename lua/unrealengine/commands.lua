local engine = require("unrealengine")
local helpers = require("unrealengine.helpers")

local M = {}

--- Generates the clangd LSP cache
--- @param opts Opts|nil Options table
function M.generate_lsp(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_build_script("-mode=GenerateClangDatabase -project=", opts)
    local compile_commands_json = "/compile_commands.json"
    helpers.copy_file(opts.engine_path .. compile_commands_json, vim.loop.cwd() .. compile_commands_json)
end

--- Builds the project
--- @param opts Opts|nil Options table
function M.build(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_build_script(nil, opts)
end

return M
