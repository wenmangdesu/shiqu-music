/**
 * 格式化工具：时长/文件大小/速度/数量/文件名清洗
 */
export class FmtUtil {
  /** 毫秒 -> mm:ss 或 h:mm:ss */
  static fmtDuration(ms: number): string {
    if (!ms || ms < 0) {
      return '00:00';
    }
    const totalSec: number = Math.floor(ms / 1000);
    const h: number = Math.floor(totalSec / 3600);
    const m: number = Math.floor((totalSec % 3600) / 60);
    const s: number = totalSec % 60;
    const ss: string = s < 10 ? `0${s}` : `${s}`;
    if (h > 0) {
      const mm: string = m < 10 ? `0${m}` : `${m}`;
      return `${h}:${mm}:${ss}`;
    }
    const mm2: string = m < 10 ? `0${m}` : `${m}`;
    return `${mm2}:${ss}`;
  }

  /** 字节 -> 可读大小 */
  static fmtSize(bytes: number): string {
    if (!bytes || bytes <= 0) {
      return '0 B';
    }
    const units: string[] = ['B', 'KB', 'MB', 'GB'];
    let v: number = bytes;
    let i: number = 0;
    while (v >= 1024 && i < units.length - 1) {
      v = v / 1024;
      i++;
    }
    const txt: string = i === 0 ? `${Math.floor(v)}` : v.toFixed(1);
    return `${txt} ${units[i]}`;
  }

  /** 字节/秒 -> 可读速度 */
  static fmtSpeed(bps: number): string {
    if (!bps || bps <= 0) {
      return '--';
    }
    return `${FmtUtil.fmtSize(bps)}/s`;
  }

  /** 数量格式化：超过1万显示 x.x万 */
  static fmtCount(n: number): string {
    if (n >= 10000) {
      return `${(n / 10000).toFixed(1)}万`;
    }
    return `${n}`;
  }

  /** 清洗文件名中的非法字符 */
  static sanitizeFileName(name: string): string {
    return name.replace(/[\\/:*?"<>|\r\n]/g, '_').trim();
  }

  /** 获取小写扩展名 */
  static extOf(path: string): string {
    const idx: number = path.lastIndexOf('.');
    if (idx < 0 || idx === path.length - 1) {
      return '';
    }
    return path.substring(idx + 1).toLowerCase();
  }

  /** 去掉扩展名的文件名 */
  static baseName(path: string): string {
    let p: string = path;
    const slash: number = Math.max(p.lastIndexOf('/'), p.lastIndexOf('\\'));
    if (slash >= 0) {
      p = p.substring(slash + 1);
    }
    const dot: number = p.lastIndexOf('.');
    if (dot > 0) {
      p = p.substring(0, dot);
    }
    return p;
  }
}
