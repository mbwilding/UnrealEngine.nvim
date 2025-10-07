local helpers = require("unrealengine.helpers")

local M = {}

--- Auto generates lsp info when uproject detected in CWD
function M.auto_generate_lsp()
    vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
        callback = function()
            local cwd = vim.loop.cwd() or vim.fn.getcwd()
            local compile_commands_path = cwd .. helpers.slash .. "compile_commands.json"

            -- Check if compile_commands.json exists
            if vim.loop.fs_stat(compile_commands_path) then
                -- Check for Plugins folder and symlink to plugin directories
                local plugins_dir = cwd .. helpers.slash .. "Plugins"
                if vim.loop.fs_stat(plugins_dir) then
                    local handle = vim.loop.fs_scandir(plugins_dir)
                    if handle then
                        while true do
                            local name, type = vim.loop.fs_scandir_next(handle)
                            if not name then
                                break
                            end
                            if type == "directory" then
                                local plugin_path = plugins_dir .. helpers.slash .. name
                                local uplugin_files = vim.fs.find(function(file_name)
                                    return file_name:match(".*%.uplugin$")
                                end, { path = plugin_path, type = "file", max_depth = 1 })

                                -- If .uplugin file found in plugin directory, symlink compile_commands.json
                                if #uplugin_files > 0 then
                                    local target_path = plugin_path .. helpers.slash .. "compile_commands.json"
                                    helpers.symlink_file(compile_commands_path, target_path)
                                end
                            end
                        end
                    end
                end
                return
            end

            local uproject_path = helpers.find_uproject(cwd)
            if uproject_path then
                require("unrealengine.commands").generate_lsp({ uproject_path = uproject_path })
            end
        end,
    })
end

--- Auto builds C++ code on save
function M.auto_build()
    vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = { "*.cpp", "*.h", "*.hpp", "*.cs" },
        callback = function()
            local cwd = vim.loop.cwd() or vim.fn.getcwd()
            local uproject_path = helpers.find_uproject(cwd)
            if uproject_path then
                require("unrealengine.commands").build({ uproject_path = uproject_path })
            end
        end,
    })
end

return M
