@Entry
@Component
struct Index {
  @StorageProp('server') server: string = ''

  build() {
    Column({ space: 10 }) {
      Text('请浏览器访问下面地址：').fontSize(16)
      Text(this.server)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .copyOption(CopyOptions.LocalDevice)
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 20, bottom: 50 })
    .height('100%')
    .width('100%')
  }
}