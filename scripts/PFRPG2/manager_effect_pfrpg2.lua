--  	Author: Ryan Hagelstrom
--	  	Copyright © 2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals onInit onClose customGetEffectsByType customHasEffect
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

function customGetEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly, aTraitFilter, bLeaveOneShots)
    if not rActor then
        return {};
    end
    rActor.sTag = sEffectType;
    local tResults = getEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly, aTraitFilter, bLeaveOneShots);
    rActor.sTag = nil;

    return tResults;
end

function customHasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
    if rActor then
        rActor.sTag = sEffect;
    end
    local bReturn = hasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets);
    if rActor and rActor.sTag then
        rActor.sTag = nil;
    end

    return bReturn;
end
