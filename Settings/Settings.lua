-- Settings/Settings.lua
local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}
local L = (XIVEquip and XIVEquip.L) or {}

-- LSP helper types for this file
---@class SettingsPanel: Frame
---@field name string

-- LSP annotations for UI widgets and helpers
---@type fun(frameType: string, name: string?, parent: table?, template: string?): Frame
-- (don't shadow the global CreateFrame at file scope; use the global at call time)

---@type fun(frame: Frame, w: number)
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth or UIDropDownMenu_SetWidth
---@type fun(frame: Frame, fn: fun(self: Frame, level: number))
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize or UIDropDownMenu_Initialize
---@type fun(): table
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo or UIDropDownMenu_CreateInfo
---@type fun(frame: Frame, text: string)
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText or UIDropDownMenu_SetText
---@type fun(info: table, level: number)
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton or UIDropDownMenu_AddButton

---@class FontString: Frame
---@field SetText fun(self: FontString, text: string)
---@field SetPoint fun(self: FontString, point: string, ...: any)
---@field SetWidth fun(self: FontString, w: number)
---@field SetJustifyH fun(self: FontString, h: string)

---@class CheckButton: Frame
---@field SetChecked fun(self: CheckButton, v: boolean)
---@field GetChecked fun(self: CheckButton): boolean
---@field SetScript fun(self: CheckButton, script: string, fn: fun(self: CheckButton))

-- Return map of comparer internal names -> display labels
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
  ---@cast panel SettingsPanel
  panel.name = L.Settings_Title or "XIVEquip"

  -- Title
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L.Settings_Title or "XIVEquip")

  -- Description
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

  -- Messages: login
  local cbLogin = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  ---@cast cbLogin CheckButton
  cbLogin:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 18, -16)
  cbLogin.Text:SetText(L.Settings_LoginMsgs or "Show login message")
  cbLogin:SetChecked(s.Messages.Login)
  cbLogin:SetScript("OnClick", function(self) s.Messages.Login = self:GetChecked() end)

  -- Messages: equip
  local cbEquip = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  ---@cast cbEquip CheckButton
  cbEquip:SetPoint("TOPLEFT", cbLogin, "BOTTOMLEFT", 0, -8)
  cbEquip.Text:SetText(L.Settings_EquipMsgs or "Show equip messages")
  cbEquip:SetChecked(s.Messages.Equip)
  cbEquip:SetScript("OnClick", function(self) s.Messages.Equip = self:GetChecked() end)

  -- Debug checkbox
  local cbDebug = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  ---@cast cbDebug CheckButton
  cbDebug:SetPoint("TOPLEFT", cbEquip, "BOTTOMLEFT", 0, -8)
  cbDebug.Text:SetText(L.Settings_Debug or "Enable debug logging")
  cbDebug:SetChecked(s.Debug and true or false)
  cbDebug:SetScript("OnClick", function(self) s.Debug = self:GetChecked() and true or false end)

  -- Auto-equip on spec change (NEW)
  local cbAuto = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  ---@cast cbAuto CheckButton
  cbAuto:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", 0, -8)
  cbAuto.Text:SetText(L.Settings_AutoSpecEquip or "Auto-equip & save set on spec change")
  cbAuto:SetChecked(s.AutoSpecEquip ~= false)
  cbAuto:SetScript("OnClick", function(self)
    s.AutoSpecEquip = self:GetChecked() and true or false
  end)

  -- Footer / license (anchor fixed; ddBias was undefined)
  local lic = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  lic:SetPoint("TOPLEFT", cbAuto, "BOTTOMLEFT", 16, -14)
  lic:SetWidth(520)
  lic:SetJustifyH("LEFT")
  lic:SetText(L.Settings_License or "Inspired by FFXIV. Pawn © their authors.")

  return panel
end

-- Register & defaults
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, e, name)
  if e == "ADDON_LOADED" and name == addon then
    XIVEquip_Settings  = XIVEquip_Settings or {}
    local s            = XIVEquip_Settings

    -- Defaults
    s.SelectedComparer = s.SelectedComparer or "default"
    s.Messages         = s.Messages or { Login = true, Equip = true }
    s.Weapons          = s.Weapons or {}
    s.Weapons.Mode     = s.Weapons.Mode or "AUTO"
    s.Weapons.Bias     = s.Weapons.Bias or "AUTO"
    s.Debug            = (s.Debug == nil) and false or s.Debug
    s.AutoSpecEquip    = (s.AutoSpecEquip ~= false) -- default ON unless explicitly false

    if Settings and Settings.RegisterCanvasLayoutCategory then
      local panel = BuildSettingsPanel()
      local category = Settings.RegisterCanvasLayoutCategory(panel, L.Settings_Title or "XIVEquip")
      category.ID = "XIVEquip_Settings"
      Settings.RegisterAddOnCategory(category)
    end
  end
end)
