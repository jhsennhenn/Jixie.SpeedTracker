untyped
global function SpeedTrackerModSettingsHookup

void function SpeedTrackerModSettingsHookup()
{
    // ══════════════════════════════════
    //  SPEEDOMETER
    // ══════════════════════════════════
    ModSettings_AddModTitle( "Speed Tracker" )
    ModSettings_AddModCategory( "Speedometer" )

    ModSettings_AddEnumSetting( "speed_enable", "Speedometer", [ "Disabled", "Enabled" ] )
    ModSettings_AddSliderSetting( "hud_fontsize", "Font Size", 8, 48, 0.5, false )
    ModSettings_AddSetting( "hud_color", "Color (RGB, 0-255)", "vector" )
    ModSettings_AddSliderSetting( "hud_base_x", "Position X", -1, 1, 0.01, false )
    ModSettings_AddSliderSetting( "hud_base_y", "Position Y", -1, 1, 0.01, false )
    ModSettings_AddSliderSetting( "hud_spacing", "Row Spacing", 0.0, 0.1, 0.001, false )
    ModSettings_AddEnumSetting(
        "hud_layout_preset",
        "Layout Preset",
        [ "Custom", "Above Ammo", "Below Radar", "Top Right", "Left of Crosshair", "Right of Crosshair" ]
    )

    // ══════════════════════════════════
    //  SPEED CHANGE TRACKER
    // ══════════════════════════════════
    ModSettings_AddModCategory( "Speed Change Tracker" )

    ModSettings_AddEnumSetting( "st_enable", "Enable Speed Tracker", [ "Disabled", "Enabled" ] )
    ModSettings_AddSliderSetting( "st_font_size", "Tracker Font Size", 8, 40, 0.5, false )
    ModSettings_AddSliderSetting( "st_column_spacing", "Column Spacing (horizontal)", 0.02, 0.3, 0.005, false )

    // How long a quiet period before the segment fades
    ModSettings_AddSliderSetting( "st_idle_timeout", "Idle Timeout (seconds)", 0.2, 10.0, 0.1, false )

    // Number of individual changes shown below each column header (0 = header only)
    ModSettings_AddSliderSetting( "st_history_count", "History Entries per Column (0-10)", 0, 10, 1, true )
}
