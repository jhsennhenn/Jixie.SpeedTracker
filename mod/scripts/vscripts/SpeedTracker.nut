untyped
global function SpeedTrackerInit
global function CreateCustomSpeedTrackerTracker
global function CreateCustomSpeedTrackerWaypoint

global struct CustomSpeedTrackerMarker
{
	var rui = null                       // contains the RUI in the returned struct
	entity target = null                 // target entity, used with CreateCustomCompassTracker
	vector position = Vector(0,0,0)      // target location, used with CreateCustomCompassWaypoint
	string imagePath = ""                // example: "$rui/menu/boosts/boost_icon_holopilot"
	float imageScaleModifier = 1.0       //
	vector colour = Vector(1.0, 1.0, 1.0)//
	int compassRow = 2                   // 3 rows, indexed from 1 to 3

	float baseAlphaModifier = 1.0        // for no change use 1.0
	bool fadeWithDistance = false        //
	bool useHorizontalDistance = true	 // distance calculations will only include the horizontal plane (x, y)
	float maxVisibleDistance = 10000     // in HU
	bool fadeWithTime = false            //
	float startTime = 0.0                // in seconds
	float duration = 10.0                // in seconds
}

struct HudElement
{
    bool enabled
    var rui
    string text
}


struct
{
	float size
	float position
	float baseAlpha
	float compassWidth
	int style
	int isEnabled
	vector colour
	var[9][2] barRUIs // this is weird, looks like the indexing is swapped for some reason
	var centerRUI
	bool isVisible = false

						// Jackson's edits
	// Movement HUD elements
	HudElement jump
	HudElement speed

	// Movement HUD state variables for calculations
	int jumpCount = 0
	float lastVZ = 0.0				// (double jump and walljump inclusion in jump count)
	float currentSpeed = 0.0

	// Layout settings for the HUD column
	float baseX = 0.42
	float baseY = -0.45
	float spacing = 0.01

	// HUD element style
	float hudFontSize = 24.0
	vector hudColor = <1.0, 1.0, 1.0>

	bool threadStarted = false		// for a bug that didn't affect the compass, but would restart the jump counter (occurred when tabbing out)
}file

void function CompassInit()
{
	//RegisterButtonPressedCallback(MOUSE_LEFT, aaa) //Callback for debugging
	if( !IsLobby() )
	{
		if (!file.threadStarted)
        {
            file.threadStarted = true

            RegisterSignal("DestroyTracker")
            RegisterSignal("DestroyWaypoints")

            thread CompassThread()
        }
		//Register the custom signals, for trackers and for waypoints
	}
}

void function UpdateJumpCounter()
{
    entity p = GetLocalViewPlayer()
    if (!IsValid(p) || !IsAlive(p))
        return

    float vz = p.GetVelocity().z

    // Detect upward impulse
    if (file.lastVZ <= 0 && vz > 0)
        file.jumpCount++

    file.lastVZ = vz
}

void function UpdateSpeed()
{
    entity p = GetLocalViewPlayer()
    if (!IsValid(p) || !IsAlive(p))
        return

    vector vel = p.GetVelocity()

    float speed = sqrt(vel.x * vel.x + vel.y * vel.y)

    file.currentSpeed = speed
}

