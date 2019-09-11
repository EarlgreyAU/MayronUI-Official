local _, namespace = ...;

-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, db, em, _, obj = MayronUI:GetCoreComponents();

local GetTime, select, SecondsToTimeAbbrev, GetWeaponEnchantInfo, UnitAura, pairs, ipairs,
    CreateFrame, GameTooltip, unpack, math, GetInventoryItemTexture, string, BUFF_MAX_DISPLAY,
    DEBUFF_MAX_DISPLAY, UIParent, InCombatLockdown, table, CancelUnitBuff = _G.GetTime, _G.select,
    _G.SecondsToTimeAbbrev, _G.GetWeaponEnchantInfo, _G.UnitAura, _G.pairs, _G.ipairs, _G.CreateFrame,
    _G.GameTooltip, _G.unpack, _G.math,_G.GetInventoryItemTexture, _G.string, _G.BUFF_MAX_DISPLAY,
    _G.DEBUFF_MAX_DISPLAY, _G.UIParent, _G.InCombatLockdown, _G.table, _G.CancelUnitBuff;

-- Main-Hand, Off-Hand, Ranged
local enchantAuraIds = { 16, 17, 18 };
local ARGS_PER_ITEM = 4;

-- Objects -----------------------------

--TODO: Make configurable

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

---@class AurasModule : BaseModule
local C_AurasModule = MayronUI:RegisterModule("AurasModule", "Auras (Buffs & Debuffs)");
namespace.C_AurasModule = C_AurasModule;

---@class C_AuraArea : Object
local C_AuraArea = Engine:CreateClass("AuraArea", "Framework.System.FrameWrapper");

---@type Stack
local Stack = obj:Import("Framework.System.Collections.Stack<T>");
local auraStack = Stack:Of("Button")();

-- Load Database Defaults --------------

db:AddToDefaults("profile.auras", {
    __templateAuraArea = {
        enabled       = true;
        unlocked      = false;
        position      = {"CENTER", "UIParent", "CENTER", 0,  0};
        colSpacing    = 4;
        rowSpacing    = 16;
        perRow        = 16;
        growDirection = "LEFT";
        showEnchants  = false;
        auraSize      = 32;
        borderSize    = 1;
        colors = {
            enchant = {0.53, 0.23, 0.78};
        }
    };
    Buffs = {
        position = {"TOPRIGHT", "Minimap", "TOPLEFT", -4, 0};
        auraType = "Buffs";
        showEnchants = true;
        colors = {
            aura = {0, 0, 0};
        }
    };

    Debuffs = {
        position = {"TOPRIGHT", "MUI_BuffsArea", "BOTTOMRIGHT", 0, -10};
        auraType = "Debuffs";
        colors = {
            aura = {0.7, 0.2, 0.2};
        }
    };
});

-- Local Functions -------------

local function AuraButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, 0);

    if (not self.filter) then
        GameTooltip:SetInventoryItem("player", self:GetID());
    else
        GameTooltip:SetUnitAura("player", self:GetID(), self.filter);
    end

    GameTooltip:Show();
end

local function UpdateIconTexture(btn, iconTexture)
    if (iconTexture) then
        btn.iconTexture:SetTexture(iconTexture);
        btn:Show();
        btn.forceUpdate = true;
    else
        btn:Hide();
    end
end

---@param auras table
---@param totalAuras number
---@param filter string
local function AuraArea_OnEvent(_, _, auraArea, data, totalAuras, filter)
    if (data.settings.showEnchants) then
        local totalArgs = select("#", GetWeaponEnchantInfo());
        local totalEnchantItems = totalArgs / ARGS_PER_ITEM;

        -- check weapon enchant auras:
        for index = 1, totalEnchantItems do
            local hasEnchant = select(ARGS_PER_ITEM * (index - 1) + 1, GetWeaponEnchantInfo());
            local btn = data.enchantButtons[index];

            UpdateIconTexture(btn, hasEnchant and GetInventoryItemTexture("player", btn:GetID()));
        end
    end

    for auraID = 1, totalAuras do
        local name, iconTexture = UnitAura("player", auraID, filter);
        local btn = data.auraButtons[auraID];

        if (name and iconTexture) then
            btn = btn or auraStack:Pop(data.frame, auraID, data.settings, filter);
            data.auraButtons[auraID] = btn;
        end

        if (btn) then
            UpdateIconTexture(btn, name and iconTexture);
        end
    end

    auraArea:RefreshAnchors();
