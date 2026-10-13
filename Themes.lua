local _, A = ...
local MEDIA = "Interface\\AddOns\\WizPetRings\\Media\\"
local THEME = {
  name = "Classic", description = "Classic parchment, gold text, olive navigation.",
  accent = { 1, 0.82, 0, 1 }, border = { 0.24, 0.24, 0.18, 1 },
  tile = { 0.10, 0.10, 0.10, 0.95 }, text = { 1, 1, 1, 1 },
  edge = 1, hover = 1.08, font = "Fonts\\FRIZQT__.TTF",
}
function A.Theme() return THEME end

function A.PaintButton(b)
  local active = b.prHover or b.prSelected
  local fs = b:GetFontString()
  fs:ClearAllPoints()
  if b.prNavigation then
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    b:SetBackdropColor(0.3, 0.3, 0, active and (b.prSelected and 0.8 or 0.56) or 0)
    fs:SetPoint("LEFT", 16, 0)
  else
    fs:SetPoint("CENTER")
    b:SetBackdrop({ bgFile = MEDIA .. "SettingsButton.tga", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b:SetBackdropColor(active and 0.9 or 0.7, active and 0.9 or 0.7, active and 0.7 or 0.7, 1)
    b:SetBackdropBorderColor(active and 0.65 or 0.25, active and 0.6 or 0.25, active and 0.25 or 0.25, 1)
  end
  fs:SetTextColor(1, 0.82, 0, 1); fs:SetFont(THEME.font, 12, "")
end
function A.StyleTile(tile)
  tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  tile:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
end
function A.ApplyTheme()
  for _, b in ipairs(A.themeButtons or {}) do A.PaintButton(b) end
  for _, fs in ipairs(A.themeTexts or {}) do
    local color = fs.prTitle and THEME.accent or THEME.text
    fs:SetTextColor(color[1], color[2], color[3], 1)
    fs:SetFont(THEME.font, fs.prTitle and 16 or 12, "")
  end
  local f = A.options
  if f then
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    f.side:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    f.divider:SetAlpha(0)
    if not f.parchmentTextures then
      local parchment = "Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated.png"
      f.parchmentTextures = {}
      for i = 1, 3 do
        local texture = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        texture:SetTexture(parchment)
        if i == 1 then
          texture:SetPoint("TOPLEFT", 1, -1); texture:SetSize(150, 581)
        elseif i == 2 then
          texture:SetPoint("TOPRIGHT", -1, -1); texture:SetSize(567, 581)
          texture:SetTexCoord(0.09, 1, 0, 1)
        else texture:SetPoint("BOTTOMLEFT", 1, 1); texture:SetSize(718, 48) end
        texture:SetVertexColor(i == 3 and 0.5 or 0.7, i == 3 and 0.5 or 0.7, i == 3 and 0.5 or 0.7, i == 3 and 1 or 0.7)
        f.parchmentTextures[i] = texture
      end
    end
    for _, texture in ipairs(f.parchmentTextures) do texture:Show() end
    for _, group in ipairs(f.groups) do
      group.marker:SetAlpha(0)
      group.slider:SetBackdropColor(0.10, 0.10, 0.10, 1)
      group.slider:GetThumbTexture():SetVertexColor(1, 0.82, 0, 1)
    end
  end
  for _, ring in ipairs(A.rings) do
    ring.disc:SetTexture(MEDIA .. "AspectRingDisc.tga")
    for _, b in ipairs(ring.slots) do A.StyleTile(b.tile) end
    ring.label:SetFont(THEME.font, 13, "OUTLINE"); ring.label:SetTextColor(1, 1, 1, 1)
    if ring.layer:IsShown() then ring:Draw() end
  end
end
