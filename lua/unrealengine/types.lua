---@alias BuildType
---| "DebugGame"
---| "Development"
---| "Shipping"

--- The options for UnrealEngine.nvim
---@class Opts
---@field engine_path string|nil The path to the source version of Unreal Engine
---@field build_type BuildType|nil The type of build
---@field with_editor boolean|nil If you are also building the editor
---@field platform string|nil The Unreal Engine platform - Will be set automatically if not specified
---@field register_icon boolean|nil Registers the Unreal Engine icon for .uproject files
---@field close_on_success boolean|nil Close the terminal split automatically when the command is successful

--- Information about the project
--- @class UprojectInfo
--- @field path string Full path to the .uproject file
--- @field name string The project name derived from the file name (without extension)
