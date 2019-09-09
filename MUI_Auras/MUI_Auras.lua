-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, db, em, _, obj = MayronUI:GetCoreComponents();

local GetTime, SecondsToTimeAbbrev, GetWeaponEnchantInfo, select, UnitAura, pairs, ipairs,
    CreateFrame, GameTooltip, unpack, math, GetInventoryItemTexture, string, BUFF_MAX_DISPLAY,
    DEBUFF_MAX_DISPLAY, UIParent = _G.GetTime, _G.SecondsToTimeAbbrev, _G.GetWeaponEnchantInfo,
    _G.select, _G.UnitAura, _G.pairs, _G.ipairs, _G.CreateFrame, _G.GameTooltip, _G.unpack, _G.math,
    _G.GetInventoryItemTexture, _G.string, _G.BUFF_MAX_DISPLAY, _G.DEBUFF_MAX_DISPLAY, _G.UIParent;

-- Main-Hand, Off-Hand, Ranged
local enchantAuraIds = { 16, 17, 18 };
local ARGS_PER_ITEM = 4;

-- Objects -----------------------------

--TODO: Make configurable

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

---@class AurasModule : BaseModule
local C_AurasModule = MayronUI:RegisterModule("AurasModule", "Auras (Buffs & Debuffs)");

---@class C_AuraArea : Object
local C_AuraArea = Engine:CreateClass("AuraArea", "Framework.System.FrameWrapper");

-- Load Database Defaults --------------

db:AddToDefaults("profile.auras", {
    __templateAuraArea = {
        enabled       = true;
        unlocked      = false;
        position = {"CENTER", "UIParent", "CENTER", 0,  0};
        colSpacing = 4;
        rowSpacing = 16;
        perRow = 15;
        direction = "LEFT";
        showEnchants = false;
        auraSize = 32;
    };
    appearance = {
        border        = "Skinner";
        borderSize    = 1;
        inset         = 1;
    };
    Buffs = {
        position = {"TOPRIGHT", "Minimap", "TOPLEFT", -4, 0};
        auraType = "Buffs";
        showEnchants = true;
    };

    Debuffs = {
        position = {"TOPRIGHT", "MUI_BuffsArea", "BOTTOMRIGHT", 0, -10};
        auraType = "Debuffs";
    };
});

-- Local Functions -------------

local function AuraButton_OnUpdate(self)
    local _, _, count, _, _, expirationTime, _, _, _,
        _, _, _, _, _, timeMod = UnitAura("player", self.id, "HELPFUL");

    if (not (count and expirationTime)) then
        return;
    end

    if (count < 1) then
        self.countText:SetText(tk.Strings.Empty);
    else
        self.countText:SetText(count);
    end

    local timeRemaining = expirationTime - GetTime();

    if (timeRemaining > 0) then
        if (timeMod > 0) then
            timeRemaining = timeRemaining / timeMod;
        end

        self.timeRemaining = timeRemaining;
        self.timeRemainingText:SetFormattedText(SecondsToTimeAbbrev(timeRemaining));
    else
        self.timeRemaining = nil;
        self.timeRemainingText:SetText(tk.Strings.Empty);
    end
end

local function AuraEnchantButton_OnUpdate(self, globalName)
    local id = self.id;
    local index = tk.Tables:IndexOf(enchantAuraIds, id);
    local hasEnchant, expirationTime, count = select(ARGS_PER_ITEM * (index - 1) + 1, GetWeaponEnchantInfo());

    if (not hasEnchant) then
        self.isEnchantActive = nil;
        -- enable/disable auraButtons:
        em:FindEventHandlerByKey(globalName.."Handler"):Run("UNIT_AURA");
        return;
    end

    if (count < 1) then
        self.countText:SetText(tk.Strings.Empty);
    else
        self.countText:SetText(count);
    end

    if (expirationTime) then
        expirationTime = expirationTime / 1000;
        self.timeRemaining = expirationTime;
        self.timeRemainingText:SetFormattedText(SecondsToTimeAbbrev(expirationTime));
    else
        self.timeRemaining = nil;
        self.timeRemainingText:SetText(tk.Strings.Empty);
    end

    -- ensure that PLAYER_ENTERING_WORLD works for enchants
    if (not self.isEnchantActive) then
        self.isEnchantActive = true;
        -- enable/disable auraButtons:
        em:FindEventHandlerByKey(globalName.."Handler"):Run("UNIT_AURA");
    end
end

