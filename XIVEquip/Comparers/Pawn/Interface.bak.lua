-- Pawn.lua — discovery-only (no comparer yet)
-- Enumerates ACTIVE Pawn scales per-character (from SavedVariables) and prints via /xivepawn.
-- Active means: PawnCommon.Scales[*].PerCharacterOptions["<Name>-<Realm>"].Visible == true

local addonName, XIVEquip = ...
XIVEquip = XIVEquip or {}

-- /---------- tiny logger (local chat only) ----------/
local PREFIX = "|cff66ccffXIVEquip|r"
local Log = XIVEquip.Log
local function log(...) Log.Debug(PREFIX, ...) end

-- /---------- character key helpers ----------/

-- returns name and realm (includes spaces)
local function currentCharPieces()
  local name  = UnitName("player") -- just the char name
  local realm = GetRealmName()     -- display realm, includes spaces
  return name, realm
end

-- returns a character Key that matches how Pawn saves Character-Realm in the SV Scales
local function buildCharKey()
  -- If Pawn already built it, reuse (optional but nice)
  if type(_G.PawnPlayerFullName) == "string" and _G.PawnPlayerFullName ~= "" then
    return _G.PawnPlayerFullName
  end
  local name, realm = currentCharPieces()
  if not name or not realm then return nil end
  return name .. "-" .. realm
end

-- true if PerCharacterOptions has a Visible=true entry for THIS character
local function isVisibleForThisChar(pco)
  if type(pco) ~= "table" then return false end
  local charKey = buildCharKey()
  if not charKey then return false end
  local v = pco[charKey]
  return type(v) == "table" and v.Visible == true
end

-- Choose the best active scale for current spec
local function getPlayerClassSpec()
  local _, _, classID = UnitClass("player")
  local specIndex = GetSpecialization() -- 1..4 (this is what Pawn SV uses)
  return classID, specIndex
end

-- /---------- Spec Selection Helpers ---------------------/
-- Normalize for name comparisons (lowercase, strip spaces/punctuation)
local function _norm(s)
  return (tostring(s or ""):lower():gsub("[%s%p]+", ""))
end

-- Does this scale's name "equal" the player's spec name?
local function _nameEqualsSpec(scaleName, specName)
  if not scaleName or not specName then return false end
  local lhs = _norm(scaleName)
  local rhs = _norm(specName)
  -- If the scale uses "Class: Spec", compare only the right side too
  local afterColon = scaleName:match(":%s*(.+)$")
  if afterColon and _norm(afterColon) == rhs then return true end
  return lhs == rhs
end

-- Does this scale's name contain the player's spec name?
local function _nameContainsSpec(scaleName, specName)
  if not scaleName or not specName then return false end
  local s = scaleName:lower()
  local q = specName:lower()
  -- Whole-word contains (loose, but avoids partials like "prot" in "prototype")
  return s:find("%f[%a]" .. q .. "%f[%A]") ~= nil
end

-- /---------- SV readers (authoritative source) ----------/
local function readAllSVScalesFromPawn()
  local Common = rawget(_G, "PawnCommon")
  if type(Common) ~= "table" or type(Common.Scales) ~= "table" then
    return {}
  end
  return Common.Scales
end

-- returns a classification of the SV Scale Record
local function classifyScaleRecord(s, key)
  -- Provider first (authoritative)
  local isProvider = (type(s.Provider) == "string" and s.Provider ~= "")
  -- Extra guard: keys like "\"MrRobot\":PALADIN1"
  if (not isProvider) and type(key) == "string" and key:match('^".-":') then
    isProvider = true
  end
  -- Custom only if NOT provider and has persisted Values
  local hasValues = (not isProvider) and (type(s.Values) == "table")
  local recType   = isProvider and "provider" or (hasValues and "custom" or "unknown")
  local source    = isProvider and "API" or "SV"
  local valueSrc  = source
  return isProvider, hasValues, recType, source, valueSrc
