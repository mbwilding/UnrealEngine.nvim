local M = {}

local find_uproject_cache = {}
local current_build_job = nil
local job_queue = {}

--- Validates and returns a valid engine path
---@param directory string Directory
function M.find_uproject(directory)
    if find_uproject_cache[directory] then
        return find_uproject_cache[directory]
    end

    local handle, _ = vim.loop.fs_scandir(directory)
    if not handle then
        return nil
    end

    while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then
            break
        end
        if type == "file" and name:match("%.uproject$") then
            local path = directory .. "/" .. name
            find_uproject_cache[directory] = path
            return path
        end
    end

    find_uproject_cache[directory] = nil
    return nil
end

--- Validates and returns a valid engine path
---@param engine_path string Engine path
function M.validate_engine_path(engine_path)
    if engine_path == nil then
        error("engine_path cannot be nil")
    end

    if type(engine_path) ~= "string" then
        error("engine_path must be a string: " .. vim.inspect(engine_path))
    end

    local stat = vim.loop.fs_stat(engine_path)
    if stat and stat.type == "directory" then
        return engine_path
    end

    error("engine_path does not exist or is not a directory: " .. engine_path)
end

--- Registers the Unreal Engine icon for .uproject and .uplugin files
M.register_icon = function()
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
        local icon = "󰦱 "
        local dark = vim.o.background == "dark"

        devicons.set_icon({
            uproject = {
                name = "UnrealEngine",
                icon = icon,
                color = dark and "#ffffff" or "#000000",
            },
            uplugin = {
                name = "UnrealEnginePlugin",
                icon = icon,
                color = "#3399FF",
            },
        })
    end
end

--- Gets the Unreal Engine platform from the detected OS platform
function M.get_platform()
    local platforms = {
        Windows = "Win64",
        Linux = "Linux",
        OSX = "Mac",
    }

    return platforms[jit.os]
end

--- Gets the platform specific build script path
---@param opts UnrealEngine.Opts Options table
function M.get_build_script_path(opts)
    if jit.os == "Windows" then
        return vim.fs.joinpath(opts.engine_path, "Engine", "Build", "BatchFiles", "Build.bat")
    else
        return vim.fs.joinpath(opts.engine_path, "Engine", "Build", "BatchFiles", M.get_platform(), "Build.sh")
    end
end

--- Gets the platform specific RunUAT script path
---@param opts UnrealEngine.Opts Options table
function M.get_uat_script_path(opts)
    if jit.os == "Windows" then
        return vim.fs.joinpath(opts.engine_path, "Engine", "Build", "BatchFiles", "RunUAT.bat")
    else
        return vim.fs.joinpath(opts.engine_path, "Engine", "Build", "BatchFiles", "RunUAT.sh")
    end
end

--- Gets the platform specific engine binary path
---@param opts UnrealEngine.Opts Options table
function M.get_engine_binary_path(opts)
    local binary = jit.os == "Windows" and "UnrealEditor.exe" or "UnrealEditor"
    return vim.fs.joinpath(opts.engine_path, "Engine", "Binaries", M.get_platform(), binary)
end

--- Returns true if the engine at engine_path is a source build
---@param opts UnrealEngine.Opts Options table
function M.is_source_engine(opts)
    return vim.loop.fs_stat(M.get_build_script_path(opts)) ~= nil
end

--- Retrieves information about the .uproject file in the current working directory
---@param uproject_path string|nil mbwilding/launcher.nvim current working directory override
---@return UnrealEngine.UprojectInfo|nil
function M.get_uproject_path_info(uproject_path)
    local cwd = vim.loop.cwd() or vim.fn.getcwd()
    if uproject_path then
        return {
            path = uproject_path,
            name = vim.fn.fnamemodify(uproject_path, ":t:r"),
            cwd = cwd,
        }
    else
        local files = vim.fs.find(function(name)
            return name:match("%.uproject$")
        end, { path = cwd, type = "file", max_depth = 1, limit = 1 })

        if #files > 0 then
            return {
                path = files[1],
                name = vim.fn.fnamemodify(files[1], ":t:r"),
                cwd = cwd,
            }
        end

        return nil
    end
end

