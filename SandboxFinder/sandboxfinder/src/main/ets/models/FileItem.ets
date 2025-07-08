/**
 * @fileName : FileItem.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : 文件描述
 */

@Observed
export class FileItem {
  name: string = ''
  date?: string = ''
  size?: string = ''
  path?: string = ''
  isFolder?: boolean = false
  url?: string = ''
}