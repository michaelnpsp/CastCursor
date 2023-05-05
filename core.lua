--====================================================================
-- CastCursor @ 2018 MiChaeL
--====================================================================

local addonName = ...

local addon = CreateFrame("Frame", "CastCursor", UIParent, "UIDropDownMenuTemplate")

--====================================================================

local UIParent = UIParent
local GetTime = GetTime
local UnitCastingInfo = UnitCastingInfo or CastingInfo
local UnitChannelInfo = UnitChannelInfo or ChannelInfo
local GetSpellCooldown = GetSpellCooldown
local GetCursorPosition = GetCursorPosition
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local next, unpack, floor, cos, sin, max, min = next, unpack, floor, cos, sin, max, min

local isRetail = select(4, GetBuildInfo())>=30000

local versionToc = GetAddOnMetadata(addonName,'Version')
addon.versionToc = versionToc=='\@project-version\@' and 'Dev' or 'v'..versionToc

--====================================================================

local Defaults = {
	cast = {
		visible = true,
		radius = 25,
		sublayer = 1,
		thickness = 5,
		color = { 1, .7, 0, 1 },
		texture = [[Interface\Addons\CastCursor\media\ring1]],
	},
	gcd = {
		visible = true,
		radius = 20,
		sublayer = 0,
		thickness = 5,
		color = { .7, 1, 0, 1 },
		texture = [[Interface\Addons\CastCursor\media\ring1]],
	},
	cursor = {
		visible = false,
		radius = 12,
		sublayer = 0,
		thickness = 5,
		color = { 0, 0.9, 1, 1 },
		texture = [[Interface\Addons\CastCursor\media\ring2]],
	},
	minimapIcon = { hide = false },
}

--====================================================================

local QUAD_POINTS = {
	{ 'TOPLEFT',     'TOP'    },
	{ 'TOPRIGHT',    'RIGHT'  },
	{ 'BOTTOMRIGHT', 'BOTTOM' },
	{ 'BOTTOMLEFT',  'LEFT'   },
}

local QUAD_COORD_FULL = {
	{ 0,0, 0,1, 1,0, 1,1 },
	{ 0,1, 1,1, 0,0, 1,0 },
	{ 1,1, 1,0, 0,1, 0,0 },
	{ 1,0, 0,0, 1,1, 0,1 },
}

local QUAD_COORD_FUNC = {
	function(t, r, x1, x2, y1, y2) -- Quadrant1: TOPRIGHT
		t:SetTexCoord(x1,1-y2, x1,1-y1, x2,1-y2, x2,1-y1)
		t:SetSize(x2*r, (1-y1)*r)
	end,
	function(t, r, x1, x2, y1, y2) -- Quadrant2: BOTTOMRIGHT
		t:SetTexCoord(x1,1-y1, x2,1-y1, x1,1-y2, x2,1-y2)
		t:SetSize((1-y1)*r, x2*r)
	end,
	function(t, r, x1, x2, y1, y2) -- Quadrant3: BOTTOMLEFT
		t:SetTexCoord(x2,1-y1, x2,1-y2, x1,1-y1, x1,1-y2)
		t:SetSize(x2*r, (1-y1)*r)
	end,
	function(t, r, x1, x2, y1, y2) -- Quadrant4: TOPLEFT
		t:SetTexCoord(x2,1-y2, x1,1-y2, x2,1-y1, x1,1-y1)
		t:SetSize((1-y1)*r, x2*r)
	end,
}

--====================================================================
-- Utils
--====================================================================

function CopyDefaults(src, dst)
	if type(dst)~="table" then dst = {} end
	for k,v in pairs(src) do
		if type(v)=="table" then
			dst[k] = CopyDefaults(v,dst[k])
		elseif dst[k]==nil then
			dst[k] = v
		end
	end
	return dst
end

--====================================================================
-- Root Frame
--====================================================================

local rootFrame = CreateFrame("Frame", nil, UIParent)

rootFrame:SetSize(8,8)
rootFrame:SetScript("OnUpdate", function(self)
	local x, y = GetCursorPosition()
	local scaleDivisor = UIParent:GetEffectiveScale()
	self:ClearAllPoints()
	self:SetPoint( "CENTER", UIParent, "BOTTOMLEFT", x / scaleDivisor , y / scaleDivisor )
end )

local ringsVisible = {}
local function RingSetShown(self, visible)
	if visible then
		if not next(ringsVisible) then
			rootFrame:Show()
		end
		ringsVisible[self] = true
		self:Show()
	else
		ringsVisible[self] = nil
		if not next(ringsVisible) then
			rootFrame:Hide()
		end
		self:Hide()
	end
