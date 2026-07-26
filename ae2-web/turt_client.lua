SERVER_NAME = "ragnamod"
WS_URL = "wss://ae2-ws.s0cks.rocks"

local ws = assert(http.websocket(WS_URL))
print("WebSocket connected.")

local me = assert(peripheral.find("meBridge"), "ME Bridge not found!")


local lastState = {}

local function getInventorySnapshot()
    local rawItems = me.listItems()
    local state = {}
    for _, item in ipairs(rawItems) do

        state[item.name] = {
            displayName = item.displayName,
            amount = item.amount
        }
    end
    return state
end

local function sendFullSnapshot()
    local currentState = getInventorySnapshot()
    lastState = currentState

    local payload = {
        type = "full",
        server = SERVER_NAME,
        items = currentState
    }
    ws.send(textutils.serializeJSON(payload))
    print("Full snapshot sent.")
end

local function sendDeltaUpdate()
    local currentState = getInventorySnapshot()
    local changes = {}
    local hasChanges = false

    for name, data in pairs(currentState) do
        local prev = lastState[name]
        if not prev or prev.amount ~= data.amount then
            changes[name] = {
                displayName = data.displayName,
                amount = data.amount
            }
            hasChanges = true
        end
    end

    for name, prev in pairs(lastState) do
        if not currentState[name] then
            changes[name] = {
                displayName = prev.displayName,
                amount = 0
            }
            hasChanges = true
        end
    end

    if hasChanges then
        local payload = {
            type = "delta",
            server = SERVER_NAME,
            changes = changes
        }
        ws.send(textutils.serializeJSON(payload))
        print("Delta update transmitted!")

        lastState = currentState
    end
end

sendFullSnapshot()

local timer = os.startTimer(2)

while true do
    local event, id = os.pullEvent()

    if event == "timer" and id == timer then
        sendDeltaUpdate()
        timer = os.startTimer(2)

    elseif event == "websocket_message" then
        print("Server msg: " .. id)
    end
end