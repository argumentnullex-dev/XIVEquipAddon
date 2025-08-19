-- Settings_Pawn.lua
local addon, XIVEquip = ...

-- Build strings at runtime (after Localization.lua is loaded)
local function T(key, fallback)
  local L = (XIVEquip and XIVEquip.L) or {}
  local v = L[key]
  if type(v) == "string" and v ~= "" then return v end
  return fallback
end

local function ensureSettings()
  _G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
  local s = _G.XIVEquip_Settings
  s.PawnScaleBySpec = s.PawnScaleBySpec or {}  -- [specID] = "Scale Name"
  return s
end

local function classAndSpecs()
  local _, classLoc = UnitClass("player")
  local specs = {}
  local n = (GetNumSpecializations and GetNumSpecializations()) or 0
  for i = 1, n do
    local specID, specName = GetSpecializationInfo(i)
    if specID and specName then
      table.insert(specs, { id = specID, name = specName, classSpec = (classLoc and (classLoc .. ": " .. specName)) or nil })
    end
  end
  return classLoc or "?", specs
end

local function createEditBox(parent, width)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(width, 28)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(120)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return eb
end

local function BuildPawnPanel()
  local s = ensureSettings()

  local panel = CreateFrame("Frame")
  panel.name = "XIVEquip • Pawn"

  -- Title
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("XIVEquip • Pawn")

  -- Description
  local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  desc:SetWidth(620)
  desc:SetJustifyH("LEFT")
  desc:SetText(T("Settings_PawnDesc",
    "Choose which Pawn scale XIVEquip should use. You can set a global default and per-spec overrides.")
  )

  -- ----- Default (fallback) -----
  local defLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  defLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
  defLabel:SetText(T("Settings_PawnDefaultLabel", "Default (fallback) Pawn scale name") .. ":")

  local defEB = createEditBox(panel, 280)
  defEB:SetPoint("LEFT", defLabel, "RIGHT", 10, 0)
  defEB:SetText(s.PawnScaleName or "")
  defEB:SetCursorPosition(0)
  defEB:SetScript("OnEditFocusLost", function(self)
    local txt = self:GetText()
    s.PawnScaleName = (txt ~= "" and txt) or nil
  end)

  local classLoc, specs = classAndSpecs()

  local defBtnSpec = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  defBtnSpec:SetSize(130, 22)
  defBtnSpec:SetPoint("LEFT", defEB, "RIGHT", 8, 0)
  defBtnSpec:SetText(T("Settings_PawnUseSpec", "Use spec name"))
  defBtnSpec:SetScript("OnClick", function()
    local curIdx = GetSpecialization and GetSpecialization()
    if curIdx then
      local _, specName = GetSpecializationInfo(curIdx)
      if specName then defEB:SetText(specName); s.PawnScaleName = specName end
    end
  end)

  local defBtnClass = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  defBtnClass:SetSize(160, 22)
  defBtnClass:SetPoint("LEFT", defBtnSpec, "RIGHT", 6, 0)
  defBtnClass:SetText(T("Settings_PawnUseClass", "Use Class: Spec"))
  defBtnClass:SetScript("OnClick", function()
    local curIdx = GetSpecialization and GetSpecialization()
    if curIdx then
      local _, specName = GetSpecializationInfo(curIdx)
      if specName and classLoc then
        local nm = classLoc .. ": " .. specName
        defEB:SetText(nm); s.PawnScaleName = nm
      end
    end
  end)

  -- ----- Per-spec overrides -----
  local hdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  hdr:SetPoint("TOPLEFT", defLabel, "BOTTOMLEFT", 0, -20)
  hdr:SetText(T("Settings_PawnPerSpecHdr", "Per-spec overrides"))

  local last = hdr
  for _, sp in ipairs(specs) do
    local rowLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    rowLabel:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -10)
    rowLabel:SetText(sp.name .. ":")

    local eb = createEditBox(panel, 260)
    eb:SetPoint("LEFT", rowLabel, "RIGHT", 10, 0)
    eb:SetText((s.PawnScaleBySpec[sp.id]) or "")
    eb:SetCursorPosition(0)
    eb:SetScript("OnEditFocusLost", function(self)
      local txt = self:GetText()
      if txt ~= "" then s.PawnScaleBySpec[sp.id] = txt else s.PawnScaleBySpec[sp.id] = nil end
    end)

    local btn1 = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn1:SetSize(120, 22)
    btn1:SetPoint("LEFT", eb, "RIGHT", 6, 0)
    btn1:SetText(T("Settings_PawnUseSpec", "Use spec name"))
    btn1:SetScript("OnClick", function()
      eb:SetText(sp.name); s.PawnScaleBySpec[sp.id] = sp.name
    end)

    local btn2 = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn2:SetSize(150, 22)
    btn2:SetPoint("LEFT", btn1, "RIGHT", 6, 0)
    btn2:SetText(T("Settings_PawnUseClass", "Use Class: Spec"))
    btn2:SetScript("OnClick", function()
      if sp.classSpec then eb:SetText(sp.classSpec); s.PawnScaleBySpec[sp.id] = sp.classSpec end
    end)

    last = rowLabel
  end

  -- Register as a sub-category under the main XIVEquip panel if present.
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local parent = Settings.GetCategory and Settings.GetCategory("XIVEquip_Settings") or nil
    if parent and Settings.RegisterCanvasLayoutSubcategory then
      local sub = Settings.RegisterCanvasLayoutSubcategory(parent, panel, "XIVEquip • Pawn")
      sub.ID = "XIVEquip_Pawn"
    else
      local cat = Settings.RegisterCanvasLayoutCategory(panel, "XIVEquip • Pawn")
      cat.ID = "XIVEquip_Pawn"
      Settings.RegisterAddOnCategory(cat)
    end
  elseif InterfaceOptions_AddCategory then
    -- Legacy fallback (pre-11.x)
    panel.name = "XIVEquip • Pawn"
    panel.parent = "XIVEquip"
    InterfaceOptions_AddCategory(panel)
  end
end

-- Build at PLAYER_LOGIN so Localization and main category exist
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() BuildPawnPanel() end)
