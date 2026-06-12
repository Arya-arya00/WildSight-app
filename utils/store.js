const STORAGE_KEY = 'ocean_records'

const sampleCards = [
  {
    id: 'sample-turtle',
    name: '玳瑁海龟',
    latin: 'Hawksbill Sea Turtle · 海龟科',
    confidence: '较明确',
    summary: '尖尖的鹰钩嘴，加上像瓦片一样叠起来的背甲，基本就是海龟界的复古穿搭选手。',
    facts: [
      { title: '怎么认', text: '看侧脸的尖嘴、背甲边缘和鳞片叠法。' },
      { title: '在干嘛', text: '常在珊瑚附近找海绵和小型无脊椎动物。' },
      { title: '小心点', text: '保持距离，不挡它的路；它慢，不代表想被贴脸拍。' }
    ],
    mediaType: 'video',
    mediaPath: '',
    mediaLabel: '视频',
    time: '2026.02.25 15:42',
    location: '菲律宾 阿尼洛',
    tags: ['海龟', '濒危'],
    createdAt: Date.now() - 3000
  },
  {
    id: 'sample-ray',
    name: '鹰鳐',
    latin: 'Eagle Ray · 鳐科',
    confidence: '较明确',
    summary: '背着星星点点的斑纹巡航，像海里飞过的一张小毯子。',
    facts: [
      { title: '怎么认', text: '尖头、宽大的胸鳍和背部斑点是重点。' },
      { title: '在干嘛', text: '常在沙地附近找贝类或小型甲壳动物。' },
      { title: '小心点', text: '远远看就好，不要追着它游。' }
    ],
    mediaType: 'image',
    mediaPath: '',
    mediaLabel: '照片',
    time: '2025.10.03 10:20',
    location: '科莫多',
    tags: ['鳐鱼', '星空背'],
    createdAt: Date.now() - 2000
  }
]

function nowText() {
  const d = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function getRecords() {
  const records = wx.getStorageSync(STORAGE_KEY)
  if (Array.isArray(records) && records.length) return records
  return sampleCards
}

function setRecords(records) {
  wx.setStorageSync(STORAGE_KEY, records)
}

function getRecord(id) {
  return getRecords().find(item => item.id === id)
}

function saveRecord(record) {
  const records = getRecords().filter(item => item.id !== record.id)
  const next = [record, ...records]
  setRecords(next)
  return record
}

function updateRecord(id, patch) {
  const records = getRecords()
  const next = records.map(item => item.id === id ? { ...item, ...patch } : item)
  setRecords(next)
  return next.find(item => item.id === id)
}

function deleteRecord(id) {
  setRecords(getRecords().filter(item => item.id !== id))
}

function mockRecognize(media) {
  return {
    id: `record-${Date.now()}`,
    name: '玳瑁海龟',
    latin: 'Hawksbill Sea Turtle · 海龟科',
    confidence: '较明确',
    summary: '尖尖的鹰钩嘴，加上像瓦片一样叠起来的背甲，基本就是海龟界的复古穿搭选手。',
    facts: [
      { title: '怎么认', text: '看侧脸的尖嘴、背甲边缘和鳞片叠法。' },
      { title: '在干嘛', text: '常在珊瑚附近找海绵和小型无脊椎动物。' },
      { title: '小心点', text: '保持距离，不挡它的路；它慢，不代表想被贴脸拍。' }
    ],
    mediaType: media.mediaType,
    mediaPath: media.path,
    mediaLabel: media.mediaType === 'video' ? '视频' : '照片',
    trimStart: media.trimStart || 0,
    trimEnd: media.trimEnd || 0,
    time: nowText(),
    location: '未填写地点',
    tags: ['海龟', '濒危'],
    createdAt: Date.now()
  }
}

module.exports = {
  getRecords,
  getRecord,
  saveRecord,
  updateRecord,
  deleteRecord,
  mockRecognize
}
