--  	Author: Ryan Hagelstrom
--	  	Copyright © 2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

-- The only way this will ever work is if we are very sure that we keep our
-- tables up to date with the known state of the universe. If they get out of sync
-- then the entire house of cards comes crashing down.

local aEffectAdded = {};
local aEffectUpdatedPrevious = {};
local aEffectUpdatedCurrent = {};
local aEffectDeleted = {};

-- Tag is rEffectComp.type uppercase if exists and ignoring conditional tags else
-- the first clause (element) rEffectComp[1] which is everything before the between the ;
-- The latter is ignored if containing a space.
-- tEffectsCT[Actor CT Node Path][Tags][Effect Node Path]
local tEffectsCT = {}

local tLabelOutstandingLookup = {}
--tEffectsLookup[Effect Node Path][Tags]  -- The Actor is implied as it is the parent of the effect
local tEffectsLookup = {}

-- Global tags to ignore
_aTurboIgnoreTags = {"", "IF", "IFT"}

local function onCustomEffectAdded(nodeEffect)
	for _,fCustomEffectAdded in ipairs(aEffectAdded) do
		fCustomEffectAdded(nodeEffect);
	end
end

local function onCustomEffectUpdatedPrevious(sActor,sTag,sPath)
    if next(aEffectUpdatedPrevious) then
        local sActorCopy = sActor;
        local sEffectCopy = sPath
        local sTagCopy = sTag;
        for _,fCustomEffectUpdatedPrevious in ipairs(aEffectUpdatedPrevious) do
            fCustomEffectUpdatedPrevious(sActorCopy, sTagCopy, sEffectCopy);
        end
    end
end

local function onCustomEffectUpdatedCurrent(sActor,sTag,sPath)
    if next(aEffectUpdatedCurrent) then
        local sActorCopy = sActor;
        local sEffectCopy = sPath
        local sTagCopy = sTag;
        for _,fCustomEffectUpdatedCurrent in ipairs(aEffectUpdatedCurrent) do
            fCustomEffectUpdatedCurrent(sActorCopy, sTagCopy, sEffectCopy);
        end
    end
end

local function onCustomEffectDeleted(nodeEffect)
	for _,fCustomEffectDeleted in ipairs(aEffectDeleted) do
		fCustomEffectDeleted(nodeEffect);
	end
end

local function updateEffectsTables(sActor, sLabel, sPath)
	local tEffectComps = EffectManager.parseEffect(sLabel);
	for _,sComp in pairs(tEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sComp);
		local sTag = rEffectComp.type:upper();
		if sTag == "" and not rEffectComp.original:match("%s") then
			sTag = rEffectComp.original;
		end
		sTag = sTag:upper();
		if not StringManager.contains(_aTurboIgnoreTags,sTag) then
			local aTags = tEffectsCT[sActor];
			if not aTags or not aTags[sTag] then
				tEffectsCT[sActor][sTag] = {};
				tEffectsCT[sActor][sTag][sPath] = true;
			else
				tEffectsCT[sActor][sTag][sPath] = true;
			end
			tEffectsLookup[sPath][sTag] = true;
			onCustomEffectUpdatedCurrent(sActor, sTag, sPath);
		end
	end
end

local function updateRegisteredEffectGuarded(nodeLabel)
	local nodeEffect = DB.getChild(nodeLabel, "..");
	local nodeActor = DB.getChild(nodeEffect, "...");
	local sActor = nodeActor.getPath();
	local sLabel = DB.getValue(nodeEffect, "label", "");
	local sPath = nodeEffect.getPath();

    -- reset what is known about this effect
	if tEffectsLookup[sPath] then
		for sTag,_ in pairs(tEffectsLookup[sPath]) do
			tEffectsCT[sActor][sTag][sPath] = nil;
			if not next(tEffectsCT[sActor][sTag]) then
				tEffectsCT[sActor][sTag] = nil;
			end
            onCustomEffectUpdatedPrevious(sActor, sTag, sPath);
			tEffectsLookup[sPath][sTag] = nil;
		end
	end
	updateEffectsTables(sActor, sLabel, sPath);
end

local function registerEffectGuarded(nodeEffect, nodeChild)
	local nodeLabel = DB.getChild(nodeEffect.getPath() ..".label");

	-- Empty Effect with no label yet
	if not nodeLabel and not nodeChild then
		DB.addHandler(nodeEffect.getPath(), "onChildAdded", registerEffect);
		tLabelOutstandingLookup[nodeEffect.getPath()] = true;
		return;
	elseif not nodeLabel then
		return;
	end
    local sPath = nodeEffect.getPath();
	local sActor = DB.getChild(nodeEffect, "...").getPath();

    DB.removeHandler(sPath, "onChildAdded", registerEffect);
	tLabelOutstandingLookup[sPath] = nil;

	tEffectsLookup[sPath] = {};
	if not tEffectsCT[sActor] then
		tEffectsCT[sActor] = {};
	end

    DB.addHandler(nodeLabel.getPath(), "onUpdate", updateRegisteredEffect);
	DB.addHandler(sPath, "onDelete", unregisterEffect);

    local sLabel = DB.getValue(nodeEffect, "label", "");
	if sLabel == "" then
		return;
	end
	updateEffectsTables(sActor, sLabel, sPath);
    if nodeChild == nodeLabel then
		DB.addHandler(nodeEffect.getPath(), "onChildAdded", registerEffect);
	end
    onCustomEffectAdded(nodeEffect);
end

