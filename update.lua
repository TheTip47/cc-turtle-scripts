-- =========================================================
-- CC: Tweaked - Turtle Repository Auto-Updater (update.lua)
-- Repository: TheTip47/cc-turtle-scripts
-- =========================================================

local baseUrl = "https://raw.githubusercontent.com/TheTip47/cc-turtle-scripts/main/"

local manifest = {
    "dig.lua",
    "tunnel.lua",
    "haul.lua",
    "sorter.lua",
    "update.lua"
}

if not http then
    error("Error: HTTP API is disabled on this server!")
end

print("========================================")
print(" Checking for Turtle Script Updates...")
print("========================================")

for _, filename in ipairs(manifest) do
    local url = baseUrl .. filename
    print("Fetching: " .. filename .. "...")
    
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(filename, "w")
        file.write(content)
        file.close()
        print(" -> Updated successfully.")
    else
        print(" -> FAILED to download " .. filename)
    end
end

print("========================================")
print(" Update Complete!")
print("========================================")
