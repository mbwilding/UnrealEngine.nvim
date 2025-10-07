# UnrealEngine.nvim

Supports Linux, Mac, and Windows

> I'm developing a plugin for Unreal Engine that integrates Neovim as the code editor. To ensure files open in the correct Neovim instance (maintaining an active LSP session), Unreal Engine 5 needs to be launched from within Neovim.

## Dependencies

- Source version of Unreal Engine
- clangd (LSP)
- Windows - LLVM (clang-cl): `winget install -e --id LLVM.LLVM`

## Options

[Options](https://github.com/mbwilding/UnrealEngine.nvim/blob/main/lua/unrealengine/types.lua#L7)

> The commands can also be passed the opts directly to allow for different configurations, these will merge with your defaults passed into setup

## Install

### lazy.nvim

```lua
return {
    "mbwilding/UnrealEngine.nvim",
    lazy = false,
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
        {
            "<leader>ur",
            function()
                require("unrealengine.commands").rebuild()
            end,
            desc = "UnrealEngine: Rebuild"
        },
        {
            "<leader>uo",
            function()
                require("unrealengine.commands").open()
            end,
            desc = "UnrealEngine: Open"
        },
        {
            "<leader>uc",
            function()
                require("unrealengine.commands").clean()
            end,
            desc = "UnrealEngine: Clean",
        },
    },
    opts = {
        auto_generate = true, -- Auto generates LSP info when detected in CWD | default: false
        auto_build = true, -- Auto builds on save | default: false
        engine_path = "/path/to/UnrealEngine", -- Path to your UnrealEngine source directory, you can also provide a table of strings
        -- More settings are in the `lua/unrealengine/init.lua` file
    }
}
```
