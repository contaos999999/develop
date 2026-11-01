import http from 'k6/http';
import { check, fail, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 5 },
    { duration: '60s', target: 20 },
    { duration: '30s', target: 40 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
  },
};

const BASE = (__ENV.SUPABASE_URL || '').replace(/\/$/, '');
const ANON = __ENV.SUPABASE_ANON_KEY || '';
const EMAIL = __ENV.CONTAOS_TEST_EMAIL || '';
const PASSWORD = __ENV.CONTAOS_TEST_PASSWORD || '';

export function setup() {
  if (!BASE || !ANON || !EMAIL || !PASSWORD) {
    fail('Defina SUPABASE_URL, SUPABASE_ANON_KEY, CONTAOS_TEST_EMAIL e CONTAOS_TEST_PASSWORD. Use somente credenciais sintéticas do HML.');
  }

  const login = http.post(
    `${BASE}/auth/v1/token?grant_type=password`,
    JSON.stringify({ email: EMAIL, password: PASSWORD }),
    { headers: { apikey: ANON, 'Content-Type': 'application/json' } },
  );

  const ok = check(login, {
    'login HML retornou 200': (r) => r.status === 200,
    'login retornou access_token': (r) => Boolean(r.json('access_token')),
  });
  if (!ok) fail(`Falha no login HML: HTTP ${login.status}`);

  return { token: login.json('access_token') };
}

export default function (data) {
  const headers = {
    apikey: ANON,
    Authorization: `Bearer ${data.token}`,
    Accept: 'application/json',
  };

  const contratos = http.get(
    `${BASE}/rest/v1/contratos?select=id,numero,situacao,criticidade&order=atualizado_em.desc&limit=25`,
    { headers, tags: { rota: 'contratos_lista' } },
  );
  check(contratos, {
    'lista de contratos autorizada': (r) => r.status === 200,
    'lista não expõe erro técnico': (r) => !/stack trace|service_role|OPENAI_API_KEY|password/i.test(r.body || ''),
  });

  const status = http.get(
    `${BASE}/rest/v1/catalogo_status_ui?select=dominio,codigo,rotulo&dominio=eq.competencia`,
    { headers, tags: { rota: 'catalogo_status' } },
  );
  check(status, {
    'catálogo de status responde': (r) => r.status === 200,
  });

  sleep(1);
}
