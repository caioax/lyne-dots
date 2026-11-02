-- =============================================================================
-- Extra Environment Variables - NVIDIA on a hybrid machine
-- =============================================================================
-- Machine-specific local environment variables.
-- This file is required by hyprland.lua
-- =============================================================================

-- The NVIDIA variables (LIBVA_DRIVER_NAME, __GLX_VENDOR_LIBRARY_NAME,
-- NVD_BACKEND) are set in local/gpus.lua, and only when NVIDIA renders the
-- desktop (lyne gpu order): set here they'd send every app to NVIDIA even
-- while the integrated GPU renders, which keeps it awake on battery.
-- prime-run <app> starts one app on NVIDIA (Steam: prime-run %command%).

-- Add machine-specific environment variables here
