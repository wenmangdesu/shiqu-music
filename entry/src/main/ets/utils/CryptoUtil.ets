/**
 * 加密工具：应用锁密码的 SHA-256 摘要
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

export class CryptoUtil {
  /** 计算文本的 SHA-256 十六进制摘要 */
  static async sha256Hex(text: string): Promise<string> {
    const md: cryptoFramework.Md = cryptoFramework.createMd('SHA-256');
    const encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
    const bytes: Uint8Array = encoder.encodeInto(text);
    await md.update({ data: bytes });
    const blob: cryptoFramework.DataBlob = await md.digest();
    let hex: string = '';
    blob.data.forEach((b: number) => {
      const s: string = b.toString(16);
      hex += s.length === 1 ? `0${s}` : s;
    });
    return hex;
  }
}
