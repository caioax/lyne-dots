-- Wrap text in quotes, brackets or tags: select it and S" (or S), S], St),
-- or ys + a motion + the pair (ysiw" wraps the word), cs"' changes the
-- pair, ds" deletes it. ys doesn't get in the way of y: after a y that
-- isn't followed by s, the copy to the system clipboard runs as before
return {
    "kylechui/nvim-surround",
    version = "^4.0.0",
    -- Not lazy: its plugin file only makes the maps (the work loads on the
    -- first use), and the shortcut search lists them before any file opens
    lazy = false,
}