end

-- returns a list of all Scales in a normalized format
local function getAllScales()
  local out = {}
  local Scales = readAllSVScalesFromPawn()
  for key, s in pairs(Scales) do
    if type(s) == "table" then
      local hasValues  = (type(s.Values) == "table")
      local isProvider = (not hasValues) and (type(s.Provider) == "string")
      local name       = s.LocalizedName or s.PrettyName or s.Name or key
      local visible    = isVisibleForThisChar(s.PerCharacterOptions)
      out[#out + 1]    = {
        key         = s.Key or s.Tag or key,
        name        = name,
        type        = hasValues and "custom" or (isProvider and "provider" or "unknown"),
        source      = hasValues and "SV" or (isProvider and "API" or "SV"),
        active      = visible,
        valueSource = hasValues and "SV" or "API",
        values      = hasValues and s.Values or nil,
        class       = s.ClassID or s.Class,
        provider    = s.Provider,
      }
    end
  end
  return out
end

-- returns a list of all *active* scales in a normalied format
local function getActiveScales()
  local all = getAllScales()
  local act = {}
  for _, r in ipairs(all) do
    if r.active then table.insert(act, r) end
  end
  return act
end

-- /========== VALUES SECTION (custom vs provider) ==========/
-- Try a few Pawn API spellings to fetch provider weights, if your build exposes them.
local function tryGetProviderValues(keyOrName)
  local cands = {
    _G.PawnGetScaleValues,
    _G.PawnGetProviderScaleValues,
    (_G.Pawn and _G.Pawn.GetScaleValues),
    (_G.Pawn and _G.Pawn.GetProviderScaleValues),
  }
  for _, fn in ipairs(cands) do
    if type(fn) == "function" then
      local ok, vals = pcall(fn, keyOrName)
      if ok and type(vals) == "table" then
        return vals
      end
    end
  end
  return nil
end

-- TODO: Is this still needed?
-- Utility: find first active entry whose key or name contains `needle` (case-insensitive)
local function findActiveByQuery(q)
  if not q or q == "" then return nil end
  local needle = q:lower()
  local list = getActiveScales()
  for _, r in ipairs(list) do
    local hay = ((r.key or "") .. " " .. (r.name or "")):lower()
    if hay:find(needle, 1, true) then
      return r
    end
  end
  return nil
end

-- Get values table for a normalized scale entry
local function getScaleValuesForEntry(entry)
  if not entry or type(entry) ~= "table" then
    return nil, nil, "bad-arg"
  end
  if entry.type == "custom" and type(entry.values) == "table" then
    return entry.values, "SV", nil
  end
  if entry.type == "provider" then
    local keyOrName = entry.key or entry.name
    local vals = tryGetProviderValues(keyOrName)
    if type(vals) == "table" then return vals, "API", nil end
    return nil, "API", "no-api-values"
  end
  return nil, nil, "unknown-type"
end

