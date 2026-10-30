const [base = 'http://localhost:3000', email, password] = process.argv.slice(2);
const REQUESTS = 200;
const day = new Date().toISOString().slice(0, 10);

const pct = (sorted, p) => sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))];

async function timed(fn) {
  const t = performance.now();
  const res = await fn();
  return { ms: performance.now() - t, status: res.status };
}

async function load(name, make, concurrency) {
  const times = []; let failed = 0; let next = 0;
  async function worker() {
    while (next++ < REQUESTS) {
      const r = await timed(make);
      if (r.status >= 400) failed++;
      times.push(r.ms);
    }
  }
  const start = performance.now();
  await Promise.all(Array.from({ length: concurrency }, worker));
  const secs = (performance.now() - start) / 1000;
  times.sort((a, b) => a - b);
  console.log(
    `${name.padEnd(26)} c=${String(concurrency).padEnd(3)} median ${pct(times, 50).toFixed(0).padStart(4)} ms   ` +
    `p95 ${pct(times, 95).toFixed(0).padStart(4)} ms   max ${times[times.length - 1].toFixed(0).padStart(4)} ms   ` +
    `${(times.length / secs).toFixed(0)} req/s   errors ${failed}`
  );
}

(async () => {
  if (!email || !password) { console.log('Usage: node tests/perf/latency.js <baseUrl> <email> <password>'); process.exit(1); }
  const login = await fetch(base + '/auth/login', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email, password }),
  });
  if (!login.ok) { console.log('Login failed:', login.status, await login.text()); process.exit(1); }
  const { access_token: token } = await login.json();
  if (!token) { console.log('No access token in the login response; check the field name in this script.'); process.exit(1); }
  const auth = { authorization: `Bearer ${token}` };
  const get = (path, headers = {}) => () => fetch(base + path, { headers });

  console.log(`API: ${base}   ${REQUESTS} requests per row\n`);
  for (const c of [1, 10, 25]) {
    await load('GET /health', get('/health'), c);
    await load('GET /community/posts', get('/community/posts', auth), c);
    await load('GET /reminders', get(`/reminders?day=${day}`, auth), c);
    await load('GET /me', get('/me', auth), c);
    console.log('');
  }
})();