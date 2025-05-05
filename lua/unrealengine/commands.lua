local engine = require("unrealengine")
local helpers = require("unrealengine.helpers")

local M = {}

--- Generates the clangd LSP cache
--- @param opts UnrealEngine.Opts|nil Options table
function M.generate_lsp(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_build_script("-mode=GenerateClangDatabase -project=", opts)
    local cc_file = "compile_commands.json"
    cc_file = helpers.platform_slash .. cc_file

    local source = opts.engine_path .. cc_file
    local uproject_dir = (opts.uproject_path and vim.fn.fnamemodify(opts.uproject_path, ":h") or vim.loop.cwd())

    helpers.copy_file(source, uproject_dir .. cc_file)

    local plugin_dir = uproject_dir .. helpers.platform_slash .. "Plugins"
    local uplugin_files = vim.fs.find(function(name)
        return name:match(".*%.uplugin$")
    end, { path = plugin_dir, type = "file", limit = math.huge })
    for _, uplugin_file in ipairs(uplugin_files) do
        local uplugin_dir = vim.fn.fnamemodify(uplugin_file, ":h")
        local current_plugin_dir = uplugin_dir .. cc_file

        helpers.copy_file(source, current_plugin_dir)
    end
end

--- Builds the project
--- @param opts UnrealEngine.Opts|nil Options table
function M.build(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    helpers.execute_build_script(nil, opts)
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

--- Cleans the project by deleting build and config directories
--- @param opts UnrealEngine.Opts|nil Options table
function M.clean(opts)
    opts = vim.tbl_deep_extend("force", engine.options, opts or {})
    local uproject = helpers.get_uproject_path_info(opts.uproject_path)

    local root_paths_to_remove = {
        "Binaries",
        "Intermediate",
        "Saved",
        ".vscode",
        ".cache",
        "DerivedDataCache",
        uproject.name .. ".code-workspace",
    }

    local plugin_dirs_to_remove = {
        "Binaries",
        "Intermediate",
        ".cache",
    }

    for _, path in ipairs(root_paths_to_remove) do
        local target = uproject.cwd .. "/" .. path
        vim.fn.delete(target, "rf")
    end

    local plugins_dir = uproject.cwd .. "/Plugins"
    if vim.fn.isdirectory(plugins_dir) == 1 then
        local scandir = vim.loop.fs_scandir(plugins_dir)
        if scandir then
            while true do
                local name, type = vim.loop.fs_scandir_next(scandir)
                if not name then
                    break
                end
                if type == "directory" then
                    local plugin_path = plugins_dir .. "/" .. name
                    for _, dir in ipairs(plugin_dirs_to_remove) do
                        local target = plugin_path .. "/" .. dir
                        vim.fn.delete(target, "rf")
                    end
                end
            end
        else
            vim.notify("Could not scan Plugins directory", vim.log.levels.ERROR)
        end
    end
end

return M
