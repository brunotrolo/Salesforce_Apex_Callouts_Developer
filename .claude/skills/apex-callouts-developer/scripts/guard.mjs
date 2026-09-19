#!/usr/bin/env node
// guard.mjs — hook PreToolUse desta skill.
// ---------------------------------------------------------------------------
// O `settings.json` deste repo usa `defaultMode: bypassPermissions` + `Bash(*)`
// (o loop de 4 fases não pode parar a cada prompt) — e é exatamente por isso que
// as travas técnicas têm que estar aqui, não só em prosa. Cobre DOIS vetores:
//
//   1) Comandos (Bash): apagar org/dados/projeto. O `permissions.deny` do
//      settings.json casa só o INÍCIO do comando (`sf org delete *`) — um
//      comando encadeado (`echo ok && sf org delete x`) passa por ele sem
//      tocar a allowlist. Regex sem âncora pega o comando em qualquer posição.
//   2) Escrita de arquivo (Write/Edit): sobrescrever um dos 4 artefatos
//      COMPARTILHADOS (`APIConnector`, `APIConfigDAO`, `APIException`, o
//      Permission Set `API_Integration`) que a AGENTS.md já declara como
//      "mudança em todas as integrações, nunca efeito colateral de uma API" —
//      até agora só a prosa dizia isso. Aqui vira `ask`: nunca sobrescrita
//      silenciosa, sempre um prompt explícito antes de tocar em base comum.
//
// LIMITAÇÃO honesta (mesma dos guards irmãos deste projeto): matching por
// texto/caminho não é fronteira criptográfica — wrapper exótico, variável de
// ambiente ou substituição de comando pode, em tese, escapar. Por isso as
// regras do AGENTS.md continuam essenciais, isto é só a 2ª camada.
// ---------------------------------------------------------------------------

import { basename } from 'node:path';

export const DESTRUCTIVE_RULES = [
  { re: /\bsf\b[\s\S]*\borg\b[\s\S]*\bdelete\b/, why: 'sf org delete (apaga uma org)' },
  { re: /\bsf\b[\s\S]*\bdata\b[\s\S]*\bdelete\b/, why: 'sf data delete (apaga registros)' },
  { re: /\bsf\b[\s\S]*\bproject\b[\s\S]*\bdelete\b/, why: 'sf project delete (apaga código-fonte)' },
];

export function classifyCommand(cmd) {
  const c = String(cmd || '').toLowerCase();
  for (const r of DESTRUCTIVE_RULES) {
    if (r.re.test(c)) return { blocked: true, decision: 'deny', why: r.why };
  }
  return { blocked: false };
}

// Artefatos compartilhados por TODAS as integrações (AGENTS.md, regra 2).
const SHARED_BASENAMES = new Set([
  'apiconnector.cls',
  'apiconnector.cls-meta.xml',
  'apiconfigdao.cls',
  'apiconfigdao.cls-meta.xml',
  'apiexception.cls',
  'apiexception.cls-meta.xml',
  'api_integration.permissionset-meta.xml',
]);

export function classifyWrite(filePath) {
  const name = basename(String(filePath || '')).toLowerCase();
  if (!SHARED_BASENAMES.has(name)) return { blocked: false };
  return {
    blocked: true,
    decision: 'ask',
    why:
      `${basename(filePath)} é artefato compartilhado por TODAS as integrações ` +
      '(AGENTS.md, regra 2) — mudança nele nunca é efeito colateral de uma API ' +
      'específica. Confirme que é intencional antes de prosseguir.',
  };
}

function deny(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: reason,
      },
    })
  );
}

function ask(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'ask',
        permissionDecisionReason: reason,
      },
    })
  );
}

// Só roda a lógica principal quando chamado como hook (via stdin), nunca ao
// ser importado pelos testes.
if (import.meta.url === `file://${process.argv[1]}`) {
  let raw = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => (raw += chunk));
  process.stdin.on('end', () => {
    try {
      const payload = JSON.parse(raw);
      const toolName = payload?.tool_name;
      const input = payload?.tool_input || {};

      if (toolName === 'Bash' || toolName === 'PowerShell') {
        const r = classifyCommand(input.command);
        if (r.blocked) return finish(() => deny(r.why));
      }
      if (toolName === 'Write' || toolName === 'Edit') {
        const path = input.file_path || input.path;
        const r = classifyWrite(path);
        if (r.blocked) return finish(() => ask(r.why));
      }
    } catch {
      // Payload malformado: fica fora do caminho em vez de bloquear por bug do guard.
    }
    process.exit(0);
  });
}

function finish(emit) {
  emit();
  process.exit(0);
}