-- Minimal stat map for fallback scoring (custom only)
local FALLBACK_STATMAP = {

  ITEM_MOD_ATTACK_POWER            = "AttackPower",
  ITEM_MOD_ATTACK_POWER_SHORT      = "AttackPower",
  ITEM_MIN_DAMAGE                  = "MinDamage",
  ITEM_MAX_DAMAGE                  = "MaxDamage",
  ITEM_MOD_DAMAGE_PER_SECOND       = "Dps",
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Dps",
  ITEM_MOD_STRENGTH                = "Strength",
  ITEM_MOD_AGILITY                 = "Agility",
  ITEM_MOD_INTELLECT               = "Intellect",
  ITEM_MOD_STAMINA                 = "Stamina",
  RESISTANCE0_NAME                 = "Armor",
  ITEM_MOD_ARMOR                   = "Armor",

  ITEM_MOD_STRENGTH_SHORT          = "Strength",
  ITEM_MOD_AGILITY_SHORT           = "Agility",
  ITEM_MOD_INTELLECT_SHORT         = "Intellect",
  ITEM_MOD_STAMINA_SHORT           = "Stamina",
  ITEM_MOD_ARMOR_SHORT             = "Armor",

  ITEM_MOD_CRIT_RATING             = "CritRating",
  ITEM_MOD_HASTE_RATING            = "HasteRating",
  ITEM_MOD_MASTERY_RATING          = "MasteryRating",
  ITEM_MOD_VERSATILITY             = "Versatility",

  ITEM_MOD_CRIT_RATING_SHORT       = "CritRating",
  ITEM_MOD_HASTE_RATING_SHORT      = "HasteRating",
  ITEM_MOD_MASTERY_RATING_SHORT    = "MasteryRating",

  ITEM_MOD_AVOIDANCE_RATING        = "AvoidanceRating",
  ITEM_MOD_SPEED_RATING            = "MovementSpeed",
  ITEM_MOD_LIFESTEAL               = "Leech",

  -- optional, if your scale uses them:
  ITEM_MOD_DODGE_RATING            = "DodgeRating",
  ITEM_MOD_PARRY_RATING            = "ParryRating",

  -- if you want sockets to add value and your scale has a weight:
  EMPTY_SOCKET_PRISMATIC           = "PrismaticSocket",
  EMPTY_SOCKET_PRISMATIC1          = "PrismaticSocket",
}

local GetItemStats = GetItemStats or C_Item.GetItemStats

-- Safe wrapper: returns stats table or nil
local function GetItemStatsCompat(itemLink)
  if type(GetItemStats) == "function" then
    return GetItemStats(itemLink)
  end
  -- (Some clients miss the global; no reliable C_Item variant for links.)
  -- return nil
end

local function fallbackScoreWithValues(itemLink, values)
  if not itemLink then return nil end
  local equipLoc = select(4, GetItemInfoInstant(itemLink))
  local slotID = (XIVEquip.Gear_Core and XIVEquip.Gear_Core.INV_BY_EQUIPLOC
    and XIVEquip.Gear_Core.INV_BY_EQUIPLOC[equipLoc]) or nil
  if _G.XIVEquip_Debug then
    Log.Debugf(slotID,
      "[fallback] weights: Armor=%s Strength=%s Stamina=%s Haste=%s Crit=%s Vers=%s MaxDamage=%s MinDamage=%s Dps=%s Avoid=%s Leech=%s Speed=%s",
      tostring(values and values.Armor),
      tostring(values and values.Strength),
      tostring(values and values.Stamina),
      tostring(values and values.HasteRating),
      tostring(values and values.CritRating),
      tostring(values and values.Versatility),
      tostring(values and values.MaxDamage),
      tostring(values and values.MinDamage),
      tostring(values and values.Dps),
      tostring(values and values.AvoidanceRating),
      tostring(values and values.Leech),
      tostring(values and values.MovementSpeed)
    )
  end
  local stats = GetItemStatsCompat(itemLink)
  if type(stats) ~= "table" then return nil end
  if _G.XIVEquip_Debug then
    Log.Debugf(slotID, "[fallback] " .. tostring(itemLink))
    for k, v in pairs(stats) do
      Log.Debugf(slotID, "key: %s - value: %s", k, v)
      local pawnKey = FALLBACK_STATMAP[k]
      if pawnKey and values[pawnKey] then
        Log.Debugf(slotID, tostring(pawnKey))
        Log.Debugf(slotID, "  + %s %s %s → %s × %s = %s",
          tostring(pawnKey),
          tostring(k), tostring(v), tostring(pawnKey), tostring(values[pawnKey]),
          tostring(v * (values[pawnKey] or 0)))
      else
        Log.Debugf(slotID, "  (ignored) %s %s %s", tostring(pawnKey), tostring(k), tostring(v))
      end
    end
    -- Also handle min/max damage if weighted in the scale
    local minD, maxD = stats.ITEM_MIN_DAMAGE, stats.ITEM_MAX_DAMAGE
    if type(minD) == "number" and values.MinDamage then
      score = score + minD * values.MinDamage
    end
    if type(maxD) == "number" and values.MaxDamage then
      score = score + maxD * values.MaxDamage
    end

    -- DPS (some scales use Dps instead of Min/Max)
    local dps = stats.ITEM_MOD_DAMAGE_PER_SECOND or stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
    if type(dps) == "number" and values.Dps then
      score = score + dps * values.Dps
    end
  end
  local score = 0

  for k, pawnKey in pairs(FALLBACK_STATMAP) do
    local amount = stats[k]
    if type(amount) == "number" and values[pawnKey] then
      score = score + amount * (values[pawnKey] or 0)
    end
  end
  return score
