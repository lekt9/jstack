// Jesus Loop Worker — append-only API in front of D1.
//
// POST /pairs        Insert one validated pair. Bearer WRITE_TOKEN.
// GET  /pairs        List. Bearer READ_TOKEN. Filters: ?verse=, ?session=,
//                    ?step=, ?genesis_day=, ?limit=
// GET  /pairs/stats  Rollup. Bearer READ_TOKEN.
//                    ?group=verse|day|step (default verse+label)
// GET  /             Service descriptor (public).
//
// No PUT/PATCH/DELETE route exists. D1 triggers enforce immutability.

const REQUIRED = ['session_id','project_dir','task','iteration','verse_ref','pattern_label','applied_lesson'];
const OPTIONAL_FIB = ['step','genesis_day','harness_ws','verdict','outcome'];

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status, headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

function checkToken(request, expected) {
  if (!expected) return false;
  const h = request.headers.get('authorization') || '';
  if (!h.startsWith('Bearer ')) return false;
  const got = h.slice(7).trim();
  if (got.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < got.length; i++) diff |= got.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

const clip = (s, max) => s == null ? null : String(s).slice(0, max);

async function handlePost(request, env) {
  if (!checkToken(request, env.WRITE_TOKEN)) return json({ error: 'unauthorized' }, 401);

  let body;
  try { body = await request.json(); } catch { return json({ error: 'invalid json' }, 400); }

  for (const k of REQUIRED) {
    if (body[k] === undefined || body[k] === null || String(body[k]).length === 0) {
      return json({ error: `missing field: ${k}` }, 400);
    }
  }

  const iteration = Number(body.iteration);
  if (!Number.isInteger(iteration) || iteration < 1) {
    return json({ error: 'iteration must be positive integer' }, 400);
  }
  let step = null;
  if (body.step !== undefined && body.step !== null && body.step !== '') {
    step = Number(body.step);
    if (!Number.isInteger(step) || step < 1 || step > 9) {
      return json({ error: 'step must be integer 1..9' }, 400);
    }
  }

  const values = [
    clip(body.session_id, 200),
    clip(body.project_dir, 500),
    clip(body.task, 8000),
    iteration,
    step,
    clip(body.genesis_day, 40),
    clip(body.harness_ws, 500),
    clip(body.verdict, 40),
    clip(body.verse_ref, 120),
    clip(body.pattern_label, 200),
    clip(body.applied_lesson, 2000),
    body.outcome ? clip(body.outcome, 100) : null,
    request.headers.get('cf-connecting-ip') || null,
    clip(request.headers.get('user-agent') || '', 300) || null,
  ];

  const result = await env.DB.prepare(
    `INSERT INTO jesus_loop_pairs
       (session_id, project_dir, task, iteration, step, genesis_day,
        harness_ws, verdict, verse_ref, pattern_label, applied_lesson,
        outcome, client_ip, user_agent)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)`,
  ).bind(...values).run();

  return json({ ok: true, id: result.meta?.last_row_id ?? null }, 201);
}

async function handleList(request, env, url) {
  if (!checkToken(request, env.READ_TOKEN)) return json({ error: 'unauthorized' }, 401);

  const limit = Math.min(parseInt(url.searchParams.get('limit') || '100', 10) || 100, 500);
  const verse = url.searchParams.get('verse');
  const session = url.searchParams.get('session');
  const step = url.searchParams.get('step');
  const day = url.searchParams.get('genesis_day');

  const wheres = [];
  const binds = [];
  if (verse)   { wheres.push('verse_ref = ?');   binds.push(verse); }
  if (session) { wheres.push('session_id = ?');  binds.push(session); }
  if (step)    { wheres.push('step = ?');        binds.push(Number(step)); }
  if (day)     { wheres.push('genesis_day = ?'); binds.push(day); }

  let q = `SELECT id, session_id, project_dir, task, iteration, step,
                  genesis_day, harness_ws, verdict, verse_ref, pattern_label,
                  applied_lesson, outcome, created_at
           FROM jesus_loop_pairs`;
  if (wheres.length) q += ' WHERE ' + wheres.join(' AND ');
  q += ' ORDER BY id DESC LIMIT ?';
  binds.push(limit);

  const { results } = await env.DB.prepare(q).bind(...binds).all();
  return json({ pairs: results });
}

async function handleStats(request, env, url) {
  if (!checkToken(request, env.READ_TOKEN)) return json({ error: 'unauthorized' }, 401);

  const group = url.searchParams.get('group') || 'verse';

  let q;
  if (group === 'day') {
    q = `SELECT genesis_day, COUNT(*) AS n,
                MIN(created_at) AS first_seen, MAX(created_at) AS last_seen
         FROM jesus_loop_pairs
         WHERE genesis_day IS NOT NULL
         GROUP BY genesis_day
         ORDER BY n DESC`;
  } else if (group === 'step') {
    q = `SELECT step, genesis_day, COUNT(*) AS n,
                MIN(created_at) AS first_seen, MAX(created_at) AS last_seen
         FROM jesus_loop_pairs
         WHERE step IS NOT NULL
         GROUP BY step, genesis_day
         ORDER BY step`;
  } else {
    q = `SELECT verse_ref, pattern_label, COUNT(*) AS n,
                MIN(created_at) AS first_seen, MAX(created_at) AS last_seen
         FROM jesus_loop_pairs
         GROUP BY verse_ref, pattern_label
         ORDER BY n DESC
         LIMIT 100`;
  }

  const { results } = await env.DB.prepare(q).all();
  return json({ group, stats: results });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/') {
      return json({
        service: 'jesus-loop',
        endpoints: {
          'POST /pairs': 'insert one pair (Bearer WRITE_TOKEN)',
          'GET /pairs':  'list (Bearer READ_TOKEN; ?verse=, ?session=, ?step=, ?genesis_day=, ?limit=)',
          'GET /pairs/stats': 'rollup (Bearer READ_TOKEN; ?group=verse|day|step)',
        },
        architecture: '9 Genesis-day steps (1-6 creation, 7 sabbath, 8 judgement, 9 emergence); harness-break escape; append-only D1',
        immutability: 'UPDATE/DELETE blocked by DB triggers',
      });
    }

    if (request.method === 'POST' && url.pathname === '/pairs')       return handlePost(request, env);
    if (request.method === 'GET'  && url.pathname === '/pairs')       return handleList(request, env, url);
    if (request.method === 'GET'  && url.pathname === '/pairs/stats') return handleStats(request, env, url);

    return json({ error: 'method not allowed' }, 405);
  },
};
