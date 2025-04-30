local helpers = require("unrealengine.helpers")


local M = {}

--- Default options
--- @type Opts
local defaults = {
    engine_path = nil,
    platform = helpers.get_platform(),
    register_icon = true,
    close_on_success = true,
}

M.options = defaults

--- Setup
--- @param opts Opts Options table
function M.setup(opts)
    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    M.options = opts

    if opts.register_icon then
        helpers.register_icon()
    end

    if opts.engine_path == nil then
        error("opts.engine_path cannot be nil")
    end

    if type(opts.engine_path) ~= "string" then
        error("opts.engine_path must be a string")
    end
end

return M
