-- Pawn_Comparer.lua — registers the Pawn comparer using helpers from Pawn.lua
local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}
XIVEquip.Comparers = XIVEquip.Comparers or {}
local M = XIVEquip.Comparers
local Log = XIVEquip.Log
local L = (XIVEquip and XIVEquip.L) or {}
local AddonPrefix = L.AddonPrefix or "XIVEquip: "

-- Small helpers
local function linkFromLocation(location)
  if C_Item and C_Item.GetItemLink and type(location)=="table" then
    local ok, link = pcall(C_Item.GetItemLink, location)
    if ok and link then return link end
  end
  if type(location)=="number" and GetInventoryItemLink then
    local ok, link = pcall(GetInventoryItemLink, "player", location)
    if ok and link then return link end
  end
  return nil
end

-- The comparer
M:RegisterComparer("Pawn", {
  Label = "Pawn",

  -- Available if we can list active scales & there is at least one
  IsAvailable = function()
    return type(XIVEquip.GetActivePawnScales) == "function"
       and #(XIVEquip.GetActivePawnScales() or {}) > 0
  end,

  -- Usable for this pass if there’s ≥1 active scale (per-character)
  PrePass = function()
    local list = (type(XIVEquip.GetActivePawnScales) == "function") and XIVEquip.GetActivePawnScales() or {}
    return #list > 0
  end,

  -- Score an item by ItemLocation or slot id
  ScoreItem = function(location)
    -- Prefer the helper if exported
    if type(XIVEquip.PawnScoreLocationAuto) == "function" then
      local v = select(1, XIVEquip.PawnScoreLocationAuto(location))
      return tonumber(v) or 0
    end
    -- Fallback: get link and use link-based helper
    local link = linkFromLocation(location)
    if link and type(XIVEquip.PawnScoreLinkAuto) == "function" then
      local v = select(1, XIVEquip.PawnScoreLinkAuto(link))
      return tonumber(v) or 0
    end
    return 0
  end,

  GetActiveTooltipHeader = function()
    return XIVEquip.PawnGetActiveTooltipHeader()
  end,

  -- Optional: richer debug info (value, source, scale used)
  DebugScore = function(location)
    if type(XIVEquip.PawnScoreLocationAuto) == "function" then
      return XIVEquip.PawnScoreLocationAuto(location)  -- v, src, scaleEntry
    end
    local link = linkFromLocation(location)
    if link and type(XIVEquip.PawnScoreLinkAuto) == "function" then
      return XIVEquip.PawnScoreLinkAuto(link)
    end
    return nil, "no-link"
  end,
})
