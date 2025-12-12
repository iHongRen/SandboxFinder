/**
 * @fileName : RequestHandler.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : HTTP请求处理相关逻辑
 */


import { buffer, util } from '@kit.ArkTS';
import { ApiHandler } from './ApiHandler';
import { FileManager } from '../manager/FileManager';
import { Utils } from '../utils/Utils';
import { socket } from '@kit.NetworkKit';

export class RequestHandler {
  private fileManager: FileManager;
  private apiHandler: ApiHandler;

  constructor(fileManager: FileManager, serverInfo: socket.NetAddress) {
    this.fileManager = fileManager;
    this.apiHandler = new ApiHandler(fileManager, serverInfo);
  }

  // 解析 HTTP 头部
  private parseHeaders(headersStr: string): Record<string, string> {
    const headers: Record<string, string> = {};
    const lines = headersStr.split('\r\n')

    for (const line of lines) {
      if (!line) {
        continue;
      }
      const list = line.split(': ', 2);
      headers[list[0].toLowerCase()] = list[1];
    }
    return headers;
  }

  // 处理HTTP请求
  public async handleHttpRequest(data: Uint8Array): Promise<string | ArrayBuffer> {
    const decoder = util.TextDecoder.create()
    const requestData = decoder.decodeToString(data);
    const headerBodySplitIndex = requestData.indexOf('\r\n\r\n');
    const headersStr = requestData.substring(0, headerBodySplitIndex);
    const lines = headersStr.split('\r\n');
    const firstLine = lines[0]
    const firstList = firstLine.split(' ');
    const method = firstList[0]
    // 修复：url 需 decodeURIComponent 还原真实路径，防止中文/空格/特殊字符出错
    let url = firstList[1]
    try {
      // 先将所有 + 替换为 %20，再 decodeURIComponent，彻底兼容空格
      url = decodeURIComponent(url.replace(/\+/g, '%20'))
    } catch {
    }

    // 提取头部和主体
    const headersLines = lines.slice(1); // 跳过请求行
    const headers = this.parseHeaders(headersLines.join('\r\n'));

    // 处理CORS预检请求（OPTIONS）
    if (method === 'OPTIONS') {
      return this.createHttpResponse(200, '', 'text/plain');
    }

    const contentType = headers['content-type'];
    let bodyParams: Record<string, Object> = {};
    // 解析 application/x-www-form-urlencoded body
    if (method === 'POST' && contentType && contentType.includes('application/x-www-form-urlencoded')) {
      const bodyStr = requestData.substring(headerBodySplitIndex + 4);
      bodyStr.split('&').forEach(pair => {
        if (!pair) {
          return;
        }
        const arr = pair.split('=');
        const k = arr[0];
        const v = arr[1];
        bodyParams[k] = v;
      });
    }

    if (contentType?.includes('multipart/form-data')) {
      // 处理文件上传
      if (url.startsWith('/api/upload') && method === 'POST') {
        return await this.handleMultipart(data, contentType, url)
      }
    }

    // 处理API请求
    if (url.startsWith('/api/')) {
      const result = await this.apiHandler.handleApiRequest(method, url, bodyParams);
      return this.createHttpResponse(result.code, JSON.stringify(result), 'application/json');
    }

    // 处理静态文件请求
    return await this.handleStaticFileRequest(url);
  }

  private async handleMultipart(data: Uint8Array, contentType: string, url: string): Promise<string | ArrayBuffer> {

    const boundary = this.extractBoundary(contentType);
    const formData = this.parseMultipartFormData(data, boundary);

    // 获取文件和文件名及分块参数
    const fileData = formData.get('file') as Uint8Array;
    const fileName = formData.get('filename') as string;
    const path = formData.get('path') as string || '';
    const isFirst = formData.get('isFirst') === '1';

    if (fileData && fileName) {
      try {
        await this.fileManager.appendFileStream(`${path}/${fileName}`, fileData, isFirst);
        return this.createHttpResponse(200, JSON.stringify({ success: true }), 'application/json');
      } catch (err) {
        return this.createHttpResponse(500, 'File save failed');
      }
    }
    return this.createHttpResponse(500, 'failed');
  }

