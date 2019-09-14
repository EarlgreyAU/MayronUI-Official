local _, namespace = ...;

-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, _, _, _, obj = MayronUI:GetCoreComponents();

local unpack, CreateFrame, InCombatLockdown, CancelUnitBuff, GameTooltip, UnitAura =
    _G.unpack, _G.CreateFrame, _G.InCombatLockdown, _G.CancelUnitBuff, _G.GameTooltip, _G.UnitAura;

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

---@class C_Aura : Object
local C_Aura = Engine:CreateClass("Aura", "Framework.System.FrameWrapper");
namespace.C_Aura = C_Aura;

-- Local Functions ---------------------
local function CancelAura(self)
    if (InCombatLockdown()) then
        return; -- cannot cancel buffs in combat due to protected blizzard utf8.codepoint(
    end

    if (self.filter) then
        -- it is a standard aura
        CancelUnitBuff("player", self:GetID(), self.filter);
    end
end

local function AuraButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, 0);

    if (not self.filter) then
        GameTooltip:SetInventoryItem("player", self:GetID());
    else
        GameTooltip:SetUnitAura("player", self:GetID(), self.filter);
    end

    GameTooltip:Show();
end

local function UpdateTextAppearance(settings, name, btn, point, relativePoint, relativeFrame) --luacheck:ignore
    local fontString = btn[name.."Text"];
    fontString:SetTextColor(unpack(settings.colors[name]));

    relativeFrame = relativeFrame or btn;

    if (btn.statusBar) then
        fontString:SetPoint(point, relativeFrame, relativePoint, unpack(settings.textPosition.statusBars[name]));
        tk:SetFontSize(fontString, settings.textSize.statusBars[name]);
    else
        fontString:SetPoint(point, relativeFrame, relativePoint, unpack(settings.textPosition[name]));
        tk:SetFontSize(fontString, settings.textSize[name]);
    end
end

-- C_Aura -------------------------------
function C_Aura:__Construct(data, parent, settings, auraID, filter)
    data.settings = settings;
    data.frame = CreateFrame("Button", nil, parent);

    local btn = data.frame;
    btn:SetID(auraID);

    btn.obj = self;
    btn.filter = filter;

    if (filter == "HELPFUL") then
        btn:RegisterForClicks("RightButtonUp");
        btn:SetScript("OnClick", CancelAura)
    end

    btn:SetScript("OnEnter", AuraButton_OnEnter);
    btn:SetScript("OnLeave", tk.GeneralTooltip_OnLeave);

    btn.iconFrame = CreateFrame("Frame", nil, btn);
    btn.iconTexture = btn.iconFrame:CreateTexture(nil, "ARTWORK");
    btn.iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9);
    btn.iconTexture:SetPoint("TOPLEFT", data.settings.border.size, -data.settings.border.size);
    btn.iconTexture:SetPoint("BOTTOMRIGHT", -data.settings.border.size, data.settings.border.size);

    btn.countText = btn.iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal");
    UpdateTextAppearance(data.settings, "count", btn, "BOTTOMRIGHT", "BOTTOMRIGHT", btn.iconTexture);

    if (settings.statusBars.enabled) then
        self:SetUpStatusBar();
    else
        self:SetUpIcon();
    end

    self:SetBorderShown(data.settings.border.show);
    self:SetSparkShown(data.settings.statusBars.showSpark);
end

function C_Aura:SetUpStatusBar(data)
    local btn = data.frame;
    local statusBars = data.settings.statusBars;

    btn:SetSize(statusBars.width, statusBars.height);
    btn.iconFrame:SetWidth(statusBars.height);
    btn.iconFrame:SetPoint("TOPLEFT");
    btn.iconFrame:SetPoint("BOTTOMLEFT");

    btn.statusBarFrame = CreateFrame("Frame", nil, btn);
    btn.statusBarFrame:SetPoint("TOPLEFT", btn.iconFrame, "TOPRIGHT", statusBars.iconGap, 0);
    btn.statusBarFrame:SetPoint("BOTTOMRIGHT");

    btn.statusBar = CreateFrame("StatusBar", nil, btn.statusBarFrame);
    btn.statusBar:SetStatusBarTexture(tk.Constants.LSM:Fetch("statusbar", statusBars.barTexture));
    btn.statusBar:SetPoint("TOPLEFT", data.settings.border.size, -data.settings.border.size);
    btn.statusBar:SetPoint("BOTTOMRIGHT", -data.settings.border.size, data.settings.border.size);

    btn.background = tk:SetBackground(btn.statusBarFrame, 0, 0, 0);
    btn.background:SetVertexColor(unpack(data.settings.colors.statusBarBackground));

    local auraColor = self:GetAuraColor();

    if (obj:IsTable(auraColor)) then
        btn.statusBar:SetStatusBarColor(unpack(auraColor));
    end

    btn.auraNameText = btn.statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    UpdateTextAppearance(data.settings, "auraName", btn, "LEFT", "LEFT");
    btn.auraNameText:SetJustifyH("LEFT");

    btn.timeRemainingText = btn.statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    UpdateTextAppearance(data.settings, "timeRemaining", btn, "RIGHT", "RIGHT");
    btn.timeRemainingText:SetJustifyH("RIGHT");