end

-- Prefer: exact id match > exact name match > contains name > class match > any
local function chooseBestActiveScaleForPlayer()
  local _, classFile, classID = UnitClass("player")
  local specIndex             = GetSpecialization() or 0
  local specName              = (specIndex > 0 and select(2, GetSpecializationInfo(specIndex))) or ""

  local act                   = getActiveScales() or {}

  local idExactCustom, idExactAny
  local nameExactCustom, nameExactAny
  local nameHasCustom, nameHasAny
  local classCustom, classAny
  local any

  for _, r in ipairs(act) do
    any            = any or r
    local isCustom = (r.type == "custom")
    local classOK  = (r.class == nil) or (r.class == classID)

    -- 1) Exact class+spec index, if the record actually has it
    if classOK and r.spec and specIndex > 0 and r.spec == specIndex then
      if isCustom then
        idExactCustom = idExactCustom or r
      else
        idExactAny = idExactAny or r
      end
    else
      -- 2) Name-based matching (specname)
      local nm = r.name or r.key
      if _nameEqualsSpec(nm, specName) then
        if isCustom then
          nameExactCustom = nameExactCustom or r
        else
          nameExactAny = nameExactAny or r
        end
      elseif _nameContainsSpec(nm, specName) then
        if isCustom then
          nameHasCustom = nameHasCustom or r
        else
          nameHasAny = nameHasAny or r
        end
      elseif classOK then
        -- 3) class match as a weaker fallback
        if isCustom then
          classCustom = classCustom or r
        else
          classAny = classAny or r
        end
      end
    end
  end

  local picked = idExactCustom or idExactAny
      or nameExactCustom or nameExactAny
      or nameHasCustom or nameHasAny
      or classCustom or classAny
      or any

  -- Optional: one debug line; use "force" to bypass slot filter
  if _G.XIVEquip_Debug and XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
    XIVEquip.Log.Debugf("force",
      "Pawn.choose: class=%s(%s) specIndex=%s specName=%s -> picked name=%s key=%s type=%s src=%s (r.spec=%s)",
      tostring(classID), tostring(classFile), tostring(specIndex), tostring(specName),
      tostring(picked and picked.name), tostring(picked and picked.key),
      tostring(picked and picked.type), tostring(picked and picked.source),
      tostring(picked and picked and picked.spec))
  end

  return picked
end

-- Robustly parse weapon min/max and speed from the tooltip (Retail DF/WotLK+).
-- Returns: minD|maxD|speed (numbers) or nils if not found.
local function GetWeaponDamageAndSpeed(link)
  if not link or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return nil end
  local tip = C_TooltipInfo.GetHyperlink(link)
  if not tip or not tip.lines then return nil end

  local minD, maxD, speed

  local function grab(s)
    if type(s) ~= "string" then return end
    -- "5 - 12 Damage"
    local a, b = s:match("(%d+)%s*%-%s*(%d+)%s+[Dd]amage")
    if a and b then minD, maxD = tonumber(a), tonumber(b) end
    -- "Speed 3.60"
    local sp = s:match("[Ss]peed%s+([%d%.]+)")
    if sp then speed = tonumber(sp) end
  end

  for _, line in ipairs(tip.lines) do
    if line.leftText then grab(line.leftText) end
    if line.rightText then grab(line.rightText) end
  end
  return minD, maxD, speed
