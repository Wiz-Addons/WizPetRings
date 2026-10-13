-- WoW Forever pet command and care rings, using the aspect ring's secure picker.
local _, A = ...
local P = A.Plain
local R = {}
A.Actions = R

R.commands = {
  { key = "attack", label = "Attack", token = "PET_ACTION_ATTACK", macro = "/petattack [@target,harm,nodead]", icon = "Ability_GhoulFrenzy" },
  { key = "follow", label = "Follow", token = "PET_ACTION_FOLLOW", macro = "/petfollow", icon = "Ability_Tracking" },
  { key = "passive", label = "Passive", token = "PET_MODE_PASSIVE", macro = "/petpassive", icon = "Ability_Seal" },
  { key = "defensive", label = "Defensive", token = "PET_MODE_DEFENSIVE", macro = "/petdefensive", icon = "Ability_Defend" },
  { key = "assist", label = "Assist", token = "PET_MODE_ASSIST", macro = "/petassist", icon = "Ability_Hunter_Pet_Assist" },
  { key = "aggressive", label = "Aggressive", token = "PET_MODE_AGGRESSIVE", macro = "/petaggressive", icon = "Ability_Racial_BloodRage" },
  { key = "moveTo", label = "Move To", token = "PET_ACTION_MOVE_TO", macro = "/petmoveto", icon = "Ability_Hunter_Pet_Goto" },
}
R.care = {
  { key = "dismiss", label = "Dismiss Pet", id = A.Spells.PET.DISMISS_PET },
  { key = "revive", label = "Revive Pet", id = A.Spells.PET.REVIVE_PET },
  { key = "call", label = "Call Pet", id = A.Spells.PET.CALL_PET },
  { key = "feed", label = "Feed Pet", id = A.Spells.PET.FEED_PET },
}

local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  return ok and P(value) or nil
end

function R.Order(def, stored)
  local valid, seen, out = {}, {}, {}
  for _, e in ipairs(def) do valid[e.key] = true end
  if type(stored) == "table" then
    for i = 1, #def do
      local key = stored[i]
      if valid[key] and not seen[key] then out[#out + 1] = key; seen[key] = true end
    end
  end
  for _, e in ipairs(def) do
    if not seen[e.key] then out[#out + 1] = e.key end
  end
  return out
end

function R.Labels(def)
  local out = {}
  for _, e in ipairs(def) do
    out[e.key] = (e.token and _G[e.token]) or (e.id and call(A.API.SpellName, e.id)) or e.label
  end
  return out
end

local function newState()
  return { open = false, cx = 0, cy = 0, known = {}, short = {}, order = {},
           macros = {}, spellIds = {}, petSlots = {}, icons = {}, active = {}, knownRev = 0 }
end
A.state.petCommandRing = newState()
A.state.petCareRing = newState()

local function publish(st, i, key, label, macro, icon)
  local known = macro and label or nil
  if st.order[i] ~= key or st.known[i] ~= known or st.macros[i] ~= macro then
    st.knownRev = st.knownRev + 1
  end
  st.order[i], st.known[i], st.short[i] = key, known, label
  st.macros[i], st.icons[i] = macro, icon
end

function R.UpdateCommands(st, p)
  local bar = {}
  if _G.GetPetActionInfo then
    for slot = 1, (_G.NUM_PET_ACTION_SLOTS or 10) do
      local ok, name, texture, isToken, active = pcall(GetPetActionInfo, slot)
      name, texture, isToken, active = P(name), P(texture), P(isToken), P(active)
      if ok and type(name) == "string" then
        bar[name] = { slot = slot, icon = isToken and _G[texture] or texture, active = active == true }
      end
    end
  end
  local byKey = {}
  for _, e in ipairs(R.commands) do byKey[e.key] = e end
  for i, key in ipairs(R.Order(R.commands, p.petCommandRingOrder)) do
    local e = byKey[key]
    local label = _G[e.token] or e.label
    local b = bar[e.token] or bar[label]
    -- Prefer the client's pet-bar action for modes; retain native macro
    -- commands for modes not exposed on the bar and for attack/follow.
    local petSlot = key ~= "attack" and key ~= "follow" and b and b.slot or nil
    if st.petSlots[i] ~= petSlot then st.knownRev = st.knownRev + 1 end
    st.petSlots[i] = petSlot
    -- Aggressive is not exposed on every Forever client. Only offer it when
    -- the pet bar supplies an executable mode action.
    local macro = "/stopmacro [nopet][@pet,dead]\n" .. e.macro
    if key == "aggressive" and not b then macro = nil end
    publish(st, i, key, label, macro,
      (b and b.icon) or ("Interface\\Icons\\" .. e.icon))
    st.active[key] = b and b.active or nil
  end
end

-- Prefer override information: Forever can replace Call Pet with Call <family>.
-- Match spellbook IDs as well as localized names; an optional explicit spell
-- ID in settings covers a family spell the client does not report as an override.
function R.ResolveSpell(id, names, book)
  local CS = _G.C_Spell
  local override = CS and call(CS.GetOverrideSpell, id)
  local resolved = type(override) == "number" and override > 0 and override or id
  local name = call(A.API.SpellName, resolved)
  for _, e in ipairs(book or {}) do
    local base = CS and call(CS.GetBaseSpell, e.id)
    if e.id == id or e.id == resolved or base == id then return P(e.name) or name, e.id end
  end
  local learnedId = type(name) == "string" and names and names[name]
  if learnedId then return name, type(learnedId) == "number" and learnedId or resolved end
  if names == nil then return name, resolved end
  -- IsSpellKnown can recognize base spells whose spellbook name is overridden.
  local SB = _G.C_SpellBook
  if SB and call(SB.IsSpellKnown, resolved) == true then return name, resolved end
  return nil, resolved
end

function R.UpdateCare(st, p)
  local names, book = A.Spellbook()
  local byKey = {}
  for _, e in ipairs(R.care) do byKey[e.key] = e end
  for i, key in ipairs(R.Order(R.care, p.petCareRingOrder)) do
    local e = byKey[key]
    local id = e.id
    if key == "call" then id = tonumber(p.petCareCallSpellID) or id end
    local name, castId = R.ResolveSpell(id, names, book)
    local label = name or call(A.API.SpellName, id) or e.label
    local macro = name and ("/cast " .. name) or nil
    -- Family summon labels can fail the macro name lookup on Forever.
    -- Execute the learned summon directly through the secure spell action.
    local spellId = key == "call" and name and castId or nil
    if st.spellIds[i] ~= spellId then st.knownRev = st.knownRev + 1 end
    st.spellIds[i] = spellId
    -- Feed opens the game's food-targeting cursor; the player picks the food.
    publish(st, i, key, label, macro, call(A.API.SpellIcon, castId or id))
  end
end

