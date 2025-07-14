/**
 * @fileName : FileManager.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description :  文件处理
 */

import { fileIo } from '@kit.CoreFileKit'
import { FileItem } from '../models/FileItem'
import { Utils } from '../utils/Utils'
import { bundleManager } from "@kit.AbilityKit";

class SandboxDir {
  static el1 = '/data/storage/el1'
  static el2 = '/data/storage/el2'
  static base = '/base'
  static database = '/database'
  static distributedfiles = '/distributedfiles'
}

interface LRUCacheEntry {
  filePath: string
  cachePath: string
  lastAccess: number
}

export class FileManager {
  private serverDir = 'sandboxfinder-static-server'
  private staticDir = 'static'
  private serverPath: string
  private context: Context
  private contextFilesDir: string
  private lruCache: Map<string, LRUCacheEntry> = new Map()
  private maxCacheCount = 10 // 最大缓存数
  private bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)

  constructor(context: Context) {
    this.context = context
    this.contextFilesDir = context.filesDir
    this.serverPath = context.filesDir + '/' + this.serverDir
    this.initServerDir()
  }

  public getServerPath() {
    return this.serverPath
  }

  private async initServerDir(): Promise<void> {
    try {
      await this.ensureDirectoryExists(this.serverPath)
      await this.createServerFiles()
      const staticPath = this.serverPath + '/' + this.staticDir
      await this.ensureDirectoryExists(staticPath)
    } catch (error) {
      console.error('初始化根目录失败:', error)
    }
  }

  // 获取缓存文件路径（原文件名）
  private getCacheFileName(filePath: string): string {
    // 只取文件名部分
    return filePath.split('/').pop() || 'file';
  }

  // LRU缓存：获取或拷贝到缓存，并返回缓存路径（原文件名，重名直接覆盖）
  public async getOrCacheFile(filePath: string): Promise<string> {
    const cacheFileName = this.getCacheFileName(filePath)
    const staticPath = '/' + this.staticDir + '/' + cacheFileName
    const cachePath = this.serverPath + staticPath
    const now = Date.now()
    // 命中缓存（同路径）
    if (this.lruCache.has(filePath)) {
      const entry = this.lruCache.get(filePath)!
      entry.lastAccess = now
      this.lruCache.delete(filePath)
      this.lruCache.set(filePath, entry)
      return staticPath
    }
    // 若缓存目录下已有同名文件但filePath不同，先删掉旧缓存
    for (const entry of this.lruCache.entries()) {
      const key = entry[0]
      const value = entry[1]
      if (value.cachePath === cachePath && key !== filePath) {
        try {
          await fileIo.unlink(value.cachePath)
        } catch {
        }
        this.lruCache.delete(key)
        break
      }
    }
    // 拷贝到缓存（覆盖）
    await this.copyFile(filePath, cachePath)
    this.lruCache.set(filePath, { filePath, cachePath, lastAccess: now })
    // 超出最大缓存，LRU淘汰
    if (this.lruCache.size > this.maxCacheCount) {
      // 找到最久未访问
      let oldestKey = ''
      let oldestTime = now
      for (const entry of this.lruCache.entries()) {
        const key = entry[0]
        const value = entry[1]
        if (value.lastAccess < oldestTime) {
          oldestTime = value.lastAccess
          oldestKey = key
        }
      }
      if (oldestKey) {
        const oldEntry = this.lruCache.get(oldestKey)!
        try {
          await fileIo.unlink(oldEntry.cachePath)
        } catch {
        }
        this.lruCache.delete(oldestKey)
      }
    }
    return staticPath
  }

  // 分块追加写入大文件，支持 isFirst 控制覆盖/追加
  public async appendFileStream(filePath: string, data: Uint8Array, isFirst: boolean = false): Promise<void> {
    const dirPath = filePath.substring(0, filePath.lastIndexOf('/'));
    await this.ensureDirectoryExists(dirPath);
    const openMode = isFirst
      ? fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      : fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.APPEND;
    const file = await fileIo.open(filePath, openMode);
    const CHUNK_SIZE = 2 * 1024 * 1024;
    let offset = 0;
    while (offset < data.length) {
      const chunk = data.slice(offset, offset + CHUNK_SIZE);
      await fileIo.write(file.fd, chunk.buffer, { offset: 0, length: chunk.length });
      offset += CHUNK_SIZE;
    }
    await fileIo.close(file.fd);
  }

  // 流式写入大文件，data为Uint8Array
  public async writeFileStream(filePath: string, data: Uint8Array): Promise<void> {
    const dirPath = filePath.substring(0, filePath.lastIndexOf('/'));
    await this.ensureDirectoryExists(dirPath);
    const file =
      await fileIo.open(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    const CHUNK_SIZE = 2 * 1024 * 1024; // 2MB分块
    let offset = 0;
    while (offset < data.length) {
      const chunk = data.slice(offset, offset + CHUNK_SIZE);
      await fileIo.write(file.fd, chunk.buffer, { offset: 0, length: chunk.length });
      offset += CHUNK_SIZE;
    }
    await fileIo.close(file.fd);
  }

  // 检查文件是否存在
  public async checkFileExists(path: string): Promise<boolean> {
    return await fileIo.access(path)
  }

  // 创建沙箱Finder
  private async createServerFiles(): Promise<void> {
    try {
      await this.copyToServerPath("index.html")
      await this.copyToServerPath("vue3.5.17.js")
      await this.copyToServerPath("sql.js")
      await this.copyToServerPath("fontawesome.css")

    } catch (error) {
      console.error('创建沙箱Finder失败:', error)
    }
  }

  // 拷贝到沙箱服务器目录
  private async copyToServerPath(fileName: string) {
    const path = this.serverPath + '/' + fileName
    const rawPath = this.serverDir + '/' + fileName
    const buf = await this.context.resourceManager.getRawFileContent(rawPath)
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

  private getDefaultItems(subs: string[], dirPath: string): FileItem[] {
    const fileInfos = subs.map(filename => {
      const filePath = dirPath + '/' + filename;
      const item = new FileItem();
      item.name = filename;
      item.path = filePath;
      item.isFolder = true
      return item;
    });
    return fileInfos
  }

  public contextDirs(): FileItem[] {
    const dataDir = this.contextFileItem('data', '/data')
    const filesDir = this.contextFileItem('filesDir', this.context.filesDir)
    const cacheDir = this.contextFileItem('cacheDir', this.context.cacheDir)
    const tempDir = this.contextFileItem('tempDir', this.context.tempDir)
    const databaseDir = this.contextFileItem('databaseDir', this.context.databaseDir)
    const preferencesDir = this.contextFileItem('preferencesDir', this.context.preferencesDir)
    const distributedFilesDir = this.contextFileItem('distributedFilesDir', this.context.distributedFilesDir)
    const cloudFileDir = this.contextFileItem('cloudFileDir', this.context.cloudFileDir)
    const bundleCodeDir = this.contextFileItem('bundleCodeDir', this.context.bundleCodeDir)

    return [dataDir, filesDir, cacheDir, tempDir, databaseDir, preferencesDir, distributedFilesDir, cloudFileDir,
      bundleCodeDir]
  }

  contextFileItem(name: string, path: string): FileItem {
    const item = new FileItem();
    item.name = name;
    item.path = path;
    item.isFolder = true;
    return item
  }

  // 列出目录内容（ls）
  public async listDir(dirPath: string): Promise<FileItem[]> {
    if (dirPath === '' || dirPath === '/data') {
      return this.getDefaultItems(['storage'], '/data')
    }

    if (dirPath === '/data/storage') {
      return this.getDefaultItems(['el1', 'el2'], dirPath)
    }

    if (dirPath === '/data/storage/el1' || dirPath === '/data/storage/el2') {
      return this.getDefaultItems(['base', 'database'], dirPath)
    }

    if (dirPath === '/') {
      return this.contextDirs()
    }

    let filenames = await fileIo.listFile(dirPath);
    if (dirPath === this.contextFilesDir) {
      filenames = filenames.filter(e => e !== this.serverDir)
    }
    const fileInfos = await Promise.all(filenames.map(async filename => {
      const filePath = dirPath + '/' + filename;
      const stat = await fileIo.stat(filePath);
      const item = new FileItem();
      item.name = filename;
      item.path = filePath;
      item.size = stat.size
      item.modified = stat.mtime
      item.isFolder = stat.isDirectory();
      item.ext = item.isFolder ? '' : this.getExtension(filePath)
      return item;
    }));

    return fileInfos;
  }

  // 新建空文件（touch）
  public async touch(filePath: string): Promise<void> {
    const dirPath = filePath.substring(0, filePath.lastIndexOf('/'));
    await this.ensureDirectoryExists(dirPath);
    const file =
      await fileIo.open(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    await fileIo.close(file.fd);
  }

  // 删除文件或目录（rm）
  public async remove(path: string): Promise<void> {
    const stat = await fileIo.stat(path);
    if (stat.isDirectory()) {
      await fileIo.rmdir(path);
    } else {
      await fileIo.unlink(path);
    }
  }

  // 重命名/移动（mv）
  public async move(src: string, dest: string): Promise<void> {
    await fileIo.rename(src, dest);
  }

  // 复制文件或目录（cp）
  public async copy(src: string, dest: string): Promise<void> {
    const stat = await fileIo.stat(src);
    if (stat.isDirectory()) {
      await this.copyDirectory(src, dest);
    } else {
      await this.copyFile(src, dest);
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
    const dirPath = filePath.substring(0, filePath.lastIndexOf('/'));
    await this.ensureDirectoryExists(dirPath);
    const file =
      await fileIo.open(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    await fileIo.write(file.fd, content);
    await fileIo.close(file.fd);
  }

  // 读文本文件
  public async readFile(filePath: string): Promise<string> {
    const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
    const stat = await fileIo.stat(filePath);
    const buffer = new ArrayBuffer(stat.size);
    await fileIo.read(file.fd, buffer);
    await fileIo.close(file.fd);
    const content = Utils.uint8ToStr(new Uint8Array(buffer))
    return content
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
    const ext = this.getExtension(filePath)

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
      // sqlite 数据库类型
      'sqlite': 'application/x-sqlite3',
      'db': 'application/x-sqlite3',
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

  getExtension(filePath: string): string {
    const ext = filePath.split('.').pop()?.toLowerCase() || ''
    return ext
  }

  isPlainText(filePath: string): boolean {
    const ext = this.getExtension(filePath)
    const plainTextExtensions = [
      'txt', 'html', 'htm', 'css', 'scss', 'sass', 'less', 'js', 'jsx', 'ts', 'tsx', 'plist',
      'json', 'json5', 'jsonc', 'xml', 'yaml', 'yml', 'toml', 'ini', 'env', 'md', 'markdown',
      'vue', 'svelte', 'astro', 'php', 'py', 'java', 'c', 'cpp', 'h', 'hpp',
      'go', 'rs', 'swift', 'kt', 'scala', 'rb', 'pl', 'pm', 'lua', 'r', 'sql', 'dbml',
      'sh', 'bash', 'zsh', 'ps1', 'bat', 'cmd', 'gitignore', 'dockerfile', 'editorconfig',
      'eslintrc', 'prettierrc', 'conf', 'config', 'log', 'csv', 'tsv', 'properties',
      'diff', 'patch', 'ad', 'adoc', 'rst', 'tex', 'latex', 'org', 'asciidoc',
      'pug', 'jade', 'styl', 'stylus', 'dart', 'fs', 'fsx', 'ml', 'mli', 'erl',
      'ex', 'exs', 'elixir', 'hs', 'purs', 'ada', 'd', 'jl', 'm', 'mm', 'pde', 'sml',
      'thrift', 'proto', 'graphql', 'gql', 'sol', 'solidity', 'wgsl', 'cypher', 'dot', 'edn',
      'haxe', 'hx', 'idris', 'idr', 'julia', 'kotlin', 'lean', 'lean4', 'lisp',
      'mercury', 'nim', 'nix', 'ocaml', 'pascal', 'pas', 'perl', 'prolog', 'pro', 'python',
      'racket', 'rkt', 'reason', 're', 'rust', 'sc', 'shell', 'swift', 'tcl', 'tk', 'vala', 'v', 'vb',
      'vhdl', 'vim', 'wren', 'zig', 'webmanifest', 'lock', 'npmrc', 'yarnrc', 'yarnrc.yml',
      'pnpm-lock', 'pnpmrc', 'browserslist', 'prettierignore', 'eslintignore', 'gitattributes',
      'dockerignore', 'npmignore', 'env.example', 'dotenv', 'tern-project', 'jsbeautifyrc',
      'stylelintrc', 'markdownlintrc', 'htmlhintrc', 'csscomb', 'tsconfig', 'jsconfig',
      'nodemon.json', 'nginx.conf', 'htaccess', 'php.ini', 'robots.txt', 'sitemap.xml', 'rss', 'atom'
    ]
    return plainTextExtensions.includes(ext)
  }

  async getAppInfo(): Promise<Record<string, Object>> {
    let name = ''
    const labelId = this.bundleInfo.appInfo?.labelId
    if (labelId) {
      name = this.context.resourceManager.getStringSync(labelId)
    } else {
      name = this.context.resourceManager.getStringByNameSync('app_name')
    }
    return {
      'versionCode': this.bundleInfo.versionCode,
      'versionName': this.bundleInfo.versionName,
      'bundleName': this.bundleInfo.name,
      'name': name
    }
  }
}