end


local function AuraButton_OnUpdate(self)
    local _, _, count, _, _, expirationTime, _, _, _,
        _, _, _, _, _, timeMod = UnitAura("player", self:GetID(), self.filter);

    if (not count or count < 1) then
        self.countText:SetText(tk.Strings.Empty);
    else
        self.countText:SetText(count);
    end

    if (not expirationTime) then
        return;
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

local function AuraEnchantButton_OnUpdate(self, btn, globalName)
    local index = tk.Tables:IndexOf(enchantAuraIds, btn:GetID());
    local hasEnchant, expirationTime, count = select(ARGS_PER_ITEM * (index - 1) + 1, GetWeaponEnchantInfo());

    if (not (hasEnchant and expirationTime and count)) then
        if (btn.isEnchantActive) then
            btn.isEnchantActive = nil;
            -- enable/disable auraButtons:
            em:FindEventHandlerByKey(globalName.."Handler"):Run("UNIT_AURA");
        end

        return;
    end

    if (self.timeSinceLastUpdate > 1 or btn.forceUpdate) then
        btn.forceUpdate = nil;

        if (count < 1) then
            btn.countText:SetText(tk.Strings.Empty);
        else
            btn.countText:SetText(count);
        end

        if (expirationTime) then
            expirationTime = expirationTime / 1000;
            btn.timeRemaining = expirationTime;
            btn.timeRemainingText:SetFormattedText(SecondsToTimeAbbrev(expirationTime));
        else
            btn.timeRemaining = nil;
            btn.timeRemainingText:SetText(tk.Strings.Empty);
        end
    end

    -- ensure that PLAYER_ENTERING_WORLD works for enchants
    if (not btn.isEnchantActive) then
        btn.isEnchantActive = true;
        -- enable/disable auraButtons:
        em:FindEventHandlerByKey(globalName.."Handler"):Run("UNIT_AURA");
    end
end

-- should only handle updating time remaining and counts
local function AuraArea_OnUpdate(self, elapsed, auraButtons, enchantButtons)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    for _, btn in ipairs(auraButtons) do
        if (self.timeSinceLastUpdate > 1 or btn.forceUpdate) then
            btn.forceUpdate = nil;
            AuraButton_OnUpdate(btn);
        end
    end

    if (enchantButtons) then
        for _, btn in ipairs(enchantButtons) do
            AuraEnchantButton_OnUpdate(self, btn, self:GetName());
        end
    end

    if (self.timeSinceLastUpdate > 1) then
        self.timeSinceLastUpdate = 0;
    end
end

-- Stack ---------------------------

