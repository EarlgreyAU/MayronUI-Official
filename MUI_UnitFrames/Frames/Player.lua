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

local function PostUpdatePower(unit, current, min, max)
	if (not self.Value) then
		return
	end

	-- local pType, pToken = _G.UnitPowerType(unit)
	-- local Color = T.RGBToHex(unpack(T.Colors.power[pToken]))

	-- if (unit == "player") or (unit == "pet") then
	-- 	self.Value:SetFormattedText(Color.."%s / %s|r", current, max)
	-- end
end

-- C_PlayerUnitFrame -----------------------
function C_PlayerUnitFrame:__Construct(_, unitID, settings)
    self:Super(unitID, settings);
end

function C_PlayerUnitFrame:ApplyStyle(data, frame)
    data.frame = frame;
    data.frame:SetScript("OnEnter", _G.UnitFrame_OnEnter);
    data.frame:SetScript("OnLeave", _G.UnitFrame_OnLeave);
    data.frame:SetFrameLevel(20);

    local power = _G.CreateFrame("StatusBar", nil, data.frame);
    power:SetPoint("TOPLEFT", data.frame, "TOPLEFT", 8, -2)
    power:SetSize(224, 20);
    power:SetFrameLevel(15);
    power:SetStatusBarTexture(tk.Constants.LSM:Fetch("statusbar", "MUI_StatusBar"));

    power.frequentUpdates = true;
    power.colorPower = true;
    power.Smooth = true;

    local border = data.frame:CreateTexture(nil, "OVERLAY");
    border:SetAllPoints(true);
    border:SetTexture(ASSETS.."UnitFrame_Overlay.tga");

    local health = _G.CreateFrame("StatusBar", nil, data.frame);
    health:SetAllPoints(true);
    health:SetFrameLevel(10);
    health.Smooth = true;

    local mask = health:CreateMaskTexture();
    mask:SetTexture(tk:GetAssetFilePath("Textures\\Widgets\\solid.tga"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST");
    mask:SetAllPoints(true);
    health:SetStatusBarTexture(mask);

    health.fill = health:CreateTexture(nil, "ARTWORK");
    health.fill:SetTexture(ASSETS.."Animated_StatusBar.tga");
    health.fill:SetAllPoints(true);
    health.fill:AddMaskTexture(mask);
    tk:ApplyThemeColor(health.fill);

    local animator = C_TextureAnimator(health, health.fill);
    animator:SetTgaFileSize(1024, 1024);
    animator:SetGridDimensions(15, 4, 256, 64);
    animator:SetFrameRate(24);
    animator:Play();

    -- Register to oUF:
    data.frame.Health = health;
    data.frame.Power = power;
    -- data.frame.Power.PostUpdate = PostUpdatePower;
end