end

-- Pretty dump of raw GetItemStats + weighted contributions (fallback path)
local function _dumpItemStatsAndContrib(link, scaleEntry)
  local stats = GetItemStatsCompat(link)
  if type(stats) ~= "table" then
    log("GetItemStats returned no table for link.")
    return
  end

  -- Try to get a values table for the chosen scale
  local values = nil
  if type(scaleEntry) == "table" then
    values = select(1, getScaleValuesForEntry(scaleEntry)) -- may be nil for provider scales
  end

  -- Raw stats first (sorted for stability)
  local keys = {}; for k in pairs(stats) do keys[#keys + 1] = k end
  table.sort(keys)
  log("Raw ItemStats for link:")
  for _, k in ipairs(keys) do
    print(PREFIX, k, "=", tostring(stats[k]))
  end

  -- If we have weights, show what the fallback scorer will add up
  if type(values) == "table" then
    local total = 0
    log("Contributions (fallback scorer):")
    -- mapped stats
    for blizzKey, pawnKey in pairs(FALLBACK_STATMAP) do
      local amt, w = stats[blizzKey], values[pawnKey]
      if type(amt) == "number" and type(w) == "number" then
        local add = amt * w
        total = total + add
        print(PREFIX, string.format("  %s (%s): %s × %s = %s", pawnKey, blizzKey, amt, w, add))
      end
    end
    -- weapon damage/speed from tooltip (preferred)
    local minD, maxD, speed = GetWeaponDamageAndSpeed(link)

    -- If tooltip didn't give min/max, try deriving from DPS + speed
    local dps = stats.ITEM_MOD_DAMAGE_PER_SECOND or stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
    if (not minD or not maxD) and type(dps) == "number" and type(speed) == "number" then
      -- avg = DPS * speed; if weights equal we can split evenly; otherwise use sum as an approximation
      local wMin, wMax = tonumber(values.MinDamage), tonumber(values.MaxDamage)
      if wMin or wMax then
        local avg = dps * speed
        if wMin and wMax then
          -- general approximation: contribution = avg * (wMin + wMax) * 1.0
          -- (exact when wMin==wMax; reasonable otherwise without asymmetry data)
          local add = avg * (wMin + wMax)
          total = total + add
          print(PREFIX, string.format("  (Derived) AvgDamage: %s × (Min+Max weights=%s) = %s",
            avg, (wMin + wMax), add))
        elseif wMin then
          local add = avg * wMin * 2
          total = total + add
          print(PREFIX, string.format("  (Derived) MinDamage: %s × %s × 2 = %s", avg, wMin, add))
        elseif wMax then
          local add = avg * wMax * 2
          total = total + add
          print(PREFIX, string.format("  (Derived) MaxDamage: %s × %s × 2 = %s", avg, wMax, add))
        end
      end
    else
      -- We have explicit min/max; apply normally
      if type(values.MinDamage) == "number" and type(minD) == "number" then
        local add = minD * values.MinDamage; total = total + add
        print(PREFIX, string.format("  MinDamage: %s × %s = %s", minD, values.MinDamage, add))
      end
      if type(values.MaxDamage) == "number" and type(maxD) == "number" then
        local add = maxD * values.MaxDamage; total = total + add
        print(PREFIX, string.format("  MaxDamage: %s × %s = %s", maxD, values.MaxDamage, add))
      end
    end

    -- If your scale also uses Dps directly, still include it
    if type(values.Dps) == "number" and type(dps) == "number" then
      local add = dps * values.Dps; total = total + add
      print(PREFIX, string.format("  Dps: %s × %s = %s", dps, values.Dps, add))
    end

    print(PREFIX, "TOTAL (fallback only) =", total)
  else
    log("No values table for this scale (provider scale or missing values); fallback won’t add contributions.")
  end
end

-- Core scoring helpers
local function scoreItemWithEntry(itemLink, entry)
  if not entry then return nil, "no-scale" end
  local vals = (entry.type == "custom") and entry.values
  if type(vals) == "table" and type(GetItemStatsCompat) == "function" then
    local s = fallbackScoreWithValues(itemLink, vals)
    if type(s) == "number" then return s, "SV-fallback" end
  end

  return nil, "no-scoring-path"
end

local function scoreItemAuto(itemLink)
  local best = chooseBestActiveScaleForPlayer()
  if not best then return nil, "no-active-scale" end
  local v, src = scoreItemWithEntry(itemLink, best)
  return v, src, best
end

local function scoreItemAs(itemLink, query)
  if not query or query == "" then return nil, "no-query" end
  local needle = query:lower()
  local act = getActiveScales()
  local match
  for _, r in ipairs(act) do
    local hay = ((r.key or "") .. " " .. (r.name or "")):lower()
    if hay:find(needle, 1, true) then
      match = r; break
    end
  end
  if not match then return nil, "no-match" end
  local v, src = scoreItemWithEntry(itemLink, match)
  return v, src, match
end

-- Expose to other modules now that we have a stable contract
function XIVEquip.PawnGetActiveScales() return getActiveScales() end

function XIVEquip.PawnGetAllScales() return getAllScales() end

function XIVEquip.PawnGetScaleValues(entry) return getScaleValuesForEntry(entry) end

function XIVEquip.PawnBestActiveScale()
  -- chooseBestActiveScaleForPlayer is the local you already have
  return (chooseBestActiveScaleForPlayer())
end

function XIVEquip.PawnScoreLinkAuto(itemLink)
  -- scoreItemAuto is your local that picks the best active scale
  return scoreItemAuto(itemLink) -- returns value, sourceTag, scaleEntryUsed
end

function XIVEquip.PawnScoreLocationAuto(location)
  -- Accepts an ItemLocation (bags/equipped) or an inventory slot number.
  local link
  if C_Item and C_Item.GetItemLink and location and type(location) == "table" then
    local ok, l = pcall(C_Item.GetItemLink, location)
    if ok then link = l end
  end
  if not link and type(location) == "number" and GetInventoryItemLink then
    local ok, l = pcall(GetInventoryItemLink, "player", location)
    if ok then link = l end
  end
  if not link then return nil, "no-link" end
  return scoreItemAuto(link) -- returns value, sourceTag, scaleEntryUsed
end

-- Returns: valuesTable|nil, sourceTag ("SV"|"API"), errMsg|nil
local function getScaleValuesForEntry(entry)
  if not entry or type(entry) ~= "table" then
    return nil, nil, "bad-arg"
  end
  -- Custom: always from SV
  if entry.type == "custom" and type(entry.values) == "table" then
    return entry.values, "SV", nil
  end
  -- Provider: attempt API lookups
  if entry.type == "provider" then
    local keyOrName = entry.key or entry.name
    local vals = tryGetProviderValues(keyOrName)
    if type(vals) == "table" then
      return vals, "API", nil
    end
    return nil, "API", "no-api-values"
  end
  return nil, nil, "unknown-type"
end

-- /---------- public API (for other modules) ----------/
function XIVEquip.GetActivePawnScales() return getActiveScales() end

function XIVEquip.GetAllPawnScales() return getAllScales() end

function XIVEquip.GetPawnScaleValues(entry) return getScaleValuesForEntry(entry) end

-- Public: returns current spec index/name and the exact scale entry
-- that chooseBestActiveScaleForPlayer() picked (or nil if none).
-- Returns: specIndex (0..4), specName|nil, scaleEntry|nil
function XIVEquip.PawnGetActiveSpec()
  local specIndex  = GetSpecialization() or 0
  local specName   = (specIndex > 0 and select(2, GetSpecializationInfo(specIndex))) or nil
  local scaleEntry = chooseBestActiveScaleForPlayer() -- << consistency anchor
  return specIndex, specName, scaleEntry
end

-- Public: returns just the human-readable spec name used by the current comparer
-- plus (optionally) the chosen scale's display name for UI headers.
-- Returns: specName|nil, scaleDisplayName|nil
function XIVEquip.PawnGetActiveSpecName()
  local _, specName, scaleEntry = XIVEquip.PawnGetActiveSpec()
  local scaleDisplay = scaleEntry and (scaleEntry.name or scaleEntry.key) or nil
  return specName, scaleDisplay
end

-- Convenience: one-line header you can print in tooltips
-- e.g., "Comparer: Pawn  |  Scale: Paladin: Protection (Spec: Protection)"
function XIVEquip.PawnGetActiveTooltipHeader()
  local specName, scaleDisplay = XIVEquip.PawnGetActiveSpecName()
  if scaleDisplay and specName then
    return string.format("Comparer: Pawn  |  Scale: %s (Spec: %s)", scaleDisplay, specName)
  elseif scaleDisplay then
    return string.format("Comparer: Pawn  |  Scale: %s", scaleDisplay)
  elseif specName then
    return string.format("Comparer: Pawn  |  Spec: %s", specName)
  else
    return "Comparer: Pawn"
  end
end

-- /---------- slash command printing helpers ----------/
local function printActive()
  local list = getActiveScales()
  if #list == 0 then
    log("No ACTIVE scales found for this character.")
    return
  end
  for _, r in ipairs(list) do
    print(PREFIX, ("ACTIVE: NAME=%s  TYPE=%s  VALUE_SRC=%s  KEY=%s")
      :format(tostring(r.name), tostring(r.type), tostring(r.valueSource), tostring(r.key)))
  end
end

local function printAll(filter)
  local list = getAllScales()
  local needle = filter and filter:lower() or nil
  local shown = 0
  for _, r in ipairs(list) do
    local line = ("NAME=%s  ACTIVE=%s  TYPE=%s  SRC=%s  PROVIDER=%s  KEY=%s")
        :format(tostring(r.name), r.active and "Y" or "N", tostring(r.type),
          tostring(r.source), tostring(r.provider or ""), tostring(r.key))
    if (not needle) or line:lower():find(needle, 1, true) then
      print(PREFIX, line)
      shown = shown + 1
    end
  end
  if shown == 0 then print(PREFIX, "No scales matched.") end
end

local function printWhoAmI()
  local name, realm = currentCharPieces()
  local charKey = buildCharKey()

  print(PREFIX, "UnitName:", tostring(name))
  print(PREFIX, "GetRealmName:", tostring(realm))
  print(PREFIX, "CharKey:", tostring(charKey or "<nil>"))
end

-- Dump weights for one ACTIVE scale by substring of name or key
local function printDump(rest)
  local q = (rest or ""):match("^%s*(.-)%s*$")
  if q == "" then
    log("Usage: /xivepawn dump <name-or-key-substring>")
    return
  end
  local entry = findActiveByQuery(q)
  if not entry then
    log("No active scale matched:", q)
    return
  end
  local vals, src, err = getScaleValuesForEntry(entry)
  if not vals then
    log(("No weight table available (%s). Will rely on ItemValue at score time."):format(err or "unknown"))
    log(("Matched: NAME=%s TYPE=%s KEY=%s"):format(tostring(entry.name), tostring(entry.type), tostring(entry.key)))
    return
  end
  log(("Weights from %s for %s (KEY=%s):"):format(src or "?", tostring(entry.name), tostring(entry.key)))
  -- pretty-print up to 25 stats, sorted
  local ks = {}
  for k in pairs(vals) do ks[#ks + 1] = k end
  table.sort(ks)
  local shown, limit = 0, 100
  for _, k in ipairs(ks) do
    print(PREFIX, k, "=", tostring(vals[k]))
    shown = shown + 1
    if shown >= limit then
      if #ks > limit then print(PREFIX, "(…truncated)") end
      break
    end
  end
end

local function extractItemLink(text)
  if not text or text == "" then return nil end

  -- 1) full colored hyperlink
  local link = text:match("(|c%x+|Hitem:[^|]+|h[^|]*|h|r)")
  if link then return link end

  -- 2) plain hyperlink (no |c…|r wrapper)
  link = text:match("(|Hitem:[^|]+|h[^|]*|h)")
  if link then return link end

  -- 3) raw itemString (item:…); try to resolve to a proper link
  local itemString = text:match("(item:[^%s|]+)")
  if itemString then
    local _, resolved = GetItemStats(itemString)
    if resolved then return resolved end
  end

  return nil
