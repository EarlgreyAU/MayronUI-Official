local _, namespace = ...;

-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, db, em, _, obj = MayronUI:GetCoreComponents();

local GetTime, select, SecondsToTimeAbbrev, GetWeaponEnchantInfo, UnitAura, ipairs, CreateFrame, unpack, math,
    GetInventoryItemTexture, string, BUFF_MAX_DISPLAY, DEBUFF_MAX_DISPLAY, UIParent, table = _G.GetTime, _G.select,
    _G.SecondsToTimeAbbrev, _G.GetWeaponEnchantInfo, _G.UnitAura, _G.ipairs, _G.CreateFrame, _G.unpack, _G.math,
    _G.GetInventoryItemTexture, _G.string, _G.BUFF_MAX_DISPLAY, _G.DEBUFF_MAX_DISPLAY, _G.UIParent, _G.table;

-- Main-Hand, Off-Hand, Ranged
local enchantAuraIds = { 16, 17, 18 };
local ARGS_PER_ITEM = 4;

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

---@class AurasModule : BaseModule
local C_AurasModule = MayronUI:RegisterModule("AurasModule", "Auras (Buffs & Debuffs)");
namespace.C_AurasModule = C_AurasModule;

---@class C_AuraArea : Object
local C_AuraArea = Engine:CreateClass("AuraArea", "Framework.System.FrameWrapper");
C_AuraArea.Static:AddFriendClass(C_AurasModule);

---@type C_Aura
local C_Aura = namespace.C_Aura;

-- Load Database Defaults --------------

db:AddToDefaults("profile.auras", {
    __templateAuraArea = {
        enabled = true;
        position = {"CENTER", "UIParent", "CENTER", 0,  0};
        textSize = {
            timeRemaining   = 10;
            count           = 14;

            statusBars = {
                auraName        = 10;
                timeRemaining   = 10;
                count           = 12;
            }
        };
        textPosition = {
            timeRemaining   = {0, -2};
            count           = {0, 2};

            statusBars = {
                timeRemaining   = {-4, 0};
                count           = {0, 2};
                auraName        = {32, 0};
            }
        };
        border = {
            type = "Skinner";
            size = 1;
            show = true;
        };
        colors = {
            enchant               = {0.53, 0.23, 0.78};
            statusBarBackground   = {0, 0, 0, 0.5};
            statusBarBorder       = { 0, 0, 0 };
            timeRemaining         = {tk:GetThemeColor()};
            count                 = {1, 1, 1};
            auraName              = {tk:GetThemeColor()};
        };
        icons = {
            auraSize        = 32;
            borderSize      = 1;
            colSpacing      = 4;
            rowSpacing      = 16;
            perRow          = 16;
            growDirection   = "LEFT";
        };
        statusBars = {
            enabled       = true; -- change to false once done
            barAlpha      = 1;
            barTexture    = "MUI_StatusBar";
            width         = 260;
            height        = 24;
            spacing       = 2;
            growDirection = "DOWN";
            borderSize    = 4;
            iconGap       = 2;
            showSpark     = true;
        };
    };
    Buffs = {
        position = {"TOPRIGHT", "Minimap", "TOPLEFT", -4, 0};
        showPulseEffect = true;
        colors = {
            aura = {0, 0, 0};
            statusBarAura = { 0.1, 0.1, 0.1 };
        }
    };

    Debuffs = {
        position = {"TOPRIGHT", "MUI_BuffsArea", "BOTTOMRIGHT", 0, -10};
        statusBars = {
            position = {"TOPRIGHT", "MUI_BuffsArea", "TOPLEFT", -10, 0};
        };
        colors = {
            aura    = {0.76, 0.2, 0.2};
            statusBarAura = {0.76, 0.2, 0.2};
            magic   = {0.2, 0.6, 1};
            disease = {0.6, 0.4, 0};
            poison  = {0.0, 0.6, 0};
            curse   = {0.6, 0.0, 1};
        }
    };
});

-- Local Functions -------------
local GetEnchantNameAndDuration;

