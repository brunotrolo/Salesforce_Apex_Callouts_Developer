# CLAUDE.md

**As regras deste repositório estão em [`AGENTS.md`](AGENTS.md). Leia-o antes de qualquer
mudança.** Fonte única, vendor-neutral — este arquivo não as duplica, para não divergir.

O essencial, em três linhas:

1. Este repositório **é uma skill**, não um projeto Salesforce. Você escreve instruções que
   outro agente executa contra uma integração que **já roda em produção**.
2. Se o curl não provou, é pergunta, não premissa. A Fase 2 para até aprovação explícita da
   spec — e isso não é formalidade.
3. Teste com `HttpCalloutMock` prova o seu código, não a API remota. O smoke contra HML é o
   único critério que toca o sistema real.

## Específico do Claude Code

- **Subagente sem frontmatter não é subagente.** Todo arquivo em `.claude/agents/` precisa
  de YAML com `name` e `description` **na primeira linha**. Sem isso o Claude Code trata o
  arquivo como documentação e nunca o despacha — falha silenciosa, e a skill parece
  completa enquanto suas quatro fases não rodam. Os quatro agentes daqui já viveram assim.
- **Campo certo por mecanismo:** subagentes usam `tools:`; uma `SKILL.md` usa
  `allowed-tools`. Trocar um pelo outro é ignorado em silêncio.
- **Skill invocável:** `.claude/skills/apex-callouts-developer/SKILL.md` está um nível
  abaixo de `skills/`, então vira comando `/`.
- **`.claude/rules/karpathy-guidelines.md`** não tem `paths:`, então carrega sempre.
- **`references/` é contrato, não decoração:** é o que o `generate-tobe` copia como
  template. Mudança ali muda o que a skill produz.
