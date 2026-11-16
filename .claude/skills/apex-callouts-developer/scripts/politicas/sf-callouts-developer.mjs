// Política do odin-guard para esta skill (ADR 0027 do Odin): as mesmas regras do guard.mjs, aplicadas depois do `odin ensure sf-callouts-developer`.
// Comando destrutivo é negado; escrita fora do lugar ou teste dependente de outro connector pede confirmação.
import { classifyCommand, classifySelfContainment, classifyWrite } from '../guard.mjs';

export default function politica(evento) {
  const entrada = evento?.tool_input ?? {};
  if (evento?.tool_name === 'Bash' || evento?.tool_name === 'PowerShell') {
    const r = classifyCommand(entrada.command);
    if (r.blocked) return { decisao: 'negar', motivo: r.why };
  }
  if (evento?.tool_name === 'Write' || evento?.tool_name === 'Edit') {
    const caminho = entrada.file_path || entrada.path;
    const w = classifyWrite(caminho); if (w.blocked) return { decisao: 'perguntar', motivo: w.why };
    const s = classifySelfContainment(caminho, entrada.content ?? entrada.new_string); if (s.blocked) return { decisao: 'perguntar', motivo: s.why };
  }
  return null;
}
