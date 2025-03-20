const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const axios = require('axios');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = 9201;
const OLLAMA_API = 'http://localhost:11434/api/generate';

// CORSをすべて許可
app.use(cors());

// =========================
//       HTTP GET API
// =========================
app.get('/generate', async (req, res) => {
    const text = req.query.text;
    if (!text) {
        return res.status(400).json({ error: '質問内容を指定してください。' });
    }

    try {
        const response = await axios.post(OLLAMA_API, {
            model: "phi4-mini:latest",
            prompt: text,
            options: { temperature: 0.7 }
        }, {
            headers: { 'Content-Type': 'application/json' }
        });

        const result = response.data.response || '';
        res.json({ response: result });

    } catch (error) {
        console.error('Error:', error.message);
        res.status(500).json({ error: 'APIリクエストエラー' });
    }
});

// =========================
//     WebSocket API
// =========================
wss.on('connection', (ws) => {
    console.log('WebSocket クライアント接続');

    ws.on('message', async (message) => {
        const text = message.toString();

        if (!text) {
            ws.send(JSON.stringify({ error: '質問内容がありません。' }));
            return;
        }

        try {
            const response = await axios.post(OLLAMA_API, {
                model: "phi4-mini:latest",
                prompt: text,
                options: { temperature: 0.7 }
            }, {
                headers: { 'Content-Type': 'application/json' },
                responseType: 'stream'
            });

            // ストリーミングレスポンスをリアルタイム送信
            response.data.on('data', (chunk) => {
                const data = JSON.parse(chunk.toString());
                if (data.response) {
                    ws.send(data.response);
                }
            });

        } catch (error) {
            console.error('Error:', error.message);
            ws.send(JSON.stringify({ error: 'APIリクエストエラー' }));
        }
    });

    ws.on('close', () => console.log('WebSocket クライアント切断'));
});

// サーバー起動
server.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});
