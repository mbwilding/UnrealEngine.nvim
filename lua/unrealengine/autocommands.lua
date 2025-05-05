local helpers = require("unrealengine.helpers")

local M = {}

--- Auto generates lsp info when uproject detected in CWD
function M.auto_generate_lsp()
    vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
        callback = function()
            local cwd = vim.loop.cwd() or vim.fn.getcwd()
            if vim.loop.fs_stat(cwd .. helpers.platform_slash .. "compile_commands.json") then
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
