import { test } from 'node:test';
import assert from 'node:assert/strict';
import politica from '../scripts/politicas/sf-callouts-developer.mjs';

test('política do Odin: comando destrutivo é negado (Bash e PowerShell); leitura passa', () => {
  assert.equal(politica({ tool_name: 'Bash', tool_input: { command: 'sf org delete scratch -o x' } })?.decisao, 'negar');
  assert.equal(politica({ tool_name: 'PowerShell', tool_input: { command: 'sf org delete scratch -o x' } })?.decisao, 'negar');
  assert.equal(politica({ tool_name: 'Bash', tool_input: { command: 'git status' } }), null);
});
test('política do Odin: teste que chama método estático de outro connector pede confirmação', () => {
  const r = politica({ tool_name: 'Write', tool_input: { file_path: 'force-app/main/default/classes/FooConnectorTest.cls', content: 'private class FooConnectorTest { @IsTest static void t() { BarConnectorTest.setup(); } }' } });
  assert.equal(r?.decisao, 'perguntar');
});
test('política do Odin: outras ferramentas e entrada vazia passam', () => {
  assert.equal(politica({ tool_name: 'Read', tool_input: {} }), null); assert.equal(politica(undefined), null);
});