end

--====================================================================
-- Shared functions
--====================================================================

local function OnEvent(self,event,...)
	self[event](self,event,...)
end

local function Start(self, d, m)
	local textures = self.textures
	local quad = min( floor( 4 * (self.reverse and m-d or d)/m ) + 1, 4)
	for i=1,4 do
		local tex = textures[i]
		if i>quad then
			tex:SetTexCoord(0,0,1,1)
			tex:Hide()
		else
			tex:SetTexCoord(unpack(QUAD_COORD_FULL[i]))
			tex:SetSize(self.radius, self.radius)
			tex:Show()
		end
	end
	self.quad = quad
	self.dur  = max(d,0)
	self.max  = m
	RingSetShown(self, true)
end

local function Update(self, elapsed)
	local dur = self.dur + elapsed
	if dur>=self.max then RingSetShown(self,false); return end
	self.dur = dur

	local rev    = self.reverse
	local maxdur = self.max
	local radius = self.radius
	local angle  = 360 * ( rev and maxdur-dur or dur ) / maxdur
	local qangle = angle % 90
	local quad   = floor(angle/90) + 1
	local tex    = self.textures[quad]
	local pquad  = self.quad
	if quad~=pquad then
		if pquad>0 and pquad<5 then
			local ptex = self.textures[pquad]
			if rev then
				ptex:Hide()
			else
				ptex:SetTexCoord(unpack(QUAD_COORD_FULL[pquad]))
				ptex:SetSize(radius, radius)
			end
		end
		tex:Show()
		self.quad = quad
	end

	if qangle>0 then
		local f = qangle<=45 and self.factor or 1
		QUAD_COORD_FUNC[quad]( tex, radius, 0, sin(qangle)*f, cos(qangle)*f, 1 )
	end
end

local function Setup(frame)
	local cfg     = frame.db
	local radius  = cfg.radius
	local r,g,b,a = unpack(cfg.color)
	frame:SetScale(1)
	frame:SetAlpha(a or 1)
	frame:SetFrameStrata( cfg.background and "BACKGROUND" or "TOOLTIP" )
	frame:ClearAllPoints()
	if cfg.detach then
		frame:SetPoint('CENTER', UIParent, 'CENTER', cfg.offsetx or 0, cfg.offsety  or 0)
	else
		frame:SetPoint('CENTER', rootFrame, 'CENTER', 0, 0)
	end
	frame:SetSize(radius*2, radius*2)
	frame.textures = frame.textures or {}
	local hide = ( not addon.testmode or not cfg.visible ) and not frame.IsCursor
	for i=1,4 do
		local tex = frame.textures[i] or frame:CreateTexture(nil, "OVERLAY")
		tex:ClearAllPoints()
		tex:SetDrawLayer("OVERLAY", cfg.sublayer or 0)
		tex:SetTexture(cfg.texture or [[Interface\Addons\CastCursor\ring.tga]])
		tex:SetVertexColor(r, g, b)
		tex:SetTexCoord(unpack(QUAD_COORD_FULL[i]))
		tex:SetSize(radius, radius)
		tex:SetPoint(QUAD_POINTS[i][1], frame, QUAD_POINTS[i][2])
		if hide then tex:Hide() end
		frame.textures[i] = tex
	end
	frame.quad   = 0
	frame.radius = radius
	frame.factor = (radius-cfg.thickness)/radius
	frame.reverse = cfg.reverse
	if not addon.testmode then
		frame:SetupRing()
	end
	return frame
end

--====================================================================
-- Casting/Channeling Ring
--====================================================================

local Cast = CreateFrame("Frame", nil, rootFrame)

function Cast:SetupRing()
	self:SetScript("OnEvent", self.db.visible and OnEvent or nil)
	self:SetScript("OnUpdate", Update)
	RingSetShown( self, false )
end

Cast:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
Cast:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
function Cast:UNIT_SPELLCAST_START(event, unit)
	local name, _, _, start, finish, _, castID = UnitCastingInfo("player")
	if name then
		self.castID = castID
		Start(self, GetTime() - start/1000, (finish - start) / 1000 )
	else
		RingSetShown( self, false )
	end
end
Cast.UNIT_SPELLCAST_DELAYED = Cast.UNIT_SPELLCAST_START

Cast:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
Cast:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
Cast:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
Cast:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
function Cast:UNIT_SPELLCAST_STOP(event, unit, castID)
	if castID == self.castID then
		RingSetShown( self, false )
	end
