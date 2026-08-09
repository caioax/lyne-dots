-- ###############
-- ### SOURCES ###
-- ###############
-- See https://wiki.hypr.land/Configuring/Start/

-- Core configurations (Managed by Git)
require("conf/variables")
require("conf/environment")
require("conf/autostart")
require("conf/appearance")
require("conf/input")
require("conf/keybinds")
require("conf/rules")
require("workspaces")

-- Load all local overrides
-- This will load any .lua file inside the local folder
require("./local/*")

-- Display Settings
require("monitors")
