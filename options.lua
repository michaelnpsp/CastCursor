--==========================================================================
-- Configuration
--==========================================================================

local addon = CastCursor

local RINGS_PATH = [[Interface\Addons\CastCursor\media\]]

local RINGS = {
	['default']     = RINGS_PATH..'ring1',
	['brighter']    = RINGS_PATH..'ring2',
	['flat thin']   = RINGS_PATH..'ring3',
	['flat thick']  = RINGS_PATH..'ring4',
	['flat double'] = RINGS_PATH..'ring5',
}

--==========================================================================
-- Refresh Addon Settings
--==========================================================================

local function SetupRing(ring)
	if ring.db.visible then
		if addon.testmode and not ring.IsCursor then
			ring.reverse = nil
			ring:SetScript("OnUpdate", nil)
			addon.Start(ring, 1, 1)
		else
			addon.Setup(ring)
		end
	end
end

local function RefreshTestMode()
	for _,ring in pairs(addon.rings) do
		SetupRing(ring)
	end
end

local function RefreshMinimap()
	if addon.db.minimapIcon.hide then
		addon.minimapIcon:Hide("CastCursor")
	else
		addon.minimapIcon:Show("CastCursor")
	end
end

local function RefreshAddon(k1)
	if k1=='minimapIcon' then
		RefreshMinimap()
	elseif k1=='testmode' then
		RefreshTestMode()
	elseif addon.rings[k1] then
		addon.Setup(addon.rings[k1])
	end
end

--==========================================================================
-- Dropdown Menu management functions
--==========================================================================

local function get(key)
	if key then
		local k1, k2 = strsplit(";",key)
		if k1 and k2 then
			return addon.db[k1][k2]
		else
			return addon[k1]
		end
	end
end

local function get_color(key)
	local r, g, b, a = unpack( get(key) )
	return r, g, b, 1-a
end

local function set(key,value)
	if key then
		local k1, k2 = strsplit(";",key)
		if k1 and k2 then
			addon.db[k1][k2] = value
		else
			addon[k1] = value
		end
		RefreshAddon(k1,k2)
		return value
	end
end

local function selectorFunc(info)
	return set(info.arg1, info.value)
end

local function selectorChecked(info)
	return get(info.arg1)==info.value
end

local function toggleFunc(info)
	return set(info.value, not get(info.value) )
end

local function toggleDetach(info)
	local detach = toggleFunc(info)
	if detach then
		print("|cFFFFFF00CastCursor|r: A ring has been detached from the cursor, you can use the following chat commands to change the ring position:")
		print("   /ccursor pos x,y      - set position for all detached rings")
		print("   /ccursor pos gcd x,y  - set position for GCD ring ")
		print("   /ccursor pos cast x,y - set position for Casting ring")
	end
end

local function toggleChecked(info)
	return get(info.value)
end

local function CreateCheck(text, key, optToggleFunc)
	return { text = text, value = key, isNotRadio=true, checked = toggleChecked, func = optToggleFunc or toggleFunc, keepShownOnClick=1 }
end

local function CreateExec(text, key, func, disabled)
	return { text = text, value = key, func = func, disable = disabled, notCheckable = true, keepShownOnClick=1 }
end

local function CreateColor( text, key )
	return  {
		notCheckable= true, hasColorSwatch = true, hasOpacity= true,
		text  = text,
		value = key,
		swatchFunc = function(a,b)
			local color = get(key)
			color[1], color[2], color[3] = ColorPickerFrame:GetColorRGB()
			RefreshAddon( strsplit(";",key) )
		end,
		opacityFunc= function()
			local color = get(key)
			color[4] = 1 - OpacitySliderFrame:GetValue()
			RefreshAddon( strsplit(";",key) )
		end,
		cancelFunc = function(c)
			local color = get(key)
			color[1], color[2], color[3], color[4] = c.r, c.g, c.b, 1-c.opacity
		end,
	}
end

