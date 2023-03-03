--  	Author: Ryan Hagelstrom
--	  	Copyright © 2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local getEffectsByType = nil;
local hasEffect = nil;

function onInit()
    getEffectsByType = EffectManagerPFRPG2.getEffectsByType;
    hasEffect = EffectManagerPFRPG2.hasEffect;

    EffectManagerPFRPG2.getEffectsByType = customGetEffectsByType;
    EffectManagerPFRPG2.hasEffect = customHasEffect;
end

function onClose()
    EffectManagerPFRPG2.getEffectsByType = getEffectsByType;
    EffectManagerPFRPG2.hasEffect = hasEffect;
end
-- Added aTraitFilter for saves and bLeaveOneShots for not removing one shot effects
function customGetEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly, aTraitFilter, bLeaveOneShots)
    if not rActor then
        return {};
    end
    local results = {};

    GlobalDebug.consoleObjects('EffectManager: getEffectsByType.  Starting data - rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly, aTraitFilter',
                               rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly, aTraitFilter);

    -- Special handling for saves.  aFilter could contain the save name and a table of traits.
    local sSaveType = nil;
    local sInitialResult = nil;
    local isBasicSave = false;
    if aFilter then
        if aFilter['save'] and aFilter['save'] ~= '' then
            sSaveType = aFilter['save'];
        end
        if aFilter['initialresult'] and aFilter['initialresult'] ~= '' then
            sInitialResult = aFilter['initialresult'];
        end
        if aFilter['basicsave'] then
            isBasicSave = aFilter['basicsave'];
        end
        if aFilter['traits'] and #aFilter['traits'] > 0 then
            aFilter = aFilter['traits'];
        end
    end
    GlobalDebug.consoleObjects('EffectManager: getEffectsByType.  Done checking for save data.  sSaveType, sInitialResult, aFilter = ', sSaveType,
                               sInitialResult, aFilter);

    -- Set up filters
    local aRangeFilter = {};
    local aOtherFilter = {};
    if aFilter then
        for _, v in pairs(aFilter) do
            if type(v) ~= 'string' then
                table.insert(aOtherFilter, v);
            elseif StringManager.contains(DataCommon.rangetypes, v) then
                table.insert(aRangeFilter, v);
            else
                table.insert(aOtherFilter, v);
            end
        end
    end

    -- Determine effect type targeting
    local bTargetSupport = StringManager.isWord(sEffectType, DataCommon.targetableeffectcomps);

    -- Iterate through effects
    local aEffectsDBNodes = TurboManager.getMatchedEffects(rActor, sEffectType);

    local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);

    --	local aEffectsDBNodes = DB.getChildren(ActorManager.getCTNode(rActor), "effects");
    --	GlobalDebug.consoleObjects("EffectManager: getEffectsByType. sActorType, nodeActor = ", sActorType, nodeActor);
    --	if sActorType == "pc" then
    --		GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  Effects node children = ", DB.getChildren(nodeActor, "effects"));
    --		for _,vCharEffectNode in pairs(DB.getChildren(nodeActor, "effects")) do
    --			table.insert(aEffectsDBNodes, vCharEffectNode);
    --		end
    --		if (rActor.nodeActionEffects or "") ~= "" then
    --			local nodeActionEffects = DB.findNode(rActor.nodeActionEffects);
    --			if nodeActionEffects then
    --				for _,vActionEffectNode in pairs(DB.getChildren(nodeActionEffects)) do
    --					table.insert(aEffectsDBNodes, vActionEffectNode);
    --				end
    --			end
    --		end
    --	end

    GlobalDebug.consoleObjects('EffectManager: getEffectsByType.  About to parse through all effects.  aEffectsDBNodes = ', aEffectsDBNodes);

    --	for _,v in pairs(DB.getChildren(ActorManager.getCTNode(rActor), "effects")) do
    for _, v in pairs(aEffectsDBNodes) do
        -- Check active
        local nActive = DB.getValue(v, 'isactive', 0);
        if (nActive ~= 0) then
            -- Check targeting
            local bTargeted = EffectManager.isTargetedEffect(v);
            if not bTargeted or EffectManager.isEffectTarget(v, rFilterActor) then
                local sLabel = DB.getValue(v, 'label', '');
                local aEffectComps = EffectManager.parseEffect(sLabel);

                -- getEffectsWithVariables no longer needed as character effects with variabes are pushed via the character sheet to the CT.
                --				GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  Before getEffectsWithVariables - aEffectComps = ", aEffectComps);
                --				aEffectComps = AutomationManagerPFRPG2.getEffectsWithVariables(nodeActor, aEffectComps);
                --				GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  After getEffectsWithVariables - aEffectComps = ", aEffectComps);

                -- Look for type/subtype match
                local nMatch = 0;
                for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                    local rEffectComp = EffectManagerPFRPG2.parseEffectComp(sEffectComp);
                    -- GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  Effect components - sEffectComp, rEffectComp = ", sEffectComp, rEffectComp);
                    -- Handle conditionals
                    if rEffectComp.type == 'IF' then
                        if not EffectManagerPFRPG2.checkConditional(rActor, v, rEffectComp.remainder) then
                            break
                        end
                    elseif rEffectComp.type == 'IFT' then
                        GlobalDebug.consoleObjects('EffectManager: getEffectsByType. Have an IFT effect.  rEffectComp = ', rEffectComp);
                        if not rFilterActor then
                            break
                        end
                        GlobalDebug.consoleObjects(
                            'EffectManager: getEffectsByType.  About to check conditional.  rFilterActor, v, rEffectComp.remainder, rActor = ', rFilterActor, v,
                            rEffectComp.remainder, rActor);
                        if not EffectManagerPFRPG2.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
                            break
                        end
                        bTargeted = true;

                        -- Compare other attributes
                    else
                        -- Strip energy/bonus types for subtype comparison
                        local aEffectRangeFilter = {};
                        local aEffectOtherFilter = {};

                        local aComponents = {};
                        for _, vPhrase in ipairs(rEffectComp.remainder) do
                            local nTempIndexOR = 0;
                            local aPhraseOR = {};
                            -- PFRPG2 - change "all magic" to just magic. Some creatures have conditional saves vs all magic.
                            if vPhrase:lower() == 'all magic' then
                                vPhrase = 'magic';
                            end
                            repeat
                                local nStartOR, nEndOR = vPhrase:find('%s+or%s+', nTempIndexOR);
                                if nStartOR then
                                    table.insert(aPhraseOR, vPhrase:sub(nTempIndexOR, nStartOR - nTempIndexOR));
                                    nTempIndexOR = nEndOR;
                                else
                                    table.insert(aPhraseOR, vPhrase:sub(nTempIndexOR));
                                end
                            until nStartOR == nil;

                            for _, vPhraseOR in ipairs(aPhraseOR) do
                                local nTempIndexAND = 0;
                                repeat
                                    local nStartAND, nEndAND = vPhraseOR:find('%s+and%s+', nTempIndexAND);
                                    if nStartAND then
                                        local sInsert = StringManager.trim(vPhraseOR:sub(nTempIndexAND, nStartAND - nTempIndexAND));
                                        table.insert(aComponents, sInsert);
                                        nTempIndexAND = nEndAND;
                                    else
                                        local sInsert = StringManager.trim(vPhraseOR:sub(nTempIndexAND));
                                        table.insert(aComponents, sInsert);
                                    end
                                until nStartAND == nil;
                            end
                        end
                        GlobalDebug.consoleObjects('EffectManager: getEffectsByType.  Filtering effect type components.  aComponents = ', aComponents);
                        local j = 1;
                        while aComponents[j] do
                            -- Process damage types that overcome the effect type - begin with a !
                            -- Remove from the filter components any individual matching clauses - e.g. save name, save result, basic save type, damage type, etc..
                            local sDamageTypeName = string.gsub(aComponents[j], '!', '');
                            if (rEffectComp.type ~= 'SAVE' and rEffectComp.type ~= 'SAVERESULT') and
                                (StringManager.contains(DataCommon.dmgtypes, sDamageTypeName) or StringManager.contains(DataCommon.bonustypes, aComponents[j]) or
                                    aComponents[j] == 'all') then
                                -- Skip
                            elseif (rEffectComp.type == 'SAVE' or rEffectComp.type == 'SAVERESULT' or rEffectComp.type == 'SAVEDAMAGEPER') and
                                (sSaveType == aComponents[j] or sInitialResult == aComponents[j] or
                                    StringManager.contains(DataCommon.bonustypes, aComponents[j]) or aComponents[j] == 'all' or
                                    (isBasicSave and aComponents[j] == 'basic')) then
                                -- Skip - testing save or SAVERESULT effect descriptors
                            elseif (rEffectComp.type == 'PCROLL') then
                                -- Skip filtering of PCROLL effects - we want to return all PCROLL effects.
                            elseif StringManager.contains(DataCommon.rangetypes, aComponents[j]) then
                                table.insert(aEffectRangeFilter, aComponents[j]);
                            else
                                table.insert(aEffectOtherFilter, aComponents[j]);
                            end

                            j = j + 1;
                        end

                        -- Do additional check for save types in aEffectOtherFilter - this means we have not matched an effect to the save type - we should not process any filters.
                        local bProcessFilters = true;
                        if rEffectComp.type == 'SAVE' or rEffectComp.type == 'SAVERESULT' or rEffectComp.type == 'SAVEDAMAGEPER' then
                            for _, sFilterString in pairs(aEffectOtherFilter) do
                                if StringManager.contains(DataCommon.savetypes, sFilterString) then
                                    -- We have a save type in the filter - means we should not process this effect as it hasn't matched the save type.
                                    bProcessFilters = false;
                                    break
                                end
                            end
                        end

                        -- Do additional check for result level in aEffectOtherFilter - this means we have not matched the initial result level to the effect result level - we should not process any filters.
                        if rEffectComp.type == 'SAVERESULT' or rEffectComp.type == 'SAVEDAMAGEPER' then
                            for _, sFilterString in pairs(aEffectOtherFilter) do
                                if StringManager.contains(DataCommon.checkresultlevels, sFilterString) or sFilterString == 'basic' then
                                    -- We have either a result level in the filter, or a basic save tag - means we should not process this effect as it hasn't matched the result level or is not a basic save.
                                    bProcessFilters = false;
                                    break
                                end
                            end
                        end

                        -- Check for match
                        GlobalDebug.consoleObjects(
                            'EffectManager: getEffectsByType.  Effect components - checking for match. bProcessFilters, bTargetedOnly, bTargeted, rEffectComp, aEffectRangeFilter, aEffectOtherFilter = ',
                            bProcessFilters, bTargetedOnly, bTargeted, rEffectComp, aEffectRangeFilter, aEffectOtherFilter);
                        local comp_match = false;
                        if rEffectComp.type == sEffectType and bProcessFilters then

                            -- Check effect targeting
                            if bTargetedOnly and not bTargeted then
                                comp_match = false;
                            else
                                comp_match = true;
                            end

                            -- Check filters
                            if #aEffectRangeFilter > 0 then
                                local bRangeMatch = false;
                                for _, v2 in pairs(aRangeFilter) do
                                    if StringManager.contains(aEffectRangeFilter, v2) then
                                        bRangeMatch = true;
                                        break
                                    end
                                end
                                if not bRangeMatch then
                                    comp_match = false;
                                end
                            end
                            if #aEffectOtherFilter > 0 then
                                local bOtherMatch = false;
                                for _, v2 in pairs(aOtherFilter) do
                                    if type(v2) == 'table' then
                                        local bOtherTableMatch = true;
                                        for k3, v3 in pairs(v2) do
                                            if not StringManager.contains(aEffectOtherFilter, v3) then
                                                bOtherTableMatch = false;
                                                break
                                            end
                                        end
                                        if bOtherTableMatch then
                                            bOtherMatch = true;
                                            break
                                        end
                                    elseif StringManager.contains(aEffectOtherFilter, v2) then
                                        bOtherMatch = true;
                                        break
                                    end
                                end
                                if not bOtherMatch then
                                    comp_match = false;
                                end
                            end
                        end

                        -- *** no longer needed.  If I'd realised a way to work it into the framework to start with, it would have been much easier! ***
                        -- At this point we should have a matched or unmatched effect based off damagetype, bonustype, range and another filter (e.g. save type).
                        -- Do a final filter if aTraitFilter exists.
                        -- Currently only for saves.
                        --						if comp_match and rEffectComp.type == "SAVE" then
                        --							GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  We have a saving throw - checking for effect descriptors that don't match with a bonus or save type.  These might be a trait descriptor.  aTraitFilter, rEffectComp.remainder = ", aTraitFilter, rEffectComp.remainder);
                        --							local temp_match = true;
                        --							for _,sEffectDescriptor in ipairs(rEffectComp.remainder) do
                        --								GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  Checking sEffectDescriptor for bonus or save type.  sEffectDescriptor = ", sEffectDescriptor);
                        --								if StringManager.contains(DataCommon.bonustypes, sEffectDescriptor) or StringManager.contains(DataCommon.savetypes, sEffectDescriptor) or sEffectDescriptor == "all" then
                        --									-- Skip - we have a valid bonus type or save name - already processed earlier.
                        --									GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  Matched to a bonus type or save name or all.  Skipping...");
                        --								else
                        --									-- We have at least one descriptor that isn't a bonus type or save name.  We now need to have a match.
                        --									GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  We have at least one unassigned effect descriptor - assume this is a trait to match against.");
                        --									temp_match = false;
                        --									if aTraitFilter then
                        --										if StringManager.contains(aTraitFilter, sEffectDescriptor) then
                        --											temp_match = true;
                        --											break;
                        --										end
                        --									end
                        --								end
                        --							end
                        --							comp_match = temp_match;
                        --							GlobalDebug.consoleObjects("EffectManager: getEffectsByType.  Exiting trait filter check.  comp_match = ", comp_match);
                        --						end

                        -- Match!
                        if comp_match then
                            nMatch = kEffectComp;
                            if nActive == 1 then
                                table.insert(results, rEffectComp);
                            end
                        end
                    end
                end -- END EFFECT COMPONENT LOOP

                -- Remove one shot effects - only if bLeaveOneShots is false
                if nMatch > 0 and not bLeaveOneShots then
                    GlobalDebug.consoleString('EffectManager: getEffectsByType.  Removing one shot effects.');
                    if nActive == 2 then
                        DB.setValue(v, 'isactive', 'number', 1);
                    else
                        local sApply = DB.getValue(v, 'apply', '');
                        if sApply == 'action' then
                            EffectManager.notifyExpire(v, 0);
                        elseif sApply == 'roll' then
                            EffectManager.notifyExpire(v, 0, true);
                        elseif sApply == 'single' then
                            EffectManager.notifyExpire(v, nMatch, true);
                        end
                    end
                end
            end -- END TARGET CHECK
        end -- END ACTIVE CHECK
    end -- END EFFECT LOOP

    GlobalDebug.consoleObjects('EffectManager: getEffectsByType.  Returning - results = ', results);

    return results;
