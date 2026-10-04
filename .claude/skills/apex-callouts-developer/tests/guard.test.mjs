// Rodar: node --test .claude/skills/apex-callouts-developer/tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { classifyCommand, classifyWrite, classifySelfContainment } from '../scripts/guard.mjs';

test('bloqueia sf org delete mesmo encadeado', () => {
  assert.equal(classifyCommand('echo ok && sf org delete -p x').blocked, true);
});
test('bloqueia sf data delete', () => {
  assert.equal(classifyCommand('sf data delete record --sobject Account --record-id 001x').blocked, true);
});
test('bloqueia sf project delete', () => {
  assert.equal(classifyCommand('sf project delete source').blocked, true);
});
test('nao bloqueia deploy comum', () => {
  assert.equal(classifyCommand('sf project deploy start -o minha-org').blocked, false);
});
test('pede confirmacao para artefato compartilhado', () => {
  const r = classifyWrite('force-app/main/default/classes/APIConnector.cls');
  assert.equal(r.blocked, true);
  assert.equal(r.decision, 'ask');
});
test('pede confirmacao para o permission set compartilhado', () => {
  const r = classifyWrite('force-app/main/default/permissionsets/API_Integration.permissionset-meta.xml');
  assert.equal(r.blocked, true);
});
test('nao bloqueia conector especifico de uma integracao', () => {
  assert.equal(classifyWrite('force-app/main/default/classes/ACMEConnector.cls').blocked, false);
});
test('nao bloqueia metadado nao-classe', () => {
  assert.equal(classifyWrite('force-app/main/default/objects/Account.object-meta.xml').blocked, false);
});

// --- Autocontencao da classe de teste do connector (generate-tobe.md regra 8) ---
test('query SOQL literal contra Profile por Name pede confirmacao', () => {
  const src = `[SELECT Id FROM Profile WHERE Name = 'System Administrator']`;
  const r = classifySelfContainment(
    'force-app/main/default/classes/ACMEConnectorTest.cls',
    src
  );
  assert.equal(r.blocked, true);
  assert.equal(r.decision, 'ask');
});

test('APIConfigDAO.mockConfig (padrao do template) nao dispara o guard', () => {
  const src = `
    @isTest
    private class ACMEConnectorTest {
      private static void useMockConfig() {
        APIConfigDAO.APIConfig cfg = new APIConfigDAO.APIConfig();
        cfg.apiName = 'ACME_CustomerData';
        APIConfigDAO.mockConfig = cfg;
      }
    }
  `;
  assert.equal(
    classifySelfContainment('force-app/main/default/classes/ACMEConnectorTest.cls', src)
      .blocked,
    false
  );
});

test('chamada a metodo estatico de OUTRA *ConnectorTest pede confirmacao', () => {
  const src = `OtherAPIConnectorTest.useMockConfig();`;
  const r = classifySelfContainment(
    'force-app/main/default/classes/ACMEConnectorTest.cls',
    src
  );
  assert.equal(r.blocked, true);
  assert.equal(r.decision, 'ask');
});

test('chamada a metodo estatico DA PROPRIA classe de teste e permitido', () => {
  const src = `ACMEConnectorTest.useMockConfig();`;
  assert.equal(
    classifySelfContainment('force-app/main/default/classes/ACMEConnectorTest.cls', src)
      .blocked,
    false
  );
});

test('classe de producao (nao termina em ConnectorTest) nao e avaliada', () => {
  const src = `[SELECT Id FROM Profile WHERE Name = 'System Administrator']`;
  assert.equal(
    classifySelfContainment('force-app/main/default/classes/ACMEConnector.cls', src).blocked,
    false
  );
});
