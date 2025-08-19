-- Comparers.lua — strict comparer runtime (no ilvl fallback)
local addon, XIVEquip = ...
XIVEquip.Comparers = XIVEquip.Comparers or {}
local M = XIVEquip.Comparers

local Log = (XIVEquip.Log) or { Debug=function() end, Info=function() end, Warn=function() end, Error=function() end }
local L = (XIVEquip and XIVEquip.L) or {}
local AddonPrefix = L.AddonPrefix or "XIVEquip: "

local registry = {}
local activeName = "default"
local runtimeActive = nil
local lastUsedLabel = nil

function M:RegisterComparer(name, def) registry[string.lower(name)] = def end
function M:Get(name) return registry[string.lower(name or "")] end
function M:All() return registry end
function M:GetActiveName() return activeName end
function M:GetActive() return runtimeActive or self:Get(activeName) end
function M:GetLastUsedLabel() return lastUsedLabel end

-- Initialize: honor user setting; "default" = prefer Pawn (strict)
function M:Initialize()
  local s = _G.XIVEquip_Settings or {}
  activeName = s.SelectedComparer or "default"
  if activeName == "default" then
    activeName = "Pawn"  -- strict preference; no implicit ilvl
  end
end

-- Start/End a pass (NO FALLBACK). If PrePass fails, return nil comparer.
function M:StartPass()
  local requested = self:Get(activeName)
  runtimeActive = nil
  lastUsedLabel = nil

  if not requested then
    Log.Warn("Comparer '"..tostring(activeName).."' not registered.")
    return nil
  end

  if requested.IsAvailable and not requested.IsAvailable() then
    Log.Warn("Comparer '"..(requested.Label or activeName).."' unavailable.")
    if _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Login ~= false then
      print(AddonPrefix .. "Comparer '"..(requested.Label or activeName).."' unavailable.")
    end
    return nil
  end

  if requested.PrePass then
    local ok, usable = pcall(requested.PrePass)
    if not ok or usable == false then
      Log.Warn("Comparer '"..(requested.Label or activeName).."' not usable for this pass.")
      if _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Login ~= false then
        print(AddonPrefix .. "Comparer '"..(requested.Label or activeName).."' not usable; no changes.")
      end
      return nil
    end
  end

  runtimeActive = requested
  lastUsedLabel = requested.Label or activeName
  return requested
end

function M:EndPass()
  runtimeActive = nil
end

-- Optional: keep ilvl comparer registered for future use, but it is never auto-selected here.
local function linkFromLocation(location)
  if C_Item and C_Item.GetItemLink and location then
    local ok, link = pcall(C_Item.GetItemLink, location)
    if ok and link then return link end
  end
  return nil
end
local function getItemLevelFromLocation(location)
  if C_Item and C_Item.GetCurrentItemLevel and location then
    local ok, ilvl = pcall(C_Item.GetCurrentItemLevel, location)
    if ok and type(ilvl) == "number" and ilvl > 0 then return ilvl end
  end
  local link = linkFromLocation(location)
  if link and GetDetailedItemLevelInfo then
    local ok, ilvl = pcall(GetDetailedItemLevelInfo, link)
    if ok and type(ilvl) == "number" and ilvl > 0 then return ilvl end
  end
  return 0
end

M:RegisterComparer("ilvl", {
  Label = "Item Level",
  IsAvailable = function() return true end,
  ScoreItem = function(location) return getItemLevelFromLocation(location) end,
})