do
    local scanner;
    local durationCache = {};

    local function GetDurationValue(text)
        local value = tk.Strings:GetSection(text, " ", 1);

        if (string.match(text, "min")) then
            value = value * 60;
        elseif (string.match(text, "hour")) then
            value = value * 60 * 60;
        end

        return value;
    end

    local function GetEnchantNameAndDurationBySlotID(slotID)
		for i = 1, 60 do
			scanner.lines[i]:SetText("");
        end

		scanner:SetInventoryItem("Player", slotID);

		for i = 1, 60 do
			local text = scanner.lines[i]:GetText();

            if (text) then
                local auraName, durationText = select(3, string.find(text, "^(.+) %((%d+ [^%)]+)%)$"))

                if (auraName) then
                    if (not durationCache[auraName]) then
                        durationCache[auraName] = GetDurationValue(durationText);
                    end

					return auraName, durationCache[auraName];
				end
            end
        end

		return nil;
    end

    GetEnchantNameAndDuration = function(slotID)
        if (not scanner) then
            scanner = CreateFrame("GameTooltip");
            scanner:SetOwner(UIParent, "ANCHOR_NONE");
            scanner.lines = obj:PopTable();

            for _ = 1, 30 do
                local left = scanner:CreateFontString(nil, "ARTWORK", "GameFontNormal");
                local right = scanner:CreateFontString(nil, "ARTWORK", "GameFontNormal");

                scanner:AddFontStrings(left, right)
                table.insert(scanner.lines, left);
                table.insert(scanner.lines, right);
            end
        end

        local enchantName, duration = GetEnchantNameAndDurationBySlotID(slotID);

        if (enchantName) then
            return enchantName, duration;
        end

        -- If we cannot find the enchant name from tooltip then use the items's name:
        local itemlink = _G.GetInventoryItemLink("player", slotID);

        if (itemlink) then
            local itemName = _G.GetItemInfo(itemlink);

            if (itemName) then
                return itemName;
            end
        end

        -- If item cannot be found (should never happen) then use fallback name:
        return "Weapon "..slotID;
    end
end

---@param auraArea C_AuraArea
---@param data table
local function AuraArea_OnEvent(_, _, auraArea, data)
    if (data.enchantButtons) then
        local totalArgs = select("#", GetWeaponEnchantInfo());
        local totalEnchantItems = totalArgs / ARGS_PER_ITEM;

        -- check weapon enchant auras:
        for index = 1, totalEnchantItems do
            local hasEnchant = select(ARGS_PER_ITEM * (index - 1) + 1, GetWeaponEnchantInfo());
            local btn = data.enchantButtons[index];
            local iconTexture, auraName, duration;

            if (data.settings.statusBars.enabled) then
                auraName, duration = GetEnchantNameAndDuration(enchantAuraIds[index]);
                btn.duration = duration;
            end

            iconTexture = hasEnchant and GetInventoryItemTexture("player", btn:GetID());
            btn.obj:SetAura(iconTexture, auraName);
        end
    end

    for auraID = 1, data.totalAuras do
        local name, iconTexture, _, debuffType = UnitAura("player", auraID, data.filter);
        local btn = data.auraButtons[auraID];

        if (name and iconTexture) then
            -- get or create new aura frame
            btn = btn or C_Aura(data.frame, data.settings, auraID, data.filter):GetFrame();
            data.auraButtons[auraID] = btn;
        end

        if (btn) then
            btn.obj:SetAura(iconTexture or false, name, debuffType);
        end
    end

    auraArea:RefreshAnchors();
end

local function AuraButton_UpdateAlpha(self, elapsed)
    self.pulseTime = (self.pulseTime or 0) - elapsed;

    if (self.pulseTime < 0) then
        local overtime = -self.pulseTime;

        if (self.isPulsing == 0) then
            self.isPulsing = 1;
            self.pulseTime = _G.BUFF_FLASH_TIME_ON;
        else
            self.isPulsing = 0;
            self.pulseTime = _G.BUFF_FLASH_TIME_OFF;
        end

        if (overtime < self.pulseTime) then
            self.pulseTime = self.pulseTime - overtime;
        end
    end

    local expirationTime = select(6, UnitAura("player", self:GetID(), self.filter));

    if (not expirationTime or expirationTime <= 0) then
        self:SetAlpha(1);
        return;
    end

    local timeRemaining = expirationTime - GetTime();

    -- Handle flashing
    if (timeRemaining and timeRemaining < _G.BUFF_WARNING_TIME) then
        local alphaValue;

        if (self.isPulsing == 1) then
            alphaValue = (_G.BUFF_FLASH_TIME_ON - self.pulseTime) / _G.BUFF_FLASH_TIME_ON;
        else
            alphaValue = self.pulseTime / _G.BUFF_FLASH_TIME_ON;
        end

        alphaValue = (alphaValue * (1 - _G.BUFF_MIN_ALPHA)) + _G.BUFF_MIN_ALPHA;

        self:SetAlpha(alphaValue);
    else
        self:SetAlpha(1.0);
    end