end
Cast.UNIT_SPELLCAST_FAILED = Cast.UNIT_SPELLCAST_STOP
Cast.UNIT_SPELLCAST_INTERRUPTED = Cast.UNIT_SPELLCAST_STOP
Cast.UNIT_SPELLCAST_CHANNEL_STOP = Cast.UNIT_SPELLCAST_STOP

Cast:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
Cast:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
function Cast:UNIT_SPELLCAST_CHANNEL_START(event, unit)
	local name, _, _, start, finish = UnitChannelInfo("player")
	if name then
		self.castID = nil
		Start(self, GetTime() - start/1000, (finish - start) / 1000 )
	else
		RingSetShown( self, false )
	end
end
Cast.UNIT_SPELLCAST_CHANNEL_UPDATE = Cast.UNIT_SPELLCAST_CHANNEL_START

--====================================================================
-- GCD Ring
--====================================================================

local GCD = CreateFrame("Frame", nil, rootFrame)

function GCD:SetupRing()
	self.hideOnCast = self.db.hideOnCast
	self:SetScript("OnEvent", self.db.visible and OnEvent or nil)
	self:SetScript("OnUpdate", Update)
	RingSetShown( self, false )
end

GCD:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
GCD:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
function GCD:UNIT_SPELLCAST_START(event, unit, guid, spellID)
	local start, duration = GetSpellCooldown( isRetail and 61304 or spellID )
	if duration>0 and (isRetail or duration<=1.51) and not (self.hideOnCast and Cast:IsShown()) then
		Start(self, GetTime() - start, duration )
	end
end
GCD.UNIT_SPELLCAST_SUCCEEDED = GCD.UNIT_SPELLCAST_START

GCD:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
GCD:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
function GCD:UNIT_SPELLCAST_STOP(event, unit, castID)
	RingSetShown( self, false )
end
GCD.UNIT_SPELLCAST_INTERRUPTED = GCD.UNIT_SPELLCAST_STOP

--====================================================================
-- Cursor Ring
--====================================================================

local Cursor = CreateFrame("Frame", nil, rootFrame)
Cursor.IsCursor = true
Cursor:Hide()

function Cursor:SetupRing()
	local cfg = self.db
	self:UnregisterAllEvents()
	if cfg.visible and (cfg.combat or cfg.hidePlayerTurn or cfg.hidePlayerLook) then
		self:SetScript("OnEvent", OnEvent)
		if cfg.hidePlayerTurn then
			self:RegisterEvent('PLAYER_STARTED_TURNING')
			self:RegisterEvent('PLAYER_STOPPED_TURNING')
		end
		if cfg.hidePlayerLook then
			self:RegisterEvent('PLAYER_STARTED_LOOKING')
			self:RegisterEvent('PLAYER_STOPPED_LOOKING')
		end
		if cfg.combat then
			self:RegisterEvent('PLAYER_REGEN_ENABLED')
			self:RegisterEvent('PLAYER_REGEN_DISABLED')
		end
		RingSetShown( self, not cfg.combat or InCombatLockdown() )
	else
		self:SetScript("OnEvent", nil)
		RingSetShown( self, cfg.visible )
	end
end

function Cursor:PLAYER_REGEN_DISABLED()
	RingSetShown(self,true)
end

function Cursor:PLAYER_REGEN_ENABLED()
	RingSetShown(self,false)
end

Cursor.PLAYER_STARTED_TURNING = Cursor.PLAYER_REGEN_ENABLED
Cursor.PLAYER_STOPPED_TURNING = Cursor.PLAYER_REGEN_DISABLED
Cursor.PLAYER_STARTED_LOOKING = Cursor.PLAYER_REGEN_ENABLED
Cursor.PLAYER_STOPPED_LOOKING = Cursor.PLAYER_REGEN_DISABLED

--====================================================================
-- Run
--====================================================================

addon:RegisterEvent("ADDON_LOADED")
addon:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then return end
	CastCursorDB = CopyDefaults(Defaults, CastCursorDB)
	self:UnregisterEvent("ADDON_LOADED")
	self:SetScript("OnEvent", nil)
	self:SetPoint("Center", UIParent, "Center")
	self:Hide()
	self.db       = CastCursorDB
	Cursor.db     = self.db.cursor
	Cast.db       = self.db.cast
	GCD.db        = self.db.gcd
	self.Start    = Start
	self.Update   = Update
	self.Setup    = Setup
	self.Defaults = Defaults
	self.rings    = { cast = Cast, gcd = GCD, cursor = Cursor }
	Setup(Cursor)
	Setup(Cast)
	Setup(GCD)
	self:InitOptions()
end )

--==========================================================================
