-- =========================================================
-- CC: Tweaked - 3x4 Tunnel Miner (tunnel.lua)
-- Setup: Place Turtle at bottom-center facing into the tunnel.
-- Drop-off Chest: Placed directly behind starting position (0,0,0)
-- Usage: tunnel [length] (default: 64 blocks)
-- =========================================================

local args = { ... }
local targetLength = tonumber(args[1]) or 64

-- Coordinate & Direction State
-- 0: Forward (+Z), 1: Right (+X), 2: Back (-Z), 3: Left (-X)
local pos = { x = 0, y = 0, z = 0, facing = 0 }

-----------------------------------------------------------
-- Movement & Fuel Functions
-----------------------------------------------------------
local function turnRight()
    turtle.turnRight()
    pos.facing = (pos.facing + 1) % 4
end

local function turnLeft()
    turtle.turnLeft()
    pos.facing = (pos.facing + 3) % 4
end

local function turnTo(targetFacing)
    while pos.facing ~= targetFacing do
        turnRight()
    end
end

local function checkFuel()
    if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < 150 then
        for i = 1, 16 do
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

local function goTo(tx, ty, tz)
    -- Move Y first (vertical alignment)
    while pos.y < ty do moveUp() end
    while pos.y > ty do moveDown() end

    -- Move X next (horizontal alignment)
    if pos.x < tx then
        turnTo(1)
        while pos.x < tx do moveForward() end
    elseif pos.x > tx then
        turnTo(3)
        while pos.x > tx do moveForward() end
    end

    -- Move Z next (depth alignment)
    if pos.z < tz then
        turnTo(0)
        while pos.z < tz do moveForward() end
    elseif pos.z > tz then
        turnTo(2)
        while pos.z > tz do moveForward() end
    end
end

-----------------------------------------------------------
-- Inventory & Chest Management
-----------------------------------------------------------
local function isInventoryFull()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then return false end
    end
    return true
end

local function dumpInventory()
    print("Inventory full. Returning to base chest...")
    local savedPos = { x = pos.x, y = pos.y, z = pos.z, facing = pos.facing }

    -- Navigate back to home position (0,0,0)
    goTo(0, 0, 0)
    
    -- Face rear chest (-Z direction / facing = 2)
    turnTo(2)

    -- Drop all items into chest across all 16 slots
    for i = 1, 16 do
        turtle.select(i)
        if turtle.getItemCount(i) > 0 then
            turtle.drop()
        end
    end
    turtle.select(1)

    -- Return to active digging location
    goTo(savedPos.x, savedPos.y, savedPos.z)
    turnTo(savedPos.facing)
    print("Resuming tunnel mining...")
end

-----------------------------------------------------------
-- Main Mining Logic
-----------------------------------------------------------
print("========================================")
print(string.format(" Starting 3x4 Tunnel Miner (%d blocks)", targetLength))
print(" Setup: Chest placed directly behind start")
print("========================================")

-- 3 wide (-1 to 1), 4 tall (0 to 3) slice pattern
local slicePattern = {
    { x = 0, y = 0 }, { x = 1, y = 0 }, { x = -1, y = 0 },
    { x = -1, y = 1 }, { x = 0, y = 1 }, { x = 1, y = 1 },
    { x = 1, y = 2 }, { x = 0, y = 2 }, { x = -1, y = 2 },
    { x = -1, y = 3 }, { x = 0, y = 3 }, { x = 1, y = 3 }
}

for z = 1, targetLength do
    print(string.format("[Slice %d/%d] Digging 3x4 cross-section...", z, targetLength))
    
    for _, pt in ipairs(slicePattern) do
        goTo(pt.x, pt.y, z)
        if isInventoryFull() then
            dumpInventory()
        end
    end

    -- Return to center bottom of slice before advancing to next Z
    goTo(0, 0, z)
    turnTo(0)
    
    if isInventoryFull() then
        dumpInventory()
    end
end

-- Final return to starting chest upon completion
print("Tunnel mining complete. Returning to base chest...")
goTo(0, 0, 0)
turnTo(2)
for i = 1, 16 do
    turtle.select(i)
    if turtle.getItemCount(i) > 0 then
        turtle.drop()
    end
end
turtle.select(1)
turnTo(0)

print("========================================")
print(" All items deposited! Job finished.")
print("========================================")
