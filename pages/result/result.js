const store = require('../../utils/store')

Page({
  data: {
    record: null
  },

  onLoad(query) {
    const media = {
      mediaType: query.type || 'image',
      path: decodeURIComponent(query.path || ''),
      trimStart: Number(query.trimStart || 0),
      trimEnd: Number(query.trimEnd || 0)
    }
    const record = store.saveRecord(store.mockRecognize(media))
    this.setData({ record })
  },

  editText(event) {
    const field = event.currentTarget.dataset.field
    this.promptEdit(field, this.data.record[field])
  },

  editFact(event) {
    const index = Number(event.currentTarget.dataset.index)
    const key = event.currentTarget.dataset.key
    const value = this.data.record.facts[index][key]
    wx.showModal({
      title: '修改内容',
      editable: true,
      placeholderText: value,
      success: res => {
        if (!res.confirm || !res.content) return
        const facts = this.data.record.facts.slice()
        facts[index] = { ...facts[index], [key]: res.content }
        this.savePatch({ facts })
      }
    })
  },

  editMeta() {
    wx.showModal({
      title: '修改时间地点',
      editable: true,
      placeholderText: `${this.data.record.time} · ${this.data.record.location}`,
      success: res => {
        if (!res.confirm || !res.content) return
        const parts = res.content.split('·').map(item => item.trim())
        this.savePatch({
          time: parts[0] || this.data.record.time,
          location: parts[1] || this.data.record.location
        })
      }
    })
  },

  promptEdit(field, value) {
    wx.showModal({
      title: '修改内容',
      editable: true,
      placeholderText: value,
      success: res => {
        if (!res.confirm || !res.content) return
        this.savePatch({ [field]: res.content })
      }
    })
  },

  savePatch(patch) {
    const record = store.updateRecord(this.data.record.id, patch)
    this.setData({ record })
  },

  previewMedia() {
    const record = this.data.record
    if (!record.mediaPath) {
      wx.showToast({ title: '示例记录暂无原媒体', icon: 'none' })
      return
    }
    if (record.mediaType === 'image') {
      wx.previewImage({ urls: [record.mediaPath] })
      return
    }
    wx.navigateTo({
      url: `/pages/detail/detail?id=${record.id}&preview=1`
    })
  }
})