--- Creates a symbolic link from src to dst cross-platform
--- If an item already exists at dst, it will be removed
---@param src string Source path
---@param dst string Destination path for the symlink
function M.symlink_file(src, dst)
    local uv = vim.loop

    local src_stat = uv.fs_stat(src)
    if not src_stat then
        error("Source does not exist: " .. src)
    end

    local link_type = src_stat.type

    local dst_lstat = uv.fs_lstat and uv.fs_lstat(dst) or nil
    if dst_lstat and dst_lstat.type == "link" then
        -- If dst is a symlink, check where it points
        local dst_target = uv.fs_readlink(dst)
        if dst_target == src then
            -- Already correct symlink
            return
        else
            -- Remove the incorrect symlink
            local ok, err = uv.fs_unlink(dst)
            if not ok then
                error("Failed to remove existing symlink: " .. err)
            end
        end
    elseif dst_lstat and dst_lstat.type ~= "link" then
        -- If it's a directory or file (not a symlink), remove it
        local ok, err
        if dst_lstat.type == "directory" then
            ok, err = uv.fs_rmdir(dst)
            if not ok then
                error("Failed to remove existing destination directory: " .. err)
            end
        else
            ok, err = uv.fs_unlink(dst)
            if not ok then
                error("Failed to remove existing destination file: " .. err)
            end
        end
    end

    -- On Windows, directories require a symlink flag.
    local symlink_flag = nil
    if jit.os == "Windows" and link_type == "directory" then
        symlink_flag = 1
    end

    local ok, err = uv.fs_symlink(src, dst, symlink_flag)
    if not ok then
        error("Failed to create symlink from " .. src .. " to " .. dst .. ": " .. err)
    end
end

--- Executes the given command in a split buffer
---@param cmd string[] The command and arguments to run
---@param opts UnrealEngine.Opts Options table
---@param on_complete? fun(opts: UnrealEngine.Opts) on_complete
function M.execute_command(cmd, opts, on_complete)
    local original_win = vim.api.nvim_get_current_win()

    local buffer = vim.api.nvim_create_buf(false, true)
    vim.bo[buffer].syntax = nil
    vim.bo[buffer].modified = false

    -- Open the build split without permanently taking focus.
    vim.cmd("botright split")
    local build_win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_is_valid(build_win) then
        vim.api.nvim_win_set_buf(build_win, buffer)
    end

    vim.api.nvim_buf_attach(buffer, false, {
        on_lines = function()
            if vim.api.nvim_win_is_valid(build_win) then
                local total_lines = vim.api.nvim_buf_line_count(buffer)
                vim.api.nvim_win_set_cursor(build_win, { total_lines, 0 })
            end
        end,
    })

    local job_opts = {
        term = true,
        curwin = true,
    }

    if opts.close_on_success then
        job_opts.on_exit = function(_, exit_code, _)
            if exit_code == 0 then
                local win_id = vim.fn.bufwinid(buffer)
                if win_id ~= -1 then
                    vim.schedule(function()
                        vim.api.nvim_win_close(win_id, true)
                    end)
                end
            end
        end
    end

    local user_on_exit = job_opts.on_exit
    job_opts.on_exit = function(job_id, exit_code, event)
        if user_on_exit then
            user_on_exit(job_id, exit_code, event)
        end

        current_build_job = nil
        if #job_queue > 0 then
            local next_job = table.remove(job_queue, 1)
            vim.schedule(function()
                M.execute_build_script(next_job.args, next_job.opts)
            end)
        end

        if exit_code == 0 and on_complete then
            on_complete(opts)
        end
    end

    current_build_job = vim.fn.jobstart(cmd, job_opts)

    vim.schedule(function()
        if vim.api.nvim_win_is_valid(original_win) then
            vim.api.nvim_set_current_win(original_win)
        end
    end)
end

