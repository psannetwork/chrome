const express = require('express')
const path = require('path')

const app = express()
const PORT = 9012

// publicフォルダを静的に配信
app.use(express.static(path.join(__dirname, 'public')))

// 404ハンドリング
app.use((req, res) => {
  res.status(404).send('404 Not Found')
})

app.listen(PORT, () => {
  console.log(`サーバーが http://localhost:${PORT} で起動しました`)
})
