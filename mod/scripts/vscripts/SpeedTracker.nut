untyped
global function SpeedTrackerInit

const float HU_TO_KMH = 0.09144

// Minimum km/h change that counts as "significant" for segment tracking
const float MIN_SIGNIFICANT_KMH = 1.0

struct ChangeEntry
{
    float   value       // signed km/h delta (positive = gain, negative = loss)
    float   timestamp   // Time() when this entry was recorded
}

struct TrackerColumn
{
    var     headerRUI               // large "cumulative" text RUI
    array<var> historyRUIs          // smaller per-change entries
    float   cumulative              // running total for the current segment
    array<ChangeEntry> history      // ring of recent individual changes
}

struct
{
    // Settings
    bool    speedEnabled
    bool    trackerEnabled
    float   hudFontSize
    vector  hudColor
    float   baseX
    float   baseY
    float   spacing

    float   trackerFontSize         // size for column headers
    float   historyFontSize         // size for per-change rows
    int     historyCount            // 0–10 entries shown per column
    float   idleTimeout             // seconds of inactivity before segment fades
    float   columnSpacing           // horizontal gap between the 3 columns
    float   resetThreshold          // km/h single-change size that resets the cumulative header

    // Speed state
    float   prevSpeedKmh            // horizontal speed last frame
    float   currentSpeedKmh        // this frame

    // Segment state
    float   lastChangeTime          // Time() of the last significant change
    bool    segmentActive           // are we inside an active segment?
    float   segmentAlpha            // 0.0–1.0, fades after idle

    // Per-column state
    TrackerColumn gainCol
    TrackerColumn lossCol
    TrackerColumn netCol

    // Speedometer RUI
    var     speedRUI

    bool    threadStarted
} file

void function SpeedTrackerInit()
{
    if ( !file.threadStarted )
    {
        file.threadStarted = true
        thread SpeedTrackerThread()
    }
}

void function SpeedTrackerThread()
{
    UpdateSettings()

    // Create all RUIs
    file.speedRUI = CreateTextRUI( file.hudFontSize )

    for ( int col = 0; col < 3; col++ )
    {
        TrackerColumn colRef = GetColumn( col )
        colRef.headerRUI = CreateTextRUI( file.trackerFontSize )

        // Pre-allocate max history RUIs (10)
        for ( int h = 0; h < 10; h++ )
        {
            colRef.historyRUIs.append( CreateTextRUI( file.historyFontSize ) )
        }
    }

    // Seed previous speed so the first frame doesn't produce a false delta
    {
        entity p = GetLocalViewPlayer()
        if ( IsValid(p) )
        {
            vector vel = p.GetVelocity()
            file.prevSpeedKmh = sqrt( vel.x*vel.x + vel.y*vel.y ) * HU_TO_KMH
        }
    }

    while ( true )
    {
        WaitFrame()

        UpdateSettings()

        bool alive = IsValid( GetLocalViewPlayer() ) && IsAlive( GetLocalViewPlayer() )

        if ( !alive )
        {
            HideAll()
            continue
        }

        // Speed sampling
        entity p = GetLocalViewPlayer()
        vector vel = p.GetVelocity()
        file.currentSpeedKmh = sqrt( vel.x * vel.x + vel.y * vel.y ) * HU_TO_KMH

        float delta = file.currentSpeedKmh - file.prevSpeedKmh  // signed, km/h

        // Segment / change tracking
        if ( fabs_c( delta ) >= MIN_SIGNIFICANT_KMH )
        {
            file.lastChangeTime = Time()

            if ( !file.segmentActive )
            {
                // New segment — reset everything
                file.segmentActive = true
                ResetColumn( file.gainCol )
                ResetColumn( file.lossCol )
                ResetColumn( file.netCol )
            }

            // If this single change is large enough, reset the cumulative
            // totals so the header reflects only this new burst — but keep
            // the history entries and the segment alive.
            bool bigChange = fabs_c( delta ) >= file.resetThreshold
            if ( bigChange )
            {
                file.gainCol.cumulative = 0.0
                file.lossCol.cumulative = 0.0
                file.netCol.cumulative  = 0.0
            }

            // Accumulate into (potentially freshly zeroed) totals
            file.netCol.cumulative += delta

            if ( delta > 0 )
            {
                file.gainCol.cumulative += delta
                RecordChange( file.gainCol, delta )
            }
            else
            {
                file.lossCol.cumulative += delta
                RecordChange( file.lossCol, delta )
            }

            RecordChange( file.netCol, delta )

            file.segmentAlpha = 1.0
        }

        // Fade logic
        if ( file.segmentActive )
        {
            float idle = Time() - file.lastChangeTime
            if ( idle > file.idleTimeout )
            {
                // Fade proportionally after the timeout elapses
                float fadeProgress = ( idle - file.idleTimeout ) / max_c( 0.5, file.idleTimeout * 0.5 )
                file.segmentAlpha = clamp_f( 1.0 - fadeProgress, 0.0, 1.0 )

                if ( file.segmentAlpha <= 0.0 )
                    file.segmentActive = false
            }
        }

        // Draw speedometer
        if ( file.speedEnabled )
        {
            string speedStr = "Speed: " + int( file.currentSpeedKmh ).tostring() + " km/h"
            RuiSetString( file.speedRUI, "msgText", speedStr )
            RuiSetFloat( file.speedRUI, "msgFontSize", file.hudFontSize )
            RuiSetFloat3( file.speedRUI, "msgColor", file.hudColor )
            RuiSetFloat( file.speedRUI, "msgAlpha", 1.0 )
            RuiSetFloat2( file.speedRUI, "msgPos", <file.baseX, file.baseY, 0> )
        }
        else
        {
            RuiSetFloat( file.speedRUI, "msgAlpha", 0.0 )
        }

        // Draw tracker columns
        if ( file.trackerEnabled && file.segmentActive )
        {
            // Y anchor — place below the speedometer (or at baseY if speedometer is off)
            float trackerBaseY = file.speedEnabled
                ? ( file.baseY + file.spacing )
                : file.baseY

            // 3 columns centred around baseX
            // col 0 = gain (left), col 1 = loss (centre), col 2 = net (right)
            float[3] colX
            colX[0] = file.baseX - file.columnSpacing
            colX[1] = file.baseX
            colX[2] = file.baseX + file.columnSpacing

            DrawColumn( file.gainCol, colX[0], trackerBaseY, file.segmentAlpha, true )
            DrawColumn( file.lossCol, colX[1], trackerBaseY, file.segmentAlpha, false )
            DrawColumn( file.netCol,  colX[2], trackerBaseY, file.segmentAlpha, false )
        }
        else if ( !file.trackerEnabled || !file.segmentActive )
        {
            HideTrackerColumns()
        }

        file.prevSpeedKmh = file.currentSpeedKmh
    }
}