--- Executes the build script with provided args and options
--- If a job is already running, queues the new job
---@param args string[]|nil Extra args to pass to the build script
---@param opts UnrealEngine.Opts Options table.
---@param on_complete? fun(opts: UnrealEngine.Opts) on_complete
function M.execute_build_script(args, opts, on_complete)
    if current_build_job then
        table.insert(job_queue, { args = args, opts = opts })
        return
    end

    if not M.is_source_engine(opts) then
        vim.notify("This command requires a source build of Unreal Engine. For binary installs, use build_plugin() instead.", vim.log.levels.ERROR)
        return
    end

    local script = M.get_build_script_path(opts)
    local uproject = M.get_uproject_path_info(opts.uproject_path)
    if not uproject then
        vim.notify("No uproject found", vim.log.levels.ERROR)
        return
    end

    local cmd = {
        script,
        uproject.name .. "Editor",
        M.get_platform(),
        opts.build_type or "Development",
    }

    if args then
        for _, arg in ipairs(args) do
            -- Args ending in = expect the uproject path appended directly (e.g. -project=)
            if arg:sub(-1) == "=" then
                table.insert(cmd, arg .. uproject.path)
            else
                table.insert(cmd, arg)
            end
        end
    end

    vim.list_extend(cmd, { uproject.path, "-game", "-engine" })

    if opts.with_editor then
        table.insert(cmd, "-Editor")
    end

    local cc_path = vim.fs.joinpath(opts.engine_path, "compile_commands.json")
    if vim.loop.fs_stat(cc_path) then
        table.insert(cmd, "-NoExecCodeGenActions")
    end

    if jit.os == "Windows" then
        cmd = vim.list_extend({ "cmd", "/c" }, cmd)
    end

    M.execute_command(cmd, opts, on_complete)
end

--- Open Unreal Editor, if opts.uproject_path is set, it will launch with that project
---@param opts UnrealEngine.Opts Options table
function M.open_unreal_editor(opts)
    local engine_binary_path = M.get_engine_binary_path(opts)
    local uproject = M.get_uproject_path_info(opts.uproject_path)

    local cmd = { engine_binary_path }
    if uproject then
        table.insert(cmd, uproject.path)
    end

    local job_opts = { detach = true }
    if opts.environment_variables and jit.os ~= "Windows" and next(opts.environment_variables) then
        local env = vim.fn.environ()
        for k, v in pairs(opts.environment_variables) do
            env[k] = v
        end
        job_opts.env = env
    end

    vim.fn.jobstart(cmd, job_opts)
end

--- Cleans the project by deleting generated files
---@param opts UnrealEngine.Opts Options table
function M.clean(opts)
    local uproject = M.get_uproject_path_info(opts.uproject_path)
    if not uproject then
        vim.notify("No uproject found", vim.log.levels.ERROR)
        return
    end

    local root_paths_to_remove = {
        "Binaries",
        "Intermediate",
        "Saved",
        ".vscode",
        ".cache",
        "DerivedDataCache",
        uproject.name .. ".code-workspace",
        "compile_commands.json",
        ".clangd",
    }

    local plugin_paths_to_remove = {
        "Binaries",
        "Intermediate",
    }

    for _, path in ipairs(root_paths_to_remove) do
        local target = vim.fs.joinpath(uproject.cwd, path)
        vim.fn.delete(target, "rf")
    end

    local engine_clangd = vim.fs.joinpath(opts.engine_path, ".clangd")
    vim.fn.delete(engine_clangd, "rf")

    local plugins_dir = vim.fs.joinpath(uproject.cwd, "Plugins")
    if vim.fn.isdirectory(plugins_dir) == 1 then
        local scandir = vim.loop.fs_scandir(plugins_dir)
        if scandir then
            while true do
                local name, type = vim.loop.fs_scandir_next(scandir)
                if not name then
                    break
                end
                local current_object_path = vim.fs.joinpath(plugins_dir, name)
                if type == "directory" then
                    local plugin_path = current_object_path
                    for _, dir in ipairs(plugin_paths_to_remove) do
                        local target = vim.fs.joinpath(plugin_path, dir)
                        vim.fn.delete(target, "rf")
                    end
                else
                    vim.fn.delete(current_object_path, "rf")
                end
            end
        end
    end
end

--- Creates a .clangd file with Unreal Engine includes
---@param project_dir string Project directory path
function M.create_clangd_file(project_dir)
    local clangd_content = [[---
CompileFlags:
  CompilationDatabase: ./
Index:
  Background: Build
]]

    local clangd_path = vim.fs.joinpath(project_dir, ".clangd")
    local file = io.open(clangd_path, "w")
    if file then
        file:write(clangd_content)
        file:close()
    end
end

--- Setup .clangd files before build script execution
---@param opts UnrealEngine.Opts Options table
function M.setup_clangd_files(opts)
    local clangd_file_name = ".clangd"
    local clangd_source = vim.fs.joinpath(opts.engine_path, clangd_file_name)
    local uproject_dir = (opts.uproject_path and vim.fn.fnamemodify(opts.uproject_path, ":h") or vim.loop.cwd())

    M.create_clangd_file(opts.engine_path)
    M.symlink_file(clangd_source, vim.fs.joinpath(uproject_dir, clangd_file_name))
