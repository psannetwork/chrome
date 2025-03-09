nohup cloudflared tunnel --no-autoupdate run --token token --protocol http2 > logfile 2>&1 &
#ps aux | grep cloudflared
#https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
cloudflared tunnel --no-autoupdate run --token token --protocol http2 &> ollama.log &
ps aux | grep cloudflared
disown