local function AuraButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, 0);

    if (not self.filter) then
        GameTooltip:SetInventoryItem("player", self.id);
    else
        GameTooltip:SetUnitAura("player", self.id, self.filter);
    end

    GameTooltip:Show();
end

local function CreateAuraButton(parent, filter)
    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate");
    btn:RegisterForClicks("RightButtonUp");
    btn:SetScript("OnEnter", AuraButton_OnEnter);
    btn:SetScript("OnLeave", tk.GeneralTooltip_OnLeave);

    btn:SetSize(32, 32);

    btn.filter = filter;

    btn.iconTexture = btn:CreateTexture(nil, "ARTWORK");
    btn.iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    btn.iconTexture:SetPoint("TOPLEFT", 1, -1);
    btn.iconTexture:SetPoint("BOTTOMRIGHT", -1, 1);

    btn.countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal");
    btn.countText:SetPoint("BOTTOMRIGHT", 0, 2);

    btn.timeRemainingText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    btn.timeRemainingText:SetPoint("TOP", btn, "BOTTOM", 0, -2);

    return btn;
end

local function SetAuraButtonIconTexture(btn, iconTexture)
    if (iconTexture) then
        btn:EnableMouse(true);
        btn.iconTexture:SetTexture(iconTexture);
        btn.forceUpdate = true;
        btn:SetAlpha(1);
    else
        btn:EnableMouse(false);
        btn.iconTexture:SetTexture("");
        btn:SetAlpha(0);
    end
end

---@param auras table
---@param totalAuras number
---@param filter string
local function AuraArea_OnEvent(_, _, buttons, totalAuras, filter)
    local totalArgs = select("#", GetWeaponEnchantInfo());
    local totalItems = totalArgs / ARGS_PER_ITEM;
    local totalActiveEnchants = 0;

    -- check weapon enchant auras:
    for index = 1, totalItems do
        local hasEnchant = select(ARGS_PER_ITEM * (index - 1) + 1, GetWeaponEnchantInfo());
        local btn = buttons[index];
        local iconTexture;
        btn.id = enchantAuraIds[index];
        btn:SetAttribute("type2", nil);
        btn:SetAttribute("cancelaura", nil);

        if (hasEnchant) then
            btn.filter = nil; -- for tooltip to work
            iconTexture = GetInventoryItemTexture("player", enchantAuraIds[index]);
            totalActiveEnchants = totalActiveEnchants + 1;
        end

        SetAuraButtonIconTexture(btn, iconTexture);
    end

    -- check regular auras:
    for auraID = 1, totalAuras - #enchantAuraIds do
        local buttonIndex = auraID + totalActiveEnchants;
        local btn = buttons[buttonIndex];
        local name, iconTexture = UnitAura("player", auraID, filter);
        btn.id = auraID;
        btn:SetAttribute("type2", "cancelaura");
        btn:SetAttribute("cancelaura", "player", auraID);
        SetAuraButtonIconTexture(btn, name and iconTexture);
    end
end

-- should only handle updating time remaining and counts
local function AuraArea_OnUpdate(self, elapsed, auraButtons)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    for _, btn in ipairs(auraButtons) do
        if (self.timeSinceLastUpdate > 1 or btn.forceUpdate) then
            btn.forceUpdate = nil;

            if (tk.Tables:Contains(enchantAuraIds, btn.id)) then
                AuraEnchantButton_OnUpdate(btn, self:GetName());
            else
                AuraButton_OnUpdate(btn);
            end

            if (self.timeSinceLastUpdate > 1) then
                self.timeSinceLastUpdate = 0;
            end
        end
    end
end

-- C_AuraArea ----------------------

Engine:DefineParams("table", "string");
function C_AuraArea:__Construct(data, settings, areaName)
    data.settings = settings[areaName];
    data.appearance = settings.appearance; -- not using yet
    data.globalName = string.format("MUI_%sArea", areaName);
    data.auraButtons = obj:PopTable(); -- stores all C_Aura objects (including enchant auras)

    if (data.settings.auraType == "Buffs") then
        data.totalAuras = BUFF_MAX_DISPLAY;
        data.filter = "HELPFUL";
    else
        data.totalAuras = DEBUFF_MAX_DISPLAY;
        data.filter = "HARMFUL";
    end
end

