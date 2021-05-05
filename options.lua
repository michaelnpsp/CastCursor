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
-- Minimap icon visibility
--==========================================================================

local function RefreshMinimap()
	if addon.db.minimapIcon.hide then
		addon.minimapIcon:Hide("CastCursor")
	else
		addon.minimapIcon:Show("CastCursor")
	end
end

--==========================================================================
-- Rings test mode
--==========================================================================

local function RefreshTestMode()
	for _,ring in pairs(addon.rings) do
		if not addon.testmode then
			addon.Setup(ring)
		elseif ring.db.visible and not ring.IsCursor then
			ring.reverse = nil
			ring:SetScript("OnUpdate", nil)
			addon.Start(ring, 1, 1)
		end
	end
end

--==========================================================================
-- Dropdown Menu management functions
--==========================================================================

local function refresh(k1,k2)
	if k1=='minimapIcon' then
		RefreshMinimap()
	elseif k1=='testmode' then
		RefreshTestMode()
	elseif addon.rings[k1] then
		addon.Setup(addon.rings[k1])
	end
end

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

local function set(key,value)
	if key then
		local k1, k2 = strsplit(";",key)
		if k1 and k2 then
			addon.db[k1][k2] = value
		else
			addon[k1] = value
		end
		refresh(k1,k2)
	end
end

local function selectorFunc(info)
	set(info.arg1, info.value)
end

local function selectorChecked(info)
	return get(info.arg1)==info.value
end

local function toggleFunc(info)
	set(info.value, not get(info.value) )
end

local function toggleChecked(info)
	return get(info.value)
end

local function CreateCheck(text, key)
	return { text = text, value = key, isNotRadio=true, checked = toggleChecked, func = toggleFunc, keepShownOnClick=1 }
end

local function CreateColor( text, key )
	return  {
		notCheckable= true, hasColorSwatch = true, hasOpacity= true,
		text  = text,
		value = key,
		swatchFunc = function(a,b)
			local color = get(key)
			color[1], color[2], color[3] = ColorPickerFrame:GetColorRGB()
			refresh( strsplit(";",key) )
		end,
		opacityFunc= function()
			local color = get(key)
			color[4] = 1 - OpacitySliderFrame:GetValue()
			refresh( strsplit(";",key) )
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

function CreateNumber(text, key, min, max, step, count)
	return { notCheckable= true, hasArrow = true, text = text, menuList = CreateNumbersMenu(key, min, max, step, count) }
end

function CreateMedia(text, key, items)
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

local function ShowMenu( frame, menu, anchor )
	for _,option in ipairs(menu) do
		if option.hasColorSwatch then
			option.r, option.g, option.b, option.opacity = unpack( get(option.value) )
			option.opacity = 1 - option.opacity
		end
	end
	EasyMenu( menu, frame, anchor or "cursor", 0 , 0, "MENU")
end

--==========================================================================
--  Configuration menu setup
--==========================================================================

local menu = {
	CreateTitle ('Cast Ring'),
	CreateCheck ( 'Enabled', 'cast;visible' ),
	CreateColor ( 'Color&Opacity', 'cast;color' ),
	CreateNumber( 'Radius', 'cast;radius', 10, 50, 1, 20 ),
	CreateNumber( 'Draw Layer', 'cast;sublayer', 0, 1 ),
	CreateMedia ( 'Ring Texture', 'cast;texture', RINGS ),
	CreateCheck ( 'Reverse Direction', 'cast;reverse' ),
	CreateTitle ('GCD Ring'),
	CreateCheck ( 'Enabled', 'gcd;visible' ),
	CreateColor ( 'Color&Opacity', 'gcd;color' ),
	CreateNumber( 'Radius', 'gcd;radius', 10, 50, 1, 20 ),
	CreateNumber( 'Draw Layer', 'gcd;sublayer', 0, 1 ),
	CreateMedia ( 'Ring Texture', 'gcd;texture', RINGS ),
	CreateCheck ( 'Reverse Direction', 'gcd;reverse' ),
	CreateTitle ('Cursor Ring'),
	CreateCheck ( 'Enabled', 'cursor;visible' ),
	CreateColor ( 'Color&Opacity', 'cursor;color' ),
	CreateNumber( 'Radius', 'cursor;radius', 10, 50, 1, 20 ),
	CreateNumber( 'Draw Layer', 'cursor;sublayer', 0, 1 ),
	CreateMedia ( 'Ring Texture', 'cursor;texture', RINGS ),
	CreateCheck ( 'Move to Background', 'cursor;background' ),
	CreateCheck ( 'Visible only in Combat', 'cursor;combat' ),
	CreateTitle ('Miscellaneous'),
	CreateCheck ( 'Hide minimap Icon', 'minimapIcon;hide' ),
	CreateCheck ( 'Enable test mode', 'testmode' ),
}

function addon:ShowMenu(anchor)
	ShowMenu(self, menu, anchor)
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
		tooltip:AddLine("CastCursor v" .. GetAddOnMetadata("CastCursor", "Version") )
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

SLASH_CASTCURSOR1 = "/castcursor"
SLASH_CASTCURSOR2 = "/ccursor"
SlashCmdList.CASTCURSOR = function() addon:ShowMenu(addon) end

--==========================================================================
