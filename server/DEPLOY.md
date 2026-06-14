# 识野识别服务部署说明

## 为什么要部署

现在 iOS App 连接的是 Mac 上的本地服务，例如 `http://192.168.1.212:3000`。这种地址只在同一个 Wi-Fi 下短时间有效，Mac IP 改变、手机换网络、给别人安装 App，都会连不上。

长期方案是把 `server.mjs` 部署到公网服务器，拿到一个固定的 HTTPS 地址，例如：

```text
https://shiye-api.example.com
```

然后 App 只访问：

```text
https://shiye-api.example.com/api/identify
https://shiye-api.example.com/api/artwork
```

## 推荐方案

### 正式体验版

用 Render、Railway、Fly.io、阿里云、腾讯云、AWS、Google Cloud 等任意能跑 Node.js 服务的平台。

服务端需要配置这些环境变量：

```text
OPENAI_API_KEY=你的服务端 API Key
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o
OPENAI_IMAGE_MODEL=gpt-image-2
OPENAI_IMAGE_QUALITY=low
OPENAI_IMAGE_SIZE=1536x1024
OPENAI_IMAGE_TIMEOUT_MS=90000
PORT=3000
```

如果继续使用中转站，把 `OPENAI_BASE_URL` 改成中转站提供的 base URL。

### 临时演示版

可以用 Cloudflare Tunnel、ngrok、Tailscale Funnel 这类工具把 Mac 本地的 `3000` 端口临时暴露成 HTTPS 地址。优点是快，缺点是 Mac 必须一直开着，地址和稳定性也不适合发给很多人长期使用。

## 启动命令

如果平台支持 Node.js：

```bash
npm start
```

如果平台支持 Docker：

```bash
docker build -t shiye-identify-server .
docker run -p 3000:3000 --env-file .env shiye-identify-server
```

## 健康检查

部署后打开：

```text
https://你的服务地址/health
```

看到下面内容表示服务已启动：

```json
{"ok":true}
```

## App 需要改哪里

拿到公网 HTTPS 地址后，修改：

```text
QiyuBook-iOS/QiyuBook/APIConfig.swift
```

把 `baseURL` 改成你的服务地址，然后重新打包安装。

## 不建议的方案

不要把 OpenAI API Key 直接写进 iOS App。App 安装包可以被反编译，Key 会泄漏，别人可以直接消耗你的额度。识别和生成图片都应该经过你自己的服务端。
