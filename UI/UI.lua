-- UI.lua
local addonName, XIVEquip = ...

-- Declare the WoW globals used in this file for the language server.
-- These annotations don't evaluate anything at runtime; they only help the LSP.
---@type GameTooltipFrame
local GameTooltip
---@type PaperDollFrameClass
local PaperDollFrame
---@type CharacterFrameClass
local CharacterFrame
---@type Frame
local UIParent
---@type Frame
local CharacterFramePortrait
---@type table
local C_Item
---@type table
local C_Timer
---@type fun(...): boolean
local InCombatLockdown
---@type fun(...)
local GetItemStats
---@type fun(...)
local GetDetailedItemLevelInfo

XIVEquip                  = XIVEquip or {}
local L                   = XIVEquip.L or {}

-- Fallback strings
L.ButtonTooltip           = L.ButtonTooltip or "Equip Recommended Gear"

-- Button textures
local TEX_ENABLED         = "Interface\\AddOns\\XIVEquip\\Assets\\icon_blue_128.tga"
local TEX_DISABLED        = "Interface\\AddOns\\XIVEquip\\Assets\\icon_white_128.tga"

---@type Frame
local btn

-- Map Blizzard stat tokens -> Pawn keys and pretty text
local STAT_TO_PAWN        = {
  ITEM_MOD_CRIT_RATING_SHORT      = { key = "CritRating", label = "Crit" },
  ITEM_MOD_HASTE_RATING_SHORT     = { key = "HasteRating", label = "Haste" },
  ITEM_MOD_MASTERY_RATING_SHORT   = { key = "MasteryRating", label = "Mastery" },
  ITEM_MOD_VERSATILITY            = { key = "Versatility", label = "Vers" },
  ITEM_MOD_LIFESTEAL_SHORT        = { key = "Leech", label = "Leech" },
  ITEM_MOD_AVOIDANCE_RATING_SHORT = { key = "Avoidance", label = "Avoid" },
  ITEM_MOD_SPEED_RATING_SHORT     = { key = "MovementSpeed", label = "Speed" },
}

local GetItemStatsCompat  =
    (type(GetItemStats) == "function" and GetItemStats) or
    (C_Item and C_Item.GetItemStats) or
    function() return nil end

local function computeStatDiff(oldLink, newLink)
  local get = GetItemStatsCompat
  local diff = {}
  if not get then return diff end
  local a = get(oldLink) or {}
  local b = get(newLink) or {}
  -- union of keys
  local seen = {}
  for k in pairs(a) do seen[k] = true end
  for k in pairs(b) do seen[k] = true end

  for k in pairs(seen) do
    local delta = (b[k] or 0) - (a[k] or 0)
    if delta ~= 0 then
      diff[k] = delta
    end
  end
  return diff
end

-- Optional: turn raw deltas into *weighted* deltas using a values table
local function weightDeltas(rawDiff, values)
  if type(values) ~= "table" then return nil end
  local weighted, total = {}, 0
  for blizzKey, amt in pairs(rawDiff or {}) do
    local map = STAT_TO_PAWN[blizzKey]
    if map then
      local w = values[map.key]
      if w then
        local contrib = amt * w
        weighted[map.key] = (weighted[map.key] or 0) + contrib
        total = total + contrib
      end
    end
  end
  return weighted, total
end

-- Retail item level (works on links)
local function GetIlvl(link)
  if type(GetDetailedItemLevelInfo) == "function" then
    local ok, v = pcall(GetDetailedItemLevelInfo, link)
    if ok then return v end
  end
  local _, _, _, ilvl = GetItemInfo(link)
  return ilvl
end

