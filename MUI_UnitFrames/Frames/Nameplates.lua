local T, C, L = select(2, ...):unpack()

local TukuiUnitFrames = T["UnitFrames"]

function TukuiUnitFrames:Nameplates()
	local HealthTexture = T.GetTexture(C["Textures"].NPHealthTexture)
	local PowerTexture = T.GetTexture(C["Textures"].NPPowerTexture)
	local CastTexture = T.GetTexture(C["Textures"].NPCastTexture)
	local Font = T.GetFont(C["NamePlates"].Font)
	local NumDebuffsPerRow = math.ceil(C.NamePlates.Width / 26)

	self:SetScale(UIParent:GetEffectiveScale())
	self:SetSize(C.NamePlates.Width, C.NamePlates.Height)
	self:SetPoint("CENTER", 0, 0)
	self:SetBackdrop(TukuiUnitFrames.Backdrop)
	self:SetBackdropColor(0, 0, 0)
	
	self:CreateShadow()

	local Health = CreateFrame("StatusBar", nil, self)
	Health:SetFrameStrata(self:GetFrameStrata())
	Health:SetPoint("TOPLEFT")
	Health:Height(C.NamePlates.Height - 4)
	Health:SetWidth(self:GetWidth())
	Health:SetStatusBarTexture(HealthTexture)

	Health.Background = Health:CreateTexture(nil, "BORDER")
	Health.Background:SetAllPoints()
	Health.Background:SetColorTexture(.1, .1, .1)

	Health.colorTapping = true
	Health.colorReaction = true
	Health.colorDisconnected = true
	Health.colorClass = true
	Health.Smooth = true
	Health.frequentUpdates = true

	local Name = Health:CreateFontString(nil, "OVERLAY")
	Name:Point("BOTTOMLEFT", Health, "TOPLEFT", -2, 4)
	Name:SetJustifyH("LEFT")
	Name:SetFontObject(Font)
	Name:SetFont(select(1, Name:GetFont()), 12, select(3, Name:GetFont()))

	self:Tag(Name, "[Tukui:Classification][Tukui:DiffColor][level] [Tukui:GetNameHostilityColor][Tukui:NameLong]")

	local Power = CreateFrame("StatusBar", nil, self)
	Power:SetFrameStrata(self:GetFrameStrata())
	Power:Height(3)
	Power:Point("TOPLEFT", Health, "BOTTOMLEFT", 0, -1)
	Power:Point("TOPRIGHT", Health, "BOTTOMRIGHT", 0, -1)
	Power:SetStatusBarTexture(PowerTexture)

	Power.Background = Power:CreateTexture(nil, "BORDER")
	Power.Background:SetAllPoints()
	Power.Background:SetColorTexture(.1, .1, .1)

	Power.IsHidden = false
	Power.frequentUpdates = true
	Power.colorPower = true
	Power.Smooth = true
	Power.PostUpdate = TukuiUnitFrames.DisplayNameplatePowerAndCastBar

	local Debuffs = CreateFrame("Frame", self:GetName()..'Debuffs', self)
	Debuffs:SetHeight(24)
	Debuffs:SetWidth(self:GetWidth())
	Debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
	Debuffs.size = 24
	Debuffs.num = NumDebuffsPerRow
	Debuffs.numRow = 1
	Debuffs.disableMouse = true
	Debuffs.spacing = 2
	Debuffs.initialAnchor = "BOTTOMLEFT"
	Debuffs["growth-y"] = "DOWN"
	Debuffs["growth-x"] = "RIGHT"
	Debuffs.PostCreateIcon = TukuiUnitFrames.PostCreateAura
	Debuffs.PostUpdateIcon = TukuiUnitFrames.PostUpdateAura
	Debuffs.onlyShowPlayer = C.NamePlates.OnlySelfDebuffs
	
	if C.NamePlates.NameplateCastBar then
		local CastBar = CreateFrame("StatusBar", "TukuiTargetCastBar", self)
		CastBar:SetFrameStrata(self:GetFrameStrata())
		CastBar:SetStatusBarTexture(CastTexture)
		CastBar:SetFrameLevel(6)
		CastBar:Height(3)
		CastBar:Point("TOPLEFT", Health, "BOTTOMLEFT", 0, -1)
		CastBar:Point("TOPRIGHT", Health, "BOTTOMRIGHT", 0, -1)

		CastBar.Background = CastBar:CreateTexture(nil, "BORDER")
		CastBar.Background:SetPoint("LEFT")
		CastBar.Background:SetPoint("BOTTOM")
		CastBar.Background:SetPoint("RIGHT")
		CastBar.Background:SetPoint("TOP", 0, 1)
		CastBar.Background:SetTexture(CastTexture)
		CastBar.Background:SetVertexColor(0.15, 0.15, 0.15)

		CastBar.Button = CreateFrame("Frame", nil, CastBar)
		CastBar.Button:Size(self:GetHeight())
		CastBar.Button:SetTemplate()
		CastBar.Button:CreateShadow()
		CastBar.Button:Point("TOPRIGHT", self, "TOPLEFT", -6, 0)

		CastBar.Icon = CastBar.Button:CreateTexture(nil, "ARTWORK")
		CastBar.Icon:SetInside()
		CastBar.Icon:SetTexCoord(unpack(T.IconCoord))

		CastBar.Text = CastBar:CreateFontString(nil, "OVERLAY")
		CastBar.Text:SetFontObject(Font)
		CastBar.Text:Point("CENTER", CastBar)
		CastBar.Text:SetTextColor(0.84, 0.75, 0.65)
		CastBar.Text:SetWidth(C.NamePlates.Width)
		CastBar.Text:SetJustifyH("CENTER")

		CastBar.PostCastStart = TukuiUnitFrames.CheckInterrupt
		CastBar.PostCastInterruptible = TukuiUnitFrames.CheckInterrupt
		CastBar.PostCastNotInterruptible = TukuiUnitFrames.CheckInterrupt
		CastBar.PostChannelStart = TukuiUnitFrames.CheckInterrupt
		
		self.Castbar = CastBar
	end

	local RaidIcon = Health:CreateTexture(nil, "OVERLAY")
	RaidIcon:Size(self:GetHeight())
	RaidIcon:Point("TOPLEFT", self, "TOPRIGHT", 4, 0)
	RaidIcon:SetTexture([[Interface\AddOns\Tukui\Medias\Textures\Others\RaidIcons]])

	self.Health = Health
	self.Buffs = Buffs
	self.Debuffs = Debuffs
	self.Name = Name
	self.Power = Power
	self.RaidTargetIndicator = RaidIcon

	-- Needed on nameplate else if will bug on AOE multi nameplates. (I'm not sure about this)
	self:EnableMouse(false)
	self.Health:EnableMouse(false)
	self.Power:EnableMouse(false)
end
