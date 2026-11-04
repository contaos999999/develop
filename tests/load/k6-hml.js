// ContaOS 4.1 — NFR-009/NFR-012: leitura somente no HML.
// Este ensaio NÃO mede o p95 de comandos síncronos (meta separada de 800 ms).
// Usar apenas identidade sintética autorizada do projeto HML; nunca PROD.
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
    checks: ['rate>0.99'],
    // Meta do DOCX RNF original: leitura API comum p95 <= 500ms.
    // Segregada por rota: um agregado global de 1000ms mascarava leituras lentas.
    'http_req_duration{rota:contratos_lista}': ['p(95)<500'],
    'http_req_duration{rota:catalogo_status}': ['p(95)<500'],
  },
};

const BASE = (__ENV.SUPABASE_URL || '').replace(/\/$/, '');
const ANON = __ENV.SUPABASE_ANON_KEY || '';
const EMAIL = __ENV.CONTAOS_TEST_EMAIL || '';
const PASSWORD = __ENV.CONTAOS_TEST_PASSWORD || '';
const HML = /^https:\/\/gklhhhyosgasnyoxlrui\.supabase\.co$/i;
const LOCAL = /^http:\/\/(?:127\.0\.0\.1|localhost):54321$/i;

export function setup() {
  if (!BASE || !ANON || !EMAIL || !PASSWORD) {
    fail('Defina SUPABASE_URL, SUPABASE_ANON_KEY, CONTAOS_TEST_EMAIL e CONTAOS_TEST_PASSWORD. Use apenas credenciais sintéticas do HML.');
  }
  if (!HML.test(BASE) && !LOCAL.test(BASE)) {
    fail('Carga recusada: SUPABASE_URL deve apontar exclusivamente para ContaOS HML ou Supabase local isolado na porta 54321. PROD é proibido.');
  }
  const login = http.post(
    `${BASE}/auth/v1/token?grant_type=password`,
    JSON.stringify({ email: EMAIL, password: PASSWORD }),
    { headers: { apikey: ANON, 'Content-Type': 'application/json' }, tags: { rota: 'auth_login' } },
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
