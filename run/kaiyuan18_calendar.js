#!/usr/bin/env node

const TG = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const DZ = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
const WUXING_BY_TG = { '甲':'木','乙':'木','丙':'火','丁':'火','戊':'土','己':'土','庚':'金','辛':'金','壬':'水','癸':'水' };
const JIANCHU = ['建','除','满','平','定','执','破','危','成','收','开','闭'];
const MONTH_NUM_MAP = { '正月':1,'二月':2,'三月':3,'四月':4,'五月':5,'六月':6,'七月':7,'八月':8,'九月':9,'十月':10,'十一月':11,'十二月':12,'冬月':11,'腊月':12 };
const MONTH_LABELS = ['正月','二月','三月','四月','五月','六月','七月','八月','九月','十月','十一月','腊月'];

function jdn(y,m,d){ const a=Math.floor((14-m)/12); const y2=y+4800-a; const m2=m+12*a-3; return d+Math.floor((153*m2+2)/5)+365*y2+Math.floor(y2/4)-Math.floor(y2/100)+Math.floor(y2/400)-32045; }
function dayGanzhi(y,m,d){ const idx=(jdn(y,m,d)+47)%60; return { tg:TG[idx%10], dz:DZ[idx%12], name:TG[idx%10]+DZ[idx%12] }; }
function monthGanzhi(yearStem, monthNum){ const stemIdx=TG.indexOf(yearStem); const first=((stemIdx%5)*2+2)%10; return TG[(first+monthNum-1)%10]+DZ[(2+monthNum-1)%12]; }

const fmt = new Intl.DateTimeFormat('zh-u-ca-chinese',{year:'numeric',month:'long',day:'numeric',weekday:'short',timeZone:'UTC'});
const months = Array.from({length:12}, (_,i)=>({monthNum:i+1, monthName:MONTH_LABELS[i], days:[], hasLeap:false, normalSize:0, leapSize:0}));

for (let t=Date.UTC(729,0,1); t<=Date.UTC(731,11,31); t+=86400000) {
  const d=new Date(t);
  const parts=fmt.formatToParts(d);
  const mp=Object.fromEntries(parts.filter(p=>p.type!=='literal').map(p=>[p.type,p.value]));
  if (mp.relatedYear!=='730' || mp.yearName!=='庚午') continue;

  const leap=mp.month.startsWith('闰');
  const baseMonth=leap?mp.month.slice(1):mp.month;
  const monthNum=MONTH_NUM_MAP[baseMonth];
  const slot=months[monthNum-1];
  if (leap) slot.hasLeap=true;

  const y=d.getUTCFullYear(), m=d.getUTCMonth()+1, day=d.getUTCDate();
  const dgz=dayGanzhi(y,m,day);
  const jianchu=JIANCHU[(DZ.indexOf(dgz.dz)-((2+monthNum-1)%12)+12)%12];
  slot.days.push({
    lunarDay:Number(mp.day),
    dayPrefix: leap ? '闰' : '',
    weekdayRaw:d.getUTCDay(),
    dayGZ:dgz.name,
    wuxing:WUXING_BY_TG[dgz.tg],
    jianchu,
  });
  if (leap) slot.leapSize += 1; else slot.normalSize += 1;
}

for (const m of months) {
  const norm = m.normalSize===29?'小建':'大建';
  if (!m.hasLeap) m.sizeLabel = norm;
  else {
    const leap = m.leapSize===29?'闰小建':'闰大建';
    m.sizeLabel = `${norm}+${leap}`;
    m.monthName = `${m.monthName}(含闰)`;
  }
  m.monthGZ = monthGanzhi('庚', m.monthNum);
}

const ordered=[...months].reverse();
const maxRows=Math.max(...ordered.map(m=>m.days.length+3));
const table=[];
table.push(ordered.flatMap(m=>[`${m.monthName}(标记列)`,`${m.monthName}(日期列)`]));
for (let r=0;r<maxRows;r++) {
  const row=[];
  for (const m of ordered) {
    let c1='',c2='';
    if (r===0) c1=m.monthName;
    else if (r===1) c1=m.sizeLabel;
    else if (r===2) c1=m.monthGZ;
    else {
      const info=m.days[r-3];
      if (info){
        c1=info.weekdayRaw===0?'蜜':'';
        c2=`${info.dayPrefix}${info.lunarDay}日 ${info.dayGZ} ${info.wuxing} ${info.jianchu}`;
      }
    }
    if (r===0) c2='日期/干支/五行/建除';
    row.push(c1,c2);
  }
  table.push(row);
}

const lines=[];
lines.push('| '+table[0].join(' | ')+' |');
lines.push('| '+table[0].map(()=> '---').join(' | ')+' |');
for (let i=1;i<table.length;i++) lines.push('| '+table[i].join(' | ')+' |');
console.log(lines.join('\n'));
