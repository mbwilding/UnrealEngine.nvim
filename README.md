# UnrealEngine.nvim

## Dependencies

- Source version of Unreal Engine
- clangd (Language Server)

## Install

### lazy.nvim

> The commands can also be passed the opts directly to allow for different configurations, these will merge with your defaults passed into setup

```lua
return {
    "mbwilding/UnrealEngine.nvim",
    dependencies = {
        -- optional, this registers the Unreal Engine icon to .uproject files
        "nvim-tree/nvim-web-devicons",
    },
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
                require("unrealengine.commands").build()
            end,
            desc = "UnrealEngine: Build"
        },
    },
    opts = {
        engine_path = "/path/to/UnrealEngine"
    }
}
```