end

--- Link clangd compile_commands.json to project and nested plugins
---@param opts UnrealEngine.Opts Options table
function M.link_clangd_cc(opts)
    local uproject_dir = (opts.uproject_path and vim.fn.fnamemodify(opts.uproject_path, ":h") or vim.loop.cwd())
    local source = vim.fs.joinpath(opts.engine_path, "compile_commands.json")
    M.symlink_file(source, vim.fs.joinpath(uproject_dir, "compile_commands.json"))
end

--- Ensure directory exists (mkdir -p)
---@param dir string
local function ensure_dir(dir)
    if vim.fn.isdirectory(dir) == 1 then
        return
    end
    vim.fn.mkdir(dir, "p")
end

--- Computes plugin source and destination directories
---@param opts UnrealEngine.Opts
---@return string src_dir
---@return string dst_dir
---@return string src_uplugin_path
function M.get_plugin_paths(opts)
    local plugin_name = "NeovimSourceCodeAccess"
    local category = "Developer"

    local this_file = debug.getinfo(1, "S").source
    if vim.startswith(this_file, "@") then
        this_file = this_file:sub(2)
    end
    local repo_root = vim.fn.fnamemodify(this_file, ":h:h:h")

    local src_dir = vim.fs.joinpath(repo_root, "Plugins", plugin_name)
    if not vim.loop.fs_stat(src_dir) then
        error("Plugin source directory not found at: " .. src_dir)
    end

    local dst_dir = vim.fs.joinpath(opts.engine_path, "Engine", "Plugins", category, plugin_name)
    local src_uplugin_path = vim.fs.joinpath(src_dir, plugin_name .. ".uplugin")

    return src_dir, dst_dir, src_uplugin_path
end

--- Returns true if the engine has the plugin symlinked to the given source
---@param opts UnrealEngine.Opts
---@return boolean
function M.is_plugin_symlinked(opts)
    local src_dir, dst_dir = M.get_plugin_paths(opts)
    local lstat = vim.loop.fs_lstat and vim.loop.fs_lstat(dst_dir) or nil
    if not lstat or lstat.type ~= "link" then
        return false
    end
    local dst_target = vim.loop.fs_readlink(dst_dir)
    return dst_target == src_dir
end

--- Ensures the plugin is symlinked into the engine tree
---@param opts UnrealEngine.Opts
function M.link_plugin(opts)
    local src_dir, dst_dir = M.get_plugin_paths(opts)
    ensure_dir(vim.fn.fnamemodify(dst_dir, ":h"))
    M.symlink_file(src_dir, dst_dir)
end

--- Builds just the NeovimSourceCodeAccess plugin using RunUAT BuildPlugin.
--- This is faster than building the full engine and works with binary engine installs.
--- UAT requires -Package= to be outside the engine directory, so we build into
--- src_dir/Build and then symlink that into the engine plugins directory.
---@param opts UnrealEngine.Opts
function M.build_plugin(opts)
    local src_dir, dst_dir, src_uplugin_path = M.get_plugin_paths(opts)

    local build_dir = vim.fs.joinpath(src_dir, "Build")
    ensure_dir(vim.fn.fnamemodify(dst_dir, ":h"))

    local script = M.get_uat_script_path(opts)
    local cmd = { script, "BuildPlugin", "-Plugin=" .. src_uplugin_path, "-Package=" .. build_dir }
    if jit.os == "Windows" then
        cmd = vim.list_extend({ "cmd", "/c" }, cmd)
    end
    M.execute_command(cmd, opts, function()
        M.symlink_file(build_dir, dst_dir)
    end)
end

--- Links plugin and builds the engine editor target which compiles the plugin too.
--- Only call this on source engine installs; use build_plugin() for binary installs.
---@param opts UnrealEngine.Opts
function M.build_engine(opts)
    M.link_plugin(opts)
    local script = M.get_build_script_path(opts)
    local cmd = { script, "UnrealEditor", M.get_platform(), opts.build_type or "Development", "-engine", "-Editor" }
    if jit.os == "Windows" then
        cmd = vim.list_extend({ "cmd", "/c" }, cmd)
    end
    M.execute_command(cmd, opts)
end

return M
