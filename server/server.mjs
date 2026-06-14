import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const port = Number(process.env.PORT || 3000);
loadDotEnv();

const server = createServer(async (request, response) => {
  setCorsHeaders(response);

  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    return;
  }

  if (request.method === "GET" && request.url === "/health") {
    sendJSON(response, 200, { ok: true });
    return;
  }

  if (request.method === "POST" && request.url === "/api/identify") {
    try {
      const body = await readRequestBody(request, 30 * 1024 * 1024);
      const form = parseMultipart(body, request.headers["content-type"] || "");
      const media = form.files.media;
      const mediaKind = form.fields.mediaKind || "image";

      if (!media) {
        sendJSON(response, 400, { error: "missing media" });
        return;
      }

      loadDotEnv();
      if (!process.env.OPENAI_API_KEY) {
        sendJSON(response, 500, { error: "OPENAI_API_KEY is not set on the server." });
        return;
      }

      if (mediaKind === "video") {
        sendJSON(response, 200, unknownVideoResponse());
        return;
      }

      const result = await identifyImage(media);
      sendJSON(response, 200, result);
    } catch (error) {
      console.error(sanitizeError(error));
      sendJSON(response, 500, { error: userFacingError(error) });
    }
    return;
  }

  if (request.method === "POST" && request.url === "/api/artwork") {
    const startedAt = Date.now();
    try {
      const body = await readRequestBody(request, 30 * 1024 * 1024);
      const form = parseMultipart(body, request.headers["content-type"] || "");
      const media = form.files.media;

      if (!media) {
        sendJSON(response, 400, { error: "missing media" });
        return;
      }

      loadDotEnv();
      if (!process.env.OPENAI_API_KEY) {
        sendJSON(response, 500, { error: "OPENAI_API_KEY is not set on the server." });
        return;
      }

      const result = {
        name: form.fields.name || "识别结果待确认",
        latin: form.fields.latin || "分类待确认",
        summary: form.fields.summary || "",
        tags: parseTags(form.fields.tags)
      };
      console.log(`Artwork request started: ${result.name}, ${media.contentType}, ${media.buffer.length} bytes`);
      const artworkBase64 = await generateCardArtwork(result, media);
      console.log(`Artwork request finished: ${result.name}, ${Date.now() - startedAt}ms, hasArtwork=${Boolean(artworkBase64)}`);
      sendJSON(response, 200, { artworkBase64 });
    } catch (error) {
      console.error(`Artwork request failed after ${Date.now() - startedAt}ms`);
      console.error(sanitizeError(error));
      sendJSON(response, 500, { error: userFacingError(error) });
    }
    return;
  }

  sendJSON(response, 404, { error: "not found" });
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Qiyubu server listening on http://0.0.0.0:${port}`);
});

function loadDotEnv() {
  const envPath = [resolve("server/.env"), resolve(".env")].find((path) => existsSync(path));
  if (!envPath) return;

  let envText;
  try {
    envText = readFileSync(envPath, "utf8");
  } catch (error) {
    console.warn(sanitizeError(`Unable to reload server/.env, keeping existing environment: ${error?.message || error}`));
    return;
  }

  for (const line of envText.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const index = trimmed.indexOf("=");
    if (index === -1) continue;
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim().replace(/^["']|["']$/g, "");
    process.env[key] = value;
  }
}

function sanitizeError(error) {
  const message = error?.stack || error?.message || String(error);
  return message.replace(/sk-[A-Za-z0-9_-]+/g, "sk-***");
}

function setCorsHeaders(response) {
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  response.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function sendJSON(response, status, data) {
  response.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(data));
}

async function readRequestBody(request, maxBytes) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maxBytes) {
      throw new Error("request body too large");
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

function parseMultipart(body, contentType) {
  const boundaryMatch = contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/i);
  if (!boundaryMatch) throw new Error("missing multipart boundary");

  const boundary = `--${boundaryMatch[1] || boundaryMatch[2]}`;
  const parts = body.toString("binary").split(boundary).slice(1, -1);
  const fields = {};
  const files = {};

  for (const part of parts) {
    const cleanPart = part.replace(/^\r\n/, "").replace(/\r\n$/, "");
    const [rawHeaders, ...bodyParts] = cleanPart.split("\r\n\r\n");
    if (!rawHeaders || bodyParts.length === 0) continue;

    const partBodyBinary = bodyParts.join("\r\n\r\n");
    const disposition = rawHeaders.match(/content-disposition: form-data;([^\r\n]+)/i)?.[1] || "";
    const name = disposition.match(/name="([^"]+)"/)?.[1];
    const filename = disposition.match(/filename="([^"]*)"/)?.[1];
    const contentTypeMatch = rawHeaders.match(/content-type:\s*([^\r\n]+)/i);
    const partContentType = contentTypeMatch?.[1]?.trim() || "application/octet-stream";
    if (!name) continue;

    if (filename !== undefined) {
      files[name] = {
        filename,
        contentType: partContentType,
        buffer: Buffer.from(partBodyBinary, "binary")
      };
    } else {
      fields[name] = Buffer.from(partBodyBinary, "binary").toString("utf8");
    }
  }

  return { fields, files };
}

