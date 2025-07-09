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
      // await this.createFinder()
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

  async mkdir(path: string, name: string): Promise<boolean> {
    if (this.canMkdir(path)) {
      await this.ensureDirectoryExists(path + '/' + name.trim().replace('/', ''))
      return true
    }
    return false
  }

  // 列出目录内容（ls）
  public async listDir(dirPath: string): Promise<FileItem[]> {
    try {
      if (dirPath === '' || dirPath === '/' || dirPath === '/data/storage') {
        const fileInfos = await Promise.all(['el1', 'el2'].map(async filename => {
          const filePath = '/data/storage/' + filename;
          const item = new FileItem();
          item.name = filename;
          item.path = filePath;
          item.isFolder = true
          return item;
        }));
        return fileInfos
      }

      if (dirPath === '/data/storage/el1' || dirPath === '/data/storage/el2') {
        const fileInfos = await Promise.all(['base', 'database'].map(async filename => {
          const filePath = dirPath + '/' + filename;
          const item = new FileItem();
          item.name = filename;
          item.path = filePath;
          item.isFolder = true
          return item;
        }));
        return fileInfos
      }

      const filenames = await fileIo.listFile(dirPath, { recursion: false });
      const fileInfos = await Promise.all(filenames.map(async filename => {
        const filePath = dirPath + '/' + filename;
        const stat = await fileIo.stat(filePath);
        const item = new FileItem();
        item.name = filename;
        item.path = filePath;
        item.size = stat.size
        item.modified = stat.mtime
        item.isFolder = stat.isDirectory();
        item.ext = item.isFolder ? '' : (filename.split('.')?.pop()?.toLowerCase() || '');
        return item;
      }));
      return fileInfos;
    } catch (err) {
      console.error('listDir失败:', err);
      return [];
    }
  }

  // 读取文件内容（cat）
  // public async readFileContent(filePath: string): Promise<string> {
  //   try {
  //     const absPath = filePath.startsWith('/') ? filePath : this.serverPath + '/' + filePath;
  //     const file = await fileIo.open(absPath, fileIo.OpenMode.READ_ONLY);
  //     const stat = await fileIo.stat(absPath);
  //     const buf = new ArrayBuffer(stat.size);
  //     await fileIo.read(file.fd, buf);
  //     await fileIo.close(file.fd);
  //     // 假设文本文件 utf-8
  //     return String.fromCharCode.apply(null, new Uint8Array(buf));
  //   } catch (err) {
  //     console.error('readFileContent失败:', err);
  //     return '';
  //   }
  // }

  // 新建空文件（touch）
  public async touch(filePath: string): Promise<void> {
    const absPath = filePath.startsWith('/') ? filePath : this.serverPath + '/' + filePath;
    const dirPath = absPath.substring(0, absPath.lastIndexOf('/'));
    await this.ensureDirectoryExists(dirPath);
    const file =
      await fileIo.open(absPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    await fileIo.close(file.fd);
  }

  // 删除文件或目录（rm）
  public async remove(path: string, recursive: boolean = false): Promise<void> {
    const absPath = path.startsWith('/') ? path : this.serverPath + '/' + path;
    const stat = await fileIo.stat(absPath);
    if (stat.isDirectory()) {
      if (recursive) {
        await this.deleteDirectory(absPath);
      } else {
        await fileIo.rmdir(absPath);
      }
    } else {
      await fileIo.unlink(absPath);
    }
  }

  // 重命名/移动（mv）
  public async move(src: string, dest: string): Promise<void> {
    const absSrc = src.startsWith('/') ? src : this.serverPath + '/' + src;
    const absDest = dest.startsWith('/') ? dest : this.serverPath + '/' + dest;
    await fileIo.rename(absSrc, absDest);
  }

  // 复制文件或目录（cp）
  public async copy(src: string, dest: string, recursive: boolean = false): Promise<void> {
    const absSrc = src.startsWith('/') ? src : this.serverPath + '/' + src;
    const absDest = dest.startsWith('/') ? dest : this.serverPath + '/' + dest;
    const stat = await fileIo.stat(absSrc);
    if (stat.isDirectory()) {
      if (!recursive) {
        throw new Error('目录复制需 recursive=true');
      }
      await this.copyDirectory(absSrc, absDest);
    } else {
      await this.copyFile(absSrc, absDest);
    }
  }

  private async copyFile(src: string, dest: string): Promise<void> {
    const srcFile = await fileIo.open(src, fileIo.OpenMode.READ_ONLY);
    const stat = await fileIo.stat(src);
    const buf = new ArrayBuffer(stat.size);
    await fileIo.read(srcFile.fd, buf);
    await fileIo.close(srcFile.fd);
    const destFile =
      await fileIo.open(dest, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    await fileIo.write(destFile.fd, buf);
    await fileIo.close(destFile.fd);
  }

  private async copyDirectory(src: string, dest: string): Promise<void> {
    await this.ensureDirectoryExists(dest);
    const files = await fileIo.listFile(src);
    for (const file of files) {
      if (file === '.' || file === '..') {
        continue;
      }
      const srcPath = src + '/' + file;
      const destPath = dest + '/' + file;
      const stat = await fileIo.stat(srcPath);
      if (stat.isDirectory()) {
        await this.copyDirectory(srcPath, destPath);
      } else {
        await this.copyFile(srcPath, destPath);
      }
    }
  }

  // 写入/覆盖文件内容（write）
  public async writeFile(filePath: string, content: ArrayBuffer): Promise<void> {
    const absPath = filePath.startsWith('/') ? filePath : this.serverPath + '/' + filePath;
    const dirPath = absPath.substring(0, absPath.lastIndexOf('/'));
    await this.ensureDirectoryExists(dirPath);
    const file =
      await fileIo.open(absPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    await fileIo.write(file.fd, content);
    await fileIo.close(file.fd);
  }

  canMkdir(path: string): boolean {
    if (!path) {
      return false
    }

    if (path === this.serverPath) {
      return false
    }

    if (!path.startsWith(SandboxDir.el1) && !path.startsWith(SandboxDir.el2)) {
      return false
    }

    if (path === SandboxDir.el1 || path === SandboxDir.el2) {
      return false
    }
    return true
  }

  // 获取目录下的所有文件和文件夹
  // async getDirectoryContents(dirName: string): Promise<FileItem[]> {
  //   try {
  //     const dirPath = this.serverPath + '/' + dirName
  //
  //     // 读取目录内容
  //     let filenames = await fileIo.listFile(dirPath)
  //     const filters = ['__MACOSX', '.DS_Store']
  //     filenames = filenames.filter(e => !filters.includes(e))
  //
  //     // 并行获取每个条目的详细信息
  //     const fileInfos = await Promise.all(filenames.map(async filename => {
  //       const filePath = dirPath + '/' + filename
  //       const stat = await fileIo.stat(filePath)
  //
  //       const item = new FileItem()
  //       item.name = filename
  //       item.path = filePath
  //       item.size = this.formatSize(stat.size)
  //       item.modified = this.formatMtime(stat.mtime)
  //       item.isFolder = stat.isDirectory()
  //       return item
  //     }))
  //
  //     return fileInfos
  //   } catch (err) {
  //     console.error('获取目录内容失败:', err)
  //     return []
  //   }
  // }

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
      const file =
        await fileIo.open(fullPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
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
