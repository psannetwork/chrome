const express = require('express')
const path = require('path')
const cors = require('cors')
const rateLimit = require('express-rate-limit')

const app = express()
const PORT = 9012

// CORSの設定
const corsOptions = {
  origin: '*',  // 必要に応じてアクセスを許可するドメインに変更
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}
app.use(cors(corsOptions))

// レートリミットの設定（1分あたり最大100リクエスト）
const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1分
  max: 100, // 1分あたりのリクエスト数
  message: 'リクエストが多すぎます。しばらく待ってから再度お試しください。',
  headers: true,
})
app.use(limiter)

// publicフォルダを静的に配信
app.use(express.static(path.join(__dirname, 'public')))

// 404ハンドリング
app.use((req, res) => {
  res.status(404).send('404 Not Found')
})

app.listen(PORT, () => {
  console.log(`サーバーが http://localhost:${PORT} で起動しました`)
})
