--  	Author: Ryan Hagelstrom
--	  	Copyright © 2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals onInit onClose customGetEffects
local getEffects = nil;

function onInit()
    getEffects = ActorManager.getEffects;
    ActorManager.getEffects = customGetEffects;
end

function onClose()
    ActorManager.getEffects = getEffects;
end

function customGetEffects(v)
    local sTag = nil;
    local tCTEffects;

    if v and v.sTag then
        sTag = v.sTag;
    end
    local rActor = ActorManager.resolveActor(v);
    if not rActor then
        return {};
    end
    if sTag then
        tCTEffects = TurboManager.getMatchedEffects(rActor, sTag);
    else
        tCTEffects = ActorManager.getCTEffects(rActor);
    end
    if not rActor.tActiveEffectNodes or (#(rActor.tActiveEffectNodes) == 0) then
        return tCTEffects;
    end
    local tAllEffects = {};
    for _, nodeEffect in ipairs(tCTEffects) do
        table.insert(tAllEffects, nodeEffect);
    end
    for _, nodeActive in ipairs(rActor.tActiveEffectNodes) do
        for _, nodeEffect in ipairs(DB.getChildList(DB.getPath(nodeActive, 'effects'))) do
            table.insert(tAllEffects, nodeEffect);
        end
    end
    return tAllEffects;
end