void function CompassThread()
{
	UpdateSettings()

	for(int k = 0; k < 2; ++k)
	{
    	printt("k = " + k)
    	for(int i = 0; i < 9; ++i)
    	{
        	printt("i = " + i)
        	file.barRUIs[k][i] = CreateCompassRUI()
    	}
	}


	file.centerRUI = CreateCenterRUI()

	file.jump.rui = CreateHudTextRUI()
	file.speed.rui = CreateHudTextRUI()

	HideCompass()

	while(true)
	{
		WaitFrame()

		UpdateSettings() //should be done only after changing mod settings, look for a callback or something

		RuiSetFloat(file.jump.rui,  "msgFontSize", file.hudFontSize)
		RuiSetFloat(file.speed.rui, "msgFontSize", file.hudFontSize)

		if(ShouldShowCompass())
		{
			UpdateCompassRUIs()
			file.isVisible = true
		}
		else if (file.isVisible)
		{
			HideCompass()
			file.isVisible = false
		}

		// Update jump and speed logic
		UpdateJumpCounter()
		UpdateSpeed()

		file.jump.text = "Jumps: " + file.jumpCount
		RuiSetString(file.jump.rui, "msgText", file.jump.text)

		float kmh = file.currentSpeed * 0.09144
		file.speed.text = "Speed: " + floor(kmh).tostring() + " km/h"
		RuiSetString(file.speed.rui, "msgText", file.speed.text)

		// HUD stacking
		array<HudElement> active = []

		// Jump
		if (file.jump.enabled)
		{
			active.append(file.jump)
			SetHudElementVisible(file.jump, true)
		}
		else
		{
			SetHudElementVisible(file.jump, false)
		}

		// Speed
		if (file.speed.enabled)
		{
			active.append(file.speed)
			SetHudElementVisible(file.speed, true)
		}
		else
		{
			SetHudElementVisible(file.speed, false)
		}

        for (int i = 0; i < active.len(); i++)
        {
            float y = file.baseY + (i * file.spacing)
            RuiSetFloat2(active[i].rui, "msgPos", <file.baseX, y, 0>)
        }

	}
}


