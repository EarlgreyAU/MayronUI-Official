-- luacheck: ignore self 143
-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, _, _, _, obj = MayronUI:GetCoreComponents();
local ASSETS = "interface\\addons\\MUI_UnitFrames\\Assets\\";

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");
local C_PlayerUnitFrame = Engine:CreateClass("PlayerUnitFrame", "BaseUnitFrame");

---@type TextureAnimator
local C_TextureAnimator = obj:Import("MayronUI.UnitFrameUtils.TextureAnimator");

-- local function PostUpdatePower(unit, current, min, max)
-- 	if (not self.Value) then
-- 		return
-- 	end

-- 	-- local pType, pToken = _G.UnitPowerType(unit)
-- 	-- local Color = T.RGBToHex(unpack(T.Colors.power[pToken]))

-- 	-- if (unit == "player") or (unit == "pet") then
-- 	-- 	self.Value:SetFormattedText(Color.."%s / %s|r", current, max)
-- 	-- end
-- end

local function PostCastStart(self)
    -- _G.UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1);
end

local function PostCastStop(self)
    -- _G.UIFrameFadeOut(self, 2, self:GetAlpha(), 0);
end

local function CastBar_OnShow(self)
    self.overlay:SetTexture(string.format("%sOverlay\\CastingOverlay.tga", ASSETS));
end

local function CastBar_OnHide(self)
    self.overlay:SetTexture(string.format("%sOverlay\\NoCastingOverlay.tga", ASSETS));
end

local function CastBar_SetStatusBarColor(self, r, g, b)
    self.fill:SetVertexColor(r, g, b);
end

local function PostHealthUpdate(self, _, cur, max)
    self.Text:SetText(tostring(math.floor((cur / max) * 1000) / 10).."%");
end

-- C_PlayerUnitFrame -----------------------
function C_PlayerUnitFrame:__Construct(_, unitID, settings)
    self:Super(unitID, settings);
end

