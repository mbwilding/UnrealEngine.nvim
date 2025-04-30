# UnrealEngine.nvim

## Dependencies

- Source version of Unreal Engine
- clangd (Language Server)

## Install

> lazy.nvim
```lua
return {
    "mbwilding/UnrealEngine.nvim",
    keys = {
        {
            "<leader>ug",
            function()
                require("unrealengine.commands").generate_lsp()
            end,
            desc = "UnrealEngine: Generate LSP"
        },
        {
            "<leader>ub",
            function()
                require("unrealengine.commands").generate_lsp()
            end,
            desc = "UnrealEngine: Build"
        },
    },
    opts = {
        engine_path = "/path/to/UnrealEngine"
    }
}
```