end

function customHasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
    GlobalDebug.consoleObjects('EffectManager: hasEffect. rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets = ', rActor, sEffect, rTarget,
                               bTargetedOnly, bIgnoreEffectTargets);
    if not sEffect or not rActor then
        return false;
    end
    local sLowerEffect = sEffect:lower();

    -- Iterate through each effect
    local aEffectsDBNodes = TurboManager.getMatchedEffects(rActor, sEffect);

    local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);

    --	local aEffectsDBNodes = DB.getChildren(ActorManager.getCTNode(rActor), "effects");
    --	GlobalDebug.consoleObjects("EffectManager: hasEffect. sActorType, nodeActor = ", sActorType, nodeActor);
    --	if sActorType == "pc" then
    --		GlobalDebug.consoleObjects("EffectManager: hasEffect.  Effects node children = ", DB.getChildren(nodeActor, "effects"));
    --		for _,vCharEffectNode in pairs(DB.getChildren(nodeActor, "effects")) do
    --			table.insert(aEffectsDBNodes, vCharEffectNode);
    --		end
    --		if (rActor.nodeActionEffects or "") ~= "" then
    --			local nodeActionEffects = DB.findNode(rActor.nodeActionEffects);
    --			if nodeActionEffects then
    --				for _,vActionEffectNode in pairs(DB.getChildren(nodeActionEffects)) do
    --					table.insert(aEffectsDBNodes, vActionEffectNode);
    --				end
    --			end
    --		end
    --	end

    GlobalDebug.consoleObjects('EffectManager: hasEffect.  About to parse through all effects.  aEffectsDBNodes = ', aEffectsDBNodes);

    local aMatch = {};
    for _, v in pairs(aEffectsDBNodes) do
        local nActive = DB.getValue(v, 'isactive', 0);
        if nActive ~= 0 then
            -- Parse each effect label
            local sLabel = DB.getValue(v, 'label', '');
            local bTargeted = EffectManager.isTargetedEffect(v);
            local aEffectComps = EffectManager.parseEffect(sLabel);

            aEffectComps = AutomationManagerPFRPG2.getEffectsWithVariables(nodeActor, aEffectComps);

            -- Iterate through each effect component looking for a type match
            local nMatch = 0;
            for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                local rEffectComp = EffectManagerPFRPG2.parseEffectComp(sEffectComp);
                GlobalDebug.consoleObjects('EffectManager: hasEffect.  Looking for a match - rEffectComp = ', rEffectComp);
                -- Check conditionals
                if rEffectComp.type == 'IF' then
                    if not EffectManagerPFRPG2.checkConditional(rActor, v, rEffectComp.remainder) then
                        break
                    end
                elseif rEffectComp.type == 'IFT' then
                    GlobalDebug.consoleObjects('EffectManager: hasEffect. Have an IFT effect.  rEffectComp = ', rEffectComp);
                    if not rTarget then
                        break
                    end
                    if not EffectManagerPFRPG2.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
                        break
                    end

                    -- Check for match
                elseif rEffectComp.original:lower() == sLowerEffect then
                    if bTargeted and not bIgnoreEffectTargets then
                        if EffectManager.isEffectTarget(v, rTarget) then
                            nMatch = kEffectComp;
                        end
                    elseif not bTargetedOnly then
                        nMatch = kEffectComp;
                    end
                end

            end

            -- If matched, then remove one-off effects
            if nMatch > 0 then
                if nActive == 2 then
                    DB.setValue(v, 'isactive', 'number', 1);
                else
                    table.insert(aMatch, v);
                    local sApply = DB.getValue(v, 'apply', '');
                    if sApply == 'action' then
                        EffectManager.notifyExpire(v, 0);
                    elseif sApply == 'roll' then
                        EffectManager.notifyExpire(v, 0, true);
                    elseif sApply == 'single' then
                        EffectManager.notifyExpire(v, nMatch, true);
                    end
                end
            end
        end
    end

    if #aMatch > 0 then
        return true;
    end
    return false;
end
