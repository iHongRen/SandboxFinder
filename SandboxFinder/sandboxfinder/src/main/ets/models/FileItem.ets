/**
 * @fileName : FileItem.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : 文件描述
 */

@Observed
export class FileItem {
  name: string = ''
  size?: number = 0
  path?: string = ''
  isFolder?: boolean = false
  ext: string = ''
  modified?: number = 0
}