var function CreateCompassRUI()
{
	var rui = RuiCreate( $"ui/cockpit_console_text_center.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, -1 )
	RuiSetInt(rui, "maxLines", 3)
	RuiSetInt(rui, "lineNum", 1)
	RuiSetFloat2(rui, "msgPos", <0,0,0>)
	RuiSetString(rui, "msgText", " | ")
	RuiSetFloat(rui, "msgFontSize", file.size)
	RuiSetFloat(rui, "msgAlpha", file.baseAlpha)
	RuiSetFloat(rui, "thicken", 0.0)
	RuiSetFloat3(rui, "msgColor", <1,1,1>)
	return rui
}

var function CreateCenterRUI()
{
	var rui = RuiCreate( $"ui/cockpit_console_text_center.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, -1 )
	RuiSetInt(rui, "maxLines", 3)
	RuiSetInt(rui, "lineNum", 1)
	RuiSetFloat2(rui, "msgPos", <0,0,0>)
	RuiSetString(rui, "msgText", "\\|/\n   \n   ")
	RuiSetFloat(rui, "msgFontSize", file.size)
	RuiSetFloat(rui, "msgAlpha", file.baseAlpha)
	RuiSetFloat(rui, "thicken", 0.0)
	RuiSetFloat3(rui, "msgColor", <1,1,1>)
	return rui
}

var function CreateHudTextRUI()
{
    var rui = RuiCreate(
    	$"ui/cockpit_console_text_center.rpak",
    	clGlobal.topoCockpitHudPermanent,
    	RUI_DRAW_COCKPIT,
    	-1
	)

    RuiSetInt(rui, "maxLines", 1)
    RuiSetInt(rui, "lineNum", 1)

    // These will be overwritten each frame by your layout system
    RuiSetFloat2(rui, "msgPos", <0, 0, 0>)

    // Unified style (color + font size)
    RuiSetFloat(rui, "msgFontSize", file.hudFontSize)
    RuiSetFloat3(rui, "msgColor", file.hudColor)
    RuiSetFloat(rui, "msgAlpha", 1.0)

    return rui
}

void function UpdateCompassRUIs()
{
	float xAngle = (GetLocalViewPlayer().EyeAngles().y - 180) * (-1) //View angle in degrees (range -180 to 180 by default, correcting)
	float offset = GetBarOffset(xAngle)
	float barPosition
	float alpha = 1.0

	if(file.style == 0) //Style: Bars
	{
		for(int i = 0; i<9; ++i)
		{
			barPosition = GetBarPosition(i, offset)
			alpha = GetBarAlpha(barPosition)
			RuiSetString(file.barRUIs[0][i], "msgText", GetBarValue(i, xAngle, offset))
			RuiSetString(file.barRUIs[1][i], "msgText", " \n|\n ")

			for(int k = 0; k<2; ++k)
			{
				RuiSetFloat2(file.barRUIs[k][i], "msgPos", <barPosition, file.position, 0>)
				RuiSetFloat(file.barRUIs[k][i], "msgAlpha", alpha)

				RuiSetFloat(file.barRUIs[k][i], "msgFontSize", file.size)
				RuiSetFloat3(file.barRUIs[k][i], "msgColor", file.colour)
			}
		}


		//	Center RUI
		RuiSetString(file.centerRUI, "msgText", "\\|/\n   \n   ")
		RuiSetFloat(file.centerRUI, "msgFontSize", file.size)
		RuiSetFloat3(file.centerRUI, "msgColor", file.colour)
		RuiSetFloat(file.centerRUI, "msgAlpha", file.baseAlpha)
		RuiSetFloat2(file.centerRUI, "msgPos", <0, file.position, 0>)
	}
	else if(file.style == 1) //Style: Minimalistic
	{
		for(int i = 0; i<9; ++i)
		{
			barPosition = GetBarPosition(i, offset)
			alpha = GetBarAlpha(barPosition)
			RuiSetString(file.barRUIs[0][i], "msgText", GetBarValue(i, xAngle, offset))
			RuiSetString(file.barRUIs[1][i], "msgText", "")

			for(int k = 0; k<2; ++k)
			{
				RuiSetFloat2(file.barRUIs[k][i], "msgPos", <barPosition, file.position, 0>)
				RuiSetFloat(file.barRUIs[k][i], "msgAlpha", alpha)

				RuiSetFloat(file.barRUIs[k][i], "msgFontSize", file.size)
				RuiSetFloat3(file.barRUIs[k][i], "msgColor", file.colour)
			}
		}

		//	Center RUI
		RuiSetString(file.centerRUI, "msgText", "\\|/\n   \n   ")
		RuiSetFloat(file.centerRUI, "msgFontSize", file.size)
		RuiSetFloat3(file.centerRUI, "msgColor", file.colour)
		RuiSetFloat(file.centerRUI, "msgAlpha", file.baseAlpha)
		RuiSetFloat2(file.centerRUI, "msgPos", <0, file.position, 0>)
	}
	else //Style: Number
	{
		for(int i = 0; i<9; ++i)
		{
			barPosition = GetBarPosition(i, offset)
			alpha = GetBarAlpha(barPosition)
			RuiSetString(file.barRUIs[0][i], "msgText", GetBarValue(i, xAngle, offset))
			RuiSetString(file.barRUIs[1][i], "msgText", "")

			for(int k = 0; k<2; ++k)
			{
				RuiSetFloat2(file.barRUIs[k][i], "msgPos", <barPosition, file.position, 0>)
				RuiSetFloat(file.barRUIs[k][i], "msgAlpha", alpha)

				RuiSetFloat(file.barRUIs[k][i], "msgFontSize", file.size)
				RuiSetFloat3(file.barRUIs[k][i], "msgColor", file.colour)
			}
		}

		//	Center RUI
		int angleNumber = (int(xAngle) + 180)%360 //could be optimized out, don't wanna bother rn so TODO

		//RuiSetString(file.centerRUI, "msgText", "\\|/\n   \n" + (angleNumber.tostring().len() == 1 ? " " + angleNumber.tostring() + " " : angleNumber.tostring())) // TODO
		RuiSetString(file.centerRUI, "msgText", "\\|/\n   \n   ")
		RuiSetFloat(file.centerRUI, "msgFontSize", file.size)
		RuiSetFloat3(file.centerRUI, "msgColor", file.colour)
		RuiSetFloat(file.centerRUI, "msgAlpha", file.baseAlpha)
		RuiSetFloat2(file.centerRUI, "msgPos", <0, file.position, 0>)
		// This is not the correct way to do this but I have no better idea rn
		// Fixing center RUI angle value offset
		RuiSetString(file.barRUIs[1][4], "msgText", "\n\n" + angleNumber.tostring()) // stealing a bar RUI for a moment
		RuiSetFloat2(file.barRUIs[1][4], "msgPos", <0, file.position, 0>)
		RuiSetFloat(file.barRUIs[1][4], "msgAlpha", file.baseAlpha)

	}

}

void function UpdateSettings()
{
    // Compass settings
    file.size        = GetConVarFloat("compass_size")
    file.baseAlpha   = GetConVarFloat("compass_base_alpha")
    file.position    = GetConVarFloat("compass_position") * (-0.57)
    file.compassWidth = GetConVarFloat("compass_width")
    file.colour      = GetConVarFloat3("compass_colour") / 255.0 
    file.style       = GetConVarInt("compass_style")
    file.isEnabled   = GetConVarInt("compass_enable")

    // Movement HUD style and layout
    file.hudFontSize = GetConVarFloat("hud_fontsize")
    file.hudColor    = GetConVarFloat3("hud_color") / 255.0
	file.baseX   = GetConVarFloat("hud_base_x")
	file.baseY   = GetConVarFloat("hud_base_y")
	file.spacing = GetConVarFloat("hud_spacing")

	int preset = GetConVarInt("hud_layout_preset")

    if (preset != 0)
{
    file.spacing     = 0.03
    file.hudFontSize = 34

    switch (preset)
    {
        case 1: file.baseX = -0.27; file.baseY = 0.27; break
        case 2: file.baseX = -0.41; file.baseY = -0.24; break
        case 3: file.baseX = 0.4;   file.baseY = -0.475; break
        case 4: file.baseX = -0.1;  file.baseY = 0.0; break
        case 5: file.baseX = 0.1;   file.baseY = 0.0; break
    }
}


    // Movement HUD
    file.jump.enabled  = GetConVarBool("jump_enable")
    file.speed.enabled = GetConVarBool("speed_enable")
}

bool function ShouldShowCompass()
{
	if(file.isEnabled && IsValid(GetLocalViewPlayer()) && IsAlive(GetLocalViewPlayer()))
		return true
	return false

	// if (!IsAlive(GetLocalViewPlayer()))		// If you want jump counter to reset with each death
    // 	file.jumpCount = 0
}

void function SetHudElementVisible(HudElement elem, bool visible)
{
    if (!IsValid(elem.rui))
        return

    float alpha = visible ? 1.0 : 0.0
    RuiSetFloat(elem.rui, "msgAlpha", alpha)
}

void function HideCompass()
{
	for(int k = 0; k < 2; ++k)
	{
		for(int i = 0; i < 9; ++i)
		{
			RuiSetFloat(file.barRUIs[k][i], "msgAlpha", 0)
		}
	}


	RuiSetFloat(file.centerRUI, "msgAlpha", 0)
}



float function GetBarOffset(float angle)
{
	float angleReduced = angle - ((int(angle)/15) * 15)

	float temp = ((angleReduced - 7.5) / 7.5) //the result here is a value from -1 to 1

	float offset = 0

	//I forgot what happens here, I'm just glad it works
	if (temp < 0)
		offset = ((1 - fabs(temp)) * (file.compassWidth/18)) * (-1.0)
	else
		offset = (1 - temp) * (file.compassWidth/18)

	return offset
}

float function GetBarPosition(int index, float offset)
{
	return (index * file.compassWidth/9 + file.compassWidth/18 + offset) - file.compassWidth/2
}

float function GetBarAlpha(float position)
{
	return file.baseAlpha * ((file.compassWidth/2 - fabs(position)) / (file.compassWidth / 2))
}

string function GetBarValue(int index, float angle, float offset)
{
	//Calculation for bar 4

	//We need to move the angle by 180 to face north (could be optimized by moving to the Update function, would require changes to passed args)
	int iAngle = (int(angle) + 180)%360

	int result = 0
	if(offset >= 0)
		result = ((iAngle - iAngle%15) + 15)
	else
		result = ((iAngle - iAngle%15))

	result += 360 //Correction for mirroring close to 0

	//Value for other bars:
	result = abs(result + 15 * (index - 4)) % 360

	string str = ""

	switch (result)
	{
		case 0:
			str = "N"
			break
		case 45:
			str = "NE"
			break
		case 90:
			str = "E"
			break
		case 135:
			str = "SE"
			break
		case 180:
			str = "S"
			break
		case 225:
			str = "SW"
			break
		case 270:
			str = "W"
			break
		case 315:
			str = "NW"
			break
		default:
			if(file.style == 2)
				str = "|"
			else
				str = result.tostring()
			break
	}

	// Style dependent results
	// In all cases these values should be applied to just one RUI row, as the other will only contain constant elements
	int len = str.len()

	if(file.style == 0) // Bars
	{
		switch (len)
		{
			case 1:
				str = " \n \n" + str
				break
			case 2:
				str = "  \n  \n" + str
				break
			case 3:
				str = "   \n   \n" + str
				break
		}
	}
	else if(file.style == 1 || file.style == 2) // Minimalistic || Number (both use row 2, implementation is the same)
	{
		switch (len)
		{
			case 1:
				str = " \n" + str + "\n "
				break
			case 2:
				str = "  \n" + str + "\n  "
				break
			case 3:
				str = "   \n" + str + "\n   "
				break
		}
	}
	else // Empty
	{

	}

	return str
}

//Stolen from 4V (thanks nerd)
vector function GetConVarFloat3(string convar)
{
    array<string> value = split(GetConVarString(convar), " ")
    try{
        return Vector(value[0].tofloat(), value[1].tofloat(), value[2].tofloat())
    }
    catch(ex){
        throw "Invalid convar " + convar + "! make sure it is a float3 and formatted as \"X Y Z\""
    }
    unreachable
}

//==================================================================================================================

//Functions for creating custom compass markers
void function CreateCustomCompassTracker( CustomCompassMarker data )
{
	data.rui = CreateCompassRUI()
	string ruiString = ""

	// Validity checks for values here? Or do we rely on the modder being competent?

	switch( data.compassRow )
	{
		case 1:
			ruiString = "%" + data.imagePath + "%\n\n"
			break
		case 2:
			ruiString = "\n%" + data.imagePath + "%\n"
			break
		default:
			ruiString = "\n\n%" + data.imagePath + "%"
			break
	}

	RuiSetString(data.rui, "msgText", ruiString )
	RuiSetFloat3(data.rui, "msgColor", data.colour )

	thread MaintainCustomCompassTracker( data )
}


void function CreateCustomCompassWaypoint( CustomCompassMarker data )
{
	data.rui = CreateCompassRUI()
	string ruiString = ""

	switch( data.compassRow )
	{
		case 1:
			ruiString = "%" + data.imagePath + "%\n\n"
			break
		case 2:
			ruiString = "\n%" + data.imagePath + "%\n"
			break
		default:
			ruiString = "\n\n%" + data.imagePath + "%"
			break
	}

	RuiSetString(data.rui, "msgText", ruiString )
	RuiSetFloat3(data.rui, "msgColor", data.colour )

	thread MaintainCustomCompassWaypoint( data )
}
//Remember to add these newly created ruis to an array, which we will use to hide them with the HideCompass function, or use ShouldShowCompass
//Might turn out to not be necessary


//Funcs for maintaining the RUIs, they run as threads and update/delete them
void function MaintainCustomCompassTracker( CustomCompassMarker data ) //add more args
{
	data.target.EndSignal( "OnDestroy" )
	//data.target.EndSignal( "OnDeath" )
	data.target.EndSignal( "DestroyTracker" )

	vector vec
	vector newAngles
	float angle
	float imagePosition
	//bool isVisible = true


	//DEBUG
	//thread kys(target)
	//DEBUG END


	OnThreadEnd(
		function() : ( data )
		{
			//Logger.Info("Thread ended!")
			printt("Thread ended!")
			if(data.rui != null)
			{
				RuiDestroyIfAlive(data.rui)
			}
		}
	)

	for(;;)
	{
		WaitFrame()

		vec =  data.target.GetOrigin() - GetLocalClientPlayer().GetOrigin()
		newAngles = VectorToAngles( vec )
		//Logger.Info((360.0 - newAngles.y).tostring()) //Y is our argument
		//East and west are swapped
		//The rotation is in the opposite direction
		//adding 360.0 - fixed it
		angle = 360.0 - newAngles.y

		imagePosition = GetImagePosition( angle )

		RuiSetFloat2(data.rui, "msgPos", < imagePosition, file.position, 0 > )
		RuiSetFloat(data.rui, "msgAlpha", GetImageAlpha( imagePosition, data ) )
		RuiSetFloat(data.rui, "msgFontSize", file.size * data.imageScaleModifier )
	}

}


void function MaintainCustomCompassWaypoint( CustomCompassMarker data )
{
	GetLocalClientPlayer().EndSignal( "DestroyWaypoints" )

	vector vec
	vector newAngles
	float angle
	float imagePosition
	//bool isVisible = true

	OnThreadEnd(
		function() : ( data )
		{
			//Logger.Info("Thread ended!")
			printt("Thread ended!")
			if(data.rui != null)
			{
				RuiDestroyIfAlive(data.rui)
			}
		}
	)

	for(;;)
	{
		WaitFrame()

		vec =  data.position - GetLocalClientPlayer().GetOrigin()
		newAngles = VectorToAngles( vec )
		angle = 360.0 - newAngles.y

		imagePosition = GetImagePosition( angle )

		RuiSetFloat2(data.rui, "msgPos", < imagePosition, file.position, 0 > )
		RuiSetFloat(data.rui, "msgAlpha", GetImageAlpha( imagePosition, data ) )
		RuiSetFloat(data.rui, "msgFontSize", file.size * data.imageScaleModifier )
	}
}


float function GetImagePosition(float angle)
{
	float eyeAngle = fmod(((GetLocalViewPlayer().EyeAngles().y - 180) * (-1.0)) + 180.0, 360.0)
	float x = angle - eyeAngle
	float uDiff = min( fabs(x), fabs( fabs(x) - 360.0 ) )

	//Nasty-ass fuckin math
	float diff = uDiff //temporary assignment in case of :clueless:
	float eyeAngle2 = fmod( (eyeAngle + 180), 360.0 )

	if(eyeAngle > 180)
	{
		if( (angle >= 0 && angle <= eyeAngle2) || (angle > eyeAngle && angle < 360) )
			diff = uDiff
		else
			diff = uDiff * (-1.0)
	}
	else
	{
		if( (angle >= 0 && angle <= eyeAngle) || (angle > eyeAngle2 && angle < 360) )
			diff = uDiff * (-1.0)
		else
			diff = uDiff
	}

	return (diff / 67.5) * (file.compassWidth / 2)
}


float function GetImageAlpha(float position, CustomCompassMarker data)
{
	if(!file.isVisible)
		return 0.0

	float alpha = file.baseAlpha * ((file.compassWidth/2 - fabs(position)) / (file.compassWidth / 2))

	alpha *= data.baseAlphaModifier

	if(data.fadeWithDistance)
	{
		float hDist // distance in hammer units
		if(data.useHorizontalDistance)
			hDist = HorizontalDistance( data.target.GetOrigin(), GetLocalClientPlayer().GetOrigin() )
		else
			hDist = Distance( data.target.GetOrigin(), GetLocalClientPlayer().GetOrigin() )

		float diff = data.maxVisibleDistance - hDist
		if(diff > 0)
		{
			alpha *= diff/data.maxVisibleDistance // we trust it was not set to 0 lmao
		}
		else
		{
			alpha *= 0
		}
	}

	if(data.fadeWithTime)
	{
		float currTime = Time()

		if(currTime - data.startTime < data.duration)
		{
			alpha *= ((data.duration - (currTime - data.startTime)) / data.duration)
		}
		else
		{
			alpha *= 0
		}
	}

	return alpha
}


float function fmod( float x, float y ) //the fuck
{
	return x - y * int(x / y)
}

float function HorizontalDistance(vector v1, vector v2)
{
	return sqrt((v1.x - v2.x) * (v1.x - v2.x)) + sqrt((v1.y - v2.y) * (v1.y - v2.y))
}