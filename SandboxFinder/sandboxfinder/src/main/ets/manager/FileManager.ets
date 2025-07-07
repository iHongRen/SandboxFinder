/**
 * @fileName : FileManager.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description :  文件处理
 */

import { zlib } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { FileItem } from '../models/FileItem'

class SandboxDir {
  static el1 = '/data/storage/el1'
  static el2 = '/data/storage/el2'
  static base = '/base'
  static database = '/database'
  static distributedfiles = '/distributedfiles'
}

export class FileManager {
  private serverDir = '/sandboxfinder-static-server'
  private serverPath: string
  private context: Context

  constructor(context: Context) {
    this.context = context
    const serverPath = context.filesDir + this.serverDir
    this.serverPath = serverPath
    this.initServerDir()
  }

  public getServerPath() {
    return this.serverPath
  }

  private async initServerDir(): Promise<void> {
    try {
      await this.ensureDirectoryExists(this.serverPath)
      await this.createFinder()
    } catch (error) {
      console.error('初始化根目录失败:', error)
    }
  }

  // 检查文件是否存在
  public async checkFileExists(path: string): Promise<boolean> {
    try {
      await fileIo.stat(path)
      return true
    } catch {
      return false
    }
  }

  // 创建沙箱Finder
  private async createFinder(): Promise<void> {
    try {
      await this.createFile("index.html")
      await this.createFile("script.js")
    } catch (error) {
      console.error('创建沙箱Finder失败:', error)
    }
  }

  private async createFile(fileName: string) {
    const path = this.serverPath + '/' + fileName
    const buf = await this.context.resourceManager.getRawFileContent(fileName)
    const outFile = await fileIo.open(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
    await fileIo.write(outFile.fd, buf.buffer)
    await fileIo.close(outFile.fd)
  }

  // 获取项目列表
  public async getProjectList(): Promise<FileItem[]> {
    try {
      let projects: FileItem[] = []
      const dir = await fileIo.listFile(this.serverPath)

      for (const item of dir) {
        if (item !== '.' && item !== '..' && item !== 'index.html') {
          const itemPath = this.serverPath + '/' + item
          const stat = await fileIo.stat(itemPath)

          if (stat.isDirectory()) {
            projects.push({
              name: item,
              date: this.formatMtime(stat.mtime),
              size: this.formatSize(stat.size),
            })
          }
        }
      }

      return projects
    } catch (error) {
      console.error('获取项目列表失败:', error)
      return []
    }
  }

  // 获取目录下的所有文件和文件夹
  async getDirectoryContents(dirName: string): Promise<FileItem[]> {
    try {
      const dirPath = this.serverPath + '/' + dirName

      // 读取目录内容
      let filenames = await fileIo.listFile(dirPath)
      const filters = ['__MACOSX', '.DS_Store']
      filenames = filenames.filter(e => !filters.includes(e))

      // 并行获取每个条目的详细信息
      const fileInfos = await Promise.all(filenames.map(async filename => {
        const filePath = dirPath + '/' + filename
        const stat = await fileIo.stat(filePath)

        const item = new FileItem()
        item.name = filename
        item.path = filePath
        item.size = this.formatSize(stat.size)
        item.date = this.formatMtime(stat.mtime)
        item.isDirectory = stat.isDirectory()
        return item
      }))

      return fileInfos
    } catch (err) {
      console.error('获取目录内容失败:', err)
      return []
    }
  }

  // 删除项目
  public async deleteProject(projectName: string): Promise<void> {
    try {
      const projectPath = this.serverPath + '/' + projectName
      await this.deleteDirectory(projectPath)
    } catch (error) {
      console.error('删除项目失败:', error)
    }
  }

  // 递归删除目录
  private async deleteDirectory(dirPath: string): Promise<void> {
    try {
      const files = await fileIo.listFile(dirPath)

      for (const file of files) {
        const filePath = dirPath + '/' + file
        const stat = await fileIo.stat(filePath)

        if (stat.isDirectory()) {
          await this.deleteDirectory(filePath)
        } else {
          await fileIo.unlink(filePath)
        }
      }

      await fileIo.rmdir(dirPath)
    } catch (error) {
      console.error('删除目录失败:', dirPath, error)
    }
  }

  // 创建项目目录
  public async createProject(projectName: string): Promise<void> {
    const projectPath = this.serverPath + '/' + projectName
    await fileIo.mkdir(projectPath)
  }

  // 写入项目文件
  public async writeProjectFile(projectName: string, content: ArrayBuffer): Promise<void> {
    try {
      const fullPath = this.context.tempDir + '/' + projectName

      // 确保目录存在
      const dirPath = fullPath.substring(0, fullPath.lastIndexOf('/'))
      await this.ensureDirectoryExists(dirPath)

      // 写入文件
      const file = await fileIo.open(fullPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      await fileIo.write(file.fd, content)

      const outFileDir = this.serverPath + '/' + projectName.replace(/\.[^/.]+$/, '')
      await this.ensureDirectoryExists(outFileDir)

      await zlib.decompressFile(fullPath, outFileDir)

      await fileIo.unlink(fullPath)
      await fileIo.close(file.fd)

    } catch (error) {
      console.error('写入项目文件失败:', error)
    }
  }

  // 确保目录存在
  private async ensureDirectoryExists(dirPath: string): Promise<void> {
    try {
      await fileIo.stat(dirPath)
    } catch {
      // 目录不存在，创建它
      await fileIo.mkdir(dirPath)
    }
  }

  // 根据文件扩展名获取Content-Type
  public getContentType(filePath: string): string {
    const extMatch = filePath.match(/\.([^./]+)$/)
    const ext = extMatch?.[1]?.toLowerCase() || ''

    const contentTypeMap: Record<string, string> = {
      // 文本类型
      'html': 'text/html',
      'htm': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
      'mjs': 'application/javascript',
      'json': 'application/json',
      'xml': 'application/xml',
      'txt': 'text/plain',
      'md': 'text/markdown',

      // 图片类型
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'svg': 'image/svg+xml',
      'webp': 'image/webp',
      'ico': 'image/x-icon',
      'avif': 'image/avif',

      // 字体类型
      'woff': 'font/woff',
      'woff2': 'font/woff2',
      'ttf': 'font/ttf',
      'otf': 'font/otf',

      // 多媒体类型
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'mp4': 'video/mp4',
      'webm': 'video/webm',

      // 其他常见类型
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'gz': 'application/gzip',
      'tar': 'application/x-tar',
      'wasm': 'application/wasm',
    }

    return contentTypeMap[ext] || 'application/octet-stream'
  }

  formatMtime(mtime: number): string {
    const date = new Date(mtime * 1000)
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    const seconds = String(date.getSeconds()).padStart(2, '0')

    return `${year}/${month}/${day} ${hours}:${minutes}:${seconds}`
  }

  formatSize(size: number): string {
    if (size === 0) {
      return '0 B'
    }

    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']
    const index = Math.floor(Math.log(size) / Math.log(1024))
    const value = size / Math.pow(1024, index)
    return `${value.toFixed(2)} ${units[index]}`
  }
}
