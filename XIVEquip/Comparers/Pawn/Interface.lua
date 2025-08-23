-- Comparers/Pawn/Interface.lua
-- Clean, focused interface between XIVEquip and Pawn scales
local addonName, XIVEquip = ...
XIVEquip = XIVEquip or {}
XIVEquip.Pawn = XIVEquip.Pawn or {}

local Pawn = XIVEquip.Pawn

-- Opt-in debug: enable by setting _G.XIVEquip_Debug = true or XIVEquip_Settings.Debug = true
local function _debugEnabled()
	return (_G.XIVEquip_Debug == true) or ((_G.XIVEquip_Settings and _G.XIVEquip_Settings.Debug) == true)
end

local function logDebug(fmt, ...)
	if not _debugEnabled() then return end
	if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
		XIVEquip.Log.Debugf("force", fmt, ...)
	else
		local ok, msg = pcall(string.format, fmt, ...)
		if ok then print((XIVEquip and XIVEquip.L and XIVEquip.L.AddonPrefix or "XIVEquip: ") .. msg) end
	end
end

-- Small helpers: safe access to Pawn saved scales
local function readAllSVScalesFromPawn()
	local Common = rawget(_G, "PawnCommon")
	if type(Common) ~= "table" or type(Common.Scales) ~= "table" then return {} end
	return Common.Scales
end

-- Character key building & visibility checker
local function currentCharPieces()
	return UnitName("player"), GetRealmName()
end

local function buildCharKey()
	if type(_G.PawnPlayerFullName) == "string" and _G.PawnPlayerFullName ~= "" then
		return _G.PawnPlayerFullName
	end
	local name, realm = currentCharPieces()
	if not name or not realm then return nil end
	return name .. "-" .. realm
end

local function isVisibleForThisChar(pco)
	if type(pco) ~= "table" then return false end
	local charKey = buildCharKey()
	if not charKey then return false end
	local v = pco[charKey]
	return type(v) == "table" and v.Visible == true
end

-- Public: return list of all scales (normalized entries)
function Pawn.GetAllScales()
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
				spec        = s.Spec or s.SpecIndex,
			}
		end
	end
	return out
end