async function identifyImage(media) {
  const dataUrl = `data:${media.contentType};base64,${media.buffer.toString("base64")}`;
  const payload = {
    model: currentModel(),
    messages: [
      {
        role: "system",
        content: identifySystemPrompt()
      },
      {
        role: "user",
        content: [
          {
            type: "text",
            text: identifyUserPrompt()
          },
          {
            type: "image_url",
            image_url: {
              url: dataUrl
            }
          }
        ]
      }
    ],
    response_format: { type: "json_object" }
  };

  const baseURL = apiBaseURL();
  const response = await fetch(`${baseURL}/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OpenAI request failed: ${response.status} ${text}`);
  }

  const json = await response.json();
  const outputText = json.choices?.[0]?.message?.content;
  if (!outputText) throw new Error("missing model output text");
  const result = normalizeIdentifyResult(JSON.parse(stripJSONFence(outputText)));
  result.artworkBase64 = shouldGenerateArtworkSync() ? await generateCardArtwork(result, media) : null;
  return result;
}

function identifySystemPrompt() {
  return [
    "你是“Arya 的非正经科普”风格的自然观察图鉴助手。",
    "你的目标不是写百科词条，而是把用户拍到的生物讲成一张轻松、有趣、好懂、但绝不编造的小科普卡。",
    "表达风格：像朋友讲自然观察笔记，短句、生活化比喻、有画面感；可以俏皮，但不要油腻，不要营销腔。",
    "事实原则高于表达效果：所有科普内容必须是公开资料中可以验证的事实。不能为了有趣而补设定、编机制、编行为、编来源。没有把握就明确说不确定，宁可少写。",
    "",
    "识别优先参考这些权威资料体系和命名习惯：",
    "- 中国近海、南海、海南、福建、广东等海域鱼类：优先参考《中国海洋鱼类图鉴》全三册、《中国海洋鱼类》上中下，以及国内高校、研究机构和权威图鉴的中文命名。",
    "- 热带太平洋、菲律宾、印尼、马来西亚、帕劳、马代等潜水场景：优先参考 Reef Fish Identification: Tropical Pacific、Reef Creature Identification: Tropical Pacific、Reef Life 等潜水员现场图鉴。",
    "- 加勒比、佛罗里达、巴哈马：优先参考 Reef Fish Identification: Florida, Caribbean, Bahamas。",
    "- 更系统的分类、分布和相似种判断：优先参考 FAO Species Identification Guides、FishBase、WoRMS、IUCN、Fishes of the World、Fishes of the Great Barrier Reef and Coral Sea、Coral Reef Fishes 等权威资料。",
    "- 综合动物百科：遇到非海洋动物时，优先参考 Grzimek’s Animal Life Encyclopedia、Animal: The Definitive Visual Guide（DK / Smithsonian）这类覆盖无脊椎、昆虫、鱼类、两栖、爬行、鸟类、哺乳动物的综合资料。",
    "- 鸟类：优先参考 Handbook of the Birds of the World、Birds of the World（Cornell Lab + Lynx）、《中国鸟类观察手册》、Birds of China、Birds of East Asia 等资料和命名体系。",
    "- 哺乳动物：优先参考 Handbook of the Mammals of the World、All the Mammals of the World、The Princeton Encyclopedia of Mammals、《中国兽类图鉴》第 3 版、《中国兽类野外手册》等资料。",
    "- 爬行动物和两栖动物：优先参考 Handbook of the Reptiles of the World、Snakes of the World、Reptiles and Amphibians（Smithsonian Handbooks）及所在地区的权威野外手册。",
    "- 昆虫、蜘蛛等陆地无脊椎动物：优先参考《中国昆虫生态大图鉴》第 2 版、Beetles of the World、Bees of the World、Butterflies of the World、Dragonflies and Damselflies of the World 及所在地区的权威昆虫图鉴。",
    "这些资料只能作为识别和命名的优先依据，不代表你可以编造书中没有的细节。看不清或资料不足时，必须降低到属、科、目或大类，不要硬判到种。"
  ].join("\n");
}

