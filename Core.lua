local addonName, A = ...
_G.WizPetRings = A
_G.PetRings = A -- Compatibility alias for earlier builds.
A.name, A.state, A.rings = addonName, {}, {}
A.build = "1.0.0"
A.Spells = { PET = { DISMISS_PET = 2641, REVIVE_PET = 982, CALL_PET = 883, FEED_PET = 6991 } }

function A.Plain(value)
  if _G.issecretvalue and issecretvalue(value) then return nil end
  return value
end
function A.Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  return ok and A.Plain(value) or nil
end
A.API = {
  SpellName = function(id)
    return A.Call(_G.C_Spell and C_Spell.GetSpellName or _G.GetSpellInfo, id)
  end,
  SpellIcon = function(id)
    if _G.C_Spell and C_Spell.GetSpellTexture then return A.Call(C_Spell.GetSpellTexture, id) end
    if _G.GetSpellInfo then local _, _, icon = GetSpellInfo(id); return A.Plain(icon) end
  end,
}

-- Player spellbook only, excluding future/unlearned spells. Names match ranks.
function A.Spellbook()
  local SB, E = _G.C_SpellBook, _G.Enum
  local bank = E and E.SpellBookSpellBank and E.SpellBookSpellBank.Player
  if not (SB and bank and SB.GetNumSpellBookSkillLines and SB.GetSpellBookItemInfo) then return nil, {} end
  local names, book = {}, {}
  local future = E.SpellBookItemType and E.SpellBookItemType.FutureSpell
  for line = 1, A.Call(SB.GetNumSpellBookSkillLines) or 0 do
    local info = A.Call(SB.GetSpellBookSkillLineInfo, line)
    if type(info) == "table" then
      local offset, count = A.Plain(info.itemIndexOffset), A.Plain(info.numSpellBookItems)
      if type(offset) == "number" and type(count) == "number" then
        for slot = offset + 1, offset + count do
          local item = A.Call(SB.GetSpellBookItemInfo, slot, bank)
          if type(item) == "table" then
            local id, name, kind = A.Plain(item.spellID), A.Plain(item.name), A.Plain(item.itemType)
            local learned = (future == nil or kind ~= future) and A.Plain(item.isPassive) ~= true
            if learned and type(id) == "number" and A.Call(SB.IsSpellKnown, id, bank) == false then learned = false end
            if learned and type(name) == "string" and type(id) == "number" then
              names[name] = id
              book[#book + 1] = { id = id, name = name }
            end
          end
        end
      end
    end
  end
  return names, book
end

function A.Print(message)
  if _G.DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff77ccffWizPetRings:|r " .. message) end
end
function A.Color()
  return A.Theme().accent
end

function A.InitializeDB()
  if type(_G.PetRingsDB) ~= "table" then _G.PetRingsDB = {} end
  A.db = _G.PetRingsDB
  A.db.petCommandRingScale = tonumber(A.db.petCommandRingScale) or 1
  A.db.petCareRingScale = tonumber(A.db.petCareRingScale) or 1
  A.db.visualTheme, A.db.installedVariant = "classic", "classic"
  A.db.style = nil
end

function A.Apply()
  if not A.started or not A.hunter then return end
  if InCombatLockdown() then A.pending = true; return end
  A.pending = nil
  if A.hunter then A.CreateRings() end
  for _, ring in ipairs(A.rings) do ring:Apply() end
end

_G.BINDING_HEADER_PETRINGS = "WizPetRings"
_G["BINDING_NAME_CLICK PetRingsCommandButton:LeftButton"] = "Pet command ring (hold)"
_G["BINDING_NAME_CLICK PetRingsCareButton:LeftButton"] = "Pet care ring (hold)"
_G.SLASH_PETRINGS1, _G.SLASH_PETRINGS2, _G.SLASH_PETRINGS3 = "/wizpetrings", "/petrings", "/prings"
SlashCmdList.PETRINGS = function(input)
  if type(input) == "string" and input:lower():match("^%s*version%s*$") then
    A.Print("Build " .. A.build)
  else A.ShowOptions() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    local _, class = UnitClass("player")
    A.hunter = class == "HUNTER"
    A.started = true
    if not A.hunter then return end
    A.InitializeDB()
    A.CreateRings(); A.Apply()
    A.ApplyTheme()
    A.RegisterSettings()
  elseif A.started and A.hunter then
    A.Apply()
  end
end)
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "PET_BAR_UPDATE", "UNIT_PET",
  "PLAYER_ENTERING_WORLD", "SPELL_UPDATE_ICON", "PET_STABLE_UPDATE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
  pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnUpdate", function()
  if not A.started or not A.hunter or InCombatLockdown() then return end
  if A.pending or (A.screenWidth and (A.screenWidth ~= UIParent:GetWidth() or A.screenHeight ~= UIParent:GetHeight())) then A.Apply() end
end)