function Pawn.GetActiveScales()
	local all = Pawn.GetAllScales() or {}
	local act = {}
	for _, r in ipairs(all) do if r.active then act[#act + 1] = r end end
	return act
end

-- Try to ask possible Pawn API functions for provider values (if exposed)
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
			if ok and type(vals) == "table" then return vals end
		end
	end
	return nil
end

-- Minimal BlizzKey -> PawnKey map used when scoring an item
local STATMAP = {
	-- primaries
	ITEM_MOD_STRENGTH                = "Strength",
	ITEM_MOD_STRENGTH_SHORT          = "Strength",
	ITEM_MOD_AGILITY                 = "Agility",
	ITEM_MOD_AGILITY_SHORT           = "Agility",
	ITEM_MOD_INTELLECT               = "Intellect",
	ITEM_MOD_INTELLECT_SHORT         = "Intellect",
	ITEM_MOD_STAMINA                 = "Stamina",
	ITEM_MOD_STAMINA_SHORT           = "Stamina",

	-- armor / resistance
	ITEM_MOD_ARMOR                   = "Armor",
	ITEM_MOD_ARMOR_SHORT             = "Armor",
	RESISTANCE0_NAME                 = "Armor",

	-- ratings
	ITEM_MOD_CRIT_RATING             = "CritRating",
	ITEM_MOD_CRIT_RATING_SHORT       = "CritRating",
	ITEM_MOD_HASTE_RATING            = "HasteRating",
	ITEM_MOD_HASTE_RATING_SHORT      = "HasteRating",
	ITEM_MOD_MASTERY_RATING          = "MasteryRating",
	ITEM_MOD_MASTERY_RATING_SHORT    = "MasteryRating",
	ITEM_MOD_VERSATILITY             = "Versatility",
	ITEM_MOD_VERSATILITY_SHORT       = "Versatility",

	-- other ratings
	ITEM_MOD_AVOIDANCE_RATING        = "AvoidanceRating",
	ITEM_MOD_DODGE_RATING            = "DodgeRating",
	ITEM_MOD_PARRY_RATING            = "ParryRating",
	ITEM_MOD_LIFESTEAL               = "Leech",
	ITEM_MOD_SPEED_RATING            = "MovementSpeed",
	ITEM_MOD_SPEED_RATING_SHORT      = "MovementSpeed",

	-- sockets
	EMPTY_SOCKET_PRISMATIC           = "PrismaticSocket",
	EMPTY_SOCKET_PRISMATIC1          = "PrismaticSocket",

	-- weapon damage / dps
	ITEM_MIN_DAMAGE                  = "MinDamage",
	ITEM_MAX_DAMAGE                  = "MaxDamage",
	ITEM_MOD_DAMAGE_PER_SECOND       = "Dps",
	ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Dps",
}

local GetItemStats = GetItemStats or (C_Item and C_Item.GetItemStats)

local function GetItemStatsCompat(itemLink)
	if type(GetItemStats) == "function" then
		return GetItemStats(itemLink)
	end
	return nil
end

-- Parse tooltip to extract min/max damage and speed (Retail DF)
local function GetWeaponDamageAndSpeed(link)
	if not link or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return nil end
	local tip = C_TooltipInfo.GetHyperlink(link)
	if not tip or not tip.lines then return nil end

	local minD, maxD, speed
	local function grab(s)
		if type(s) ~= "string" then return end
		local a, b = s:match("(%d+)%s*%-%s*(%d+)%s+[Dd]amage")
		if a and b then minD, maxD = tonumber(a), tonumber(b) end
		local sp = s:match("[Ss]peed%s+([%d%.]+)")
		if sp then speed = tonumber(sp) end
	end

	for _, line in ipairs(tip.lines) do
		if line.leftText then grab(line.leftText) end
		if line.rightText then grab(line.rightText) end
	end
	return minD, maxD, speed
end

-- Compute a numeric score for an itemLink given a values table

local function computeScoreFromValues(itemLink, values, slot)
	if not itemLink or type(values) ~= "table" then return nil end
	local stats = GetItemStatsCompat(itemLink)
	if type(stats) ~= "table" then return nil end
	local dbgslot = slot or "force"
	if _debugEnabled() then
		local parts = {}
		for k, v in pairs(stats) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
		table.sort(parts)
		if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
			XIVEquip.Log.Debugf(dbgslot, "[score] stats tokens: %s", table.concat(parts, ", "))
		else
			logDebug("[score] stats tokens: %s", table.concat(parts, ", "))
		end
	end
	local score = 0

	-- Debug: print a compact list of common weights if logger available
	if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
		local function tv(k) return tostring(values and values[k]) end
		XIVEquip.Log.Debugf(dbgslot,
			"[score] weights: Armor=%s Strength=%s Stamina=%s Haste=%s Crit=%s Vers=%s MaxDamage=%s MinDamage=%s Dps=%s Avoid=%s Leech=%s Speed=%s",
			tv("Armor"), tv("Strength"), tv("Stamina"), tv("HasteRating"), tv("CritRating"), tv("Versatility"),
			tv("MaxDamage"), tv("MinDamage"), tv("Dps"), tv("AvoidanceRating"), tv("Leech"), tv("MovementSpeed"))
	end

	local total = 0

	-- First: non-damage stats (skip Min/Max/Dps keys)
	for blizzKey, pawnKey in pairs(STATMAP) do
		if pawnKey ~= "MinDamage" and pawnKey ~= "MaxDamage" and pawnKey ~= "Dps" then
			local amt = stats[blizzKey]
			local w = values[pawnKey]
			if type(amt) == "number" and type(w) == "number" then
				local add = amt * w
				total = total + add
				if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
					XIVEquip.Log.Debugf(dbgslot, "[score] %s (%s): %s × %s = %s", tostring(pawnKey), tostring(blizzKey),
						tostring(amt), tostring(w), tostring(add))
				end
			end
		end
	end

	-- Weapon damage handling: prefer Min/Max + speed; if not available, fall back to DPS
	local minW = values and tonumber(values.MinDamage)
	local maxW = values and tonumber(values.MaxDamage)
	local dpsW = values and tonumber(values.Dps)

	local minStat = stats.ITEM_MIN_DAMAGE
	local maxStat = stats.ITEM_MAX_DAMAGE
	local dpsStat = stats.ITEM_MOD_DAMAGE_PER_SECOND or stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or stats.Dps

	-- Try to get tooltip-derived min/max/speed if min/max weights exist but stats lack them
	if (minW or maxW) and (not minStat or not maxStat) then
		local tmin, tmax, tspeed = GetWeaponDamageAndSpeed(itemLink)
		if tmin and tmax then
			minStat = minStat or tmin
			maxStat = maxStat or tmax
			dpsStat = dpsStat or (tspeed and ((tmin + tmax) / 2) / tspeed)
		end
	end

	-- If we have min/max weights, apply them preferentially
	if (minW or maxW) then
		if type(minStat) == "number" and type(minW) == "number" then
			local add = minStat * minW; total = total + add
			if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
				XIVEquip.Log.Debugf(dbgslot, "[score] MinDamage (ITEM_MIN_DAMAGE): %s × %s = %s", tostring(minStat),
					tostring(minW), tostring(add))
			end
		end
		if type(maxStat) == "number" and type(maxW) == "number" then
			local add = maxStat * maxW; total = total + add
			if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
				XIVEquip.Log.Debugf(dbgslot, "[score] MaxDamage (ITEM_MAX_DAMAGE): %s × %s = %s", tostring(maxStat),
					tostring(maxW), tostring(add))
			end
		end
	else
		-- No Min/Max weights: if DPS weight exists, use DPS stat
		if dpsW and type(dpsStat) == "number" then
			local add = dpsStat * dpsW; total = total + add
			if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
				XIVEquip.Log.Debugf(dbgslot, "[score] Dps (ITEM_MOD_DAMAGE_PER_SECOND): %s × %s = %s", tostring(dpsStat),
					tostring(dpsW), tostring(add))
			end
		end
	end

	-- Debug: total
	if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
		XIVEquip.Log.Debugf(dbgslot, "[score] TOTAL (computed) = %s", tostring(total))
	end

	return total
end

-- Score an item when given a scale entry (custom or provider).
-- Returns: value|nil, sourceTag ("SV"|"API"|"no-values"), err|nil
local function scoreItemWithEntry(itemLink, entry, slot)
	if not entry then return nil, "no-scale" end
	-- Custom (values saved in SV)
	if entry.type == "custom" and type(entry.values) == "table" then
		local s = computeScoreFromValues(itemLink, entry.values, slot)
		if type(s) == "number" then return s, "SV", nil end
		return nil, "SV", "no-stats"
	end
	-- Provider: try API values
	if entry.type == "provider" or not entry.values then
		local keyOrName = entry.key or entry.name
		local vals = tryGetProviderValues(keyOrName)
		if type(vals) == "table" then
			local s = computeScoreFromValues(itemLink, vals, slot)
			if type(s) == "number" then return s, "API", nil end
			return nil, "API", "no-stats"
		end
		return nil, "API", "no-api-values"
	end
	return nil, "no-scoring-path"
end

-- Choose a single best active scale for the player's current spec/class.
-- Logic: exact spec name match preferred, then class filter, else first active.
local function chooseBestActiveScaleForPlayer()
	local _, _, classID = UnitClass("player")
	local specIndex = GetSpecialization() or 0
	local specName = (specIndex > 0 and select(2, GetSpecializationInfo(specIndex))) or ""
	local act = Pawn.GetActiveScales() or {}
	if #act == 0 then return nil end
	-- helper normalizer
	local function norm(s) return tostring(s or ""):lower():gsub("[%s%p]+", "") end
	local normSpec = norm(specName)
	local firstByClass
	for _, r in ipairs(act) do
		if (r.class == nil) or (r.class == classID) then
			firstByClass = firstByClass or r
			local rn = norm(r.name or r.key)
			if rn == normSpec then return r end
			if rn:find(normSpec, 1, true) then return r end
		end
	end
	return firstByClass or act[1]
end

-- Public scorer: score by link using the chosen active scale
function Pawn.ScoreItemLink(itemLink, slot)
	if not itemLink then return nil, "no-link" end
	local best = chooseBestActiveScaleForPlayer()
	if not best then return nil, "no-active-scale" end
	-- Debug: chosen scale
	if XIVEquip and XIVEquip.Log and XIVEquip.Log.Debugf then
		-- log choice using provided slot (if any) so lines can be filtered
		local dbgslot = slot or "force"
		XIVEquip.Log.Debugf(dbgslot, "[score] choose: name=%s key=%s type=%s src=%s spec=%s", tostring(best.name),
			tostring(best.key), tostring(best.type), tostring(best.source), tostring(best.spec))
	end
	local v, src, err = scoreItemWithEntry(itemLink, best, slot)
	return v, src or err, best
end

-- Public: simple tooltip header for UI
function Pawn.GetTooltipHeader()
	local specIndex = GetSpecialization() or 0
	local specName = (specIndex > 0 and select(2, GetSpecializationInfo(specIndex))) or nil
	local scaleEntry = chooseBestActiveScaleForPlayer()
	local scaleDisplay = scaleEntry and (scaleEntry.name or scaleEntry.key) or nil
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

-- End of Interface.lua