function identifyUserPrompt() {
  return [
    "请识别图片里的主要生物或自然对象。",
    "",
    "输出内容要像下面这种风格，但不要照抄例子：",
    "- “尖尖的鹰钩嘴，像自带开罐器，专门在珊瑚缝里夹海绵吃。”",
    "- “白天集体悬停像开省电模式，留着晚上出去干饭。”",
    "- “清洁站就是海底大澡堂，此处只搓澡，不杀生。”",
    "",
    "硬性事实要求：",
    "- 只写你确信可由公开资料验证的内容，例如百科、维基、权威机构科普、论文或常见教材级资料。",
    "- 不要编造出处，不要编造有趣知识点，不要把推测写成事实。",
    "- 如果图片只能判断到大类，就只写这个大类确定成立的事实，并说明“不一定精确到种”。",
    "- 第 3 条优先写“有趣观察”：如果能确认到具体物种，写该物种可靠、有记忆点的事实；如果只能确认到属、科或大类，写这个层级普遍成立的有趣特征；如果连大类都不稳，facts 可以只有 2 条。",
    "",
    "识别流程要求：",
    "1. 先看照片里真实可见的形态特征：体型轮廓、鳍/触手/壳/尾巴形态、斑纹、颜色、嘴部、眼位、游泳姿态、栖息环境。",
    "2. 再判断大类：鱼类、鲨鳐、头足类、甲壳类、软体动物、棘皮动物、鸟类、哺乳动物、爬行动物、两栖动物、昆虫、蜘蛛等。",
    "3. 对相似物种做排除，不要只凭一个斑点或颜色下结论。至少在心里比较 2-3 个相似候选。",
    "4. 地点只能作为辅助线索，不能替代形态判断；如果没有地点，就不要把区域特有种写死。",
    "5. 中文名必须可追溯，优先使用权威中文俗名或潜水员常用名。不要生造中文名。若中文名不确定，写“大类名 + 拉丁属名/科名”，例如“鹰鳐类 / Aetobatus sp.”。",
    "",
    "容易误判的重点规则：",
    "- 鹰鳐/鹰鲼类：如果照片中是宽大翼状胸鳍、头部前突、长鞭状尾、背部白色斑点或环斑，优先考虑鹰鳐类/鹰鲼类，而不是普通鱼类。中文名不要写成“雁鱼”“燕鱼”等错名。若地点在印太海域，不能自动写死 Aetobatus narinari；更稳妥写“鹰鳐类 / Aetobatus sp.”，或在证据充分时考虑 Aetobatus ocellatus。若地点在加勒比/大西洋且特征清楚，才更适合考虑 Aetobatus narinari。",
    "- 鲨、鳐、魟、鲼的区分要谨慎：扁平盘状身体和鞭状尾不是普通鱼；胸鳍像翅膀在水中“飞”的，优先检查鲼形目/鹰鲼科相关候选。",
    "- 鸟类：不要只凭羽毛颜色判种。优先看喙形、翼斑、尾型、腿色、体型、站姿/飞行姿态、栖息地和地点。年龄、性别、繁殖羽、冬羽、换羽都会改变外观；证据不足时写到属、科或“可能是某类鸟”。",
    "- 哺乳动物：先区分野生动物、家养动物、宠物和人工饲养个体。优先看脸型、耳形、尾巴、蹄/爪、体型比例、毛色斑纹、行动姿态和环境。幼体、亚成体和家养品种不要硬套野生种。",
    "- 爬行动物和两栖动物：蛇、蜥蜴、蛙、蟾、龟等如果关键特征不清，优先写到属、科或大类。疑似有毒、有咬伤风险或受保护动物时，只提醒保持距离、不要触碰/捕捉/投喂，不提供抓捕或处理建议。",
    "- 昆虫、蜘蛛等无脊椎动物：照片常常不足以精确到种。优先看翅、触角、足、口器、体节、斑纹、寄主植物或栖息环境；不确定时写到目、科或属，不要为了好看硬给种名。",
    "- 幼体、雌雄、婚姻色、夜间体色、季节羽、换羽期会变化；如果只看到颜色，不要直接判种。",
    "- 视频截图如果主体很小、糊、被遮挡，只能给倾向性判断，不要生成看似确定的种名。",
    "- 对危险动物、可能有毒动物、受保护动物或野生动物，不要建议触摸、投喂、捕捉、带回家；只给温和的安全提醒。",
    "",
    "人物彩蛋规则：",
    "- 如果图片主体明确是人物，而不是动物或自然对象，不要做人脸识别，不要猜测姓名、身份、职业、民族、健康、性格、家庭关系等敏感或不可见信息。",
    "- 可以把它当作一个温暖的小彩蛋：name 写“人类朋友”，latin 写“Homo sapiens · 人科”。status 用 unknown 或 uncertain 都可以，但 confidence 写“这是一位人类朋友”。",
    "- summary 不要套用固定句式。根据画面里可见的姿态、表情、动作、物品和氛围写一句轻松描述。例如看到笑容可以写“画面里的人笑得很开心，像把快乐递到了镜头前”；看到神情安静或低落，可以写“画面里的人看起来安静了一点，像被镜头轻轻接住的一刻”。",
    "- facts 写 2 条即可：第 1 条 title 用“1️⃣ 画面里：”描述可见构图、动作、物品、氛围；第 2 条 title 用“2️⃣ 悄悄说：”基于可见表情和氛围给一句温柔互动。看到开心，可以写“希望屏幕前的你也被这份开心传染一点”；看到安静、疲惫或低落，只能说“看起来有一点……”，并温柔地写“如果这是你在意的人，也许可以给 TA 一个抱抱”。不要断言真实情绪，不要断言关系，不要评价身材、年龄或做外貌排名。第 2 条末尾自然补一句引导，例如“也可以试着上传一张自然界里的动物照片，继续认识更多有趣的生命。”",
    "",
    "请只输出 JSON，不要 Markdown，不要代码块。字段必须包含：status, confidence, name, latin, summary, facts, tags。",
    "",
    "字段要求：",
    "- status：identified / uncertain / unknown。",
    "- confidence：中文短语，例如“较明确”“可能是”“看不清”。",
    "- name：尽量给可追溯中文俗名；不确定时写“可能是……”或“大类名”，不要生造中文名。",
    "- latin：拉丁名 + 中文分类提示；不确定时写到更高层级，例如“Octopoda · 章鱼目”或“Aetobatus sp. · 鹰鲼科”。不要把不确定的种名写得像确定事实。",
    "- summary：1 句话，40 字以内，像开场白，要有记忆点，但不能牺牲事实准确性。",
    "- facts：2-3 条，每条是 { title, text }。",
    "",
    "facts 结构：",
    "1. title 用“1️⃣ 它是谁：”；不要在冒号后添加省略号、点点点或占位符。text 讲它是什么、怎么认、身体结构特点。优先抓照片里看得见的特征。",
    "2. title 用“2️⃣ 怎么生活：”；不要在冒号后添加省略号、点点点或占位符。text 讲习性，比如昼夜节律、捕食方式、食性、栖息环境、社交/独居、游动/伪装方式。",
    "3. title 用“3️⃣ 有趣观察：”；不要在冒号后添加省略号、点点点或占位符。text 讲一个可靠、有记忆点的事实。优先从繁殖、发育、呼吸、捕食、伪装、共生、清洁行为、防御机制里选。能确认到种，就写该物种事实；只能确认到属/科/大类，就写该层级普遍成立的特征。不要为了有趣硬编；连大类都不稳时才省略第三条。",
    "",
    "长度要求：每条 text 60-110 字。可以用一个生活化比喻，但不要堆形容词。",
    "如果完全看不出，返回 unknown，并让 facts 解释为什么看不出、需要补什么照片。",
    "tags 给 2-4 个短标签。"
  ].join("\n");
}