local function CreateNumbersMenu(key, from, to, step, count)
	step= step or 1
	count= count or 1000
	local page= step*count
	local menu,subMenu
	for i=0,to,page do
		subMenu= {}
		local j1,j2= math.max(from,i), math.min(to,i+page-step)
		for j=j1,j2,step do
			table.insert( subMenu, { text= j, value= j, arg1 = key, func = selectorFunc, checked = selectorChecked } )
		end
		if to>=page then
			if not menu then menu={} end
			table.insert( menu, { text = j1.." - "..j2, notCheckable= true, hasArrow = true,  menuList = subMenu } )
		end
	end
	return to>=page and menu or subMenu
end

local function CreateNumber(text, key, min, max, step, count)
	return { notCheckable= true, hasArrow = true, text = text, menuList = CreateNumbersMenu(key, min, max, step, count) }
end

local function CreateMedia(text, key, items)
	local sorted = {}
	for key in pairs(items) do
		sorted[#sorted+1] = key
	end
	table.sort( sorted, function(a,b) return items[a]<items[b] end )
	local options =	{ text = text, notCheckable= true, hasArrow = true, menuList = { } }
	for _,name in ipairs(sorted) do
		table.insert( options.menuList, { text = name, value = items[name], arg1 = key, func = selectorFunc, checked = selectorChecked } )
	end
	return options
end

local function CreateTitle( text )
	return { text = text, notCheckable= true, isTitle = true }
end

local function CreateSubMenu(text, subMenu)
	return	{ text = text, notCheckable= true, hasArrow = true, menuList = subMenu }
end

local function InitializeMenu( frame, level, menuList )
	if level then
		for index, item in ipairs(menuList) do
			if item.text then
				item.index = index
				if item.hasColorSwatch then
					item.r, item.g, item.b, item.opacity = get_color(item.value)
				end
				UIDropDownMenu_AddButton(item, level)
			end
		end
	end
end

local function ShowMenu( menuFrame, menuList )
	UIDropDownMenu_Initialize(menuFrame, InitializeMenu, 'MENU', nil, menuList)
	ToggleDropDownMenu(1, nil, menuFrame, 'cursor', 0, 0, menuList)
end

--==========================================================================
--  Configuration menu setup
--==========================================================================

local menu = {
	-- cast
	CreateTitle ('Cast Ring'),
	CreateCheck ( 'Enabled', 'cast;visible' ),
	CreateColor ( 'Color&Opacity', 'cast;color' ),
	CreateNumber( 'Radius', 'cast;radius', 10, 50, 1, 20 ),
	CreateNumber( 'Draw Layer', 'cast;sublayer', 0, 1 ),
	CreateMedia ( 'Ring Texture', 'cast;texture', RINGS ),
	CreateCheck ( 'Reverse Direction', 'cast;reverse' ),
	CreateCheck( 'Detach from Cursor' , 'cast;detach', toggleDetach ),
	-- gcd
	CreateTitle ('GCD Ring'),
	CreateCheck ( 'Enabled', 'gcd;visible' ),
	CreateColor ( 'Color&Opacity', 'gcd;color' ),
	CreateNumber( 'Radius', 'gcd;radius', 10, 50, 1, 20 ),
	CreateNumber( 'Draw Layer', 'gcd;sublayer', 0, 1 ),
	CreateMedia ( 'Ring Texture', 'gcd;texture', RINGS ),
	CreateCheck ( 'Reverse Direction', 'gcd;reverse' ),
	CreateCheck( 'Detach from Cursor', 'gcd;detach', toggleDetach ),
	-- cursor
	CreateTitle ('Cursor Ring'),
	CreateCheck ( 'Enabled', 'cursor;visible' ),
	CreateColor ( 'Color&Opacity', 'cursor;color' ),
	CreateNumber( 'Radius', 'cursor;radius', 10, 50, 1, 20 ),
	CreateNumber( 'Draw Layer', 'cursor;sublayer', 0, 1 ),
	CreateMedia ( 'Ring Texture', 'cursor;texture', RINGS ),
	CreateSubMenu( 'Visibility' , {
		CreateCheck ('Visible only in Combat', 'cursor;combat'),
		CreateCheck ('Hide On Player Turning', 'cursor;hidePlayerTurn'),
		CreateCheck ('Hide On Player Looking', 'cursor;hidePlayerLook'),
	}),
	CreateCheck ( 'Move to Background', 'cursor;background' ),
	-- misc
	CreateTitle ('Miscellaneous'),
	CreateCheck ( 'Hide minimap Icon', 'minimapIcon;hide' ),
	CreateCheck ( 'Enable test mode', 'testmode' ),
}

function addon:ShowMenu()
	ShowMenu(self, menu)
end

--==========================================================================
-- Databroker icon
--==========================================================================

local CastCursorLDB = LibStub("LibDataBroker-1.1", true):NewDataObject("CastCursor", {
	type  = "launcher",
	label = GetAddOnInfo("CastCursor", "Title"),
	icon  = "Interface\\AddOns\\CastCursor\\media\\icon",
	OnClick = function(self, button)
		addon:ShowMenu()
	end,
	OnTooltipShow = function(tooltip)
		tooltip:AddDoubleLine("CastCursor ",addon.versionToc)
		tooltip:AddLine("Displays Cast & GCD rings around the cursor.", 1,1,1, true)
		tooltip:AddLine("|cFFff4040Click|r to open configuration menu", 0.2, 1, 0.2)
	end,
})

--==========================================================================
-- Minimap icon
--==========================================================================

function addon:InitOptions()
	local icon = LibStub("LibDBIcon-1.0")
	if icon then
		icon:Register("CastCursor", CastCursorLDB, self.db.minimapIcon)
		addon.minimapIcon = icon
	end
	self.InitOptions = nil
end

--==========================================================================
-- Command line setup
--==========================================================================

local function ForAllDetachableRings(ring, func)
	if ring==nil or ring==addon.rings.gcd  then func(addon.rings.gcd)  end
	if ring==nil or ring==addon.rings.cast then func(addon.rings.cast) end
end

local function SetRingPosition(ring, x, y)
	ring.db.offsetx = tonumber(x) or 0
	ring.db.offsety = tonumber(y) or 0
	addon.Setup(ring)
end

local function SetRingDetach(ring)
	ring.db.detach = not ring.db.detach or nil
	addon.Setup(ring)
end

SLASH_CASTCURSOR1 = "/castcursor"
SLASH_CASTCURSOR2 = "/ccursor"
SlashCmdList.CASTCURSOR = function(input)
	local cmd, arg1, arg2 = strsplit(" ",input,3)
	cmd = strlower(cmd)
	if cmd == 'pos' then -- /ccursor pos x,y  /ccursor pos gcd|cast x,y
		local ring = addon.rings[ strlower(arg1 or '') ]
		local x, y = strsplit(",", ring and arg2 or arg1 or '')
		ForAllDetachableRings(ring, function(ring) SetRingPosition(ring, x, y) end)
	elseif cmd == 'detach' then
		local ring = addon.rings[ strlower(arg1 or '') ]
		ForAllDetachableRings(ring, function(ring) SetRingDetach(ring) end)
	elseif cmd == 'test' then
		addon.testmode = not addon.testmode
		RefreshTestMode()
	elseif cmd =='menu' then
		addon:ShowMenu()
	else
		print("CastCursor usage:")
		print("  /castcursor")
		print("  /ccursor")
		print("  /ccursor menu          - show configuration menu")
		print("  /ccursor test          - toggle test mode")
		print("  /ccursor detach        - toggle GCD&Casting rings detach mode")
		print("  /ccursor pos x,y       - set detached GCD&Casting rings position")
		print("  /ccursor detach cast   - toggle Casting ring detach mode")
		print("  /ccursor pos gcd x,y   - set detached GCD ring position")
		print("  /ccursor detach gcd    - toggle GCD ring detach mode")
		print("  /ccursor pos cast x,y  - set detached Casting ring position")
		print("\n")
	end
end

--==========================================================================