end

-- escape a string so we can gsub it out safely
local function escape_for_pattern(s)
  return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function printScoreAuto(rest)
  local link = extractItemLink(rest)
  if not link then
    log("Usage: /xivepawn score <itemLink>")
    return
  end
  local v, src, scale = scoreItemAuto(link)
  if not v then
    log(("Could not score item (%s)."):format(src or "unknown"))
    return
  end
  if v and src then
    log(("Score: %.2f  via %s  using %s (KEY=%s)"):format(tonumber(v) or 0, tostring(src),
      tostring(scale and (scale.name or "?") or "?"), tostring(scale and (scale.key or "?") or "?")))
  end
  _dumpItemStatsAndContrib(link, scale) -- keep this; very useful
end

local function printScoreAs(rest)
  local link = extractItemLink(rest)
  if not link then
    log("Usage: /xivepawn scoreas <scale-substring> <itemLink>")
    return
  end
  -- remove the link from the input to leave only the query
  local query = rest:gsub(escape_for_pattern(link), ""):match("^%s*(.-)%s*$")
  if query == "" then
    log("Usage: /xivepawn scoreas <scale-substring> <itemLink>")
    return
  end
  local v, src, scale = scoreItemAs(link, query)
  if not v then
    log(("Could not score item with '%s' (%s)."):format(query, src or "unknown"))
    return
  end
  if v and src then
    log(("Score: %.2f  via %s  using %s (KEY=%s)"):format(tonumber(v) or 0, tostring(src),
      tostring(scale and (scale.name or "?") or "?"), tostring(scale and (scale.key or "?") or "?")))
  end
