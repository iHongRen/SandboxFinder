/**
 * @fileName : Response.ets
 * @author : @cxy
 * @date : 2025/7/10
 * @description : 文件描述
 */

export interface Response {
  code: number
  message?: string
  data?: ESObject
}