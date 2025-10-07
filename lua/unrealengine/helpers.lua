local M = {}

--- Platform slash
M.slash = jit.os == "Windows" and "\\" or "/"

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
---@param engine_path string|table<string> Engine path
function M.validate_engine_path(engine_path)
    if engine_path == nil then
        error("engine_path cannot be nil")
    end

    if type(engine_path) ~= "string" and type(engine_path) ~= "table" then
        error("engine_path must be a string or table of strings: " .. vim.inspect(engine_path))
    end

    if type(engine_path) == "table" then
        for _, path in ipairs(engine_path) do
            if type(path) ~= "string" then
                error("engine_path table must contain only strings: " .. vim.inspect(path))
            end
        end
    end

    if type(engine_path) == "string" then
        local stat = vim.loop.fs_stat(engine_path)
        if stat and stat.type == "directory" then
            return engine_path
        end
    end

    if type(engine_path) == "table" then
        for _, path in ipairs(engine_path) do
            if type(path) ~= "string" then
                error("engine_path element is not a string: " .. tostring(path))
            end

            local stat = vim.loop.fs_stat(path)
            if stat and stat.type == "directory" then
                return path
            end
        end
    end

    -- error("engine_path is invalid: " .. vim.inspect(engine_path))
    return nil
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
        return opts.engine_path .. "\\Engine\\Build\\BatchFiles\\Build.bat"
    else
        return opts.engine_path .. "/Engine/Build/BatchFiles/" .. M.get_platform() .. "/Build.sh"
    end
end

--- Gets the platform specific engine binary
---@param opts UnrealEngine.Opts Options table
function M.get_engine_binary_path(opts)
    if jit.os == "Windows" then
        return opts.engine_path .. "\\Engine\\Binaries\\" .. M.get_platform() .. "\\UnrealEditor.exe"
    else
        return opts.engine_path .. "/Engine/Binaries/" .. M.get_platform() .. "/UnrealEditor"
    end
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
        end, { path = cwd, max_depth = 1 })

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

--- Wraps the string in "
---@param value string The value to wrap in "
function M.wrap(value)
    if value == nil or value == "" then
        return ""
    end
    return '"' .. value .. '"'
end

--- Executes the given command in a split buffer
---@param cmd string The command to run
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

        if on_complete then
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
---@param args string|nil The script args
---@param opts UnrealEngine.Opts Options table.
---@param on_complete? fun(opts: UnrealEngine.Opts) on_complete
function M.execute_build_script(args, opts, on_complete)
    if current_build_job then
        table.insert(job_queue, { args = args, opts = opts })
        return
    end

    local script = M.get_build_script_path(opts)
    local uproject = M.get_uproject_path_info(opts.uproject_path)
    if not uproject then
        vim.notify("No uproject found", error)
        return
    end

    local cmd = {
        M.wrap(script),
        M.wrap(uproject.name .. "Editor"),
        opts.platform,
        opts.build_type,
        (args or "") .. M.wrap(uproject.path),
        "-game -engine",
        (opts.with_editor and "-Editor " or ""),
    }

    local cc_path = opts.engine_path .. M.slash .. "compile_commands.json"
    if vim.loop.fs_stat(cc_path) then
        table.insert(cmd, "-NoExecCodeGenActions")
    end

    local formatted_cmd = table.concat(cmd, " ")

    M.execute_command((jit.os == "Windows") and ("cmd /c " .. formatted_cmd) or formatted_cmd, opts, on_complete)
end

--- Open Unreal Editor, if opts.uproject_path is set, it will launch with that project
---@param opts UnrealEngine.Opts Options table
function M.open_unreal_editor(opts)
    local engine_binary_path = M.get_engine_binary_path(opts)
    local uproject = M.get_uproject_path_info(opts.uproject_path)

    ---@type string
    local cmd
    if uproject then
        cmd = table.concat({
            M.wrap(engine_binary_path),
            M.wrap(uproject.path),
        }, " ")
    else
        cmd = M.wrap(engine_binary_path)
    end

    local environment_variables = ""
    if opts.environment_variables and jit.os ~= "Windows" then
        for k, v in pairs(opts.environment_variables) do
            environment_variables = environment_variables .. k .. '="' .. v .. '" '
        end
    end

    if environment_variables then
        cmd = environment_variables .. cmd
    end

    -- Start remote server
    M.remote_start()
    -- Start Unreal Engine
    vim.fn.jobstart(cmd, { detach = true })
end

