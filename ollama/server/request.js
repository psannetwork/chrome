const ws = new WebSocket('wss://ollama.psannetwork.net');

ws.onopen = () => {
    // 初回リクエスト (chatId なし → 新規チャット)
    ws.send(JSON.stringify({
        text: "こんにちは、自己紹介をお願いします。"
    }));

    // 2回目のリクエスト (chatId 指定 → 履歴引き継ぎ)
    ws.send(JSON.stringify({
        text: "あなたの得意なことは？",
        chatId: "chat_12345"
    }));
};

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log(`受信: ${data.response || ''} | 終了: ${data.done}`);
};