end

local function AuraButton_OnUpdate(self)
    local _, _, count, _, duration, expirationTime, _, _, _,
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

    if (self.statusBar) then
        self.obj:UpdateStatusBar(duration, timeRemaining);
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

        if (btn.statusBar) then
            btn.obj:UpdateStatusBar(btn.duration, expirationTime);
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
local function AuraArea_OnUpdate(self, elapsed, auraButtons, enchantButtons, pulse)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    for _, btn in ipairs(auraButtons) do
        if (btn.filter == "HELPFUL" and pulse) then
            AuraButton_UpdateAlpha(btn, elapsed);
        end

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

-- C_AuraArea ----------------------

Engine:DefineParams("table", "string");
function C_AuraArea:__Construct(data, moduleSettings, areaName)
    data.settings = moduleSettings[areaName];
    data.globalName = string.format("MUI_%sArea", areaName);
    data.auraButtons = obj:PopTable();
    data.enchantButtons = false;
    data.areaName = areaName;

    if (areaName == "Buffs") then
        data.enchantButtons = obj:PopTable();
        data.totalAuras = BUFF_MAX_DISPLAY;
        data.filter = "HELPFUL";
    else
        data.totalAuras = DEBUFF_MAX_DISPLAY;
        data.filter = "HARMFUL";
    end
end

function C_AuraArea:UpdateSize(data)
    if (data.settings.statusBars.enabled) then
        local bars = data.settings.statusBars;

        data.frame:SetSize(bars.width, ((bars.height + bars.spacing) * data.totalAuras) - bars.spacing);
    else
        local icons = data.settings.icons;
        local maxColumns;

        if (data.enchantButtons) then
            maxColumns = math.ceil((data.totalAuras + 1) / icons.perRow);
        else
            maxColumns = math.ceil((data.totalAuras) / icons.perRow);
        end

        data.frame:SetSize(
            ((icons.auraSize + icons.colSpacing) * icons.perRow) - icons.colSpacing,
            ((icons.auraSize + icons.rowSpacing) * maxColumns) - icons.rowSpacing);
    end
end

