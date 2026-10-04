# LESSONS.md — histórico de falhas reais

Log append-only. Cada entrada: data, o que aconteceu, a regra que resultou
disso. Nunca editar ou remover uma entrada antiga — só adicionar uma nova
no final. Esta é a memória de falhas reais do repositório: se algo real
quebrar numa sessão (subagente, deploy, metadata), a entrada vai aqui, não
só na cabeça de quem resolveu.

---

## 2025 — Subagente sem frontmatter não existe

**O que aconteceu:** os quatro agentes de fase (`analyze-asis`, `spec-callout`,
`generate-tobe`, `validate-tobe`) viviam em `.claude/agents/` sem frontmatter
YAML, enquanto o `SKILL.md` os despachava por nome. Sem `name`/`description`
na primeira linha de cada arquivo, o Claude Code trata o arquivo como
documentação ao lado dos agentes e **nunca o despacha** — a falha é
silenciosa: a skill parece completa, as quatro fases existem no disco, mas
nenhuma delas de fato roda quando invocada.

**Regra resultante:** todo arquivo em `.claude/agents/` precisa de
frontmatter YAML com `name` e `description` na primeira linha. Se você criar
um agente novo, comece pelo frontmatter — e verifique visualmente que o
arquivo abre com `---` antes de qualquer prosa.

---

## 2026-10-04 — classe de teste não autocontida (propagado da skill irmã apex-test-loop)

**O que aconteceu:** o time de desenvolvimento validou, usando a skill irmã
`apex-test-loop`, que uma classe de teste bateu ≥99% de cobertura localmente
mas quebrou o deploy em PRODUÇÃO porque fazia uma query SOQL a um artefato
de configuração da org (RecordType/Profile por nome literal) que não
existia naquele ambiente. O mesmo risco existe aqui: `generate-tobe` gera
`XConnectorTest.cls`, e nada impedia uma geração futura de se desviar do
template (que já é seguro, via `APIConfigDAO.mockConfig`) e introduzir uma
query real ou uma dependência de outra classe `*ConnectorTest`.

**Regra que resultou:**
- `generate-tobe.md`: nova regra 8 — nunca SOQL literal contra objeto de
  configuração da org por Name/DeveloperName, nunca chamada a método
  estático de outra classe `*ConnectorTest`.
- `validate-tobe.md`: novo item no checklist de Testes cobrando a mesma
  verificação antes de aprovar.
- `guard.mjs`: nova função `classifySelfContainment` (hook `PreToolUse` em
  Write/Edit de `*ConnectorTest.cls`) detecta os dois padrões por heurística
  de texto e pede confirmação (`ask`).