--- Cleans the project by deleting generated files
---@param opts UnrealEngine.Opts Options table
function M.clean(opts)
    local uproject = M.get_uproject_path_info(opts.uproject_path)
    if not uproject then
        vim.notify("No uproject found", error)
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
        ".cache",
        "compile_commands.json",
        ".clangd",
    }

    for _, path in ipairs(root_paths_to_remove) do
        local target = uproject.cwd .. M.slash .. path
        vim.fn.delete(target, "rf")
    end

    -- Clean .clangd file from engine directory
    local engine_clangd = opts.engine_path .. M.slash .. ".clangd"
    vim.fn.delete(engine_clangd, "rf")

    local plugins_dir = uproject.cwd .. M.slash .. "Plugins"
    if vim.fn.isdirectory(plugins_dir) == 1 then
        local scandir = vim.loop.fs_scandir(plugins_dir)
        if scandir then
            while true do
                local name, type = vim.loop.fs_scandir_next(scandir)
                if not name then
                    break
                end
                local current_object_path = plugins_dir .. M.slash .. name
                if type == "directory" then
                    local plugin_path = current_object_path
                    for _, dir in ipairs(plugin_paths_to_remove) do
                        local target = plugin_path .. M.slash .. dir
                        vim.fn.delete(target, "rf")
                    end
                else
                    vim.fn.delete(current_object_path, "rf")
                end
            end
        else
            vim.notify("Could not scan Plugins directory", vim.log.levels.ERROR)
        end
    end
end

--- Creates a .clangd file with Unreal Engine includes
---@param project_dir string Project directory path
function M.create_clangd_file(project_dir)
    local clangd_content = [[CompileFlags:
Add: [-include, CoreMinimal.h, -include, EngineMinimal.h]
]]

    local clangd_path = project_dir .. M.slash .. ".clangd"
    local file = io.open(clangd_path, "w")
    if file then
        file:write(clangd_content)
        file:close()
    end
end

--- Setup .clangd files before build script execution
---@param opts UnrealEngine.Opts Options table
function M.setup_clangd_files(opts)
    local clangd_file = ".clangd"
    local clangd_source = opts.engine_path .. M.slash .. clangd_file
    local uproject_dir = (opts.uproject_path and vim.fn.fnamemodify(opts.uproject_path, ":h") or vim.loop.cwd())

    -- Create .clangd file in engine directory first
    M.create_clangd_file(opts.engine_path)

    -- Symlink .clangd file to project root
    M.symlink_file(clangd_source, uproject_dir .. M.slash .. clangd_file)

    local plugin_dir = uproject_dir .. M.slash .. "Plugins"
    local uplugin_files = vim.fs.find(function(name)
        return name:match(".*%.uplugin$")
    end, { path = plugin_dir, type = "file", limit = math.huge })
    for _, uplugin_file in ipairs(uplugin_files) do
        local uplugin_dir = vim.fn.fnamemodify(uplugin_file, ":h")
        local current_plugin_clangd = uplugin_dir .. M.slash .. clangd_file

        -- Symlink .clangd file to plugin directory
        M.symlink_file(clangd_source, current_plugin_clangd)
    end
end

--- Link clangd compile_commands.json to project and nested plugins
---@param opts UnrealEngine.Opts Options table
function M.link_clangd_cc(opts)
    local cc_file = "compile_commands.json"
    cc_file = M.slash .. cc_file

    local source = opts.engine_path .. cc_file
    local uproject_dir = (opts.uproject_path and vim.fn.fnamemodify(opts.uproject_path, ":h") or vim.loop.cwd())

    -- Symlink compile_commands.json to project root
    M.symlink_file(source, uproject_dir .. cc_file)

    local plugin_dir = uproject_dir .. M.slash .. "Plugins"
    local uplugin_files = vim.fs.find(function(name)
        return name:match(".*%.uplugin$")
    end, { path = plugin_dir, type = "file", limit = math.huge })
    for _, uplugin_file in ipairs(uplugin_files) do
        local uplugin_dir = vim.fn.fnamemodify(uplugin_file, ":h")
        local current_plugin_dir = uplugin_dir .. cc_file

        -- Symlink compile_commands.json to plugin directory
        M.symlink_file(source, current_plugin_dir)
    end
end

--- Start the remote control server
function M.remote_start()
    if (vim.v.servername == nil or vim.v.servername == "") then
        pcall(function()
            vim.fn.serverstart(vim.fn.tempname())
        end)
    end
end

return M
