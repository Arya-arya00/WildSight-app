const store = require('../../utils/store')

Page({
  data: {
    records: []
  },

  onShow() {
    this.setData({ records: store.getRecords() })
  },

  openDetail(event) {
    wx.navigateTo({
      url: `/pages/detail/detail?id=${event.currentTarget.dataset.id}`
    })
  }
})
