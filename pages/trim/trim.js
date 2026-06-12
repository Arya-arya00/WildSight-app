Page({
  data: {
    path: '',
    duration: 0,
    maxStart: 0,
    start: 0,
    end: 10
  },

  onLoad(query) {
    const duration = Number(query.duration || 0)
    this.setData({
      path: decodeURIComponent(query.path || ''),
      duration,
      maxStart: Math.max(duration - 10, 0),
      start: 0,
      end: Math.min(10, duration)
    })
  },

  onSlide(event) {
    const start = Number(event.detail.value)
    this.setData({
      start,
      end: start + 10
    })
  },

  useClip() {
    wx.navigateTo({
      url: `/pages/result/result?type=video&path=${encodeURIComponent(this.data.path)}&trimStart=${this.data.start}&trimEnd=${this.data.end}`
    })
  }
})
