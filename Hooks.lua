-- Hooks.lua
local addon, XIVEquip = ...
local Hooks = {}
XIVEquip.Hooks = Hooks

-- registry keys can be: "ALL", category string (e.g. "TRINKET"), or slotID (number)
local reg = { ALL = {} }

local function addKey(key)
  if not reg[key] then reg[key] = {} end
  return reg[key]
end

-- fn(ctx) -> overrideCandidate|nil
-- ctx = { slotID, category, equipped = {loc, score, ilvl, link}, candidates = { ... }, chosen, comparer }
function Hooks:Register(key, fn)
  table.insert(addKey(key), fn)
end

function Hooks:Unregister(key, fn)
  local t = reg[key]; if not t then return end
  for i = #t, 1, -1 do if t[i] == fn then table.remove(t, i) end end
end

local function fireList(list, ctx)
  if not list then return nil end
  for _, fn in ipairs(list) do
    local ok, override = pcall(fn, ctx)
    if ok and override then return override end
  end
end

function Hooks:Run(slotID, category, ctx)
  -- Priority: slotID > category > ALL
  return fireList(reg[slotID], ctx)
      or fireList(reg[category], ctx)
      or fireList(reg.ALL, ctx)
end
