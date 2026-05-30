const fs = require('fs');
const path = require('path');

const dict = JSON.parse(fs.readFileSync('exact_to_inspired.json', 'utf8'));
const sortedKeys = Object.keys(dict).sort((a, b) => b.length - a.length);

const walk = (dir) => {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) {
      if (!file.includes('node_modules') && !file.includes('.git') && !file.includes('build') && !file.includes('ios') && !file.includes('android')) {
         results = results.concat(walk(file));
      }
    } else {
      if (file.endsWith('.md') || file.endsWith('.sql') || file.endsWith('.mjs') || file.endsWith('.dart') || file.endsWith('.txt')) {
         results.push(file);
      }
    }
  });
  return results;
};

const files = walk('.');
let totalReplaced = 0;

for(let f of files) {
   let content = fs.readFileSync(f, 'utf8');
   let changed = false;
   if(f.includes('exact_to_inspired.json') || f.includes('ko_names_list') || f.includes('db_payload') || f.includes('latin_to_en_dict') || f.includes('do_replace')) continue;

   let newContent = content;
   for (let key of sortedKeys) {
       // Escape special chars in key if any (e.g. parentheses in "Ring of Life (Alt)")
       const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
       // Don't use word boundary for things starting/ending with parenthesis
       let regexStr = '\\b' + escapedKey + '\\b';
       if(key.includes('(')) regexStr = escapedKey; 
       
       const regex = new RegExp(regexStr, 'g');
       if(regex.test(newContent)) {
           newContent = newContent.replace(regex, dict[key]);
           changed = true;
           totalReplaced++;
       }
   }
   
   if(changed) {
      fs.writeFileSync(f, newContent);
      console.log('Updated: ' + f);
   }
}
console.log('Total replacements made: ' + totalReplaced);