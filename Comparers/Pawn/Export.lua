-- Pawn_Comparer.lua — registers the Pawn comparer using helpers from Pawn.lua
local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}
XIVEquip.Comparers = XIVEquip.Comparers or {}
local M = XIVEquip.Comparers
local Log = XIVEquip.Log
local L = (XIVEquip and XIVEquip.L) or {}
local Core = XIVEquip.Gear_Core
local AddonPrefix = L.AddonPrefix or "XIVEquip: "

-- The comparer
M:RegisterComparer("Pawn", {
  Label = "Pawn",

  -- Available if we can list active scales & there is at least one
  IsAvailable = function()
    return XIVEquip.Pawn and type(XIVEquip.Pawn.GetActiveScales) == "function"
        and #((XIVEquip.Pawn.GetActiveScales and XIVEquip.Pawn.GetActiveScales()) or {}) > 0
  end,

  -- Usable for this pass if there’s ≥1 active scale (per-character)
  PrePass = function()
    local list = (XIVEquip.Pawn and type(XIVEquip.Pawn.GetActiveScales) == "function") and
        XIVEquip.Pawn.GetActiveScales() or {}
    return #list > 0
  end,

  -- Score an item by ItemLocation
  ScoreItem = function(location, slotID) -- slot id is passed as a convenience
    local link = Core.linkFromLocation(location)
    if link and XIVEquip.Pawn and type(XIVEquip.Pawn.ScoreItemLink) == "function" then
      local v = select(1, XIVEquip.Pawn.ScoreItemLink(link, slotID))
      return tonumber(v) or 0
    end
    print("Failed to score item in Pawn comparer")
    return 0
  end,

  GetActiveTooltipHeader = function()
    if XIVEquip.Pawn and type(XIVEquip.Pawn.GetTooltipHeader) == "function" then
      return XIVEquip.Pawn.GetTooltipHeader()
    end
    return ""
  end
})
