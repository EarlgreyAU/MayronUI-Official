-- luacheck: ignore MayronUI self 143 631
local _, namespace = ...;

local _G = _G;
local tonumber, ipairs, MayronUI = _G.tonumber, _G.ipairs, _G.MayronUI;
local tk, db, _, _, _, L = MayronUI:GetCoreComponents();
local C_AurasModule = namespace.C_AurasModule;

-- contains auraarea name / table pairs where each table holds the 5 config textfield widgets
-- this is used to update the config menu view after moving the aura areas (by unlocking them)
local position_TextFields = {};
local savePositionButtons = {};

local function AuraAreaPosition_OnLoad(configTable, container)
    local positionIndex = configTable.dbPath:match("%[(%d)%]$");
    position_TextFields[configTable.auraAreaName][tonumber(positionIndex)] = container.widget;
end

local function AuraArea_OnDragStop(field)
    local positions = tk.Tables:GetFramePosition(field);
    local auraAreaName = field:GetName():match("MUI_(.*)Area");

    if (positions) then
        -- update the config menu view
        for id, textField in ipairs(position_TextFields[auraAreaName]) do
            textField:SetText(positions[id]);
        end
    end

    savePositionButtons[auraAreaName]:SetEnabled(true);
end

function C_AurasModule:GetConfigTable()
    return {
        name = "Auras (Buffs & Debuffs)",
        type = "menu",
        module = "AurasModule",
        children =  {
            {   type = "loop";
                args = { "Buffs", "Debuffs" },
                func = function(_, name)
                    local dbPath = "profile.auras."..name;

                    local tbl = {
                        type = "submenu",
                        name = name;
                        dbPath = dbPath,
                        children = {
                            {   name = "Enabled",
                                type = "check",
                                appendDbPath = "enabled",
                            },
                            {   name = L["Unlock"];
                                type = "button";
                                OnClick = function(button)
                                    local auraArea = _G["MUI_"..name.."Area"];

                                    if (not (auraArea and auraArea:IsShown())) then
                                        return;
                                    end

                                    button.toggle = not button.toggle;
                                    tk:MakeMovable(auraArea, nil, button.toggle, nil, AuraArea_OnDragStop);

                                    if (button.toggle) then
                                        if (not auraArea.moveIndicator) then
                                            local r, g, b = tk:GetThemeColor();
                                            auraArea.moveIndicator = tk:SetBackground(auraArea, r, g, b);
                                            auraArea.moveLabel = auraArea:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
                                            auraArea.moveLabel:SetText(string.format("<%s Area>", name));
                                            auraArea.moveLabel:SetPoint("CENTER");
                                        end

                                        auraArea.moveIndicator:SetAlpha(0.4);
                                        auraArea.moveLabel:SetAlpha(0.8);
                                        button:SetText(L["Lock"]);

                                    elseif (auraArea.moveIndicator) then
                                        auraArea.moveIndicator:SetAlpha(0);
                                        auraArea.moveLabel:SetAlpha(0);
                                        button:SetText("Unlock");
                                    end
                                end
                            };
                            {   name = "Save Position";
                                type = "button";

                                OnLoad = function(_, button)
                                    savePositionButtons[name] = button;
                                    button:SetEnabled(false);
                                end;

                                OnClick = function(_)
                                    local auraArea = _G["MUI_"..name.."Area"];

                                    if (not (auraArea and auraArea:IsShown())) then
                                        return;
                                    end

                                    local positions = tk.Tables:GetFramePosition(auraArea);
                                    db:SetPathValue(dbPath .. ".position", positions);

                                    AuraArea_OnDragStop(auraArea);
                                    savePositionButtons[name]:SetEnabled(false);
                                end
                            };
                            {   type = "divider"
                            },
                            {   name = "Max per Row",
                                type = "slider",
                                min = 5,
                                max = _G.BUFF_MAX_DISPLAY,
                                step = 1,
                            },
                            {   name = "Growth Direction",
                                type = "dropdown",
                                appendDbPath = "growDirection",
                                options = { "Left", "Right" }
                            },
                            {   name = "Show Enchants", -- should be for buffs only
                                type = "check",
                                appendDbPath = "showEnchants",
                            },
                            {   name = "Aura Size",
                                type = "slider",
                                appendDbPath = "auraSize",
                                min = 20,
                                max = 100,
                                step = 1,
                            },
                            {   name = "Border Size",
                                type = "slider",
                                appendDbPath = "borderSize",
                                min = 1,
                                max = 5,
                                step = 1,
                            },
                            {   name = "Column Spacing",
                                type = "slider",
                                appendDbPath = "colSpacing",
                                min = 1,
                                max = 50,
                                step = 1,
                            },
                            {   name = "Row Spacing",
                                type = "slider",
                                appendDbPath = "rowSpacing",
                                min = 1,
                                max = 50,
                                step = 1,
                            },
                            {   name = L["Manual Positioning"],
                                type = "title",
                            },
                            {   type = "loop";
                                args = { L["Point"], L["Relative Frame"], L["Relative Point"], L["X-Offset"], L["Y-Offset"] };
                                func = function(index, arg)
                                    return {
                                        name = arg;
                                        type = "textfield";
                                        valueType = "string";
                                        dbPath = tk.Strings:Concat(dbPath, ".position[", index, "]");
                                        auraAreaName = name;
                                        OnLoad = AuraAreaPosition_OnLoad;
                                    };
                                end
                            };
                            {   name = "Colors",
                                type = "title",
                            },
                            {   name = "Buff Border",
                                type = "color",
                                appendDbPath = "colors.aura"
                            },
                            {   name = "Enchant Border",
                                type = "color",
                                appendDbPath = "colors.enchant"
                            },
                        }
                    };

                    if (name == "Debuffs") then
                        local debuffColors = {
                            {   name = "Magic Debuff Color";
                                type = "color";
                                width = 220;
                                useIndexes = true;
                                hasOpacity = true;
                                dbPath = "profile.colors.magic";
                            };
                            {   name = "Disease Debuff Color";
                                type = "color";
                                width = 220;
                                useIndexes = true;
                                hasOpacity = true;
                                dbPath = "profile.colors.disease";
                            };
                            {   name = "Poison Debuff Color";
                                type = "color";
                                width = 220;
                                useIndexes = true;
                                hasOpacity = true;
                                dbPath = "profile.colors.poison";
                            };
                            {   name = "Curse Debuff Color";
                                type = "color";
                                width = 220;
                                useIndexes = true;
                                hasOpacity = true;
                                dbPath = "profile.colors.curse";
                            };
                        };

                        table.insert(tbl.children, debuffColors);
                    end
                end;
            };
        }
    };
end