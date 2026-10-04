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
