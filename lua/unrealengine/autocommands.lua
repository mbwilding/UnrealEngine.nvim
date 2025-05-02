local M = {}

function M.auto_generate()
    vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
        callback = function()
            local cwd = vim.loop.cwd() or vim.fn.getcwd()
            if vim.loop.fs_stat(cwd .. "/compile_commands.json") then
                return
            end

            local handle, _ = vim.loop.fs_scandir(cwd)
            if not handle then
                return
            end

            while true do
                local name, type = vim.loop.fs_scandir_next(handle)
                if not name then
                    break
                end
                if type == "file" and name:match("%.uproject$") then
                    local uproject_path = cwd .. "/" .. name
                    require("unrealengine.commands").generate_lsp({
                        uproject_path = uproject_path
                    })
                    break
                end
            end
        end,
    })
end

return M