//  Column helpers
TrackerColumn function GetColumn( int index )
{
    switch ( index )
    {
        case 0: return file.gainCol
        case 1: return file.lossCol
        default: return file.netCol
    }

    return file.netCol
}

void function ResetColumn( TrackerColumn col )
{
    col.cumulative = 0.0
    col.history.clear()
}

void function RecordChange( TrackerColumn col, float delta )
{
    ChangeEntry entry
    entry.value     = delta
    entry.timestamp = Time()

    col.history.insert( 0, entry )  // newest at index 0

    // Trim to max history size
    while ( col.history.len() > 10 )
        col.history.remove( col.history.len() - 1 )
}

void function DrawColumn( TrackerColumn col, float x, float baseY, float alpha, bool isGain )
{
    // Header: cumulative value
    string sign   = col.cumulative >= 0 ? "+" : ""
    string header = sign + int( col.cumulative ).tostring()

    RuiSetString( col.headerRUI, "msgText", header )
    RuiSetFloat( col.headerRUI, "msgFontSize", file.trackerFontSize )
    RuiSetFloat3( col.headerRUI, "msgColor", file.hudColor )
    RuiSetFloat( col.headerRUI, "msgAlpha", alpha )
    RuiSetFloat2( col.headerRUI, "msgPos", <x, baseY, 0> )

    // History rows
    int visibleHistory = min_c( file.historyCount, col.history.len() )
    float rowSpacing   = file.spacing * 0.7   // tighter than the main spacing

    for ( int h = 0; h < 10; h++ )
    {
        var rui = col.historyRUIs[ h ]

        if ( h < visibleHistory )
        {
            ChangeEntry entry = col.history[ h ]
            string entrySign  = entry.value >= 0 ? "+" : ""
            string entryStr   = entrySign + int( entry.value ).tostring()

            float rowY = baseY + file.spacing + ( h * rowSpacing )

            RuiSetString( rui, "msgText", entryStr )
            RuiSetFloat( rui, "msgFontSize", file.historyFontSize )
            RuiSetFloat3( rui, "msgColor", file.hudColor )
            RuiSetFloat( rui, "msgAlpha", alpha * 0.65 )   // slightly dimmer than header
            RuiSetFloat2( rui, "msgPos", <x, rowY, 0> )
        }
        else
        {
            RuiSetFloat( rui, "msgAlpha", 0.0 )
        }
    }
}

