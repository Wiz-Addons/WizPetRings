local _, A = ...
local TWO_PI = 2 * math.pi
local MEDIA = "Interface\\AddOns\\WizPetRings\\Media\\"

function A.Scale(key)
  return math.max(0.75, math.min(2, tonumber(A.db[key]) or 1))
end
function A.Offset(i, radius, n)
  local angle = (i - 1) * TWO_PI / n
  return radius * math.sin(angle), radius * math.cos(angle)
end
function A.Pick(dx, dy, dead, n)
  if dx * dx + dy * dy < dead * dead then return nil end
  local best, index
  for i = 1, n do
    local x, y = A.Offset(i, 1, n)
    local dot = dx * x + dy * y
    if not best or dot >= best then best, index = dot, i end
  end
  return index
end

-- Executed by a secure handler on both key edges. Protected actions are
-- prepared out of combat; the hardware release selects and executes one.
function A.Snippet(n)
  local lines = {
    "local x, y = control:GetMousePosition()",
    "local layer = self:GetFrameRef('layer')",
    "self:SetAttribute('type', nil)",
    "self:SetAttribute('useOnKeyDown', false)",
    "if down then",
    "  self:SetAttribute('ringX', x); self:SetAttribute('ringY', y)",
    "  local other = self:GetFrameRef('other')",
    "  if other then other:Hide() end",
    "  local otherDriver = self:GetFrameRef('otherDriver')",
    "  if otherDriver then otherDriver:SetAttribute('ringX', nil); otherDriver:SetAttribute('ringY', nil) end",
    "  if layer and x then",
    "    local sc = self:GetAttribute('scale') or 1",
    "    layer:ClearAllPoints()",
    "    layer:SetPoint('CENTER', control, 'BOTTOMLEFT', x * (self:GetAttribute('sw') or 0) / sc, y * (self:GetAttribute('sh') or 0) / sc)",
    "    layer:Show()",
    "  end",
    "  return false",
    "end",
    "if layer then layer:Hide() end",
    "local cx, cy = self:GetAttribute('ringX'), self:GetAttribute('ringY')",
    "self:SetAttribute('ringX', nil); self:SetAttribute('ringY', nil)",
    "if not (x and cx) then return false end",
    "local dx = (x - cx) * (self:GetAttribute('sw') or 0)",
    "local dy = (y - cy) * (self:GetAttribute('sh') or 0)",
    "local dead = self:GetAttribute('dead') or 14",
    "if dx * dx + dy * dy < dead * dead then return false end",
    "local best, bi",
  }
  for i = 1, n do
    local x, y = A.Offset(i, 1, n)
    lines[#lines + 1] = ("do local v = dx * %.7f + dy * %.7f if not best or v >= best then best, bi = v, %d end end"):format(x, y, i)
  end
  lines[#lines + 1] = "local kind = bi and self:GetAttribute('kind' .. bi)"
  lines[#lines + 1] = "local value = bi and self:GetAttribute('value' .. bi)"
  lines[#lines + 1] = "if not (kind and value) then return false end"
  lines[#lines + 1] = "self:SetAttribute('type', kind)"
  lines[#lines + 1] = "if kind == 'pet' then self:SetAttribute('action', value) elseif kind == 'spell' then self:SetAttribute('spell', value) else self:SetAttribute('macrotext', value) end"
  return table.concat(lines, "\n")
end

local function createTile(parent)
  local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  tile:SetSize(36, 36)
  tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  tile:SetBackdropColor(0.035, 0.035, 0.045, 0.96)
  tile:SetBackdropBorderColor(0, 0, 0, 1)
  local icon = tile:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", -1, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  tile.icon = icon
  return tile
end

local function cursor()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  return x / scale, y / scale
end

local function createRing(spec)
  local ring = { spec = spec, state = A.state[spec.state], n = #spec.def, slots = {} }
  local radius = math.floor(45 / (2 * math.sin(math.pi / ring.n)) + 0.5)
  local size = 2 * (radius + 30)
  local layer = CreateFrame("Frame", spec.button .. "Layer", UIParent)
  layer:SetSize(1, 1); layer:SetFrameStrata("DIALOG"); layer:Hide()
  ring.layer = layer
  local disc = layer:CreateTexture(nil, "BACKGROUND")
  disc:SetTexture(MEDIA .. "AspectRingDisc.tga"); disc:SetSize(size, size); disc:SetPoint("CENTER")
  local wedge = layer:CreateTexture(nil, "BORDER")
  wedge:SetTexture(MEDIA .. spec.wedge); wedge:SetSize(size, size); wedge:SetPoint("CENTER"); wedge:Hide()
  ring.wedge, ring.disc = wedge, disc
  local label = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOP", layer, "CENTER", 0, -(size / 2 + 5)); label:SetJustifyH("CENTER")
  ring.label = label

  local screen = CreateFrame("Frame", spec.button .. "Screen", UIParent, "SecureHandlerBaseTemplate")
  screen:SetAllPoints(UIParent)
  local driver = CreateFrame("Button", spec.button, UIParent, "SecureActionButtonTemplate")
  driver:RegisterForClicks("AnyDown", "AnyUp"); driver:SetAttribute("useOnKeyDown", false)
  driver:SetScript("PreClick", function(_, _, down)
    if down then ring.cx, ring.cy = cursor() end
  end)
  SecureHandlerSetFrameRef(driver, "layer", layer)
  SecureHandlerWrapScript(driver, "OnClick", screen, A.Snippet(ring.n))
  ring.driver = driver
  for i = 1, ring.n do
    local button = CreateFrame("Button", spec.button .. "Slot" .. i, layer, "SecureActionButtonTemplate")
    button:SetSize(36, 36); button:RegisterForClicks("AnyUp"); button:SetAttribute("useOnKeyDown", false)
    local x, y = A.Offset(i, radius, ring.n)
    button:SetPoint("CENTER", layer, "CENTER", x, y)
    local tile = createTile(button)
    tile:SetPoint("CENTER"); tile:Show()
    button.tile, button.item = tile, { exp = 0, dur = 0 }
    SecureHandlerSetFrameRef(button, "layer", layer)
    SecureHandlerSetFrameRef(button, "driver", driver)
    SecureHandlerWrapScript(button, "OnClick", screen,
      "local layer = self:GetFrameRef('layer'); if layer then layer:Hide() end; local driver = self:GetFrameRef('driver'); if driver then driver:SetAttribute('ringX', nil); driver:SetAttribute('ringY', nil) end")
    ring.slots[i] = button
  end

  function ring:Apply()
    if not A.hunter then return end
    spec.update(self.state, A.db)
    local scale = A.Scale(spec.scale)
    self.layer:SetScale(scale)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    A.screenWidth, A.screenHeight = sw, sh
    driver:SetAttribute("dead", 14 * scale); driver:SetAttribute("scale", scale)
    driver:SetAttribute("sw", sw); driver:SetAttribute("sh", sh)
    for i, button in ipairs(self.slots) do
      local st = self.state
      local kind, value
      if st.known[i] then
        if st.petSlots[i] then kind, value = "pet", st.petSlots[i]
        elseif st.spellIds[i] then kind, value = "spell", st.spellIds[i]
        elseif st.macros[i] then kind, value = "macro", st.macros[i] end
      end
      driver:SetAttribute("kind" .. i, kind); driver:SetAttribute("value" .. i, value)
      button:SetAttribute("type", kind)
      button:SetAttribute("action", kind == "pet" and value or nil)
      button:SetAttribute("spell", kind == "spell" and value or nil)
      button:SetAttribute("macrotext", kind == "macro" and value or nil)
      button:EnableMouse(kind ~= nil)
    end
    ClearOverrideBindings(driver)
    local key = A.db[spec.key]
    if type(key) == "string" and key ~= "" then SetOverrideBindingClick(driver, true, key, spec.button, "LeftButton") end
  end

  function ring:Draw()
    if not self.cx then return end
    local x, y = cursor()
    local hovered = A.Pick(x - self.cx, y - self.cy, 14 * A.Scale(spec.scale), self.n)
    if hovered and not self.state.known[hovered] then hovered = nil end
    local color = A.Color()
    local active = {}
    if _G.GetPetActionInfo then
      for slot = 1, (_G.NUM_PET_ACTION_SLOTS or 10) do
        local ok, name, _, _, isActive = pcall(GetPetActionInfo, slot)
        name, isActive = A.Plain(name), A.Plain(isActive)
        if ok and type(name) == "string" and isActive == true then active[name] = true end
      end
    end
    for i, button in ipairs(self.slots) do
      local st, tile = self.state, button.tile
      local learned = st.known[i] ~= nil
      tile.icon:SetTexture(st.icons[i]); tile.icon:SetDesaturated(not learned)
      local selected = hovered == i
      local entry
      for _, e in ipairs(spec.def) do if e.key == st.order[i] then entry = e; break end end
      local isActive = entry and entry.token and (active[entry.token] or active[_G[entry.token] or entry.label])
      local theme = A.Theme()
      tile:SetScale(selected and theme.hover or 1)
      local border = (selected or isActive) and color or theme.border
      tile:SetBackdropBorderColor(border[1], border[2], border[3], 1)
      if isActive and not selected then tile:SetBackdropBorderColor(color[1], color[2], color[3], 1) end
      tile.icon:SetAlpha(learned and 1 or 0.4)
    end
    self.label:SetText(hovered and self.state.short[hovered] or "")
    if hovered then
      wedge:SetRotation(-(hovered - 1) * TWO_PI / self.n)
      wedge:SetVertexColor(color[1], color[2], color[3], 0.22); wedge:Show()
    else wedge:Hide() end
  end
  layer:SetScript("OnShow", function()
    ring:Draw()
  end)
  layer:SetScript("OnUpdate", function() ring:Draw() end)
  return ring
end

function A.CreateRings()
  if not A.hunter then return end
  if #A.rings > 0 then return end
  if InCombatLockdown() then A.pending = true; return end
  local R = A.Actions
  A.rings[1] = createRing({ state = "petCommandRing", button = "PetRingsCommandButton", def = R.commands,
    wedge = "PetCommandRingWedge.tga", key = "petCommandRingKey", scale = "petCommandRingScale", update = R.UpdateCommands })
  A.rings[2] = createRing({ state = "petCareRing", button = "PetRingsCareButton", def = R.care,
    wedge = "PetCareRingWedge.tga", key = "petCareRingKey", scale = "petCareRingScale", update = R.UpdateCare })
  SecureHandlerSetFrameRef(A.rings[1].driver, "other", A.rings[2].layer)
  SecureHandlerSetFrameRef(A.rings[2].driver, "other", A.rings[1].layer)
  SecureHandlerSetFrameRef(A.rings[1].driver, "otherDriver", A.rings[2].driver)
  SecureHandlerSetFrameRef(A.rings[2].driver, "otherDriver", A.rings[1].driver)
  A.ApplyTheme()
end