end

function C_Aura:SetUpIcon(data)
    local btn = data.frame;

    btn:SetSize(data.settings.icons.auraSize, data.settings.icons.auraSize);
    btn.iconTexture:SetPoint("TOPLEFT", data.settings.icons.borderSize, -data.settings.icons.borderSize);
    btn.iconTexture:SetPoint("BOTTOMRIGHT", -data.settings.icons.borderSize, data.settings.icons.borderSize);

    local auraColor = self:GetAuraColor();
    if (obj:IsTable(auraColor)) then
        btn.background:SetVertexColor(unpack(auraColor));
    end

    UpdateTextAppearance(data.settings, "timeRemaining", btn, "TOP", "BOTTOM");
end

--Changes which aura is being tracked and updates the icon and aura name
Engine:DefineParams("number|boolean", "?string", "?string");
function C_Aura:SetAura(data, iconTexture, auraName, debuffType)
    local btn = data.frame;

    if (not iconTexture) then
        btn:Hide();
        return;
    end

    btn.iconTexture:SetTexture(iconTexture);

    if (btn.auraNameText) then
        btn.auraNameText:SetText(auraName);
    end

    local color = data.settings.colors.aura;

    if (debuffType) then
        color = data.settings.colors[debuffType:lower()];
    end

    if (obj:IsTable(color)) then
        btn.background:SetVertexColor(unpack(color));
    end

    btn:Show();
    btn.forceUpdate = true;
end

function C_Aura:SetBorderShown(data, shown)
    if (not data.backdrop and not shown) then
        return;
    end

    local backdrop = nil;

    if (shown) then
        if (not data.backdrop) then
            data.backdrop = obj:PopTable();
        end

        local borderType = data.settings.border.type;
        local borderSize = data.settings.border.size;

        data.backdrop.edgeFile = tk.Constants.LSM:Fetch("border", borderType);
        data.backdrop.edgeSize = borderSize;

        backdrop = data.backdrop;
    end

    if (data.frame.statusBarFrame) then
        data.frame.statusBarFrame:SetBackdrop(backdrop);
        data.frame.statusBarFrame:SetBackdropBorderColor(unpack(data.settings.colors.statusBarBorder));
    end

    data.frame.iconFrame:SetBackdrop(backdrop);
    data.frame.iconFrame:SetBackdropBorderColor(unpack(data.settings.colors.statusBarBorder));
end

Engine:DefineReturns("table");
function C_Aura:GetAuraColor(data)
    local btn = data.frame;
    local _, _, _, debuffType = UnitAura("player", btn:GetID(), btn.filter);
    local auraColor;

    if (btn.filter == "HARMFUL" and debuffType) then
        auraColor = data.settings.colors[debuffType:lower()];
    elseif (not btn.filter) then
        auraColor = data.settings.colors.enchant;
    end

    if (not obj:IsTable(auraColor)) then
        if (data.settings.statusBars.enabled) then
            auraColor = data.settings.colors.statusBarAura;
        else
            auraColor = data.settings.colors.auras;
        end
    end

    return auraColor;
end

Engine:DefineParams("boolean");
---@param shown boolean @Set to true to show the timer bar spark effect.
function C_Aura:SetSparkShown(data, shown)
    local btn = data.frame;

    if (not btn.spark and not shown) then
        return;
    end

    if (not btn.spark) then
        btn.spark = btn.statusBar:CreateTexture(nil, "OVERLAY");
        btn.spark:SetSize(26, 50);
        btn.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark");

        local r, g, b = tk:GetThemeColor();
        btn.spark:SetVertexColor(r, g, b);
        btn.spark:SetBlendMode("ADD");
    end

    btn.spark:SetShown(shown);
    data.showSpark = shown;
end

function C_Aura:UpdateStatusBar(data, duration, timeRemaining)
    local btn = data.frame;

    if (timeRemaining > 0) then
        btn.statusBar:SetMinMaxValues(0, duration);
        btn.statusBar:SetValue(timeRemaining);

        if (btn.spark) then
            local offset = btn.spark:GetWidth() / 2;
            local barWidth = btn.statusBar:GetWidth();
            local value = (timeRemaining / duration) * barWidth - offset;

            if (value > barWidth - offset) then
                value = barWidth - offset;
            end

            btn.spark:SetPoint("LEFT", value, 0);
            btn.spark:Show();
        end
    else
        btn.statusBar:SetMinMaxValues(0, 1);

        if (timeRemaining > -10) then
            -- for slow to remove buffs (like weapon enchants that take time to fade away)
            btn.statusBar:SetValue(0);
        elseif (timeRemaining < 0) then
            btn.statusBar:SetValue(1);
        end

        btn.duration = nil;

        if (btn.spark) then
            btn.spark:Hide();
        end
    end
end