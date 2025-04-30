local helpers = require("unrealengine.helpers")


local M = {}

--- The options for UnrealEngine.nvim
---@class Opts
---@field engine_path string|nil The path to the source version of Unreal Engine
---@field platform string|nil The Unreal Engine platform - Will be set automatically if not specified
---@field register_icon boolean|nil Registers the Unreal Engine icon for .uproject files
---@field close_on_success boolean|nil Close the terminal split automatically when the command is successful

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