local function CancelAura(self)
    if (InCombatLockdown()) then
        return; -- cannot cancel buffs in combat due to protected blizzard utf8.codepoint(
    end

    if (self.filter) then
        -- it is a standard aura
        CancelUnitBuff("player", self:GetID(), self.filter);
    end
end

auraStack:OnNewItem(function(parent, auraID, settings, filter)
    local btn = CreateFrame("Button", nil, parent);
    btn:SetSize(settings.auraSize, settings.auraSize);
    btn:SetID(auraID);
    btn.filter = filter;

    if (filter == "HELPFUL") then
        btn:RegisterForClicks("RightButtonUp");
        btn:SetScript("OnClick", CancelAura)
        tk:SetBackground(btn, unpack(settings.colors.aura));
    end

    if (not filter) then
        tk:SetBackground(btn, unpack(settings.colors.enchant));
    elseif (filter == "HELPFUL" or filter == "HARMFUL") then
        tk:SetBackground(btn, unpack(settings.colors.aura));
    end

    btn:SetScript("OnEnter", AuraButton_OnEnter);
    btn:SetScript("OnLeave", tk.GeneralTooltip_OnLeave);

    btn.iconTexture = btn:CreateTexture(nil, "ARTWORK");
    btn.iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    btn.iconTexture:SetPoint("TOPLEFT", 1, -1);
    btn.iconTexture:SetPoint("BOTTOMRIGHT", -1, 1);

    btn.countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal");
    btn.countText:SetPoint("BOTTOMRIGHT", 0, 2);

    btn.timeRemainingText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    btn.timeRemainingText:SetPoint("TOP", btn, "BOTTOM", 0, -2);

    return btn;
end);

-- C_AuraArea ----------------------

Engine:DefineParams("table", "string");
function C_AuraArea:__Construct(data, moduleSettings, areaName)
    data.settings = moduleSettings[areaName];
    data.globalName = string.format("MUI_%sArea", areaName);
    data.auraButtons = obj:PopTable();
    data.enchantButtons = false;

    if (data.settings.showEnchants) then
        data.enchantButtons = obj:PopTable();
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

            local totalAuras, filter, maxColumns;
            local s = data.settings;

            if (data.settings.auraType == "Buffs") then
                totalAuras = BUFF_MAX_DISPLAY;
                filter = "HELPFUL";
            else
                totalAuras = DEBUFF_MAX_DISPLAY;
                filter = "HARMFUL";
            end

            if (data.settings.showEnchants) then
                for index, enchantID in ipairs(enchantAuraIds) do
                    data.enchantButtons[index] = auraStack:Pop(data.frame, enchantID, data.settings, false);
                    data.enchantButtons[index]:Hide();
                end

                maxColumns = math.ceil((totalAuras + 1) / s.perRow);
            else
                maxColumns = math.ceil((totalAuras) / s.perRow);
            end

            data.frame:SetSize(
                ((s.auraSize + s.colSpacing) * s.perRow) - s.colSpacing,
                ((s.auraSize + s.rowSpacing) * maxColumns) - s.rowSpacing);

            data.frame:SetPoint(unpack(s.position));

            -- Can I shorten this?
            em:CreateUnitEventHandlerWithKey("UNIT_AURA", data.globalName.."Handler", AuraArea_OnEvent, "Player")
                :SetCallbackArgs(self, data, totalAuras, filter)
                :AppendEvent("GROUP_ROSTER_UPDATE")
                :AppendEvent("PLAYER_ENTERING_WORLD")
        end

        data.frame.timeSinceLastUpdate = 0;
        data.frame:SetScript("OnUpdate", function(self, elapsed)
            AuraArea_OnUpdate(self, elapsed, data.auraButtons, data.enchantButtons);
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

local function SortByTimeRemaining(a, b)
    if (not (a and b)) then
        return true;
    end

    if (not a.timeRemaining and b.timeRemaining) then
        return true;
    end

    if (a.timeRemaining and not b.timeRemaining) then
        return false;
    end

    if (not a.timeRemaining and not b.timeRemaining) then
        return false;
    end

    return a.timeRemaining > b.timeRemaining;
end

function C_AuraArea:RefreshAnchors(data)
    local totalPositioned = 0;
    local activeButons = obj:PopTable();

    for _, auraBtn in ipairs(data.auraButtons) do
        auraBtn:ClearAllPoints();

        if (auraBtn:IsShown()) then
            table.insert(activeButons, auraBtn);
        end
    end

    table.sort(activeButons, SortByTimeRemaining);

    if (data.enchantButtons) then
        for id, enchantBtn in ipairs(data.enchantButtons) do
            enchantBtn:ClearAllPoints();

            if (enchantBtn:IsShown()) then
                table.insert(activeButons, id, enchantBtn);
            end
        end
    end

    for id, auraBtn in ipairs(activeButons) do
        if (not auraBtn:IsShown()) then
            break;
        end

        if (id == 1) then
            if (data.settings.growDirection == "LEFT") then
                auraBtn:SetPoint("TOPRIGHT");
            elseif (data.settings.growDirection == "RIGHT") then
                auraBtn:SetPoint("TOPLEFT");
            end

        elseif (totalPositioned % data.settings.perRow == 0) then
            local anchor = activeButons[(totalPositioned - data.settings.perRow) + 1];
            auraBtn:SetPoint("TOP", anchor, "BOTTOM", 0, -data.settings.rowSpacing);
        else
            if (data.settings.growDirection == "LEFT") then
                auraBtn:SetPoint("RIGHT", activeButons[id - 1], "LEFT", -data.settings.colSpacing, 0);
            elseif (data.settings.growDirection == "RIGHT") then
                auraBtn:SetPoint("LEFT", activeButons[id - 1], "RIGHT", data.settings.colSpacing, 0);
            end
        end

        totalPositioned = totalPositioned + 1;
    end

    obj:PushTable(activeButons);
end

-- C_AurasModule -----------------------
function C_AurasModule:OnInitialize(data)
    data.auraAreas = obj:PopTable();

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
                    local auraArea = data.auraAreas[auraAreaName]; ---@type C_AuraArea

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