Page({
  openPicker() {
    wx.showActionSheet({
      itemList: ['从相册选择图片或视频'],
      success: () => {
        wx.chooseMedia({
          count: 1,
          mediaType: ['image', 'video'],
          sourceType: ['album'],
          success: res => {
            const file = res.tempFiles[0]
            const type = res.type
            if (type === 'video' && file.duration > 10) {
              wx.navigateTo({
                url: `/pages/trim/trim?path=${encodeURIComponent(file.tempFilePath)}&duration=${Math.round(file.duration)}`
              })
              return
            }

            wx.navigateTo({
              url: `/pages/result/result?type=${type}&path=${encodeURIComponent(file.tempFilePath)}`
            })
          }
        })
      }
    })
  }
})
