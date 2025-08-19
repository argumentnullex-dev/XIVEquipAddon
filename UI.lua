-- UI.lua (drop-in)
local addonName, XIVEquip = ...
XIVEquip = XIVEquip or {}
local L = XIVEquip.L or {}

-- Fallback strings
L.ButtonTooltip = L.ButtonTooltip or "Equip Recommended Gear"

-- Button textures
local TEX_ENABLED  = "Interface\\AddOns\\XIVEquip\\assets\\icon_blue_128.tga"
local TEX_DISABLED = "Interface\\AddOns\\XIVEquip\\assets\\icon_white_128.tga"

local btn

-- only silence the LOGIN banner during preview; never touch Equip prints
local function withLoginSilenced(fn)
  local msgs = _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages
  local prev = msgs and msgs.Login
  if msgs then msgs.Login = false end
  local ok, err = xpcall(fn, geterrorhandler())
  if msgs then msgs.Login = prev end
  return ok, err
end

-- Use saved button position if present, otherwise sensible defaults near the portrait
local function anchorButton()
  if not btn then return end
  btn:ClearAllPoints()

  local S = _G.XIVEquip_Settings
  local pos = S and S.ButtonPos
  if pos and pos.point and pos.rel and pos.relPoint then
    local rel = _G[tostring(pos.rel)] or PaperDollFrame or CharacterFrame or UIParent
    btn:SetPoint(pos.point, rel, pos.relPoint, tonumber(pos.x) or 0, tonumber(pos.y) or 0)
  else
    local portrait = _G.CharacterFramePortrait
    if portrait then
      btn:SetPoint("LEFT", portrait, "RIGHT", 305, -22.5)
    elseif CharacterFrame then
      btn:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 300, -38)
    else
      btn:SetPoint("CENTER", UIParent, "CENTER", -180, -120)
    end
  end

  btn:Show()
end

local function saveButtonPosition()
  if not btn then return end
  local point, rel, relPoint, x, y = btn:GetPoint(1)
  _G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
  _G.XIVEquip_Settings.ButtonPos = {
    point = point, rel = rel and rel:GetName() or "PaperDollFrame",
    relPoint = relPoint, x = x, y = y
  }
end

local function createButton()
  if btn then return end
  local parent = PaperDollFrame or CharacterFrame or UIParent

  btn = CreateFrame("Button", "XIVEquipButton", parent, "BackdropTemplate")
  btn:SetSize(26, 26)
  btn:SetFrameStrata("DIALOG")
  if parent.GetFrameLevel then btn:SetFrameLevel(parent:GetFrameLevel() + 20) end
  btn:SetClampedToScreen(true)
  btn:SetMovable(true)
  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
  btn:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); saveButtonPosition(); anchorButton() end)

  btn:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  btn:SetBackdropColor(0.15, 0.15, 0.15, 0.85)
  btn:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)

  btn:SetNormalTexture(TEX_ENABLED)
  btn:SetPushedTexture(TEX_ENABLED)
  btn:SetDisabledTexture(TEX_DISABLED)
  local hi = btn:CreateTexture(nil, "HIGHLIGHT")
  hi:SetAllPoints(true)
  hi:SetTexture("Interface\\Buttons\\WHITE8x8")
  hi:SetVertexColor(1, 1, 1, 0.12)
  btn:SetHighlightTexture(hi)

  -- PREVIEW TOOLTIP (no equipping, no chat spam)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.ButtonTooltip, 0.2, 0.8, 1.0)

    if InCombatLockdown() then
      GameTooltip:AddLine("|cffaaaaaa(Disabled in combat)|r")
      GameTooltip:Show()
      return
    end

    local changes, pending, weaponPlan

    withLoginSilenced(function()
      local cmp = XIVEquip.Comparers and XIVEquip.Comparers:StartPass()

      if cmp and XIVEquip.Gear and XIVEquip.Gear.PlanBest then
        changes, pending = XIVEquip.Gear:PlanBest(cmp)
      else
        changes, pending = {}, false
      end

      if XIVEquip.Weapons and XIVEquip.Weapons.FindBestLoadout and XIVEquip.Weapons.PlanBest then
        weaponPlan = XIVEquip.Weapons:PlanBest(cmp) -- optional if implemented
      end

      if XIVEquip.Comparers and XIVEquip.Comparers.EndPass then
        XIVEquip.Comparers:EndPass()
      end
    end)

    if pending then
      GameTooltip:AddLine("|cffFFD100Loading item data…|r")
    end

    if (not changes or #changes == 0) and not weaponPlan then
      GameTooltip:AddLine("|cffaaaaaaNo upgrades.|r")
    else
      local showDetails = IsShiftKeyDown()
      for _, c in ipairs(changes or {}) do
        GameTooltip:AddLine(string.format("|cffdddddd%s|r", c.slotName or " "))
        if showDetails and c.deltaScore then
          local dIlvl = c.deltaIlvl or 0
          GameTooltip:AddLine(string.format(
            "  %s |TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:0|t %s  |cff7fff7f+%.1f score|r  |cff7fbfff+%d ilvl|r",
            c.oldLink or "", c.newLink or "", c.deltaScore, dIlvl))
        else
          GameTooltip:AddLine(string.format(
            "  %s |TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:0|t %s",
            c.oldLink or "", c.newLink or ""))
        end
      end

      if weaponPlan then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffddddddWeapons|r")
        GameTooltip:AddLine("  "..weaponPlan.oldText.." |TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:0|t "..weaponPlan.newText)
      end

      if not showDetails then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888(Hold Shift for score/ilvl deltas)|r")
      end
    end

    GameTooltip:Show()
  end)

  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  btn:SetScript("OnClick", function()
    if XIVEquip and XIVEquip.EquipBestGear then
      XIVEquip:EquipBestGear()
    end
  end)

  -- Disable during combat
  btn:RegisterEvent("PLAYER_REGEN_DISABLED")
  btn:RegisterEvent("PLAYER_REGEN_ENABLED")
  btn:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then self:Disable() else self:Enable() end
  end)

  anchorButton()
  C_Timer.After(0, anchorButton)
end

-- Show only on the Character (PaperDoll) tab
local function onPaperDollShow()
  createButton()
  if btn and PaperDollFrame and btn:GetParent() ~= PaperDollFrame then
    btn:SetParent(PaperDollFrame)
  end
  anchorButton()
end
local function onPaperDollHide()
  if btn then btn:Hide() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  if PaperDollFrame then
    if not PaperDollFrame.__XIVEquipHook then
      PaperDollFrame:HookScript("OnShow", onPaperDollShow)
      PaperDollFrame:HookScript("OnHide", onPaperDollHide)
      PaperDollFrame.__XIVEquipHook = true
    end
    if PaperDollFrame:IsShown() then onPaperDollShow() end
  elseif CharacterFrame then
    if not CharacterFrame.__XIVEquipHook then
      CharacterFrame:HookScript("OnShow", onPaperDollShow)
      CharacterFrame:HookScript("OnHide", onPaperDollHide)
      CharacterFrame.__XIVEquipHook = true
    end
    if CharacterFrame:IsShown() then onPaperDollShow() end
  end
end)
