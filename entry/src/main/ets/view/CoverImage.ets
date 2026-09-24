/**
 * 封面图组件
 * 优先本地封面文件，其次网络封面；加载失败或无封面时显示渐变占位图
 */
@Component
export struct CoverImage {
  @Prop coverPath: string = '';
  @Prop coverUrl: string = '';
  @Prop imgSize: number = 46;
  @Prop radius: number = 6;
  @State failedSrc: string = '';

  private candidate(): string {
    if (this.coverPath) {
      return `file://${this.coverPath}`;
    }
    if (this.coverUrl) {
      return this.coverUrl;
    }
    return '';
  }

  build() {
    Stack() {
      if (this.candidate() !== '' && this.failedSrc !== this.candidate()) {
        Image(this.candidate())
          .width(this.imgSize)
          .height(this.imgSize)
          .borderRadius(this.radius)
          .objectFit(ImageFit.Cover)
          .onError(() => {
            this.failedSrc = this.candidate();
          })
      } else {
        Column() {
          Text('♪').fontSize(this.imgSize * 0.42).fontColor('#8C8570')
        }
        .width(this.imgSize)
        .height(this.imgSize)
        .borderRadius(this.radius)
        .justifyContent(FlexAlign.Center)
        .linearGradient({ angle: 135, colors: [['#EFE9D8', 0], ['#DCD4BE', 1]] })
      }
    }
    .width(this.imgSize)
    .height(this.imgSize)
  }
}
