# Torのインストール
apk add tor

# torrc 設定ファイルを安全に書き込む
echo "HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:9012
" >> /etc/tor/torrc

# Torのディレクトリとパーミッションの設定
mkdir -p /var/lib/tor/hidden_service
chown -R tor:tor /var/lib/tor/hidden_service
chmod 700 /var/lib/tor/hidden_service

# Torをバックグラウンドで実行
nohup tor > /var/log/tor.log 2>&1 &