function currentModel() {
  return process.env.OPENAI_MODEL || "gpt-4o";
}

function currentImageModel() {
  return process.env.OPENAI_IMAGE_MODEL || "gpt-image-2";
}

function shouldGenerateArtworkSync() {
  return process.env.OPENAI_GENERATE_ARTWORK_SYNC === "true";
}

function apiBaseURL() {
  const baseURL = (process.env.OPENAI_BASE_URL || "https://gainianai.cn").replace(/\/$/, "");
  return baseURL.endsWith("/v1") ? baseURL : `${baseURL}/v1`;
}

function userFacingError(error) {
  const message = error?.message || String(error);
  if (message.includes("fetch failed") || message.includes("Connect Timeout") || message.includes("ECONNRESET")) {
    return "本机服务端连不上识别 API。请确认这台 Mac 的网络可以访问 server/.env 里的 OPENAI_BASE_URL。";
  }
  if (message.includes("OpenAI request failed: 401")) {
    return "API Key 无效或没有权限。请检查 server/.env 里的 OPENAI_API_KEY 是否属于当前中转站。";
  }
  if (message.includes("insufficient_quota")) {
    return "API 账户额度不足。请到当前中转站后台确认余额或令牌额度。";
  }
  if (message.includes("OpenAI request failed: 429")) {
    return "OpenAI 调用速率受限。请稍后再试，或检查 API 账户限额。";
  }
  if (message.includes("OpenAI request failed: 400")) {
    return "OpenAI 不接受这次请求。可能是模型、图片格式或结构化输出参数不兼容。";
  }
  return "识别服务调用失败，请查看 /tmp/qiyubook-server.log。";
}

