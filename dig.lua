-- =========================================================
-- CC: Tweaked - 16x16 Chunk Miner (dig.lua)
-- Setup: Place Turtle facing into the chunk.
-- Slot 16: Ender Chest (Optional - for on-the-go dumping)
-- Rear Chest: Fallback drop-off behind starting position
-- =========================================================

local args = { ... }
local targetDepth = tonumber(args[1]) or 64

-- Coordinate & Direction State
local pos = { x = 0, y = 0, z = 0, facing = 0 } -- 0: Forward (+z), 1: Right (+x), 2: Back (-z), 3: Left (-x)

-- Wireless Rednet Setup
peripheral.find("modem", rednet.open)

local function sendDashboardUpdate(statusText)
    if rednet.isOpen() then
        local payload = {
            label = os.getComputerLabel() or ("Turtle #" .. os.getComputerID()),
            id = os.getComputerID(),
            x = pos.x,
            y = pos.y,
            z = pos.z,
            fuel = turtle.getFuelLevel(),
            status = statusText
        }
        rednet.broadcast(payload, "TURTLE_TELEMETRY")
    end
end

-----------------------------------------------------------
-- Movement & Location Trackers
-----------------------------------------------------------
local function turnRight()
    turtle.turnRight()
    pos.facing = (pos.facing + 1) % 4
end

local function turnLeft()
    turtle.turnLeft()
    pos.facing = (pos.facing + 3) % 4
end

local function checkFuel()
    if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < 150 then
        for i = 1, 15 do
            turtle.select(i)
            if turtle.refuel(0) then
                turtle.refuel()
            end
        end
        turtle.select(1)
    end
end

local function safeDig()
    local attempts = 0
    while turtle.detect() and attempts < 10 do
        turtle.dig()
        attempts = attempts + 1
        sleep(0.3)
    end
end

local function safeDigDown()
    local attempts = 0
    while turtle.detectDown() and attempts < 10 do
        turtle.digDown()
        attempts = attempts + 1
        sleep(0.3)
    end
end

local function safeDigUp()
    local attempts = 0
    while turtle.detectUp() and attempts < 10 do
        turtle.digUp()
        attempts = attempts + 1
        sleep(0.3)
    end
end

local function moveForward()
    checkFuel()
    safeDig()
    while not turtle.forward() do
        safeDig()
        turtle.attack()
        sleep(0.3)
    end
    if pos.facing == 0 then pos.z = pos.z + 1
    elseif pos.facing == 1 then pos.x = pos.x + 1
    elseif pos.facing == 2 then pos.z = pos.z - 1
    elseif pos.facing == 3 then pos.x = pos.x - 1 end
end

local function moveDown()
    checkFuel()
    safeDigDown()
    while not turtle.down() do
        safeDigDown()
        turtle.attackDown()
        sleep(0.3)
    end
    pos.y = pos.y - 1
end

local function moveUp()
    checkFuel()
    safeDigUp()
    while not turtle.up() do
        safeDigUp()
        turtle.attackUp()
        sleep(0.3)
    end
    pos.y = pos.y + 1
end

-----------------------------------------------------------
-- Inventory & Chest Management
-----------------------------------------------------------
local function isInventoryFull()
    for i = 1, 15 do
        if turtle.getItemCount(i) == 0 then return false end
    end
    return true
end

local function dumpInventory()
    print("Dumping inventory...")
    
    -- Check if Ender Chest is in slot 16
    turtle.select(16)
    local item = turtle.getItemDetail()
    
    if item and item.name:find("ender_chest") then
        -- Mid-run Ender Chest deployment above turtle
        safeDigUp()
        if turtle.placeUp() then
            for i = 1, 15 do
                turtle.select(i)
                turtle.dropUp()
            end
            turtle.select(16)
            safeDigUp() -- Mined back into slot 16
            turtle.select(1)
        end
    else
        -- Fallback: Return to starting chest at (0,0,0)
        local savedPos = { x = pos.x, y = pos.y, z = pos.z, facing = pos.facing }
        
        -- Rise back to surface
        while pos.y < 0 do moveUp() end
        
        -- Navigate back to (0,0)
        while pos.facing ~= 2 do turnRight() end
        while pos.z > 0 do moveForward() end
        while pos.facing ~= 3 do turnRight() end
        while pos.x > 0 do moveForward() end
        
        -- Turn to face rear drop-off chest
        while pos.facing ~= 2 do turnRight() end
        for i = 1, 15 do turtle.select(i) turtle.drop() end
        turtle.select(1)
        
        -- Return to active mining coordinates
        while pos.facing ~= 1 do turnRight() end
        while pos.x < savedPos.x do moveForward() end
        while pos.facing ~= 0 do turnRight() end
        while pos.z < savedPos.z do moveForward() end
        while pos.y > savedPos.y do moveDown() end
        while pos.facing ~= savedPos.facing do turnRight() end
    end
end

-----------------------------------------------------------
-- Main Mining Logic
-----------------------------------------------------------
print("========================================")
print(string.format(" Starting Chunk Miner (%d layers)", targetDepth))
print(" Slot 16: Ender Chest (Optional)")
print(" Rear Chest: Fallback Drop-off")
print("========================================")

for level = 1, targetDepth do
    print(string.format("\n[Layer %d/%d] Mining layer at Y offset %d...", level, targetDepth, pos.y - 1))
    moveDown()
    
    for row = 1, 16 do
        for col = 1, 15 do
            moveForward()
            if isInventoryFull() then dumpInventory() end
        end
        if row < 16 then
            if row % 2 == 1 then
                turnRight() moveForward() turnRight()
            else
                turnLeft() moveForward() turnLeft()
            end
        end
    end
    
    -- Corrected Return: End of Row 16 is at (15, 0) facing -z (2).
    -- Turn right to face -x (3), walk 15 steps back to x=0, turn right to face +z (0).
    turnRight()
    for col = 1, 15 do moveForward() end
    turnRight()
    
    dumpInventory()
end

print("\n========================================")
print(" Chunk mining complete!")
print("========================================")
