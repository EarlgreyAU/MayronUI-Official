-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, _, em, _, obj = MayronUI:GetCoreComponents();
local ASSETS = "interface\\addons\\MUI_UnitFrames\\Assets\\";

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");
local C_TargetUnitFrame = Engine:CreateClass("TargetUnitFrame", "BaseUnitFrame");

---@type TextureAnimator
local C_TextureAnimator = obj:Import("MayronUI.UnitFrameUtils.TextureAnimator");

-- C_PlayerUnitFrame -----------------------
function C_TargetUnitFrame:__Construct(_, unitName, settings)
    self:Super(unitName, settings);
end

function C_TargetUnitFrame:ApplyStyle(data, frame)
    data.frame = frame;
    -- Blizzard scripts:
    data.frame:SetScript("OnEnter", _G.UnitFrame_OnEnter);
    data.frame:SetScript("OnLeave", _G.UnitFrame_OnLeave);

    local health = data.frame:CreateTexture(nil, "ARTWORK");
    health:SetAllPoints(true);
    health:SetTexture(ASSETS.."Animated_StatusBar.tga");

    em:CreateEventHandler("PLAYER_TARGET_CHANGED", function()
        if (not _G.UnitExists("target")) then
            data.frame:Hide();
            return;
        end

        if (_G.UnitIsPlayer("target")) then
            local _, className = _G.UnitClass("target");
            tk:SetClassColoredTexture(className, health);
        else
            tk:ApplyThemeColor(health);
        end

        data.frame:Show();
    end);

    local border = data.frame:CreateTexture(nil, "OVERLAY");
    border:SetAllPoints(true);
    border:SetTexture(ASSETS.."UnitFrame_Overlay.tga");

    local animator = C_TextureAnimator(data.frame, health);
    animator:SetTgaFileSize(1024, 1024);
    animator:SetGridDimensions(15, 4, 256, 64);
    animator:SetFrameRate(24);
    animator:Play(); -- causes a lot of lag

    tk:MakeMovable(data.frame);

    -- Register to oUF:
    data.frame.Health = health;
end