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
  // 各クライアントごとに現在の生成リクエストの CancelToken を管理
  let currentCancelToken = null;

  ws.on('message', async (message) => {
    const text = message.toString().trim();
    if (!text) {
      ws.send(JSON.stringify({ error: '質問内容がありません。' }));
      return;
    }

    // 「STOP」要求の場合
    if (text === 'STOP') {
      if (currentCancelToken) {
        currentCancelToken.cancel('ユーザーにより生成停止要求が出されました');
        currentCancelToken = null;
        ws.send(JSON.stringify({ message: '生成を停止しました。' }));
      } else {
        ws.send(JSON.stringify({ message: '生成は開始されていません。' }));
      }
      return;
    }

    // 新たな生成要求開始前に、もし前回の生成があればキャンセル
    if (currentCancelToken) {
      currentCancelToken.cancel('新しい生成要求により前回の生成をキャンセルしました');
      currentCancelToken = null;
    }

    try {
      const cancelTokenSource = axios.CancelToken.source();
      currentCancelToken = cancelTokenSource;

      // OLLAMA_API にリクエストを投げ、responseType:'stream' でストリーミング取得
      const response = await axios.post(OLLAMA_API, {
        model: "phi4-mini:latest",
        prompt: text,
        options: { temperature: 0.7 }
      }, {
        headers: { 'Content-Type': 'application/json' },
        responseType: 'stream',
        cancelToken: cancelTokenSource.token
      });

      response.data.on('data', (chunk) => {
        try {
          const data = JSON.parse(chunk.toString());
          if (data.response) {
            // サーバー側でコードブロック等のマークアップはそのまま送信する
            ws.send(data.response);
          }
        } catch (e) {
          console.error('データのパースエラー:', e.message);
        }
      });

      // 生成完了時（"end" イベント）は「生成が完了しました」の通知は送らず、ただリクエストの終了として currentCancelToken をクリア
      response.data.on('end', () => {
        currentCancelToken = null;
      });

    } catch (error) {
      if (axios.isCancel(error)) {
        console.log('生成リクエストがキャンセルされました:', error.message);
      } else {
        console.error('Error:', error.message);
        ws.send(JSON.stringify({ error: 'APIリクエストエラー' }));
      }
      currentCancelToken = null;
    }
  });

  ws.on('close', () => {
    console.log('WebSocket クライアント切断');
    if (currentCancelToken) {
      currentCancelToken.cancel('クライアント切断により生成を停止');
      currentCancelToken = null;
    }
  });
});

// サーバー起動
server.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
