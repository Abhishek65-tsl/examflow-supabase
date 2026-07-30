import Papa from 'papaparse';
export const CSV_HEADERS=['test_title','subject','class_name','duration_minutes','starts_at','ends_at','question','option_a','option_b','option_c','option_d','correct_option','marks','explanation'];
export function downloadTemplate(){
 const sample={test_title:'Mathematics Mock 1',subject:'Mathematics',class_name:'Class 10',duration_minutes:45,starts_at:'2026-08-01T09:00:00+05:30',ends_at:'2026-08-08T18:00:00+05:30',question:'What is 2 + 2?',option_a:'3',option_b:'4',option_c:'5',option_d:'6',correct_option:'B',marks:1,explanation:'2 plus 2 is 4'};
 const blob=new Blob([Papa.unparse([sample],{columns:CSV_HEADERS})],{type:'text/csv'}); const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download='examflow-test-template.csv'; a.click(); URL.revokeObjectURL(a.href);
}
export function parseCsv(file){return new Promise((resolve,reject)=>Papa.parse(file,{header:true,skipEmptyLines:true,complete:r=>{if(r.errors.length)return reject(new Error(r.errors[0].message));const missing=CSV_HEADERS.filter(h=>!r.meta.fields.includes(h));if(missing.length)return reject(new Error('Missing columns: '+missing.join(', ')));resolve(r.data)},error:reject}))}