Engine:DefineParams("boolean")
function C_AuraArea:SetEnabled(data, enabled)
    if (not data.frame and not enabled) then
        return;
    end

    if (enabled) then
        if (not data.frame) then
            data.frame = CreateFrame("Frame", data.globalName, UIParent);

            local s = data.settings;
            data.frame:SetSize(
                ((s.auraSize + s.colSpacing) * s.perRow) - s.colSpacing,
                ((s.auraSize + s.rowSpacing) * math.ceil(BUFF_MAX_DISPLAY / s.perRow)) - s.rowSpacing);

            data.frame:SetPoint(unpack(s.position));

            for index = 1, (data.totalAuras + #enchantAuraIds) do
                data.auraButtons[index] = CreateAuraButton(data.frame, data.filter);
            end

            self:PositionAuraButtons();

            -- Can I shorten this?
            em:CreateUnitEventHandlerWithKey("UNIT_AURA", data.globalName.."Handler", AuraArea_OnEvent, "Player")
                :SetCallbackArgs(data.auraButtons, data.totalAuras, data.filter)
                :AppendEvent("GROUP_ROSTER_UPDATE")
                :AppendEvent("PLAYER_ENTERING_WORLD")
        end

        data.frame.timeSinceLastUpdate = 0;
        data.frame:SetScript("OnUpdate", function(self, elapsed)
            AuraArea_OnUpdate(self, elapsed, data.auraButtons);
        end);

        -- Hide Blizzard frames
        tk:KillElement(_G.BuffFrame);
        tk:KillElement(_G.TemporaryEnchantFrame);
    else
        data.frame:SetScript("OnUpdate", nil);
        em:DestroyEventHandlerByKey(data.globalName.."Handler");
        data.frame:SetParent(tk.Constants.DUMMY_FRAME);
        data.frame:SetAllPoints(tk.Constants.DUMMY_FRAME);
    end

    data.frame:SetShown(enabled);
    data.enabled = enabled;
end

Engine:SetAttribute("Framework.System.Attributes.InCombatAttribute");
function C_AuraArea:PositionAuraButtons(data)
    local totalPositioned = 0;

    for id, auraBtn in ipairs(data.auraButtons) do
        if (id == 1) then
            if (data.settings.direction == "LEFT") then
                auraBtn:SetPoint("TOPRIGHT");
            elseif (data.settings.direction == "RIGHT") then
                auraBtn:SetPoint("TOPLEFT");
            end

        elseif (totalPositioned % data.settings.perRow == 0) then
            local anchor = data.auraButtons[(totalPositioned - data.settings.perRow) + 1];
            auraBtn:SetPoint("TOP", anchor, "BOTTOM", 0, -data.settings.rowSpacing);
        else
            if (data.settings.direction == "LEFT") then
                auraBtn:SetPoint("RIGHT", data.auraButtons[id - 1], "LEFT", -data.settings.colSpacing, 0);
            elseif (data.settings.direction == "RIGHT") then
                auraBtn:SetPoint("LEFT", data.auraButtons[id - 1], "RIGHT", data.settings.colSpacing, 0);
            end
        end

        totalPositioned = totalPositioned + 1;
    end
end

-- C_AurasModule -----------------------
function C_AurasModule:OnInitialize(data)
    data.auraAreas = obj:PopTable();

    -- TODO: Target should be here
    for _, barName in obj:IterateArgs("Buffs", "Debuffs") do -- TODO: Add Debuffs
        local sv = db.profile.auras[barName]; ---@type Observer
        sv:SetParent(db.profile.auras.__templateAuraArea);
    end

    local options = {
        onExecuteAll = {
            first = {
                "Buffs.enabled";
                "Debuffs.enabled";
            };
        };
        groups = {
            {
                patterns = { "^%a+%.enabled$" };
                value = function(value, keysList)
                    local auraAreaName = keysList:PopFront();
                    local auraArea = data.auraAreas[auraAreaName];

                    if (value and not auraArea) then
                        auraArea = C_AuraArea(data.settings, auraAreaName);
                        data.auraAreas[auraAreaName] = auraArea;
                    end

                    if (auraArea) then
                        auraArea:SetEnabled(value);
                    end
                end;
            };
        };
    };

    self:RegisterUpdateFunctions(db.profile.auras, {
        appearance = {
            texture = function(value)
                local auraAreaData;

                for _, auraArea in pairs(data.auraAreas) do
                    auraAreaData = data:GetFriendData(auraArea);
                    auraAreaData.frame.statusbar:SetStatusBarTexture(tk.Constants.LSM:Fetch("statusbar", value));
                end
            end;
        }
    }, options);

    self:SetEnabled(true);
end