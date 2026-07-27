local WS_URL = "wss://<url_here>"
local INTERVAL_SECONDS = 30
local CHUNK_SIZE = 60000

local me = peripheral.find("meBridge") or peripheral.find("me_bridge") or peripheral.find("advancedPeripherals:me_bridge") or peripheral.find("ae2:interface")

if not me then
    error("No ME Bridge or AE2 interface attached!")
end

local function sendChunked(ws, payload)
    local len = #payload
    if len <= CHUNK_SIZE then
        ws.send(payload)
    else
        local totalChunks = math.ceil(len / CHUNK_SIZE)
        ws.send(textutils.serializeJSON({ type = "start_stream", total = totalChunks }))
        
        for i = 1, len, CHUNK_SIZE do
            local chunk = payload:sub(i, math.min(i + CHUNK_SIZE - 1, len))
            ws.send(textutils.serializeJSON({ type = "chunk", data = chunk }))
        end
        
        ws.send(textutils.serializeJSON({ type = "end_stream" }))
    end
end

print("Connecting to WebSocket server: " .. WS_URL)
local ws, err = http.websocket(WS_URL)

if not ws then
    error("WebSocket connection failed: " .. tostring(err))
end

print("Connected! Pushing snapshots every " .. INTERVAL_SECONDS .. "s...")

while true do
    print("[" .. textutils.formatTime(os.time(), true) .. "] Fetching inventory...")
    local rawItems = me.listItems() or me.getItems() or {}
    local itemList = {}

    for _, item in ipairs(rawItems) do
        local name = item.name or item.id or "unknown"
        local amount = item.count or item.amount or 0
        local displayName = item.displayName or item.label or name

        if amount > 0 then
            table.insert(itemList, {
                name = name,
                displayName = displayName,
                amount = amount
            })
        end
    end

    -- Create full snapshot JSON
    local payload = textutils.serializeJSON({
        type = "full_snapshot",
        items = itemList
    })

    print("Transmitting snapshot (" .. #itemList .. " items, " .. #payload .. " bytes)...")
    
    local success, sendErr = pcall(function()
        sendChunked(ws, payload)
    end)

    if not success then
        print("Send error: " .. tostring(sendErr) .. ". Attempting reconnect...")
        ws.close()
        sleep(2)
        ws = http.websocket(WS_URL)
    end

    sleep(INTERVAL_SECONDS)
end