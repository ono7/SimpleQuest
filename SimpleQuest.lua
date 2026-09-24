local ADDON_NAME = ...
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_ACCEPT_CONFIRM")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("QUEST_GREETING")

-- NOTE(jlima): Normalize legacy vs modern namespace for TOC metadata retrieval
local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

local function ProcessGossip()
  -- 1. Complete any active/ready turn-ins first
  if C_GossipInfo and C_GossipInfo.GetActiveQuests then
    local activeQuests = C_GossipInfo.GetActiveQuests()
    for _, q in ipairs(activeQuests) do
      if q.isComplete then
        C_GossipInfo.SelectActiveQuest(q.questID)
        return
      end
    end
  end

  -- 2. Pick up available quests
  if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
    local availableQuests = C_GossipInfo.GetAvailableQuests()
    if #availableQuests > 0 then
      C_GossipInfo.SelectAvailableQuest(availableQuests[1].questID)
      return
    end
  end

  -- 3. Auto-select single non-quest gossip options (vendor, taxi, binder, dialog)
  if C_GossipInfo and C_GossipInfo.GetOptions then
    local options = C_GossipInfo.GetOptions()
    -- NOTE(jlima): Restrict to strictly single-option trees without confirmation prompts to prevent destructive misclicks
    local numActive = C_GossipInfo.GetActiveQuests and #C_GossipInfo.GetActiveQuests() or 0
    local numAvail = C_GossipInfo.GetAvailableQuests and #C_GossipInfo.GetAvailableQuests() or 0

    if #options == 1 and numActive == 0 and numAvail == 0 then
      local opt = options[1]
      local needsConfirm = opt.confirmInput or opt.flags == 1 or (opt.status and opt.status > 0)
      if not needsConfirm then
        -- Modern Retail uses gossipOptionID; older builds fallback to index 1
        local optID = opt.gossipOptionID or 1
        C_GossipInfo.SelectOption(optID)
        return
      end
    end
  end
end

local function ProcessQuestGreeting()
  -- Legacy multi-quest NPC frame fallback
  local numActive = GetNumActiveQuests()
  for i = 1, numActive do
    local _, isComplete = GetActiveTitle(i)
    if isComplete then
      SelectActiveQuest(i)
      return
    end
  end

  local numAvailable = GetNumAvailableQuests()
  if numAvailable > 0 then
    SelectAvailableQuest(1)
  end
end

f:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      local clientVer, buildNum, _, clientToc = GetBuildInfo()
      local tocInterface = tonumber(GetMetadata(ADDON_NAME, "Interface"))

      if tocInterface and clientToc and tocInterface ~= clientToc then
        print(string.format("|cffff2020[%s]|r Version mismatch! Installed client: |cff00ff00%s|r (Build: %s, TOC: |cff00ff00%d|r). Current .toc is set to: |cffff2020%d|r. Update '## Interface: %d' in %s.toc.", ADDON_NAME, clientVer, buildNum, clientToc, tocInterface, clientToc, ADDON_NAME))
      end
    end
    return
  end

  -- Hold Shift to bypass automation
  if IsShiftKeyDown() then
    return
  end

  if event == "GOSSIP_SHOW" then
    ProcessGossip()
  elseif event == "QUEST_GREETING" then
    ProcessQuestGreeting()
  elseif event == "QUEST_DETAIL" then
    AcceptQuest()
  elseif event == "QUEST_ACCEPT_CONFIRM" then
    ConfirmAcceptQuest()
  elseif event == "QUEST_PROGRESS" then
    if IsQuestCompletable() then
      CompleteQuest()
    end
  elseif event == "QUEST_COMPLETE" then
    -- Stop automation if there are multiple gear/reward options
    if GetNumQuestChoices() <= 1 then
      GetQuestReward(1)
    end
  end
end)