function C_PlayerUnitFrame:CreateBar(data, parentFrame, textureName)
    local bar = _G.CreateFrame("StatusBar", nil, parentFrame);

    bar.Smooth = true;
    bar.frequentUpdates = true;

    -- health Bar Textures:
    bar.bg = bar:CreateTexture(nil, "BACKGROUND");
    bar.bg:SetPoint("TOPLEFT", data.frame, "TOPLEFT");
    bar.bg:SetPoint("BOTTOMRIGHT", data.frame, "BOTTOMRIGHT");
    bar.bg:SetTexture(string.format("%sBackground\\%sBarBackground.tga", ASSETS, textureName));

    bar.mask = bar:CreateMaskTexture();
    bar.mask:SetAllPoints(true);
    bar.mask:SetTexture(tk:GetAssetFilePath("Textures\\Widgets\\solid.tga"),
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST");

    bar:SetStatusBarTexture(bar.mask);

    bar.fill = bar:CreateTexture(nil, "ARTWORK");
    bar.fill:SetAllPoints(true);
    bar.fill:SetTexture(string.format("%sFill\\%sBarFill.tga", ASSETS, textureName));
    bar.fill:AddMaskTexture(bar.mask);

    -- prevent oUF from changing this and breaking the mask
    bar.SetStatusBarTexture = tk.Constants.DUMMY_FUNC;
    bar.SetStatusBarColor = CastBar_SetStatusBarColor;

    return bar;
end

function C_PlayerUnitFrame:ApplyStyle(data, frame)
    data.frame = frame;
    data.frame:SetScript("OnEnter", _G.UnitFrame_OnEnter);
    data.frame:SetScript("OnLeave", _G.UnitFrame_OnLeave);

    -- Health Bar:
    local healthBar = self:CreateBar(data.frame, "Health");
    healthBar:SetAllPoints(true);
    healthBar.colorDisconnected = true;
    healthBar.colorClass = true;
    healthBar.colorReaction = true;

    healthBar.Text = healthBar:CreateFontString(nil, "OVERLAY");
    healthBar.Text:SetFontObject("GameFontHighlight");
    healthBar.Text:SetPoint("RIGHT", -12, 0);
    healthBar.Text:SetJustifyH("RIGHT");

    healthBar.PostUpdate = PostHealthUpdate;

    -- Power Bar:
    local powerBar = self:CreateBar(healthBar, "Power");
    powerBar:SetPoint("BOTTOMRIGHT", -5, 2);
    powerBar:SetSize(224, 20);

    powerBar.colorDisconnected = true;
    powerBar.colorPower = true;

    if (data.unit == "Player") then
        powerBar.Prediction = _G.CreateFrame("StatusBar", nil, powerBar);
        powerBar.Prediction:SetReverseFill(true);
        powerBar.Prediction:SetPoint("TOP");
        powerBar.Prediction:SetPoint("BOTTOM");
        powerBar.Prediction:SetPoint("RIGHT", powerBar.mask, "RIGHT");
        powerBar.Prediction:SetWidth(powerBar:GetWidth());
        powerBar.Prediction:SetStatusBarTexture(ASSETS.."UnitFrame_PowerBarFill.tga");
        powerBar.Prediction:SetStatusBarColor(1, 1, 1, .3);
    end

    -- Overlay Texture:
    local overlay = powerBar:CreateTexture(nil, "OVERLAY");
    overlay:SetPoint("TOPLEFT", data.frame, "TOPLEFT");
    overlay:SetPoint("BOTTOMRIGHT", data.frame, "BOTTOMRIGHT");

    -- TODO: When casting...
    overlay:SetTexture(string.format("%sOverlay\\NoCastingOverlay.tga", ASSETS));

    -- cast bar:
    local castBar = self:CreateBar(healthBar, "Cast");
    castBar:SetPoint("TOPLEFT", 6, -4);
    castBar:SetSize(234, 21);
    tk:ApplyThemeColor(0.8, castBar.fill);

    castBar.Time = castBar:CreateFontString(nil, "OVERLAY");
    castBar.Time:SetFontObject("GameFontHighlight");
    tk:SetFontSize(castBar.Time, 11);
    castBar.Time:SetPoint("RIGHT", -20, 0);
    castBar.Time:SetJustifyH("RIGHT");

    castBar.Text = castBar:CreateFontString(nil, "OVERLAY");
    castBar.Text:SetFontObject("GameFontHighlight");
    tk:SetFontSize(castBar.Text, 11);
    castBar.Text:SetPoint("LEFT", 12, 0);
    castBar.Text:SetWidth(166);
    castBar.Text:SetJustifyH("LEFT");

    -- Add spark
    -- castBar.Spark = castBar:CreateTexture(nil, 'OVERLAY');
    -- castBar.Spark:SetSize(20, 20);
    -- castBar.Spark:SetBlendMode('ADD');

    castBar.timeToHold = 1; -- doesn't work with PostCastStop
    castBar.overlay = overlay;
    castBar.PostCastStart = PostCastStart;
    castBar.PostCastStop = PostCastStop;

    castBar:SetScript("OnShow", CastBar_OnShow);
    castBar:SetScript("OnHide", CastBar_OnHide);

    -- castBar.SafeZone = castBar:CreateTexture(nil, "ARTWORK")
    -- castBar.SafeZone:SetTexture(ASSETS)
    -- castBar.SafeZone:SetVertexColor(0.69, 0.31, 0.31, 0.75)


    -- Animator:
    local animator = C_TextureAnimator(healthBar, healthBar.fill);
    animator:SetTgaFileSize(1024, 1024);
    animator:SetGridDimensions(15, 4, 256, 64);
    animator:SetFrameRate(24);
    animator:Play();

    -- Register to oUF:
    data.frame.Health = healthBar;
    data.frame.Power = powerBar;
    data.frame.Castbar = castBar;
    -- data.frame.colors.power["MANA"] = {1, 1, 1}

    -- MayronUI:PrintTable(data.frame.colors.power, 1);
        -- data.frame.Power.PostUpdate = PostUpdatePower;
end
