local M = {}

local find_uproject_cache = {}
local current_build_job = nil
local job_queue = {}

--- Validates and returns a valid engine path
--- @param directory string Directory
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
--- @param engine_path string|table<string> Engine path
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

--- Registers the Unreal Engine icon for .uproject files
M.register_icon = function()
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
        local icons = (devicons.get_icons and devicons.get_icons()) or devicons.icons or {}
        if icons["uproject"] then
            return
        end

        devicons.set_icon({
            uproject = {
                name = "UnrealEngine",
                icon = "󰦱 ",
                color = vim.o.background == "dark" and "#ffffff" or "#000000",
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
--- @param opts UnrealEngine.Opts Options table
function M.get_build_script_path(opts)
    if jit.os == "Windows" then
        return opts.engine_path .. "\\Engine\\Build\\BatchFiles\\Build.bat"
    else
        return opts.engine_path .. "/Engine/Build/BatchFiles/" .. M.get_platform() .. "/Build.sh"
    end
end

--- Gets the platform specific engine binary
--- @param opts UnrealEngine.Opts Options table
function M.get_engine_binary_path(opts)
    if jit.os == "Windows" then
        return opts.engine_path .. "\\Engine\\Binaries\\" .. M.get_platform() .. "\\UnrealEditor.exe"
    else
        return opts.engine_path .. "/Engine/Binaries/" .. M.get_platform() .. "/UnrealEditor"
    end
end

--- Retrieves information about the .uproject file in the current working directory
--- @param uproject_path string|nil mbwilding/launcher.nvim current working directory override
--- @return UnrealEngine.UprojectInfo
--- @throws An error if no .uproject file is found in the current working directory
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

        error("No .uproject file found in the current working directory (" .. cwd .. ")")
    end
end

--- Copies a file from source to destination
--- @param src string Source path
--- @param dst string Destination path
function M.copy_file(src, dst)
    local input = assert(io.open(src, "rb"))
    local content = input:read("*all")
    input:close()

    local output = assert(io.open(dst, "wb"))
    output:write(content)
    output:close()
end

--- Wraps the string in "
--- @param value string The value to wrap in "
function M.wrap(value)
    if value == nil or value == "" then
        return ""
    end
    return '"' .. value .. '"'
end

--- Executes the given command in a split buffer
--- @param cmd string The command to run
--- @param opts UnrealEngine.Opts Options table
function M.execute_command(cmd, opts)
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
--- @param args string|nil The script args
--- @param opts UnrealEngine.Opts Options table.
function M.execute_build_script(args, opts)
    if current_build_job then
        table.insert(job_queue, { args = args, opts = opts })
        return
    end

    local script = M.get_build_script_path(opts)
    local uproject = M.get_uproject_path_info(opts.uproject_path)
    local formatted_cmd = table.concat({
        M.wrap(script),
        M.wrap(uproject.name .. "Editor"),
        opts.platform,
        opts.build_type,
        (args or "") .. M.wrap(uproject.path),
        "-game -engine",
        (opts.with_editor and "-Editor " or ""),
    }, " ")

    local cmd = (jit.os == "Windows") and ("cmd /c " .. formatted_cmd) or formatted_cmd
    M.execute_command(cmd, opts)
end

function M.execute_engine(opts)
    local engine_binary_path = M.get_engine_binary_path(opts)
    local uproject = M.get_uproject_path_info(opts.uproject_path)
    local cmd = table.concat({
        M.wrap(engine_binary_path),
        M.wrap(uproject.path),
    }, " ")
    vim.fn.jobstart(cmd, { detach = true })
end

return M