end

-- /---------- slash ----------/
SLASH_XIVEPAWN1 = "/xivepawn"
SlashCmdList["XIVEPAWN"] = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$")
  local cmd, rest = msg:match("^(%S+)%s*(.*)$"); cmd = cmd and cmd:lower() or ""

  if cmd == "" or cmd == "active" then
    printActive()                        -- default: Active only
  elseif cmd == "scales" then
    printAll(rest ~= "" and rest or nil) -- full list (debug)
  elseif cmd == "whoami" then
    printWhoAmI()                        -- show key candidates
  elseif cmd == "dump" then
    printDump(rest)                      -- show weight table for one active scale
  elseif cmd == "score" then
    printScoreAuto(rest)
  elseif cmd == "scoreas" then
    printScoreAs(rest)
  else
    log("Usage:")
    log("  /xivepawn             — list ACTIVE scales for this character")
    log("  /xivepawn active      — same as default")
    log("  /xivepawn scales [q]  — full list (filter optional)")
    log("  /xivepawn whoami      — show character key candidates used for SV matching")
    log("  /xivepawn stats       — counts")
    log("  /xivepawn dump [q]    - dump values for scale")
    log("  /xivepawn score <link>   — score with best scale for current spec")
    log("  /xivepawn scoreas <q> <link> — score with a specific ACTIVE scale")
  end
end
