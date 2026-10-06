const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');

const PORT = 6767;
const JSON_PATH = path.join(__dirname, 'items.json');

const wss = new WebSocket.Server({ port: PORT });
console.log(`WebSocket server running on port ${PORT}`);

let chunkBuffer = "";

function processAndSaveItems(jsonString) {
    try {
        const parsed = JSON.parse(jsonString);
        
        let rawItems = [];
        if (Array.isArray(parsed)) {
            rawItems = parsed;
        } else if (parsed.items && Array.isArray(parsed.items)) {
            rawItems = parsed.items;
        }

        const aggregated = {};
        for (const item of rawItems) {
            const key = item.name || item.id || 'unknown';
            const qty = Number(item.amount || item.count || 0);
            const label = item.displayName || item.label || key;

            if (qty > 0) {
                if (!aggregated[key]) {
                    aggregated[key] = {
                        name: key,
                        displayName: label,
                        amount: qty
                    };
                } else {
                    aggregated[key].amount += qty;
                }
            }
        }

        const itemList = Object.values(aggregated);

        const outputPayload = {
            itemCount: itemList.length,
            items: itemList
        };

        fs.writeFileSync(JSON_PATH, JSON.stringify(outputPayload, null, 2));
        console.log(`[${new Date().toLocaleTimeString()}] Saved ${itemList.length} item types to items.json`);

        broadcast(JSON.stringify(outputPayload));
    } catch (err) {
        console.error("Failed to parse or write snapshot:", err.message);
    }
}

wss.on('connection', (ws) => {
    console.log('CC Turtle / Client connected');

    ws.on('message', (message) => {
        const msgString = message.toString();

        try {
            const msg = JSON.parse(msgString);

            if (msg.type === 'start_stream') {
                chunkBuffer = "";
            } else if (msg.type === 'chunk') {
                chunkBuffer += msg.data;
            } else if (msg.type === 'end_stream') {
                processAndSaveItems(chunkBuffer);
                chunkBuffer = "";
            } 
            else if (msg.type === 'full_snapshot' || Array.isArray(msg)) {
                processAndSaveItems(msgString);
            }
        } catch (e) {
            processAndSaveItems(msgString);
        }
    });

    ws.on('close', () => console.log('Client disconnected'));
});

function broadcast(data) {
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(data);
        }
    });
}