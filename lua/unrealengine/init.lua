local helpers = require("unrealengine.helpers")

local M = {}

--- Default options
--- @type UnrealEngine.Opts
local defaults = {
    engine_path = nil,
    build_type = "Development",
    with_editor = false,
    platform = helpers.get_platform(),
    register_icon = true,
    close_on_success = true,
    uproject_path = nil,
    auto_generate = false,
    auto_build = false,
}

M.options = defaults

--- Setup
--- @param opts UnrealEngine.Opts Options table
function M.setup(opts)
    local engine_path = helpers.validate_engine_path(opts.engine_path)
    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    opts.engine_path = engine_path
    M.options = opts

    if opts.register_icon then
        helpers.register_icon()
    end

    if opts.auto_generate then
        require("unrealengine.autocommands").auto_generate_lsp()
    end

    if opts.auto_build then
        require("unrealengine.autocommands").auto_build()
    end
end

return M
