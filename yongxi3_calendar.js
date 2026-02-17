#!/usr/bin/env node

const fs = require('fs');

const TIAN_GAN = '甲乙丙丁戊己庚辛壬癸';
const DI_ZHI = '子丑寅卯辰巳午未申酉戌亥';
const JIAN_CHU = ['建', '除', '满', '平', '定', '执', '破', '危', '成', '收', '开', '闭'];
const MONTH_MAP = new Map([
  ['正', 1], ['二', 2], ['三', 3], ['四', 4], ['五', 5], ['六', 6],
  ['七', 7], ['八', 8], ['九', 9], ['十', 10], ['十一', 11], ['十二', 12], ['腊', 12]
]);

function jdn(y, m, d) {
  const a = Math.floor((14 - m) / 12);
  const y2 = y + 4800 - a;
  const m2 = m + 12 * a - 3;
  return d + Math.floor((153 * m2 + 2) / 5) + 365 * y2 + Math.floor(y2 / 4) - Math.floor(y2 / 100) + Math.floor(y2 / 400) - 32045;
}

function dayGanzhi(y, m, d) {
  const j = jdn(y, m, d);
  const gan = TIAN_GAN[(j + 9) % 10];
  const zhiIdx = (j + 1) % 12;
  return { ganzhi: gan + DI_ZHI[zhiIdx], zhiIdx };
}

function parseMonth(monthText) {
  const leap = monthText.startsWith('闰');
  const core = (leap ? monthText.slice(1) : monthText).replace('月', '');
  const monthNum = MONTH_MAP.get(core);
  if (!monthNum) throw new Error(`Unknown month: ${monthText}`);
  return { monthNum, leap };
}

const fmt = new Intl.DateTimeFormat('zh-Hans-CN-u-ca-chinese', {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  timeZone: 'UTC'
});

function getParts(utcDate) {
  const parts = fmt.formatToParts(utcDate);
  const obj = {};
  for (const p of parts) obj[p.type] = p.value;
  return obj;
}

let rows = [];
const start = Date.UTC(985, 0, 1);
const end = Date.UTC(987, 11, 31);
for (let t = start; t <= end; t += 86400000) {
  const d = new Date(t);
  const parts = getParts(d);
  if (Number(parts.relatedYear) !== 986) continue;

  const y = d.getUTCFullYear();
  const m = d.getUTCMonth() + 1;
  const day = d.getUTCDate();
  const { ganzhi, zhiIdx } = dayGanzhi(y, m, day);
  const { monthNum, leap } = parseMonth(parts.month);
  const monthBranchIdx = (monthNum + 1) % 12;
  const jianchu = JIAN_CHU[(zhiIdx - monthBranchIdx + 12) % 12];

  rows.push([
    `${y.toString().padStart(4, '0')}-${m.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`,
    `${leap ? '闰' : ''}${monthNum}月${parts.day}日`,
    parts.yearName || '',
    ganzhi,
    jianchu
  ]);
}

const header = ['公历', '农历', '年干支', '日干支', '五行建除'];
const csv = [header, ...rows]
  .map(r => r.map(v => `"${String(v).replaceAll('"', '""')}"`).join(','))
  .join('\n');

fs.writeFileSync('yongxi3_daily_calendar.csv', '\uFEFF' + csv);
console.log(`Wrote ${rows.length} rows to yongxi3_daily_calendar.csv`);
