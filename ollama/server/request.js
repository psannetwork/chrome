const ws = new WebSocket('wss://ollama.psannetwork.net');
ws.onopen = () => ws.send("あなたの質問内容");
ws.onmessage = (event) => console.log("受信:", event.data);



//curl "http://localhost:9201/generate?text=あなたの質問内容"
