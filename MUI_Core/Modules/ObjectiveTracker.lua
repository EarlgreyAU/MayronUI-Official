

-- luacheck: ignore self 143 631
local _G = _G;
local MayronUI = _G.MayronUI;
local tk, db, em, gui, obj, L = MayronUI:GetCoreComponents(); -- luacheck: ignore

---@class ObjectiveTrackerModule : BaseModule
local C_ObjectiveTracker = MayronUI:RegisterModule("ObjectiveTrackerModule", "Objective Tracker", true);


MayronUI:Hook("SideBarModule", "OnInitialize", function(sideBarModule)
    MayronUI:ImportModule("ObjectiveTrackerModule"):Initialize(sideBarModule);
end);

local QuestWatchFrame, IsInInstance, ObjectiveTracker_Collapse, ObjectiveTracker_Update,
ObjectiveTracker_Expand, UIParent, hooksecurefunc, ipairs =
    _G.QuestWatchFrame, _G.IsInInstance, _G.ObjectiveTracker_Collapse, _G.ObjectiveTracker_Update,
    _G.ObjectiveTracker_Expand, _G.UIParent, _G.hooksecurefunc, _G.ipairs;

local function UpdateTextColor(block)
    for questLogIndex = 1, _G.GetNumQuestLogEntries() do
        local _, level, _, _, _, _, _, questID, _, _, _, _, _, _, _, _, isScaling = _G.GetQuestLogTitle(questLogIndex);

        if (questID == block.id) then
            -- bonus quests do not have HeaderText
            if (block.HeaderText) then
                local difficultyColor = _G.GetQuestDifficultyColor(level, isScaling);
                block.HeaderText:SetTextColor(difficultyColor.r, difficultyColor.g, difficultyColor.b);
                block.HeaderText.colorStyle = difficultyColor;
            end

            break;
        end
    end
end

db:AddToDefaults("profile.objectiveTracker", {
    enabled = true;
    hideInInstance = true;
    anchoredToSideBars = true;
    width = 250;
    height = 600;
    yOffset = 0;
    xOffset = -30;
});

function C_ObjectiveTracker:OnInitialize(data, sideBarModule)
    data.panel = sideBarModule:GetPanel();

    local function SetUpAnchor()
        data.objectiveContainer:ClearAllPoints();

        if (data.settings.anchoredToSideBars) then
            data.objectiveContainer:SetPoint("TOPRIGHT", data.panel, "TOPLEFT", data.settings.xOffset, data.settings.yOffset);
        else
            data.objectiveContainer:SetPoint("CENTER", data.settings.xOffset, data.settings.yOffset);
        end
    end

    self:RegisterUpdateFunctions(db.profile.objectiveTracker, {
        hideInInstance = function(value)
            if (not value) then
                em:DestroyEventHandlerByKey("ObjectiveTracker_InInstance");
                return;
            end

            em:CreateEventHandlerWithKey("PLAYER_ENTERING_WORLD", "ObjectiveTracker_InInstance", function()
                local inInstance = IsInInstance();

                if (inInstance) then
                    if (not QuestWatchFrame.collapsed) then
                        ObjectiveTracker_Collapse();
                        data.previouslyCollapsed = true;
                    end
                else
                    if (QuestWatchFrame.collapsed and data.previouslyCollapsed) then
                        ObjectiveTracker_Expand();
                        ObjectiveTracker_Update();
                    end

                    data.previouslyCollapsed = nil;
                end
            end);

            if (IsInInstance()) then
                em:TriggerEventHandlerByKey("ObjectiveTracker_InInstance");
            end
        end;

        width = function(value)
            data.objectiveContainer:SetSize(value, data.settings.height);
        end;

        height = function(value)
            data.objectiveContainer:SetSize(data.settings.width, value);
        end;

        anchoredToSideBars = SetUpAnchor;
        yOffset = SetUpAnchor;
        xOffset = SetUpAnchor;
    });

    if (data.settings.enabled) then
        self:SetEnabled(true);
    end
end

function C_ObjectiveTracker:OnEnable(data)
    if (not data.objectiveContainer) then
        -- holds and controls blizzard objectives tracker frame
        data.objectiveContainer = _G.CreateFrame("Frame", nil, UIParent);

        -- blizzard objective tracker frame global variable
        QuestWatchFrame:SetClampedToScreen(false);
        QuestWatchFrame:SetParent(data.objectiveContainer);
        QuestWatchFrame:SetAllPoints(true);

        QuestWatchFrame.ClearAllPoints = tk.Constants.DUMMY_FUNC;
        QuestWatchFrame.SetParent = tk.Constants.DUMMY_FUNC;
        QuestWatchFrame.SetPoint = tk.Constants.DUMMY_FUNC;
        QuestWatchFrame.SetAllPoints = tk.Constants.DUMMY_FUNC;
    end
end