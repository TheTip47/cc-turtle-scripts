-- =========================================================
-- CC: Tweaked - Exact Route Automated Item Hauler (haul.lua)
-- Setup:
--   Place Turtle at Base Origin (510, 122) facing South (Facing 0).
--   Behind Turtle (North / Facing 2): Functional Storage Controller
--   In Front of Turtle (South / Facing 0): Overflow Storage Chest
-- Axis & Facing Index Mapping:
--   Facing 0 = South (+Z)
--   Facing 1 = East (+X) [turnLeft from South]
--   Facing 2 = North (-Z) [turnRight/Left x2]
--   Facing 3 = West (-X) [turnRight from South]
-- Optimization:
--   Direct movement execution eliminates pre-step delays (safeDig/checkFuel)
--   on clear tunnel blocks, executing uninterrupted 1-tick moves.
-- =========================================================

-- Coordinate & Direction State Tracking
local pos = { x = 510, y = 122, z = 0, facing = 0 }

-- Track if an extra forward step was taken to reach chest
local tookExtraStep = false

-----------------------------------------------------------
-- Movement & Fuel Functions
-----------------------------------------------------------
local function turnRight()
    turtle.turnRight()
    pos.facing = (pos.facing + 3) % 4
end

local function turnLeft()
    turtle.turnLeft()
    pos.facing = (pos.facing + 1) % 4
end

local function checkFuel()
    if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < 100 then
        for i = 1, 16 do
            if turtle.getItemCount(i) > 0 then
                turtle.select(i)
                if turtle.refuel(0) then
                    turtle.refuel()
                    if turtle.getFuelLevel() >= 500 then
                        break
                    end
                end
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
        sleep(0.2)
    end
end

local function safeDigUp()
    local attempts = 0
    while turtle.detectUp() and attempts < 10 do
        turtle.digUp()
        attempts = attempts + 1
        sleep(0.2)
    end
end

local function safeDigDown()
    local attempts = 0
    while turtle.detectDown() and attempts < 10 do
        turtle.digDown()
        attempts = attempts + 1
        sleep(0.2)
    end
end

local function moveForward()
    if not turtle.forward() then
        checkFuel()
        safeDig()
        while not turtle.forward() do
            safeDig()
            turtle.attack()
            sleep(0.2)
        end
    end
    if pos.facing == 0 then
        pos.z = pos.z + 1
    elseif pos.facing == 1 then
        pos.x = pos.x + 1
    elseif pos.facing == 2 then
        pos.z = pos.z - 1
    elseif pos.facing == 3 then
        pos.x = pos.x - 1
    end
end

local function moveBack()
    if not turtle.back() then
        checkFuel()
        while not turtle.back() do
            turnRight()
            turnRight()
            safeDig()
            turtle.attack()
            turnRight()
            turnRight()
            sleep(0.2)
        end
    end
    if pos.facing == 0 then
        pos.z = pos.z - 1
    elseif pos.facing == 1 then
        pos.x = pos.x - 1
    elseif pos.facing == 2 then
        pos.z = pos.z + 1
    elseif pos.facing == 3 then
        pos.x = pos.x + 1
    end
end

local function moveDown()
    if not turtle.down() then
        checkFuel()
        safeDigDown()
        while not turtle.down() do
            safeDigDown()
            turtle.attackDown()
            sleep(0.2)
        end
    end
    pos.y = pos.y - 1
end

local function moveUp()
    if not turtle.up() then
        checkFuel()
        safeDigUp()
        while not turtle.up() do
            safeDigUp()
            turtle.attackUp()
            sleep(0.2)
        end
    end
    pos.y = pos.y + 1
end

-----------------------------------------------------------
-- Chest Inspection Helper
-----------------------------------------------------------
local function isChestInFront()
    local pType = peripheral.getType("front")
    if pType then
        return true
    end
    
    local hasBlock, data = turtle.inspect()
    if hasBlock and type(data) == "table" and data.name then
        local name = data.name:lower()
        if name:find("chest") or name:find("barrel") or name:find("drawer") or name:find("storage") or name:find("shulker") then
            return true
        end
    end
    
    return false
end

-----------------------------------------------------------
-- Route Execution Functions
-----------------------------------------------------------
local function runOutbound()
    print("[Outbound] Navigating to Miner Chest...")
    
    -- Turn Left from South (0) to face East (1 / +X)
    turnLeft()
    
    -- Move forward 67 blocks (X: 510 -> 577)
    for i = 1, 67 do
        moveForward()
    end
    
    -- Move down 9 blocks (Y: 122 -> 113)
    for i = 1, 9 do
        moveDown()
    end
    
    -- Turn Right from East (1) to face South (0 / Miner Chest direction)
    turnRight()
    
    -- Check if chest is directly adjacent or 1 block away
    if not isChestInFront() then
        print("[Outbound] Stepping forward 1 block to reach chest...")
        moveForward()
        tookExtraStep = true
    else
        print("[Outbound] Chest detected directly in front!")
        tookExtraStep = false
    end
end

local function pullFromMinerChest()
    local pulled = false
    print("[Miner Chest] Collecting items...")
    for slot = 1, 16 do
        turtle.select(slot)
        while turtle.suck() do
            pulled = true
            if turtle.getItemCount(slot) == turtle.getItemSpace(slot) then
                break
            end
        end
    end
    turtle.select(1)
    return pulled
end

local function runInbound()
    print("[Inbound] Returning to Base Storage...")
    
    -- If an extra step was taken forward to reach the chest, step back 1 block
    if tookExtraStep then
        print("[Inbound] Stepping back 1 block under shaft...")
        moveBack()
        tookExtraStep = false
    end
    
    -- Move up 9 blocks (Y: 113 -> 122)
    for i = 1, 9 do
        moveUp()
    end
    
    -- Turn Right from South (0) to face West (3 / -X)
    turnRight()
    
    -- Move forward 67 blocks back to X=510 (X: 577 -> 510)
    for i = 1, 67 do
        moveForward()
    end
    
    -- Turn Left from West (3) to face South (0 / Realigned at Base)
    turnLeft()
end

local function offloadAtBase()
    print("[Offloading] Depositing items at Base...")
    
    -- Turn 180 degrees to face Storage Controller behind turtle (North / 2)
    turnRight()
    turnRight()
    
    -- Offload into Functional Storage Controller
    local remainingItems = false
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            turtle.drop()
            if turtle.getItemCount(slot) > 0 then
                remainingItems = true
            end
        end
    end
    
    -- Turn 180 degrees back to face Overflow Chest in front (South / 0)
    turnRight()
    turnRight()
    
    -- Offload unhandled leftover items into Overflow Chest
    if remainingItems then
        print("[Overflow] Offloading unhandled items into Overflow Chest...")
        for slot = 1, 16 do
            turtle.select(slot)
            if turtle.getItemCount(slot) > 0 then
                turtle.drop()
            end
        end
    end
    
    turtle.select(1)
end

-----------------------------------------------------------
-- Main Loop Execution
-----------------------------------------------------------
print("========================================")
print(" Corrected Route Automated Hauler Active")
print(" Base: (510, 122) | Target: (577, 113)")
print(" Behind: Storage Controller | Front: Overflow Chest")
print("========================================")

while true do
    runOutbound()
    
    local itemsCollected = pullFromMinerChest()
    
    runInbound()
    
    offloadAtBase()
    
    if itemsCollected then
        print("[Status] Cycle complete. Resuming immediately...")
    else
        print("[Status] Miner Chest empty. Standing by at Base for 10s...")
        sleep(10)
    end
end