void function HideTrackerColumns()
{
    for ( int col = 0; col < 3; col++ )
    {
        TrackerColumn c = GetColumn( col )
        RuiSetFloat( c.headerRUI, "msgAlpha", 0.0 )
        for ( int h = 0; h < 10; h++ )
            RuiSetFloat( c.historyRUIs[h], "msgAlpha", 0.0 )
    }
}

void function HideAll()
{
    RuiSetFloat( file.speedRUI, "msgAlpha", 0.0 )
    HideTrackerColumns()
}

//  RUI factory
var function CreateTextRUI( float fontSize )
{
    var rui = RuiCreate(
        $"ui/cockpit_console_text_center.rpak",
        clGlobal.topoCockpitHudPermanent,
        RUI_DRAW_COCKPIT,
        -1
    )
    RuiSetInt( rui, "maxLines", 1 )
    RuiSetInt( rui, "lineNum", 1 )
    RuiSetFloat2( rui, "msgPos", <0, 0, 0> )
    RuiSetFloat( rui, "msgFontSize", fontSize )
    RuiSetFloat3( rui, "msgColor", <1, 1, 1> )
    RuiSetFloat( rui, "msgAlpha", 0.0 )
    RuiSetFloat( rui, "thicken", 0.0 )
    return rui
}

//  Settings
void function UpdateSettings()
{
    file.speedEnabled       = GetConVarBool( "speed_enable" )
    file.trackerEnabled     = GetConVarBool( "st_enable" )

    file.hudFontSize        = GetConVarFloat( "hud_fontsize" )
    file.hudColor           = GetConVarFloat3( "hud_color" ) / 255.0
    file.baseX              = GetConVarFloat( "hud_base_x" )
    file.baseY              = GetConVarFloat( "hud_base_y" )
    file.spacing            = GetConVarFloat( "hud_spacing" )

    file.trackerFontSize    = GetConVarFloat( "st_font_size" )
    file.historyFontSize    = file.trackerFontSize * 0.65
    file.historyCount       = clamp_i( GetConVarInt( "st_history_count" ), 0, 10 )
    file.idleTimeout        = max_c( 0.1, GetConVarFloat( "st_idle_timeout" ) )
    file.columnSpacing      = GetConVarFloat( "st_column_spacing" )
    file.resetThreshold     = max_c( 1.0, GetConVarFloat( "st_reset_threshold" ) )

    // Layout presets
    int preset = GetConVarInt( "hud_layout_preset" )
    if ( preset != 0 )
    {
        file.spacing     = 0.03
        file.hudFontSize = 34

        switch ( preset )
        {
            case 1: file.baseX = -0.27; file.baseY =  0.27;   break
            case 2: file.baseX = -0.41; file.baseY = -0.24;   break
            case 3: file.baseX =  0.4;  file.baseY = -0.475;  break
            case 4: file.baseX = -0.1;  file.baseY =  0.0;    break
            case 5: file.baseX =  0.1;  file.baseY =  0.0;    break
        }
    }
}

//  Utility: parse a "X Y Z" convar into a vector
vector function GetConVarFloat3( string convar )
{
    array<string> value = split( GetConVarString( convar ), " " )
    try
    {
        return Vector( value[0].tofloat(), value[1].tofloat(), value[2].tofloat() )
    }
    catch ( ex )
    {
        throw "Invalid convar " + convar + "! make sure it is a float3 formatted as \"X Y Z\""
    }
    unreachable
}

float function fabs_c( float x )
{
    return x < 0.0 ? x * -1.0 : x
}

int function clamp_i( int v, int lo, int hi )
{
    if ( v < lo ) return lo
    if ( v > hi ) return hi
    return v
}

float function clamp_f( float v, float lo, float hi )
{
    if ( v < lo ) return lo
    if ( v > hi ) return hi
    return v
}

float function max_c( float a, float b )
{
    return a > b ? a : b
}

int function min_c( int a, int b )
{
    return a < b ? a : b
}