local function unregisterEffectGuarded(nodeEffect)
	local nodeLabel = DB.getChild(nodeEffect, "label");
	local sPath = nodeEffect.getPath();
	local sActor = DB.getChild(nodeEffect, "...").getPath();
	for sTag,_ in pairs(tEffectsLookup[sPath]) do
		DB.removeHandler(nodeLabel.getPath(), "onUpdate", updateRegisteredEffect);
		DB.removeHandler(sPath, "onDelete", unregisterEffect);
        onCustomEffectDeleted(nodeLabel);
		tEffectsCT[sActor][sTag][sPath] = nil;
		if not next(tEffectsCT[sActor][sTag]) then
			tEffectsCT[sActor][sTag] = nil;
		end
	end
	tEffectsLookup[sPath] = nil;
end

local function initRegisterEffects()
	local ctEntries = CombatManager.getCombatantNodes();
	for _,nodeCT in pairs(ctEntries) do
		for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
			registerEffect(nodeEffect);
		end
	end
end

local function destroyEffects()
	for sPath,_ in pairs(tLabelOutstandingLookup) do
		DB.removeHandler(sPath, "onChildAdded", registerEffect);
		Debug.console("Delete oustanding handler: "  .. sPath);
	end
	for sPath,_ in pairs(tEffectsLookup) do
		local nodeEffect = DB.findNode(sPath)
		unregisterEffectGuarded(nodeEffect);
	end
	tEffectsCT = {};
	tLabelOutstandingLookup = {};
	tEffectsLookup = {};
end

function addCombatEffect(nodeActor, nodeEffect)
	registerEffect(nodeEffect);
end
-- Is this called before the nodes delete? Will have to test
function unregisterCombatant(nodeCT)
	tEffectsCT[nodeCT.getPath()] = nil;
end

function registerEffect(nodeEffect, nodeChild)
    registerEffectGuarded(nodeEffect, nodeChild);
end

function updateRegisteredEffect(nodeLabel)
    updateRegisteredEffectGuarded(nodeLabel);
end

function unregisterEffect(nodeEffect)
    unregisterEffectGuarded(nodeEffect);
end

function setCustomEffectAdded(f)
	table.insert(aEffectAdded, f);
end

function removeCustomEffectAdded(f)
	for kCustomEffectAdded, fCustomEffectUpdated in ipairs(aEffectAdded) do
		if fCustomEffectUpdated == f then
			table.remove(aEffectAdded, kCustomEffectAdded);
		end
	end
end

function setCustomEffectUpdatedPrevious(f)
	table.insert(aEffectUpdatedPrevious, f);
end

function removeCustomEffectUpdatedPrevious(f)
	for kCustomEffectUpdatedPrevious, fCustomEffectUpdatedPrevious in ipairs(aEffectUpdatedPrevious) do
		if fCustomEffectUpdatedPrevious == f then
			table.remove(aEffectUpdatedPrevious, kCustomEffectUpdatedPrevious);
		end
	end
end

function setCustomEffectUpdatedCurrent(f)
	table.insert(aEffectUpdatedCurrent, f);
end

function removeCustomEffectUpdatedCurrent(f)
	for kCustomEffectUpdatedPrevious, fCustomEffectUpdatedPrevious in ipairs(aEffectUpdatedCurrent) do
		if fCustomEffectUpdatedPrevious == f then
			table.remove(aEffectUpdatedCurrent, kCustomEffectUpdatedPrevious);
		end
	end
end

function setCustomEffectDeleted(f)
	table.insert(aEffectDeleted, f);
end

function removeCustomEffectDeleted(f)
	for kCustomEffectDeleted, fCustomEffectDeleted in ipairs(aEffectDeleted) do
		if fCustomEffectDeleted == f then
			table.remove(aEffectDeleted, kCustomEffectDeleted);
		end
	end
end

function toggleTurbo()
	if OptionsManager.isOption("TURBO", "on") then
		initRegisterEffects();
	else
		destroyEffects();
	end
end

function printet()
	Debug.console(tEffectsCT);
end

function printetl()
	Debug.console(tEffectsLookup);
end

-- Keep a table of all the tags on all the actors and the database node path
-- Searching only effects that have the tag that is being searched for is highly
-- probable to match unless filtered by a filter or conditional. Far more efficient
-- than a liner search of everything. In summary returns mostly empty sets or sets
-- with very few elements.
function getMatchedEffects(rActor, sTag)
	local aReturn = {};
	if OptionsManager.isOption("TURBO", "on") then
		local nodeCT = ActorManager.getCTNode(rActor);
		local sActor = nodeCT.getPath();
		local aEffectPaths = {};
		local aTags = tEffectsCT[sActor];
		sTag = sTag:upper();
		if aTags and aTags[sTag] then
			aEffectPaths = tEffectsCT[sActor][sTag];
		end
		for sEffectPath,_ in pairs(aEffectPaths) do
			table.insert(aReturn, DB.findNode(sEffectPath));
		end
	else
		aReturn = DB.getChildren(ActorManager.getCTNode(rActor), "effects");
	end
	return aReturn;
end

function onInit()
	CombatManager.setCustomAddCombatantEffectHandler(addCombatEffect);
	CombatManager.setCustomDeleteCombatantHandler(unregisterCombatant);

	Comm.registerSlashHandler("turbo_et", printet, "Prints out Turbo tEffectsCT table");
	Comm.registerSlashHandler("turbo_etl", printetl, "Prints out Turbo tEffectsLookup table");

	OptionsManager.registerOption2("TURBO", false, "option_header_game",
	"option_Turbo", "option_entry_cycler",
	{ labels = "option_val_off", values = "off",
		baselabel = "option_val_on", baseval = "on", default = "on" });

	OptionsManager.registerCallback("TURBO", toggleTurbo);
end

function onTabletopInit()
    initRegisterEffects();
end

function onClose()
	destroyEffects();
	OptionsManager.unregisterCallback("TURBO", toggleTurbo);
end