function stripJSONFence(text) {
  return text.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
}

function normalizeIdentifyResult(result) {
  const facts = Array.isArray(result.facts) ? result.facts : [];
  const tags = Array.isArray(result.tags) ? result.tags : [];
  const normalizedName = normalizeCommonName(
    stringify(result.name, "识别结果待确认"),
    stringify(result.latin, "分类待确认")
  );
  const normalizedLatin = normalizeLatin(
    stringify(result.latin, "分类待确认"),
    normalizedName
  );

  return {
    status: stringify(result.status, "unknown"),
    confidence: stringify(result.confidence, "不确定"),
    name: normalizedName,
    latin: normalizedLatin,
    summary: stringify(result.summary, "这张照片的信息还不够明确，可以补充更多角度或更清晰的图片继续判断。"),
    facts: facts.map((fact) => ({
      title: normalizeFactTitle(stringify(fact?.title, "观察提示")),
      text: stringify(fact?.text, "")
    })).filter((fact) => fact.text),
    tags: tags.map((tag) => stringify(tag, "")).filter(Boolean),
    artworkBase64: typeof result.artworkBase64 === "string" ? result.artworkBase64 : null
  };
}

function normalizeFactTitle(title) {
  return title
    .replace(/([：:])\s*(?:…+|\.{2,}|。+)$/u, "$1")
    .replace(/([：:])\s*(?:…+|\.{2,}|。+)\s*/u, "$1")
    .trim();
}