Engine:DefineParams("boolean")
function C_AuraArea:SetEnabled(data, enabled)
    if (not data.frame and not enabled) then
        return;
    end

    if (enabled) then
        if (not data.frame) then
            data.frame = CreateFrame("Frame", data.globalName);

            if (data.enchantButtons) then
                for index, enchantID in ipairs(enchantAuraIds) do
                    data.enchantButtons[index] = C_Aura(data.frame, data.settings, enchantID, false):GetFrame();
                    data.enchantButtons[index]:Hide();
                end
            end

            self:UpdateSize();

            em:CreateUnitEventHandlerWithKey("UNIT_AURA", data.globalName.."Handler", AuraArea_OnEvent, "Player")
                :SetCallbackArgs(self, data)
                :AppendEvent("GROUP_ROSTER_UPDATE")
                :AppendEvent("PLAYER_ENTERING_WORLD");
        end

        data.frame.timeSinceLastUpdate = 0;
        data.frame:SetScript("OnUpdate", function(self, elapsed)
            AuraArea_OnUpdate(self, elapsed, data.auraButtons, data.enchantButtons, data.settings.pulse);
        end);

        data.frame:SetParent(UIParent);

        if (data.settings.statusBars.enabled and data.settings.statusBars.position) then
            data.frame:SetPoint(unpack(data.settings.statusBars.position));
        else
            data.frame:SetPoint(unpack(data.settings.position));
        end
    else
        em:DestroyEventHandlerByKey(data.globalName.."Handler");
        data.frame:SetScript("OnUpdate", nil);
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

        if (data.settings.statusBars.enabled) then
            local bars = data.settings.statusBars;

            if (id == 1) then
                if (bars.growDirection == "DOWN") then
                    auraBtn:SetPoint("TOP");
                elseif (bars.growDirection == "UP") then
                    auraBtn:SetPoint("BOTTOM");
                end

            else
                if (bars.growDirection == "DOWN") then
                    auraBtn:SetPoint("TOP", activeButons[id - 1], "BOTTOM", 0, -bars.spacing);
                elseif (bars.growDirection == "UP") then
                    auraBtn:SetPoint("BOTTOM", activeButons[id - 1], "TOP", 0, bars.spacing);
                end
            end
        else
            local icons = data.settings.icons;

            if (id == 1) then
                if (data.settings.icons.growDirection == "LEFT") then
                    auraBtn:SetPoint("TOPRIGHT");
                elseif (icons.growDirection == "RIGHT") then
                    auraBtn:SetPoint("TOPLEFT");
                end

            elseif (totalPositioned % icons.perRow == 0) then
                local anchor = activeButons[(totalPositioned - icons.perRow) + 1];
                auraBtn:SetPoint("TOP", anchor, "BOTTOM", 0, -icons.rowSpacing);

            elseif (icons.growDirection == "LEFT") then
                auraBtn:SetPoint("RIGHT", activeButons[id - 1], "LEFT", -icons.colSpacing, 0);
            elseif (icons.growDirection == "RIGHT") then
                auraBtn:SetPoint("LEFT", activeButons[id - 1], "RIGHT", icons.colSpacing, 0);
            end
        end



        totalPositioned = totalPositioned + 1;
    end

    obj:PushTable(activeButons);
end

-- C_AurasModule -----------------------
function C_AurasModule:OnInitialize(data)
    data.auraAreas = obj:PopTable();

    for _, barName in obj:IterateArgs("Buffs", "Debuffs") do
        local sv = db.profile.auras[barName]; ---@type Observer
        sv:SetParent(db.profile.auras.__templateAuraArea);
    end

    -- local function RefreshAnchors(_, keyName, auraArea, areaName)
    --     if (auraArea) then
    --         local settingName = keyName:PopFront();

    --         if (settingName == "position") then
    --             local frame = auraArea:GetFrame();
    --             frame:ClearAllPoints();
    --             frame:SetPoint(unpack(data.settings[areaName].position));
    --         else
    --             auraArea:RefreshAnchors();
    --         end

    --     end
    -- end

    -- local function UpdateAppearance(_, _, auraArea)
    --     if (auraArea) then
    --         auraArea:UpdateAppearance();
    --     end
    -- end

    local options = {
        onExecuteAll = {
            first = {
                "Buffs.enabled";
                "Debuffs.enabled";
            };
            ignore = { ".*" }; -- ignore everything else
        };
        groups = {
            {
                patterns = { ".*" }; -- (i.e. "Buffs.<setting>")

                onPre = function(value, keysList)
                    local auraAreaName = keysList:PopFront();
                    keysList:PopFront();
                    local auraArea = data.auraAreas[auraAreaName]; ---@type C_AuraArea

                    if (value and not auraArea) then
                        auraArea = C_AuraArea(data.settings, auraAreaName);
                        data.auraAreas[auraAreaName] = auraArea;
                    end

                    return auraArea, auraAreaName;
                end;

                value = {
                    enabled = function(value, _, auraArea, areaName)
                        if (auraArea) then
                            auraArea:SetEnabled(value, areaName);
                        end
                    end;
                    -- position = RefreshAnchors;
                    -- appearance = UpdateAppearance;
                    -- showPulseEffect = function(value, _, auraArea)
                    --     if (not value) then
                    --         local areaData = data:GetFriendData(auraArea);

                    --         for _, btn in ipairs(areaData.auraButtons) do
                    --             btn:SetAlpha(1);
                    --         end
                    --     end
                    -- end;
                }
            };
        };
    };

    self:RegisterUpdateFunctions(db.profile.auras, {}, options);

    -- Hide Blizzard frames
    tk:KillElement(_G.BuffFrame);
    tk:KillElement(_G.TemporaryEnchantFrame);

    self:SetEnabled(true);
end