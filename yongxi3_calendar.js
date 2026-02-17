#!/usr/bin/env node

const STEMS = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const BRANCHES = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
const JIAN_CHU = ['建','除','满','平','定','执','破','危','成','收','开','闭'];
const STEM_WUXING = {
  '甲':'木','乙':'木','丙':'火','丁':'火','戊':'土',
  '己':'土','庚':'金','辛':'金','壬':'水','癸':'水'
};

// 正月起寅
const MONTH_BRANCHES = ['寅','卯','辰','巳','午','未','申','酉','戌','亥','子','丑'];

function gregorianToJdn(y, m, d) {
  const a = Math.floor((14 - m) / 12);
  const y2 = y + 4800 - a;
  const m2 = m + 12 * a - 3;
  return d + Math.floor((153 * m2 + 2) / 5) + 365 * y2 + Math.floor(y2 / 4) - Math.floor(y2 / 100) + Math.floor(y2 / 400) - 32045;
}

function gzFromIndex(idx) {
  const i = ((idx % 60) + 60) % 60;
  return STEMS[i % 10] + BRANCHES[i % 12];
}

function dayGanzhi(y, m, d) {
  const jdn = gregorianToJdn(y, m, d);
  // 1984-02-02 为甲子日，对应索引 0
  const base = gregorianToJdn(1984, 2, 2);
  return gzFromIndex(jdn - base);
}

function parseChineseLunar(date) {
  const fmt = new Intl.DateTimeFormat('zh-u-ca-chinese', {
    year: 'numeric', month: 'long', day: 'numeric', weekday: 'long', timeZone: 'UTC'
  });
  const parts = fmt.formatToParts(date);
  const get = (type) => (parts.find(p => p.type === type) || {}).value;
  const lunarYearNum = Number(get('relatedYear'));
  const lunarYearGz = get('yearName');
  const lunarMonthName = get('month');
  const lunarDayName = get('day');
  const weekday = get('weekday') || '';
  const weekdayCn = weekday.replace('星期', '');
  if (!lunarYearNum || !lunarYearGz || !lunarMonthName || !lunarDayName) {
    throw new Error(`无法解析农历: ${fmt.format(date)}`);
  }
  return { lunarYearNum, lunarYearGz, lunarMonthName, lunarDayName, weekdayCn };
}

function monthGanzhi(yearStem, lunarMonthName) {
  const clean = lunarMonthName.replace('闰', '');
  const monthOrderMap = {
    '正月':1,'一月':1,'二月':2,'三月':3,'四月':4,'五月':5,'六月':6,
    '七月':7,'八月':8,'九月':9,'十月':10,'十一月':11,'冬月':11,'十二月':12,'腊月':12
  };
  const m = monthOrderMap[clean];
  const yStem = yearStem;
  const startStemByYearStem = {
    '甲':'丙','己':'丙','乙':'戊','庚':'戊','丙':'庚','辛':'庚','丁':'壬','壬':'壬','戊':'甲','癸':'甲'
  };
  const startStem = startStemByYearStem[yStem];
  const stemIdx = STEMS.indexOf(startStem);
  const monthStem = STEMS[(stemIdx + (m - 1)) % 10];
  const monthBranch = MONTH_BRANCHES[m - 1];
  return { order: m, gz: monthStem + monthBranch, branch: monthBranch };
}

const months = [];
let current = null;
for (let month = 1; month <= 12; month++) {
  const maxDay = new Date(Date.UTC(986, month, 0)).getUTCDate();
  for (let day = 1; day <= maxDay; day++) {
    const date = new Date(Date.UTC(986, month - 1, day));
    const lunar = parseChineseLunar(date);
    const key = `${lunar.lunarYearNum}-${lunar.lunarMonthName}`;
    if (!current || current.key !== key) {
      current = {
        key,
        lunarYearNum: lunar.lunarYearNum,
        lunarYearGz: lunar.lunarYearGz,
        lunarMonthName: lunar.lunarMonthName,
        days: [],
      };
      months.push(current);
    }
    const dgz = dayGanzhi(986, month, day);
    const dStem = dgz[0];
    const dBranch = dgz[1];
    const monthInfo = monthGanzhi(lunar.lunarYearGz[0], lunar.lunarMonthName);
    const diff = (BRANCHES.indexOf(dBranch) - BRANCHES.indexOf(monthInfo.branch) + 12) % 12;
    current.days.push({
      gDate: `986-${String(month).padStart(2,'0')}-${String(day).padStart(2,'0')}`,
      lunarDayName: lunar.lunarDayName,
      weekdayCn: lunar.weekdayCn,
      dayGanzhi: dgz,
      wuxing: STEM_WUXING[dStem],
      jianchu: JIAN_CHU[diff],
    });
  }
}

for (const m of months) {
  const yearStem = m.lunarYearGz[0];
  const mgzInfo = monthGanzhi(yearStem, m.lunarMonthName);
  m.monthGanzhi = mgzInfo.gz;
  m.monthSize = m.days.length === 29 ? '小建' : '大建';
}

let html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>雍熙三年（986）日历</title>
<style>
body{font-family:"Noto Serif CJK SC","Songti SC",serif;margin:20px;}
.grid{display:flex;flex-direction:row-reverse;gap:12px;align-items:flex-start;overflow:auto;}
.month{border:1px solid #999;padding:6px;writing-mode:vertical-rl;text-orientation:upright;line-height:1.5;background:#fff;}
.header{font-weight:700;border-left:1px solid #ccc;padding-left:4px;margin-left:4px;}
.day{border-left:1px dotted #ddd;padding-left:4px;margin-left:4px;}
.mii{color:#c2185b;font-weight:700;}
small{font-size:12px;color:#555;}
</style></head><body>
<h1>雍熙三年（按公元986年逐日）农历/干支/五行/建除</h1>
<p><small>说明：采用 UTC 日期逐日换算；“蜜”标记为星期日。</small></p>
<div class="grid">
`;
for (const m of months) {
  html += `<div class="month">`;
  html += `<div class="header">${m.lunarMonthName}${m.monthSize}${m.monthGanzhi}</div>`;
  for (const d of m.days) {
    html += `<div class="day"><span class="mii">${d.weekdayCn === '日' || d.weekdayCn === '天' ? '蜜' : '　'}</span>${d.lunarDayName}${d.dayGanzhi}${d.wuxing}${d.jianchu}</div>`;
  }
  html += `</div>`;
}
html += `</div></body></html>`;

require('fs').writeFileSync('yongxi3_calendar.html', html, 'utf8');
console.log('已生成 yongxi3_calendar.html');
