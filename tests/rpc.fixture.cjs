const readline = require('node:readline');
readline.createInterface({ input: process.stdin }).on('line', line => {
  const m = JSON.parse(line); if (m.id === undefined) return;
  if (m.method === 'hang') return;
  if (m.method === 'error') return console.log(JSON.stringify({ id: m.id, error: { code: -1, message: 'fixture' } }));
  if (m.method === 'exit') return process.exit(0);
  console.log(JSON.stringify({ id: m.id, result: m.method === 'initialize' ? {} : { ok: true, method: m.method } }));
});
