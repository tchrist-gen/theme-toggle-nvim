---Check if the user provided config is as expected
---@param args table
---@return boolean

local function dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

local function handle_user_config(args)
    if args == nil then
        vim.notify("theme-toggle-nvim: Expected an argument in setup function", vim.log.levels.ERROR)
        return false
    end

    if args.colorscheme == nil then
        vim.notify("theme-toggle-nvim: Expected `colorscheme` table", vim.log.levels.ERROR)
        return false
    end

    if args.colorscheme.light == nil then
        vim.notify("theme-toggle-nvim: Expected `colorscheme.light` a colorscheme for light mode", vim.log.levels.ERROR)
        return false
    end

    if args.colorscheme.dark == nil then
        vim.notify("theme-toggle-nvim: Expected `colorscheme.dark` a colorscheme for dark mode", vim.log.levels.ERROR)
        return false
    end

    args.has_lualine, args.lualine = pcall(require, "lualine")
    if args.colorscheme.lualine ~= nil then
        args.lualine_configured = true
        if args.colorscheme.lualine.dark == nil then
            args.lualine_configured = false
            vim.notify("theme-toggle-nvim: Expected lualine colorscheme definition for dark", vim.log.levels.WARN)
        end

        if args.colorscheme.lualine.light == nil then
            args.lualine_configured = false
            vim.notify("theme-toggle-nvim: Expected lualine colorscheme definition for light", vim.log.levels.WARN)
        end
    end

    return true
end

---Initialize the plugin with light and dark colorschemes and start to listen
---for changes in display mode. If the provided user config is as expected then
---with changes in display mode, the neovim colorscheme will also change.
---
---@param args table
---@usage [[
--- require("theme-toggle-nvim").setup({
---     colorscheme = {
---         light = "onedark",
---         dark = "gruvbox",
---     }
--- })
---@usage ]]
local function setup(args)
    if not handle_user_config(args) then
        return
    end

    local stdout = vim.loop.new_pipe(false)
    local stdin = vim.loop.new_pipe(false)

    if stdout == nil or stdin == nil then
        vim.notify("theme-toggle-nvim: Something went wrong", vim.log.levels.ERROR)
        return
    end

    local handle, _ = vim.loop.spawn("theme-toggle-nvim", {
        stdio = { stdin, stdout, nil },
    }, function(code, signal) -- on exit
        print("exit code:", code)
        print("exit signal", signal)
    end)

    if not handle then
        vim.notify("theme-toggle-nvim: Unable to spawn child process", vim.log.levels.ERROR)
        return
    end

    vim.loop.read_start(
        stdout,
        vim.schedule_wrap(function(err, data)
            assert(not err, err)
            if not data then
                return
            end

            local mode = data:match("^()%s*$") and "" or data:match("^%s*(.*%S)")

            if mode == "light" then
                vim.opt.background = "light"
                vim.cmd.colorscheme(args.colorscheme.light)
                if args.has_lualine and args.lualine_configured then
                    local config = args.lualine.get_config()
                    config.options.theme = args.colorscheme.lualine.light
                    args.lualine.setup(config)
                end
            end
            if mode == "dark" then
                vim.opt.background = "dark"
                vim.cmd.colorscheme(args.colorscheme.dark)
                if args.has_lualine and args.lualine_configured then
                    local config = args.lualine.get_config()
                    config.options.theme = args.colorscheme.lualine.dark
                    args.lualine.setup(config)
                end
            end
        end)
    )

    vim.api.nvim_create_autocmd("VimLeave", {
        pattern = "*",
        callback = function()
            vim.loop.write(stdin, "quit\n")

            handle:close()
            stdout:close()
            stdin:close()
        end,
    })
end

return { setup = setup }
