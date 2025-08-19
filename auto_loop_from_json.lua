obs = obslua

-- You need dkjson.lua in the same folder (or OBS's built-in json support if available)
local json = require("dkjson")

local sources = {}
local current_index = 1

-- Load JSON from file
function load_sources_from_json()
    local file = io.open(script_path() .. "source_config.json", "r")
    if not file then
        print("❌ Could not open source_config.json")
        return
    end

    local content = file:read("*all")
    file:close()

    local data, pos, err = json.decode(content)
    if err then
        print("❌ JSON parse error: " .. err)
        return
    end

    if type(data) == "table" then
        sources = data
        print("✅ Sources loaded from JSON")
    end
end

-- Main switching function
function switch_sources()
    if #sources == 0 then return end

    local current_scene = obs.obs_frontend_get_current_scene()
    if current_scene == nil then
        print("❌ No active scene found")
        return
    end

    local scene = obs.obs_scene_from_source(current_scene)
    if scene == nil then
        print("❌ Failed to get scene object")
        obs.obs_source_release(current_scene)
        return
    end

    for i, item in ipairs(sources) do
        local scene_item = obs.obs_scene_find_source(scene, item.name)
        if scene_item ~= nil then
            local visible = (i == current_index)
            obs.obs_sceneitem_set_visible(scene_item, visible)
            print("🔁 " .. item.name .. " visible = " .. tostring(visible))
        else
            print("⚠️ Source not found in scene: " .. item.name)
        end
    end

    obs.obs_source_release(current_scene)

    -- Set up timer for next
    obs.timer_remove(switch_sources)
    local duration = sources[current_index].duration or 60000
    obs.timer_add(switch_sources, duration)

    -- Move to next source
    current_index = current_index + 1
    if current_index > #sources then
        current_index = 1
    end
end

-- When script loads
function script_load(settings)
    load_sources_from_json()
    if #sources > 0 then
        obs.timer_add(switch_sources, sources[1].duration)
        print("✅ Loop started from JSON config")
    else
        print("⚠️ No sources loaded")
    end
end

-- When script unloads
function script_unload()
    obs.timer_remove(switch_sources)
    print("🛑 Timer stopped")
end

-- Description
function script_description()
    return "Loops through multiple scene sources using duration config from JSON file (source_config.json)."
end

