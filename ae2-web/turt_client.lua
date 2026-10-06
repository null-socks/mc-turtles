local WS_URL = "wss://<url_here>"

local INTERVAL_SECONDS = 30
local CHUNK_SIZE = 60000

local me = peripheral.find("meBridge") or peripheral.find("me_bridge") or peripheral.find("advancedPeripherals:me_bridge") or peripheral.find("ae2:interface")

if not me then
    error("No ME Bridge or AE2 interface attached!")
end

local function connectWebSocket()
    while true do
        print("Connecting to WebSocket...")
        local ws, err = http.websocket(WS_URL)
        if ws then
            print("Connected successfully!")
            return ws
        end
        print("Connection failed (" .. tostring(err) .. "). Retrying in 5s...")
        sleep(5)
    end
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

local ws = connectWebSocket()

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
        -- Only close if ws is a valid object
        if ws and type(ws) == "table" and ws.close then
            pcall(function() ws.close() end)
        end

        ws = connectWebSocket()
    end

    sleep(INTERVAL_SECONDS)
end