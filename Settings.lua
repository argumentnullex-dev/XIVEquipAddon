local addon, XIVEquip = ...
local L = (XIVEquip and XIVEquip.L) or {}

local function comparerNames()
  local list = { ["default"] = L.Settings_Default or "Auto (Pawn → ilvl)" }
  if XIVEquip.Comparers and XIVEquip.Comparers.All then
    for name, cmp in pairs(XIVEquip.Comparers:All()) do
      list[name] = (cmp and cmp.Label) or name
    end
  end
  return list
end

local function BuildSettingsPanel()
  local s = XIVEquip_Settings
  local panel = CreateFrame("Frame")
  panel.name = L.Settings_Title or "XIVEquip"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L.Settings_Title or "XIVEquip")

  local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  desc:SetWidth(520)
  desc:SetJustifyH("LEFT")
  desc:SetText(L.Settings_Desc or "FFXIV-style Equip Recommended Gear. Prefers Pawn scales; falls back to item level.")

  -- Comparer dropdown
  local dd = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -16, -16)
  UIDropDownMenu_SetWidth(dd, 220)

  local names = comparerNames()
  UIDropDownMenu_Initialize(dd, function(self, level)
    local info
    for value, label in pairs(names) do
      info = UIDropDownMenu_CreateInfo()
      info.text = label
      info.func = function()
        s.SelectedComparer = value
        if XIVEquip.Comparers and XIVEquip.Comparers.Initialize then
          XIVEquip.Comparers:Initialize()
        end
        UIDropDownMenu_SetText(dd, label)
      end
      info.checked = (s.SelectedComparer == value)
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  do
    local cur = s.SelectedComparer or "default"
    UIDropDownMenu_SetText(dd, names[cur] or (L.Settings_Default or "Auto (Pawn → ilvl)"))
  end
  local ddLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ddLabel:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 16, 4)
  ddLabel:SetText(L.Settings_ActiveLabel or "Active comparer")

  -- Messages
  local cbLogin = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  cbLogin:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 18, -16)
  cbLogin.Text:SetText(L.Settings_LoginMsgs or "Show login message")
  cbLogin:SetChecked(s.Messages.Login)
  cbLogin:SetScript("OnClick", function(self) s.Messages.Login = self:GetChecked() end)

  local cbEquip = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  cbEquip:SetPoint("TOPLEFT", cbLogin, "BOTTOMLEFT", 0, -8)
  cbEquip.Text:SetText(L.Settings_EquipMsgs or "Show equip messages")
  cbEquip:SetChecked(s.Messages.Equip)
  cbEquip:SetScript("OnClick", function(self) s.Messages.Equip = self:GetChecked() end)

  -- Debug checkbox
  local cbDebug = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  cbDebug:SetPoint("TOPLEFT", cbEquip, "BOTTOMLEFT", 0, -8)
  cbDebug.Text:SetText(L.Settings_Debug or "Enable debug logging")
  cbDebug:SetChecked(s.Debug and true or false)
  cbDebug:SetScript("OnClick", function(self) s.Debug = self:GetChecked() and true or false end)

  -- Weapon mode
  local ddMode = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
  ddMode:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", -16, -20)
  UIDropDownMenu_SetWidth(ddMode, 260)
  local ddModeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ddModeLabel:SetPoint("BOTTOMLEFT", ddMode, "TOPLEFT", 16, 4)
  ddModeLabel:SetText(L.Settings_WeaponModeLabel or "Weapon mode")

  local modes = {
    { val="AUTO",      txt=L.Settings_WeaponMode_Auto or "Auto" },
    { val="TWOHAND",   txt=L.Settings_WeaponMode_2H or "Two-Hand" },
    { val="DUAL_1H",   txt=L.Settings_WeaponMode_Dual1H or "Dual 1H" },
    { val="DUAL_2H",   txt=L.Settings_WeaponMode_Dual2H or "Dual 2H (TG)" },
    { val="MH_SHIELD", txt=L.Settings_WeaponMode_MHShield or "MH + Shield" },
    { val="MH_OFFHAND",txt=L.Settings_WeaponMode_MHOffhand or "MH + Off-hand (Frill)" },
  }
  UIDropDownMenu_Initialize(ddMode, function(self, level)
    local info
    for _, m in ipairs(modes) do
      info = UIDropDownMenu_CreateInfo()
      info.text = m.txt
      info.func = function()
        s.Weapons.Mode = m.val
        UIDropDownMenu_SetText(ddMode, m.txt)
      end
      info.checked = (s.Weapons.Mode == m.val)
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  do
    local cur = s.Weapons.Mode or "AUTO"
    local map = {}; for _, m in ipairs(modes) do map[m.val]=m.txt end
    UIDropDownMenu_SetText(ddMode, map[cur] or (L.Settings_WeaponMode_Auto or "Auto"))
    if not map[cur] then s.Weapons.Mode = "AUTO" end
  end

  -- Bias
  local ddBias = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
  ddBias:SetPoint("TOPLEFT", ddMode, "BOTTOMLEFT", 0, -16)
  UIDropDownMenu_SetWidth(ddBias, 260)
  local ddBiasLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ddBiasLabel:SetPoint("BOTTOMLEFT", ddBias, "TOPLEFT", 16, 4)
  ddBiasLabel:SetText(L.Settings_WeaponBiasLabel or "Weapon bias")

  local biases = {
    { val="AUTO",    txt=L.Settings_WeaponBias_Auto or "Auto" },
    { val="PREF_2H", txt=L.Settings_WeaponBias_Pref2H or "Prefer 2H" },
    { val="PREF_DW", txt=L.Settings_WeaponBias_PrefDW or "Prefer Dual Wield" },
    { val="PREF_1H", txt=L.Settings_WeaponBias_Pref1H or "Prefer 1H + off-hand" },
    { val="NONE",    txt=L.Settings_WeaponBias_None or "No bias" },
  }
  UIDropDownMenu_Initialize(ddBias, function(self, level)
    local info
    for _, b in ipairs(biases) do
      info = UIDropDownMenu_CreateInfo()
      info.text = b.txt
      info.func = function()
        s.Weapons.Bias = b.val
        UIDropDownMenu_SetText(ddBias, b.txt)
      end
      info.checked = (s.Weapons.Bias == b.val)
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  do
    local cur = s.Weapons.Bias or "AUTO"
    local map = {}; for _, b in ipairs(biases) do map[b.val]=b.txt end
    UIDropDownMenu_SetText(ddBias, map[cur] or (L.Settings_WeaponBias_Auto or "Auto"))
  end

  -- License / footer
  local lic = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  lic:SetPoint("TOPLEFT", ddBias, "BOTTOMLEFT", 16, -14)
  lic:SetWidth(520); lic:SetJustifyH("LEFT")
  lic:SetText(L.Settings_License or "Inspired by FFXIV. Pawn © their authors.")

  return panel
end

-- Register & defaults
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, e, name)
  if e == "ADDON_LOADED" and name == addon then
    XIVEquip_Settings = XIVEquip_Settings or {}
    local s = XIVEquip_Settings
    s.SelectedComparer = s.SelectedComparer or "default"
    s.Messages = s.Messages or { Login = true, Equip = true }
    s.Weapons  = s.Weapons  or {}
    s.Weapons.Mode = s.Weapons.Mode or "AUTO"
    s.Weapons.Bias = s.Weapons.Bias or "AUTO"
    s.Debug = (s.Debug == nil) and false or s.Debug  -- << default debug flag

    if Settings and Settings.RegisterCanvasLayoutCategory then
      local panel = BuildSettingsPanel()
      local category = Settings.RegisterCanvasLayoutCategory(panel, L.Settings_Title or "XIVEquip")
      category.ID = "XIVEquip_Settings"
      Settings.RegisterAddOnCategory(category)
    end
  end
end)