-- If PlanBest didn't populate deltas, compute them now
local function ensureDeltas(c)
  -- score delta (Pawn helpers from Pawn.lua)
  if (not c.deltaScore) or c.deltaScore == 0 then
    local newV = XIVEquip.PawnScoreLinkAuto and select(1, XIVEquip.PawnScoreLinkAuto(c.newLink))
    local oldV = XIVEquip.PawnScoreLinkAuto and select(1, XIVEquip.PawnScoreLinkAuto(c.oldLink))
    if oldV == nil then oldV = 0 end
    if type(newV) == "number" and type(oldV) == "number" then
      c.deltaScore = newV - oldV
    end
  end
  -- ilvl delta
  if (not c.deltaIlvl) or c.deltaIlvl == 0 then
    local newI = GetIlvl(c.newLink)
    local oldI = GetIlvl(c.oldLink)
    if oldI == nil then oldI = 0 end
    if type(newI) == "number" and type(oldI) == "number" then
      c.deltaIlvl = (newI - oldI)
    end
  end
end

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
    point = point,
    rel = rel and rel:GetName() or "PaperDollFrame",
    relPoint = relPoint,
    x = x,
    y = y
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
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing(); saveButtonPosition(); anchorButton()
  end)

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

  -- helper to get a stable key for a *physical* item instance (GUID preferred)
  local function instanceKeyFromChange(c)
    if c and c.newLoc and C_Item and C_Item.GetItemGUID then
      local ok, guid = pcall(C_Item.GetItemGUID, c.newLoc)
      if ok and guid and guid ~= "" then return guid end
    end
    local id = c and c.newLink and tonumber(c.newLink:match("|Hitem:(%d+)"))
    local bag = c and c.newLoc and c.newLoc.bagID or -1
    local slot = c and c.newLoc and c.newLoc.slotIndex or -1
    return table.concat({ id or 0, bag, slot }, ":")
  end

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

    local changes, pending, weaponPlan, tooltipHeader

    withLoginSilenced(function()
      local cmp = XIVEquip.Comparers and XIVEquip.Comparers:StartPass()

      if cmp and type(cmp.PawnGetActiveTooltipHeader) == "function" then
        tooltipHeader = cmp.PawnGetActiveTooltipHeader()
      end

      if cmp and XIVEquip.Gear and XIVEquip.Gear.PlanBest then
        changes, pending = XIVEquip.Gear:PlanBest(cmp) -- requires Gear:PlanBest to honor opts.exclude
      else
        changes, pending = {}, false
      end

      if tooltipHeader and tooltipHeader ~= "" then
        GameTooltip:AddLine("|cffffd200" .. tooltipHeader .. "|r")
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
      for _, c in ipairs(changes or {}) do
        GameTooltip:AddLine(string.format("|cffdddddd%s|r", c.slotName or " "))

        -- compute deltas if missing/zero
        ensureDeltas(c)

        local dIlvl   = c.deltaIlvl or 0
        local raw     = computeStatDiff(c.oldLink, c.newLink) or {}
        local values  = c.scaleValues
        local _, wsum = weightDeltas(raw, values)

        -- main line: new link, score, ilvl
        GameTooltip:AddLine(string.format(
          "  %s  |cff7fff7f%+.1f score|r  |cff7fbfff%+d ilvl|r",
          c.newLink or "", c.deltaScore or 0, dIlvl))

        -- pretty-print mapped secondaries, sorted by |delta|
        local rows = {}
        for blizzKey, delta in pairs(raw) do
          local map = STAT_TO_PAWN[blizzKey]
          if map and delta ~= 0 then rows[#rows + 1] = { label = map.label, d = delta } end
        end
        table.sort(rows, function(a, b) return math.abs(a.d) > math.abs(b.d) end)

        for i, row in ipairs(rows) do
          if i > 8 then
            GameTooltip:AddLine("     |cffaaaaaa(…more)|r"); break
          end
          local color = row.d > 0 and "|cff7fff7f" or "|cffff3a3a"
          GameTooltip:AddLine(string.format("     %s%+d %s|r", color, row.d, row.label))
        end

        if wsum and wsum ~= 0 then
          local color = wsum > 0 and "|cff7fff7f" or "|cffff3a3a"
          GameTooltip:AddLine(string.format("     %s%+.1f weighted|r", color, wsum))
        end
      end

      if weaponPlan then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffddddddWeapons|r")
        GameTooltip:AddLine("  " .. weaponPlan.newText) -- no arrow; proposed only
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
