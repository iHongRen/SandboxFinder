/**
 * @fileName : HttpServer.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : http服务器
 */


import { wifiManager } from '@kit.ConnectivityKit';
import { ServerInfo } from '../models/ServerInfo';
import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Utils } from '../utils/Utils';

export class HttpServer {
  private tcpServer: socket.TCPSocketServer | null = null;
  private serverAddress: string = '';
  private clientHandler: (requestData: Uint8Array) => Promise<string | ArrayBuffer>;
  // 定义存放客户端连接的数组
  private clients: socket.TCPSocketConnection[] = [];

  constructor(clientHandler: (requestData: Uint8Array) => Promise<string | ArrayBuffer>) {
    this.clientHandler = clientHandler;
  }

  // 启动服务器
  public async startServer(port: number): Promise<ServerInfo | void> {
    try {
      this.tcpServer = socket.constructTCPSocketServerInstance();

      // 监听连接
      this.tcpServer.on('connect', (clientSocket: socket.TCPSocketConnection) => {
        this.clients.push(clientSocket)
        this.handleClient(clientSocket);
      });

      // 监听错误
      this.tcpServer.on('error', (error: BusinessError) => {
        console.error('服务器错误:', error);
      });

      // 绑定到动态端口
      const bindAddress: socket.NetAddress = {
        address: '0.0.0.0',
        port: port
      };

      await this.tcpServer.listen(bindAddress);
      // 获取实际的端口和地址
      // const localAddress: socket.NetAddress = await this.tcpServer.getLocalAddress();
      // this.serverPort = localAddress.port || 8080;
      this.serverAddress = this.getLocalIP()
      console.log(`沙盒查看器启动成功，地址: ${this.serverAddress}:${port}`);
      return {
        address: this.serverAddress,
        port: port
      }
    } catch (error) {
      console.error('沙盒查看器启动失败:', error);
    }
  }

  // 停止服务器
  public async stopServer(): Promise<void> {
    return new Promise((resolve)=>{
      if (this.tcpServer) {
        this.tcpServer.off('connect', () => {
          this.clients = []
          this.tcpServer = null;
          resolve()
        })
      } else {
        resolve()
      }
      console.log('服务器已停止');
    })
  }

  // 处理客户端连接
  private handleClient(clientSocket: socket.TCPSocketConnection) {
    let receivedData = new ArrayBuffer(0);
    let isReceivingBody = false;
    let expectedContentLength = 0;
    let headerEndIndex = -1;

    clientSocket.on('message', async (data: socket.SocketMessageInfo) => {
      // 合并接收到的数据
      receivedData = Utils.mergeArrayBuffers(receivedData, data.message);

      if (!isReceivingBody) {
        // 查找HTTP头结束标志
        const headerStr = Utils.arrayBufferToStr(receivedData);
        headerEndIndex = headerStr.indexOf('\r\n\r\n');

        if (headerEndIndex !== -1) {
          isReceivingBody = true;
          // 解析Content-Length
          const contentLengthMatch = headerStr.match(/Content-Length:\s*(\d+)/i);
          if (contentLengthMatch) {
            expectedContentLength = parseInt(contentLengthMatch[1]);
          }
        }
      }

      // 检查是否接收完整个请求
      if (isReceivingBody) {
        const headerLength = headerEndIndex + 4; // '\r\n\r\n' 的长度
        const bodyLength = receivedData.byteLength - headerLength;

        if (bodyLength >= expectedContentLength) {

          // 处理完整数据
          const response = await this.clientHandler(new Uint8Array(receivedData));

          await clientSocket.send({
            data: response
          });
          return;
        }
      }

      // 如果没有Content-Length或者是GET请求，直接处理
      if (!isReceivingBody && headerEndIndex !== -1 && expectedContentLength === 0) {
        const response = await this.clientHandler(new Uint8Array(receivedData));

        await clientSocket.send({
          data: response
        })
      }


      clientSocket.on('error', (error: BusinessError) => {
        console.error('错误:', error);
      });

      clientSocket.on('close', () => {
        console.error('已关闭');
      });
    });
  }


  // 获取本地IP地址
  private getLocalIP(): string {
    const ipAddress = wifiManager.getIpInfo().ipAddress;
    const ip =
      (ipAddress >>> 24) + "." + (ipAddress >> 16 & 0xFF) + "." + (ipAddress >> 8 & 0xFF) + "." + (ipAddress & 0xFF);
    return ip
  }
}