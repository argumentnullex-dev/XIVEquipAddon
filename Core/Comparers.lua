-- Core/Comparers.lua — strict comparer runtime (no ilvl fallback/registration here)
local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}
XIVEquip.Comparers = XIVEquip.Comparers or {}
local M = XIVEquip.Comparers

---@type Logger
local Log = (XIVEquip.Log) or
{ Debug = function(...) end, Info = function(...) end, Warn = function(...) end, Error = function(...) end }
local L = (XIVEquip and XIVEquip.L) or {}
local AddonPrefix = L.AddonPrefix or "XIVEquip: "

-- Internal registry and state
local registry = {}
local activeName = "default"
local runtimeActive = nil
local lastUsedLabel = nil

function M:RegisterComparer(name, def)
  registry[string.lower(name)] = def
end

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
    activeName = "Pawn" -- strict preference; we do not implicitly swap to ilvl here
  end
end

-- Start/End a pass (NO implicit fallback). If PrePass fails, return nil comparer.
function M:StartPass()
  local requested = self:Get(activeName)
  runtimeActive = nil
  lastUsedLabel = nil

  if not requested then
    Log.Warn("Comparer '" .. tostring(activeName) .. "' not registered.")
    return nil
  end

  if requested.IsAvailable and not requested.IsAvailable() then
    Log.Warn("Comparer '" .. (requested.Label or activeName) .. "' unavailable.")
    if _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Login ~= false then
      print(AddonPrefix .. "Comparer '" .. (requested.Label or activeName) .. "' unavailable.")
    end
    return nil
  end

  if requested.PrePass then
    local ok, usable = pcall(requested.PrePass)
    if not ok or usable == false then
      Log.Warn("Comparer '" .. (requested.Label or activeName) .. "' not usable for this pass.")
      if _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Login ~= false then
        print(AddonPrefix .. "Comparer '" .. (requested.Label or activeName) .. "' not usable; no changes.")
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
