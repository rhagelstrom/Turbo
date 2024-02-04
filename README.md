
# Turbo

[![Build FG Extension](https://github.com/rhagelstrom/Turbo/actions/workflows/create-release.yml/badge.svg)](https://github.com/rhagelstrom/Turbo/actions/workflows/create-release.yml) [![Luacheckrc](https://github.com/rhagelstrom/Turbo/actions/workflows/luacheck.yml/badge.svg)](https://github.com/rhagelstrom/Turbo/actions/workflows/luacheck.yml)

**Current Version:** 1.5
**Updated:** 12/10/23

Turbo optimized the performance of the Fantasy Grounds effect processing. It has shown an average performance improvement of **590%** in the 5E ruleset's getEffectsByType function. One may see performance degradation in FG effects processing when:

* Actors in the CT have more than 15 effects active
* CT is overloaded with Actors
* Extensions are loaded which increase the load on the FG effects processing system

Turbo has been adapted to support various rulesets, including 5E, 4E, 3.5E/PFRPG, 2E, PFRPG2, SFRPG, and CoreRPG and can be customized to support additional rulesets. Performance gains in rulesets other than 5E are expected to be similar. While performance gains with Turbo may be mostly imperceptible, any improvement will help reduce the perceivable performance impacts caused by other sources.

A full report on analysis can be viewed [FG Effect Processing Performance Improvements](https://github.com/rhagelstrom/Turbo/raw/main/FG%20Effect%20Processing%20Performance%20Improvements.pdf)

To test if turbo is active in your ruleset, the following slash command can be used:
**/turbo_test**
If the test fails, either there is an extension conflict or Turbo is disabled via the options.

**Note:** Active in ruleset CoreRPG means Turbo is Active for CoreRPG, however if your ruleset uses an alternative effects manager then Turbo is likely idle. There is no way to automatically detect an alternative effects manager.

## Options

| Name| Default | Options | Notes |
|---|---|---|---|
|Game: Combat: Turbo|on|off/on|When on Turbo is enabled. When off will revert to Vanilla FG processing of effects|
