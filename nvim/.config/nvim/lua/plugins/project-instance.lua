-- One Neovim per project: the first one opened in a project listens on that
-- project's socket (local-plugins/project-instance.nvim). Not lazy: it has to
-- run while Neovim starts, before the files are read
return {
    dir = vim.fn.stdpath("config") .. "/local-plugins/project-instance.nvim",
    name = "project-instance.nvim",
    main = "project_instance",
    lazy = false,
    opts = {},
}
