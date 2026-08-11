-- =========================================================
-- CC: Tweaked - 16x16 Chunk Miner with Telemetry & Persistence (dig.lua)
-- Setup: Place Turtle facing into the chunk.
-- Drop-off Chest: Placed directly behind starting position (0,0,0)
-- Wireless / Ender Modem: Equipped on side for telemetry
-- =========================================================

local args = { ... }
local targetDepth = tonumber(args[1]) or 64

local STATE_FILE = "mining_state.txt"

-- Coordinate & Direction State
-- 0: Forward (+z), 1: Right (+x), 2: Back (-z), 3: Left (-x)
local pos = { x = 0, y = 0, z = 0, facing = 0 }

-- Execution State Trackers
local currentLevel = 1
local currentRow = 1
local currentCol = 1
local currentStatus = "Initializing"

-- Item tracking state
local totalItemsMined = 0
local itemsMined = {}

-- Explicitly find and open Wireless/Ender Modem (ignoring Wired Modems)
local function openWirelessModem()
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "modem" then
            local m = peripheral.wrap(side)
            if m and m.isWireless() then
                rednet.open(side)
                return side
            end
        end
    end
    return nil
end

local activeModemSide = openWirelessModem()

-----------------------------------------------------------
-- Persistence Helper Functions
-----------------------------------------------------------
local function saveState()
    local data = {
        pos = pos,
        level = currentLevel,
        row = currentRow,
        col = currentCol,
        targetDepth = targetDepth,
        totalItemsMined = totalItemsMined,
        itemsMined = itemsMined,
        status = currentStatus
    }
    local f = fs.open(STATE_FILE, "w")
    if f then
        f.write(textutils.serialize(data))
        f.close()
    end
end

local function loadState()
    if fs.exists(STATE_FILE) then
        local f = fs.open(STATE_FILE, "r")
        if f then
            local content = f.readAll()
            f.close()
            local data = textutils.unserialize(content)
            if type(data) == "table" then
                return data
            end
        end
    end
    return nil
end

local function clearState()
    if fs.exists(STATE_FILE) then
        fs.delete(STATE_FILE)
    end
end

-----------------------------------------------------------
-- Inventory Helper
-----------------------------------------------------------
local function getInventorySummary()
    local inv = {}
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail then
            local name = detail.name:match(":(.+)") or detail.name
            inv[name] = (inv[name] or 0) + detail.count
        end
    end
    return inv
end

-----------------------------------------------------------
-- Telemetry Broadcast Helper
-----------------------------------------------------------
local function sendTelemetry(status)
    if status then
        currentStatus = status
    end
    if rednet.isOpen() then
        local payload = {
            id = os.getComputerID(),
            label = os.getComputerLabel() or ("Turtle #" .. os.getComputerID()),
            x = pos.x,
            y = pos.y,
            z = pos.z,
            fuel = turtle.getFuelLevel(),
            items = totalItemsMined,
            inventory = getInventorySummary(),
            deposited = itemsMined,
            status = currentStatus
        }
        rednet.broadcast(payload, "TURTLE_TELEMETRY")
    end
end

-----------------------------------------------------------
-- Movement & Navigation Trackers
-----------------------------------------------------------
local function turnRight()
    turtle.turnRight()
    pos.facing = (pos.facing + 1) % 4
    saveState()
    sendTelemetry()
end

local function turnLeft()
    turtle.turnLeft()
    pos.facing = (pos.facing + 3) % 4
    saveState()
    sendTelemetry()
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
    
    saveState()
    sendTelemetry()
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
    
    saveState()
    sendTelemetry()
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
    
    saveState()
    sendTelemetry()
end

