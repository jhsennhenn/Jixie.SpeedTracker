untyped
global function SpeedTrackerModSettingsHookup

void function SpeedTrackerModSettingsHookup()
{
    // ================
    // SPEED TRACKER SETTINGS
    // ================
    ModSettings_AddModTitle("Speed Tracker")
    ModSettings_AddModCategory("General settings")
    ModSettings_AddEnumSetting("speed_tracker_enable", "Enable Speed Tracker", [ "Disabled", "Enabled" ])
    ModSettings_AddEnumSetting("speed_tracker_style", "Speed Tracker style", [ "Bars", "Minimalistic", "Number" ])
    ModSettings_AddSliderSetting("speed_tracker_position", "Speed Tracker position (offset from the center)", -1, 1, 0.01, false)
    ModSettings_AddSliderSetting("speed_tracker_width", "Speed Tracker width", 0, 1, 0.01, false)
    ModSettings_AddSliderSetting("speed_tracker_size", "Speed Tracker size", 1, 100, 0.1, false)
    ModSettings_AddSliderSetting("speed_tracker_base_alpha", "Speed Tracker base alpha", 0, 1, 0.01, false)
    ModSettings_AddSetting("speed_tracker_color", "Speed Tracker color (RGB, 0-255)", "vector")

    // =====================
    // MOVEMENT HUD SETTINGS
    // =====================
    ModSettings_AddModCategory("Movement HUD")

    // HUD Element style and layout
    ModSettings_AddSliderSetting("hud_fontsize", "HUD Font Size", 8, 48, 0.5, false)
    ModSettings_AddSetting("hud_color", "HUD Color (RGB, 0-255)", "vector")
    ModSettings_AddSliderSetting("hud_base_x", "HUD Base X Position", -1, 1, 0.01, false)
    ModSettings_AddSliderSetting("hud_base_y", "HUD Base Y Position", -1, 1, 0.01, false)
    ModSettings_AddSliderSetting("hud_spacing", "HUD Element Spacing", 0.0, 0.1, 0.001, false)

    // Individual HUD elements
    ModSettings_AddEnumSetting(
        "hud_layout_preset",
        "HUD Layout Preset",
        ["Custom", "Above Ammo", "Below Radar", "Top Right", "Left of Crosshair", "Right of Crosshair"]
    )
    
    ModSettings_AddEnumSetting("jump_enable", "Jump Counter", ["Disabled", "Enabled"])
    ModSettings_AddEnumSetting("speed_enable", "Speedometer", ["Disabled", "Enabled"])
}