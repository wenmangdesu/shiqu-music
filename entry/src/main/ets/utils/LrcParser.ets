/**
 * LRC歌词解析器
 * 支持：
 *  1. 标准逐行歌词：[mm:ss.xx]歌词内容（一行可含多个时间标签）
 *  2. 增强逐字歌词：[mm:ss.xx]<mm:ss.xx>字<mm:ss.xx>字...
 */
export class LrcWord {
  /** 开始时间(ms) */
  start: number = 0;
  /** 结束时间(ms) */
  end: number = 0;
  text: string = '';
}

export class LrcLine {
  /** 行开始时间(ms) */
  time: number = 0;
  /** 行文本 */
  text: string = '';
  /** 逐字时间信息（仅增强歌词有值） */
  words: LrcWord[] = [];
}

export class LrcData {
  lines: LrcLine[] = [];
  /** 是否为逐字歌词 */
  enhanced: boolean = false;
}

export class LrcParser {
  private static readonly TIME_RE: RegExp = /\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g;
  private static readonly WORD_RE: RegExp = /<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>/g;

  /**
   * 解析LRC文本；解析失败返回空行数组（UI显示"暂无歌词"）
   */
  static parse(text: string): LrcData {
    const data: LrcData = new LrcData();
    if (!text) {
      return data;
    }
    try {
      const arr: string[] = text.split(/\r?\n/);
      for (let i = 0; i < arr.length; i++) {
        const raw: string = arr[i];
        if (!raw) {
          continue;
        }
        // 1. 收集行内所有时间标签
        const times: number[] = [];
        const re: RegExp = /\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g;
        let m: RegExpExecArray | null = re.exec(raw);
        while (m !== null) {
          times.push(LrcParser.tagMs(m[1], m[2], m[3]));
          m = re.exec(raw);
        }
        if (times.length === 0) {
          continue;
        }
        // 2. 去掉时间标签得到内容
        const content: string = raw.replace(re, '').trim();
        if (!content) {
          continue;
        }
        // 3. 生成行（一行多个时间标签 => 拆成多行）
        for (let k = 0; k < times.length; k++) {
          const line: LrcLine = new LrcLine();
          line.time = times[k];
          line.text = content;
          data.lines.push(line);
        }
      }
      data.lines.sort((a: LrcLine, b: LrcLine) => a.time - b.time);
      // 4. 逐字歌词解析：填充每行的words与行结束时间
      for (let i = 0; i < data.lines.length; i++) {
        const line: LrcLine = data.lines[i];
        const nextTime: number = i + 1 < data.lines.length ? data.lines[i + 1].time : line.time + 5000;
        const words: LrcWord[] = LrcParser.parseWords(line.text, line.time, nextTime);
        if (words.length > 0) {
          line.words = words;
          data.enhanced = true;
        }
      }
      // 去重（同一时间同一内容）
      const out: LrcLine[] = [];
      for (let i = 0; i < data.lines.length; i++) {
        const cur: LrcLine = data.lines[i];
        if (out.length === 0 || cur.time - out[out.length - 1].time > 30) {
          out.push(cur);
        }
      }
      data.lines = out;
    } catch (err) {
      // 解析异常时返回空数据，由UI展示"暂无歌词"
    }
    return data;
  }

  /**
   * 二分查找当前播放位置对应的行索引（最后一行 time<=pos），未开始返回-1
   */
  static findIndex(lines: LrcLine[], pos: number): number {
    let lo: number = 0;
    let hi: number = lines.length - 1;
    let ans: number = -1;
    while (lo <= hi) {
      const mid: number = (lo + hi) >> 1;
      if (lines[mid].time <= pos) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /** 时间标签 -> 毫秒 */
  private static tagMs(min: string, sec: string, frac: string): number {
    const f: string = frac ? frac : '0';
    const fracVal: number = parseInt(f) / Math.pow(10, f.length);
    return Math.floor((parseInt(min) * 60 + parseInt(sec) + fracVal) * 1000);
  }

  /** 解析一行内的逐字标签，形如 <00:12.50>字词 */
  private static parseWords(content: string, lineStart: number, lineEnd: number): LrcWord[] {
    const words: LrcWord[] = [];
    if (content.indexOf('<') < 0) {
      return words;
    }
    const re: RegExp = /<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>/g;
    const texts: string[] = [];
    const times: number[] = [];
    let lastIdx: number = 0;
    let pending: number = lineStart;
    let m: RegExpExecArray | null = re.exec(content);
    while (m !== null) {
      if (m.index > lastIdx) {
        texts.push(content.substring(lastIdx, m.index));
        times.push(pending);
      }
      pending = LrcParser.tagMs(m[1], m[2], m[3]);
      lastIdx = re.lastIndex;
      m = re.exec(content);
    }
    if (lastIdx < content.length) {
      texts.push(content.substring(lastIdx));
      times.push(pending);
    }
    for (let i = 0; i < texts.length; i++) {
      const w: LrcWord = new LrcWord();
      w.text = texts[i];
      w.start = times[i];
      w.end = i + 1 < times.length ? times[i + 1] : lineEnd;
      if (w.text.trim().length > 0) {
        words.push(w);
      }
    }
    return words;
  }
}