local function goTo(tx, ty, tz)
    -- Vertical alignment first
    while pos.y < ty do moveUp() end
    while pos.y > ty do moveDown() end

    -- Horizontal X alignment
    if pos.x < tx then
        turnTo(1)
        while pos.x < tx do moveForward() end
    elseif pos.x > tx then
        turnTo(3)
        while pos.x > tx do moveForward() end
    end

    -- Depth Z alignment
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
    local prevStatus = currentStatus
    sendTelemetry("Returning Base")
    print("Returning to base chest to dump inventory...")
    
    local savedPos = { x = pos.x, y = pos.y, z = pos.z, facing = pos.facing }
    
    -- Navigate to surface origin (0,0,0)
    goTo(0, 0, 0)
    
    -- Face rear chest (-Z direction / facing = 2)
    turnTo(2)
    sendTelemetry("Dumping Base")
    
    -- Offload inventory slots 1 through 16 into rear chest
    for i = 1, 16 do
        turtle.select(i)
        local detail = turtle.getItemDetail(i)
        if detail then
            local name = detail.name:match(":(.+)") or detail.name
            local initialCount = detail.count
            turtle.drop()
            local remainingCount = turtle.getItemCount(i)
            local dropped = initialCount - remainingCount
            if dropped > 0 then
                itemsMined[name] = (itemsMined[name] or 0) + dropped
                totalItemsMined = totalItemsMined + dropped
            end
        end
    end
    turtle.select(1)
    
    sendTelemetry("Resuming Dig")
    
    -- Return to active digging coordinates
    goTo(savedPos.x, savedPos.y, savedPos.z)
    turnTo(savedPos.facing)

    currentStatus = prevStatus
    saveState()
    sendTelemetry(currentStatus)
end

-----------------------------------------------------------
-- Main Mining Logic & Resume Handler
-----------------------------------------------------------
print("========================================")
print(" 16x16 Chunk Miner with Telemetry")
if activeModemSide then
    print(" Wireless Telemetry: ACTIVE (" .. activeModemSide .. ")")
else
    print(" Wireless Telemetry: INACTIVE (No Modem)")
end

local savedState = loadState()
local startLevel = 1
local startRow = 1
local startCol = 1

if savedState then
    print(" Saved state detected!")
    print(string.format(" Resuming at Layer %d, Row %d, Col %d", savedState.level, savedState.row, savedState.col))
    print(string.format(" Recorded Pos: (%d, %d, %d)", savedState.pos.x, savedState.pos.y, savedState.pos.z))
    
    pos = savedState.pos
    targetDepth = savedState.targetDepth or targetDepth
    totalItemsMined = savedState.totalItemsMined or 0
    itemsMined = savedState.itemsMined or {}
    startLevel = savedState.level or 1
    startRow = savedState.row or 1
    startCol = savedState.col or 1
    sleep(2)
else
    print(string.format(" Starting fresh run (%d layers)", targetDepth))
end
print("========================================")

sendTelemetry("Mining Started")

for level = startLevel, targetDepth do
    currentLevel = level
    currentStatus = string.format("Layer %d/%d", currentLevel, targetDepth)
    sendTelemetry(currentStatus)
    
    -- Move down if starting a new layer
    if not savedState or level > savedState.level then
        moveDown()
    end
    
    local rStart = (savedState and level == savedState.level) and startRow or 1
    for row = rStart, 16 do
        currentRow = row
        local cStart = (savedState and level == savedState.level and row == savedState.row) and startCol or 1
        for col = cStart, 15 do
            currentCol = col
            moveForward()
            currentStatus = string.format("Mining L%d R%d", currentLevel, currentRow)
            saveState()
            if isInventoryFull() then dumpInventory() end
        end
        if currentRow < 16 then
            if currentRow % 2 == 1 then
                turnRight() moveForward() turnRight()
            else
                turnLeft() moveForward() turnLeft()
            end
        end
        startCol = 1
    end
    
    -- Return to starting corner of row
    turnRight()
    for col = 1, 15 do moveForward() end
    turnRight()
    
    dumpInventory()
    startRow = 1
end

clearState()
sendTelemetry("Mining Complete")
print("\n========================================")
print(" Chunk mining complete!")
print("========================================")
