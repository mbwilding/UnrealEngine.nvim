local engine = require("unrealengine")
local helpers = require("unrealengine.helpers")

local M = {}

--- Generates the clangd LSP cache
--- @param opts Opts|nil Options table
function M.generate_lsp(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_build_script("-mode=GenerateClangDatabase -project=", opts)
    local cc_file = "compile_commands.json"
    cc_file = jit.os == "Windows" and "\\" .. cc_file or "/" .. cc_file

    helpers.copy_file(
        opts.engine_path .. cc_file,
        (opts.uproject_path and vim.fn.fnamemodify(opts.uproject_path, ":h") or vim.loop.cwd()) .. cc_file
    )
end

--- Builds the project
--- @param opts Opts|nil Options table
function M.build(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_build_script(nil, opts)
end

--- Cleans the project by deleting build and config directories
--- @param opts Opts|nil Options table
function M.clean(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    local uproject = helpers.get_uproject_path_info(opts.uproject_path)
    local paths_to_remove = {
        "Binaries",
        "Intermediate",
        "Saved",
        ".vscode",
        ".cache",
        "DerivedDataCache",
        uproject.name .. ".code-workspace",
        "compile_commands.json",
    }

    for _, path in ipairs(paths_to_remove) do
        local target = uproject.cwd .. "/" .. path
        vim.fn.delete(target, "rf")
    end
end

return M