function normalizeCommonName(name, latin) {
  const text = `${name} ${latin}`;
  if (/Aetobatus|eagle ray|鹰[鳐鲼]|鳐|鲼/i.test(text) && /雁鱼|燕鱼|斑点雁|斑点燕/.test(name)) {
    return "鹰鳐类";
  }
  return name;
}

function normalizeLatin(latin, name) {
  if (name === "鹰鳐类" && !/Aetobatus|鹰/.test(latin)) {
    return "Aetobatus sp. · 鹰鲼科";
  }
  return latin;
}

function stringify(value, fallback) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === "string") return value || fallback;
  return String(value);
}

function parseTags(value) {
  if (!value) return [];
  try {
    const tags = JSON.parse(value);
    if (Array.isArray(tags)) return tags.map((tag) => stringify(tag, "")).filter(Boolean);
  } catch {
    // Fall through to comma-separated parsing.
  }
  return value.split(",").map((tag) => tag.trim()).filter(Boolean);
}

async function generateCardArtwork(result, sourceMedia) {
  const prompt = artworkPrompt(result);
  const edited = await withTimeout(
    tryGenerateArtworkFromSource(prompt, sourceMedia),
    imageTimeoutMs(),
    "Image edit timed out"
  );
  if (edited) return edited;
  if (isHumanResult(result)) return null;

  return await withTimeout(
    generateArtworkFromPrompt(prompt),
    imageTimeoutMs(),
    "Image generation timed out"
  );
}

async function tryGenerateArtworkFromSource(prompt, sourceMedia) {
  const form = new FormData();
  const imageBlob = new Blob([sourceMedia.buffer], { type: sourceMedia.contentType });
  form.append("model", currentImageModel());
  form.append("prompt", prompt);
  form.append("size", imageSize());
  form.append("n", "1");
  form.append("quality", imageQuality());
  form.append("output_format", "jpeg");
  form.append("image", imageBlob, sourceMedia.filename || "source.jpg");

  const response = await fetch(`${apiBaseURL()}/images/edits`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`
    },
    body: form
  });

  if (!response.ok) {
    const text = await response.text();
    console.warn(sanitizeError(`Image edit failed, falling back to generation: ${response.status} ${text}`));
    return null;
  }

  const json = await response.json();
  return imageResultBase64(json);
}

async function generateArtworkFromPrompt(prompt) {
  const payload = {
    model: currentImageModel(),
    prompt,
    size: imageSize(),
    n: 1,
    quality: imageQuality(),
    output_format: "jpeg"
  };
  const response = await fetch(`${apiBaseURL()}/images/generations`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const text = await response.text();
    if (response.status === 400) {
      console.warn(sanitizeError(`Image generation speed options failed, retrying without them: ${response.status} ${text}`));
      return await generateArtworkFromPromptWithoutSpeedOptions(prompt);
    }
    throw new Error(`Image generation failed: ${response.status} ${text}`);
  }

  const json = await response.json();
  return imageResultBase64(json);
}

async function generateArtworkFromPromptWithoutSpeedOptions(prompt) {
  const response = await fetch(`${apiBaseURL()}/images/generations`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: currentImageModel(),
      prompt,
      size: imageSize(),
      n: 1
    })
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Image generation failed: ${response.status} ${text}`);
  }

  const json = await response.json();
  return imageResultBase64(json);
}

function imageQuality() {
  return process.env.OPENAI_IMAGE_QUALITY || "low";
}

function imageSize() {
  return process.env.OPENAI_IMAGE_SIZE || "1536x1024";
}

async function imageResultBase64(json) {
  const item = json.data?.[0];
  if (item?.b64_json) return item.b64_json;
  if (item?.url) return await fetchImageAsBase64(item.url);
  throw new Error("missing generated image");
}

