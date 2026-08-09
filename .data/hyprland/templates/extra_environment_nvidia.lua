-- =============================================================================
-- Extra Environment Variables - NVIDIA
-- =============================================================================
-- Environment variables for systems with an NVIDIA GPU
-- This file is required by hyprland.lua
-- =============================================================================

-- NVIDIA VA-API driver
hl.env("LIBVA_DRIVER_NAME", "nvidia")

-- Force NVIDIA GLX vendor
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- NVIDIA Video Decode backend
hl.env("NVD_BACKEND", "direct")

-- For hybrid systems (Intel + NVIDIA), uncomment the line below
-- and adjust according to your configuration:
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu")
