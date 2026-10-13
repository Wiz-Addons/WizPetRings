local _, A = ...
local function text(parent, label, x, y, width)
  local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t:SetPoint("TOPLEFT", x, -y); t:SetJustifyH("LEFT"); t:SetText(label)
  if width then t:SetWidth(width) end
  A.themeTexts = A.themeTexts or {}; A.themeTexts[#A.themeTexts + 1] = t
  return t
end
local function button(parent, label, x, y, width, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  -- Keep the caption object separate from the label string passed to SetText.
  -- No Blizzard button template: its red textures can return on state changes.
  local caption = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  caption:SetPoint("CENTER"); b:SetFontString(caption)
  b:SetSize(width or 260, 24); b:SetPoint("TOPLEFT", x, -y); b:SetText(label)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function() b.prHover = true; A.PaintButton(b) end)
  b:SetScript("OnLeave", function() b.prHover = nil; A.PaintButton(b) end)
  A.themeButtons = A.themeButtons or {}; A.themeButtons[#A.themeButtons + 1] = b
  A.PaintButton(b)
  return b
end
local IGNORE = { LSHIFT = true, RSHIFT = true, LALT = true, RALT = true, LCTRL = true, RCTRL = true }
local function capture(bindingButton, key, otherKey)
  if A.capture then A.capture.cancel() end
  local function finish(value)
    bindingButton:EnableKeyboard(false)
    bindingButton:SetPropagateKeyboardInput(true)
    bindingButton:SetScript("OnKeyDown", nil)
    bindingButton:SetScript("OnMouseDown", nil)
    A.capture = nil
    if value ~= nil then
      if value ~= "" and value == A.db[otherKey] then A.Print("Choose a different key for each ring.")
      else A.db[key] = value ~= "" and value or nil; A.Apply() end
    end
    A.RefreshOptions()
  end
  local function accept(value)
    if IGNORE[value] then return end
    if value == "ESCAPE" then finish(""); return end
    if IsShiftKeyDown() then value = "SHIFT-" .. value end
    if IsControlKeyDown() then value = "CTRL-" .. value end
    if IsAltKeyDown() then value = "ALT-" .. value end
    local action = GetBindingAction and GetBindingAction(value, true)
    if action == "OPENCHAT" or action == "OPENCHATSLASH" or action == "TOGGLEGAMEMENU" then
      A.Print("Choose a key that is not used for chat or the game menu."); return
    end
    finish(value)
  end
  A.capture = { cancel = function() finish(nil) end }
  bindingButton:SetText("Press a key (Esc clears)")
  bindingButton:EnableKeyboard(true); bindingButton:SetPropagateKeyboardInput(false)
  bindingButton:SetScript("OnKeyDown", function(_, value) accept(value) end)
  bindingButton:SetScript("OnMouseDown", function(_, value)
    local mouse = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
    if mouse[value] then accept(mouse[value]) elseif value == "RightButton" then finish("") end
  end)
end

function A.RefreshOptions()
  if not A.options then return end
  for _, group in ipairs(A.options.groups) do
    local def, prefix = group.def, group.prefix
    group.key:SetText(A.db[prefix .. "Key"] or "Click to bind a key")
    group.slider:SetValue(A.Scale(prefix .. "Scale"))
    group.sizeText:SetText(("Ring size: %d%%"):format(A.Scale(prefix .. "Scale") * 100 + 0.5))
    local order, labels = A.Actions.Order(def, A.db[prefix .. "Order"]), A.Actions.Labels(def)
    for i, b in ipairs(group.directions) do b:SetText(group.names[i] .. ": " .. labels[order[i]]) end
  end
  A.options.callID:SetText(A.db.petCareCallSpellID and tostring(A.db.petCareCallSpellID) or "")
  local theme = A.Theme()
  A.options.theme:SetText(theme.name .. " — " .. theme.description)
  A.ApplyTheme()
end

function A.SelectOptionsPage(index)
  if not A.options then return end
  if A.capture then A.capture.cancel() end
  index = index == 2 and 2 or 1
  for i, group in ipairs(A.options.groups) do
    if i == index then group.page:Show(); group.marker:Show()
    else group.page:Hide(); group.marker:Hide() end
    group.nav.prSelected = i == index
    A.PaintButton(group.nav)
  end
  A.db.optionsPage = index
  A.RefreshOptions()
end

local function buildOptions()
  if A.options then return end
  local f = CreateFrame("Frame", "PetRingsOptions", UIParent, "BackdropTemplate")
  f:SetSize(720, 630); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  f:SetBackdropColor(0.055, 0.055, 0.065, 0.98); f:SetBackdropBorderColor(0.4, 0.35, 0.22, 1)
  local position = A.db.optionsPosition
  if type(position) == "table" and type(position.point) == "string" then
    f:SetPoint(position.point, UIParent, position.relative or position.point, tonumber(position.x) or 0, tonumber(position.y) or 0)
  else f:SetPoint("CENTER") end
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relative, x, y = self:GetPoint()
    if point then A.db.optionsPosition = { point = point, relative = relative, x = x, y = y } end
  end)
  f:SetScript("OnHide", function() if A.capture then A.capture.cancel() end end)
  f:SetScript("OnShow", A.RefreshOptions)
  _G.UISpecialFrames = _G.UISpecialFrames or {}; table.insert(UISpecialFrames, "PetRingsOptions")
  local side = f:CreateTexture(nil, "BACKGROUND")
  side:SetColorTexture(0.025, 0.025, 0.03, 0.9)
  side:SetPoint("TOPLEFT", 1, -1); side:SetPoint("BOTTOMLEFT", 1, 1); side:SetWidth(150)
  local divider = f:CreateTexture(nil, "BORDER")
  divider:SetColorTexture(0.4, 0.35, 0.22, 0.65)
  divider:SetPoint("TOPLEFT", 151, -1); divider:SetPoint("BOTTOMLEFT", 151, 1); divider:SetWidth(1)
  local title = text(f, "WizPetRings", 16, 20, 130)
  title.prTitle = true
  f.side, f.divider = side, divider
  text(f, "WoW Forever", 16, 46, 130)
  button(f, "Close", 620, 14, 80, function() f:Hide() end)
  f.groups = {}
  local R = A.Actions
  for index, spec in ipairs({
    { title = "Pet Commands", prefix = "petCommandRing", def = R.commands,
      intro = "Hold the key, flick toward a command, then release. Release in the centre to cancel. Move To opens the ground cursor.",
      directions = { "Up", "Upper-right", "Lower-right", "Bottom-right", "Bottom-left", "Lower-left", "Upper-left" } },
    { title = "Pet Care", prefix = "petCareRing", def = R.care,
      intro = "Hold the key, flick toward a pet spell, then release. Release in the centre to cancel. Feed opens the food cursor.",
      directions = { "Up", "Right", "Down", "Left" } },
  }) do
    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 174, -20); page:SetSize(510, 520); page:Hide()
    local group = { prefix = spec.prefix, def = spec.def, names = spec.directions, directions = {}, page = page }
    local prefix = spec.prefix
    group.nav = button(f, spec.title, 12, 88 + (index - 1) * 34, 126, function() A.SelectOptionsPage(index) end)
    group.nav.prNavigation = true
    group.marker = group.nav:CreateTexture(nil, "OVERLAY")
    group.marker:SetColorTexture(1, 0.82, 0.3, 1); group.marker:SetSize(3, 18); group.marker:SetPoint("LEFT", 1, 0)
    text(page, spec.title, 0, 0, 420).prTitle = true
    text(page, spec.intro, 0, 34, 490)
    text(page, "Ring key", 0, 98, 300)
    group.key = button(page, "", 0, 120, 300, function(b)
      capture(b, prefix .. "Key", index == 1 and "petCareRingKey" or "petCommandRingKey")
    end)
    button(page, "Clear", 308, 120, 80, function() A.db[prefix .. "Key"] = nil; A.Apply(); A.RefreshOptions() end)
    group.sizeText = text(page, "", 0, 162)
    local slider = CreateFrame("Slider", nil, page, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", 0, -185); slider:SetSize(388, 16); slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0.75, 2); slider:SetValueStep(0.05); slider:SetObeyStepOnDrag(true)
    slider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" }); slider:SetBackdropColor(0.15, 0.2, 0.28, 1)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetScript("OnValueChanged", function(_, value)
      value = math.floor(value * 20 + 0.5) / 20
      if A.db[prefix .. "Scale"] ~= value then A.db[prefix .. "Scale"] = value; A.Apply() end
      group.sizeText:SetText(("Ring size: %d%%"):format(value * 100 + 0.5))
    end)
    group.slider = slider
    text(page, "Click a direction to cycle its action and swap positions.", 0, 220, 490)
    for i in ipairs(spec.directions) do
      group.directions[i] = button(page, "", 0, 246 + (i - 1) * 28, 420, function()
        local order = R.Order(spec.def, A.db[prefix .. "Order"])
        local current, target
        for j, entry in ipairs(spec.def) do if entry.key == order[i] then current = j; break end end
        local nextKey = spec.def[(current % #spec.def) + 1].key
        for j, key in ipairs(order) do if key == nextKey then target = j; break end end
        order[i], order[target] = order[target], order[i]
        A.db[prefix .. "Order"] = order; A.Apply(); A.RefreshOptions()
      end)
    end
    local resetY = index == 1 and 454 or 370
    button(page, "Reset layout", 0, resetY, 240, function() A.db[prefix .. "Order"] = nil; A.Apply(); A.RefreshOptions() end)
    if index == 2 then
      text(page, "Optional Call Pet spell ID", 0, 412, 400)
      local edit = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
      edit:SetPoint("TOPLEFT", 6, -434); edit:SetSize(220, 26); edit:SetAutoFocus(false)
      f.callID = edit
      local function saveID()
        local value = edit:GetText()
        local id = tonumber(value)
        if value ~= "" and not (id and id > 0 and id == math.floor(id)) then A.Print("Enter a positive whole spell ID, or leave blank."); return end
        A.db.petCareCallSpellID = id; edit:ClearFocus(); A.Apply(); A.RefreshOptions()
      end
      edit:SetScript("OnEnterPressed", saveID)
      edit:SetScript("OnEscapePressed", function() edit:ClearFocus(); A.RefreshOptions() end)
      button(page, "Save", 240, 434, 90, saveID)
      text(page, "Leave blank for automatic detection.", 0, 476, 490)
    end
    f.groups[#f.groups + 1] = group
  end
  f.theme = text(f, "", 174, 554, 520)
  text(f, "Key Bindings → WizPetRings also works.\nChanges made in combat apply when combat ends.", 174, 592, 520)
  A.options = f
  f:Hide()
end

function A.ShowOptions()
  if not A.started then return end
  if not A.hunter then A.Print("WizPetRings is enabled only for Hunters; it does not claim keys on this character."); return end
  buildOptions()
  A.options:Show()
  A.SelectOptionsPage(A.db.optionsPage)
end

function A.RegisterSettings()
  if not A.hunter then return end
  if A.category then return end
  if not (_G.Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
  local panel = CreateFrame("Frame", "PetRingsSettingsPanel")
  text(panel, "WizPetRings", 16, 16)
  text(panel, "Configure each ring in the WizPetRings window.", 16, 48, 550)
  button(panel, "Open WizPetRings", 16, 84, 250, A.ShowOptions)
  local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "WizPetRings")
  if ok and category then
    Settings.RegisterAddOnCategory(category)
    A.category, A.settingsPanel = category, panel
  end
end
