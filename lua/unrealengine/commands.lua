local engine = require("unrealengine")
local helpers = require("unrealengine.helpers")

local M = {}

--- Generates the clangd LSP cache
--- @param opts UnrealEngine.Opts|nil Options table
function M.generate_lsp(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_build_script("-mode=GenerateClangDatabase -project=", opts, helpers.link_clangd_cc)
end

--- Builds the project
--- @param opts UnrealEngine.Opts|nil Options table
function M.build(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_build_script(nil, opts)
    M.generate_lsp(opts)
end

--- Opens the project in UE
--- @param opts UnrealEngine.Opts|nil Options table
function M.open(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_engine(opts)
end

--- Rebuilds the project (clean and build)
--- @param opts UnrealEngine.Opts|nil Options table
function M.rebuild(opts)
    M.clean(opts)
    M.build(opts)
end

--- Cleans the project by deleting generated files
--- @param opts UnrealEngine.Opts|nil Options table
function M.clean(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.clean(opts)
end

return M
