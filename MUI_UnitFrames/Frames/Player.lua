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

-- C_PlayerUnitFrame -----------------------
function C_PlayerUnitFrame:__Construct(_, unitID, settings)
    self:Super(unitID, settings);
end

local function CreateBar(parentFrame, backgroundTexture, fillTexture)
    local bar = _G.CreateFrame("StatusBar", nil, parentFrame);

    bar.Smooth = true;
    bar.frequentUpdates = true;

    -- health Bar Textures:
    bar.background = bar:CreateTexture(nil, "BACKGROUND");
    bar.background:SetAllPoints(true);
    bar.background:SetTexture(backgroundTexture);

    bar.mask = bar:CreateMaskTexture();
    bar.mask:SetAllPoints(true);
    bar.mask:SetTexture(tk:GetAssetFilePath("Textures\\Widgets\\solid.tga"),
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST");

    bar:SetStatusBarTexture(bar.mask);

    -- prevent oUF from changing this and breaking the mask
    bar.SetStatusBarTexture = tk.Constants.DUMMY_FUNC;
    bar.SetStatusBarColor = function(self, r, g, b)
        self.fill:SetVertexColor(r, g, b);
    end

    bar.fill = bar:CreateTexture(nil, "ARTWORK");
    bar.fill:SetAllPoints(true);
    bar.fill:SetTexture(fillTexture);
    bar.fill:AddMaskTexture(bar.mask);

    return bar;
end

function C_PlayerUnitFrame:ApplyStyle(data, frame)
    data.frame = frame;
    data.frame:SetScript("OnEnter", _G.UnitFrame_OnEnter);
    data.frame:SetScript("OnLeave", _G.UnitFrame_OnLeave);

    -- Health Bar:
    local healthBar = CreateBar(data.frame,
        ASSETS.."UnitFrame_Background.tga",
        ASSETS.."Animated_StatusBar.tga");

    healthBar:SetAllPoints(true);
    healthBar.colorDisconnected = true;
    healthBar.colorClass = true;
    healthBar.colorReaction = true;

    -- Power Bar:
    local powerBar = CreateBar(healthBar,
        ASSETS.."UnitFrame_PowerBarBackground.tga",
        ASSETS.."UnitFrame_PowerBarFill.tga");
    powerBar:SetPoint("TOPLEFT", 8, -2);
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
    overlay:SetTexture(ASSETS.."UnitFrame_Overlay.tga");

    -- Animator:
    local animator = C_TextureAnimator(healthBar, healthBar.fill);
    animator:SetTgaFileSize(1024, 1024);
    animator:SetGridDimensions(15, 4, 256, 64);
    animator:SetFrameRate(24);
    animator:Play();

    -- Register to oUF:
    data.frame.Health = healthBar;
    data.frame.Power = powerBar;
    -- data.frame.colors.power["MANA"] = {1, 1, 1}

    -- MayronUI:PrintTable(data.frame.colors.power, 1);
        -- data.frame.Power.PostUpdate = PostUpdatePower;
end