  private splitMultipartData(data: Uint8Array, boundary: string): Uint8Array[] {
    const boundaryBytes = Utils.strToUint8Array(`--${boundary}`);
    const parts: Uint8Array[] = [];
    let startIndex = 0;

    while (true) {
      const endIndex = this.findBoundary(data, boundaryBytes, startIndex);
      if (endIndex === -1) {
        break;
      }

      if (endIndex > startIndex) {
        parts.push(data.slice(startIndex, endIndex));
      }
      startIndex = endIndex + boundaryBytes.length + 2; // +2 for CRLF
    }
    return parts.filter(part => part.length > 0);
  }

  private findBoundary(data: Uint8Array, boundary: Uint8Array, start: number): number {
    for (let i = start; i <= data.length - boundary.length; i++) {
      let match = true;
      for (let j = 0; j < boundary.length; j++) {
        if (data[i + j] !== boundary[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        // Check for CRLF before the boundary, and CRLF after the boundary
        if (i > 0 && data[i - 1] === 0x0A && data[i - 2] === 0x0D) {
          return i - 2; // Return start of CRLF before boundary
        }
      }
    }
    return -1;
  }

  private parseMultipartFormData(data: Uint8Array,
    boundary: string): Map<string, string | ArrayBuffer> {
    const parts = this.splitMultipartData(data, boundary);
    const result = new Map<string, string | ArrayBuffer>();

    for (const part of parts) {
      let headersEnd = -1;
      const CRLF_CRLF = new Uint8Array([0x0D, 0x0A, 0x0D, 0x0A]);
      for (let i = 0; i <= part.length - CRLF_CRLF.length; i++) {
        if (part[i] === CRLF_CRLF[0] &&
          part[i + 1] === CRLF_CRLF[1] &&
          part[i + 2] === CRLF_CRLF[2] &&
          part[i + 3] === CRLF_CRLF[3]) {
          headersEnd = i;
          break;
        }
      }

      if (headersEnd === -1) {
        continue;
      }

      const headers = Utils.uint8ToStr(part.slice(0, headersEnd));
      const content = part.slice(headersEnd + 4); // Skip CRLF CRLF

      const nameMatch = headers.match(/name="([^"]+)"/);
      if (nameMatch && nameMatch[1]) {
        const name = nameMatch[1];
        const contentTypeMatch = headers.match(/Content-Type: ([^\r\n]+)/);

        if (contentTypeMatch) {
          // This is likely a file
          result.set(name, content); // 直接存 Uint8Array
        } else {
          // Assume text content
          result.set(name, Utils.uint8ToStr(content));
        }
      }
    }
    return result;
  }


  // 提取 multipart 边界符
  private extractBoundary(contentType: string): string {
    const match = /boundary=([^;]+)/.exec(contentType);
    return match ? `${match[1]}` : '';
  }

  // 处理静态文件请求
  private async handleStaticFileRequest(url: string): Promise<string | ArrayBuffer> {
    try {
      let filePath = url === '/' ? '/index.html' : url;
      filePath = this.fileManager.getServerPath() + filePath;

      // 检查文件是否存在
      const exists = await this.fileManager.checkFileExists(filePath);
      if (!exists) {
        return this.createHttpResponse(404, 'File not found');
      }

      const buffer = await this.fileManager.readFile(filePath)

      // 获取文件的MIME类型
      const contentType = this.fileManager.getContentType(filePath);

      return this.createHttpResponse(200, buffer, contentType);
    } catch (error) {
      console.error('读取文件失败:', error);
      return this.createHttpResponse(500, 'Internal Server Error');
    }
  }

  // 创建HTTP响应
  private createHttpResponse(statusCode: number, body: string | ArrayBuffer,
    contentType: string = 'text/html'): string | ArrayBuffer {
    const statusText = statusCode === 200 ? 'OK' :
      statusCode === 404 ? 'Not Found' :
        statusCode === 500 ? 'Internal Server Error' : 'Unknown';

    let bodyLength = typeof body === 'string' ? buffer.byteLength(body, 'utf8') : body.byteLength;

    let response = `HTTP/1.1 ${statusCode} ${statusText}\r\n` +
      `Content-Type: ${contentType}; charset=utf-8\r\n` +
      `Content-Length: ${bodyLength}\r\n` +
      `Connection: close\r\n` +
      `\r\n`;

    if (typeof body === 'string') {
      return response += body;
    } else {
      const headersBuffer = Utils.strToUint8Array(response);
      const responseBuffer = new Uint8Array(headersBuffer.byteLength + body.byteLength);

      responseBuffer.set(headersBuffer, 0);
      responseBuffer.set(new Uint8Array(body), headersBuffer.byteLength);
      return responseBuffer.buffer
    }

  }
}