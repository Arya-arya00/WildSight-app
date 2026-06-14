# 识野识别服务接口

App 通过 `POST /api/identify` 上传图片或视频片段，服务端返回可直接生成图鉴卡的结构化 JSON。

## iOS 配置

当前开发地址已经填好：

`WildSight-iOS/WildSight/APIConfig.swift`

```swift
static let identifyEndpoint = "http://192.168.1.213:3000/api/identify"
```

真机调试时，iPhone 和 Mac 需要在同一个 Wi-Fi 下。当前 iOS 工程为开发期打开了本地 HTTP 和局域网访问权限。正式上线前应改成 HTTPS 服务地址，并关闭任意 HTTP 访问。

## 本地服务

服务端入口：

`server/server.mjs`

启动前创建：

`server/.env`

内容：

```bash
OPENAI_API_KEY=你的 OpenAI API Key
OPENAI_MODEL=gpt-4o-mini
PORT=3000
```

启动：

```bash
sh server/start.sh
```

健康检查：

```bash
curl http://127.0.0.1:3000/health
```

当前无依赖版本支持图片识别。视频上传会返回“视频识别待接入”；后续可在服务端加入 ffmpeg 抽帧。

## Request

`Content-Type: multipart/form-data`

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| media | file | 图片或视频文件 |
| mediaKind | string | `image` 或 `video` |
| observedAt | string | App 侧记录的上传时间 |
| trimStart | string | 视频片段起点，可选 |
| trimEnd | string | 视频片段终点，可选 |

## Response

```json
{
  "status": "clear",
  "confidence": "较明确",
  "name": "玳瑁海龟",
  "latin": "Eretmochelys imbricata · 海龟科",
  "summary": "尖尖的鹰钩嘴，加上像瓦片一样叠起来的背甲，基本就是海龟界的复古穿搭选手。",
  "facts": [
    { "title": "怎么认", "text": "看侧脸的尖嘴、背甲边缘和鳞片叠法。" },
    { "title": "在干嘛", "text": "常在珊瑚附近找海绵和小型无脊椎动物。" },
    { "title": "小心点", "text": "保持距离，不挡它的路。" }
  ],
  "tags": ["海龟", "濒危"]
}
```

必填字段：

- `name`
- `summary`
- `facts`

可选字段：

- `status`
- `confidence`
- `latin`
- `tags`

如果 AI 无法判断，也不要编造物种，可以返回：

```json
{
  "status": "unknown",
  "confidence": "看不出",
  "name": "暂时看不出",
  "latin": "信息不足",
  "summary": "这张图里的主体太小或太糊，暂时没法可靠判断是什么。",
  "facts": [
    { "title": "可以怎么补", "text": "换一张主体更近、更清楚、侧面或正面特征更完整的照片。" }
  ],
  "tags": ["待确认"]
}
```