function artworkPrompt(result) {
  if (isHumanResult(result)) {
    return [
      "Transform the uploaded portrait/person photo into a cute hand-drawn identity-card illustration.",
      "",
      "Most important rule:",
      "- Use the uploaded image as the source of truth. Do not invent a different person, pose, outfit, object, hairstyle, expression, or scene.",
      "- Preserve the main person's visible pose, direction, body angle, gesture, clothing colors, accessories, held objects, and overall composition as much as possible.",
      "- If the person is smiling, keep the visible smile. If the expression is quiet or neutral, keep that gentle expression. Do not exaggerate emotion.",
      "- Do not beautify into a generic model, celebrity, anime character, child/adult swap, or different age impression.",
      "",
      "Reference style to match:",
      "- cute hand-drawn sticker / identity-card illustration",
      "- soft watercolor/gouache coloring with gentle gradients",
      "- warm dark-gray hand-drawn outline, slightly uneven ink edge",
      "- rounded but recognizable features, simple friendly expression",
      "- clean white or transparent-feeling background",
      "",
      "Composition rules:",
      "- one main person subject from the uploaded photo",
      "- no extra people, animals, props, labels, text, signature, frame, or background scene unless they are clearly visible and important in the original photo",
      "- not photorealistic, not 3D, not vector-flat, not anime style",
      "- landscape 4:3 identity-card image, rounded-card friendly, simple and clean",
      `- subject hint: ${result.name}`,
      `- observed traits: ${result.summary}`
    ].join("\n");
  }

  return [
    "Turn the uploaded animal photo into a single cute hand-drawn sticker illustration for a nature identity card.",
    "",
    "Reference style to match:",
    "- kawaii marine-animal sticker sheet feeling",
    "- soft watercolor/gouache coloring with gentle gradients",
    "- rounded chubby proportions, small dot eyes, subtle smile only if natural",
    "- warm dark-gray hand-drawn outline, slightly uneven ink edge",
    "- soft highlights, tiny blush-like color accents only if suitable",
    "- clean white or transparent-feeling background",
    "",
    "Subject rules:",
    "- draw only the main animal/natural subject from the uploaded photo",
    "- keep the animal's original pose, direction, body angle, and visible action as much as possible",
    "- keep biologically important features recognizable",
    `- identified subject: ${result.name}`,
    `- taxonomy hint: ${result.latin}`,
    `- observed traits: ${result.summary}`,
    "",
    "Composition rules:",
    "- one centered subject, full body if visible",
    "- no extra animals, shells, stars, bubbles, props, labels, text, signature, frame, or background scene",
    "- not photorealistic, not 3D, not vector-flat, not anime human style",
    "- landscape 4:3 identity-card image, rounded-card friendly, simple and clean"
  ].join("\n");
}

function isHumanResult(result) {
  const text = `${result?.name || ""} ${result?.latin || ""} ${result?.confidence || ""}`.toLowerCase();
  return /人类朋友|homo sapiens|人科|human|person/.test(text);
}

async function fetchImageAsBase64(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Generated image download failed: ${response.status}`);
  }
  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer).toString("base64");
}

function imageTimeoutMs() {
  return Math.max(Number(process.env.OPENAI_IMAGE_TIMEOUT_MS || 90000), 90000);
}

async function withTimeout(promise, timeoutMs, label) {
  let timeoutId;
  const timeout = new Promise((resolve) => {
    timeoutId = setTimeout(() => {
      console.warn(label);
      resolve(null);
    }, timeoutMs);
  });

  try {
    return await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(timeoutId);
  }
}

function unknownVideoResponse() {
  return {
    status: "unknown",
    confidence: "暂未支持",
    name: "视频识别待接入",
    latin: "Video input pending",
    summary: "服务端已经收到视频，但当前无依赖版本先不做抽帧。下一步可以接 ffmpeg，把视频截成几张清晰帧后再识别。",
    facts: [
      { title: "现在能做什么", text: "先上传一张最清晰的截图，识别会更稳定。" },
      { title: "下一步", text: "服务端接入视频抽帧后，可以自动从 10 秒片段里挑几帧给 AI 判断。" }
    ],
    tags: ["视频", "待接入"]
  };
}
