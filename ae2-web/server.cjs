// server.cjs
const WebSocket = require('ws');
const http = require('http');
const express = require('express');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.use(express.static(__dirname));

let globalItemState = {};

wss.on('connection', (ws) => {
    console.log('Client connected');

    ws.send(JSON.stringify({ type: 'full', items: globalItemState }));

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            if (data.type === 'full') {
                globalItemState = data.items;
                broadcast(data);
            } 
            else if (data.type === 'delta') {

                for (const [name, item] of Object.entries(data.changes)) {
                    if (item.amount <= 0) {
                        delete globalItemState[name];
                    } else {
                        globalItemState[name] = item;
                    }
                }
                broadcast(data);
            }
        } catch (err) {
            console.error('Invalid message received:', err);
        }
    });
});

function broadcast(data) {
    const payload = JSON.stringify(data);
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(payload);
        }
    });
}

server.listen(3000, () => {
    console.log('Server running on http://localhost:3000');
});