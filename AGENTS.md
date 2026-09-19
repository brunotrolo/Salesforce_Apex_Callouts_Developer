# AGENTS.md — Salesforce Apex Callouts Developer

Instruções para qualquer agente de código que trabalhe **neste repositório**.
Vendor-neutral por design (Claude Code, Cursor, Codex e afins). `CLAUDE.md` aponta para cá
para que exista uma única fonte de verdade.

## O que é este repositório

Este repositório **é uma skill**, não um projeto Salesforce. O que se entrega é o conteúdo
de `.claude/` — a skill `apex-callouts-developer`, 4 subagentes e as referências validadas
— instalado dentro do projeto SFDX de outra pessoa.

A skill refatora um callout HTTP Apex legado para a arquitetura de referência
(Template Method + Lookup Table + Named Credential + External Credential + cache de token),
em quatro fases: **Analyze AS IS → Spec (aprovável) → Generate → Validate**.

Consequência prática para você: aqui você quase nunca escreve Apex. Você escreve
**instruções que outro agente vai executar contra uma integração que já roda em
produção**, movendo dados reais entre sistemas. Um erro não aparece como exceção — aparece
como um callout que falha contra um sistema de terceiro.

## Disciplina comportamental

`.claude/rules/karpathy-guidelines.md` vale para o trabalho **neste repositório** tanto
quanto para a execução da skill:

1. **Pense antes de codar** — se o curl não provou, é pergunta, não premissa. A API remota
   não perdoa palpite.
2. **Simplicidade primeiro** — a arquitetura de referência já é a abstração; não invente
   camada em cima dela para uma API só. E "não migrar" é uma decisão legítima e frequente.
3. **Mudanças cirúrgicas** — o escopo é UMA integração. Artefatos compartilhados
   (`APIConnector`, `APIConfigDAO`, `APIException`, Permission Set) servem todas.
4. **Execução orientada a objetivo** — teste com mock não é integração funcionando. O smoke
   contra HML é o único critério que toca o sistema real.

## Regras inegociáveis

### 1. Subagente sem frontmatter não existe
Todo arquivo em `.claude/agents/` **precisa** de frontmatter YAML com `name` e
`description` na primeira linha. Sem isso o Claude Code trata o arquivo como documentação
ao lado dos agentes e **nunca o despacha** — a falha é silenciosa e a skill parece estar
completa enquanto suas quatro fases não rodam.

Foi exatamente o que aconteceu aqui: os quatro agentes viviam sem frontmatter enquanto o
`SKILL.md` os despachava por nome. Se você criar um agente novo, comece pelo frontmatter.

### 2. Artefatos compartilhados mudam para todos
`APIConnector`, `APIConfigDAO`, `APIException` e o Permission Set `API_Integration` são
base comum de todas as integrações. Mudança neles nunca é efeito colateral de uma API
específica — é decisão a levar ao usuário. O Permission Set em particular é sempre
**delta**: apenas os novos principals, nunca o arquivo reescrito.

Isso é reforçado tecnicamente, não só em prosa: `.claude/skills/apex-callouts-developer/scripts/guard.mjs`
roda como hook `PreToolUse` e transforma `Write`/`Edit` num desses 4 arquivos em
confirmação explícita (`ask`), nunca sobrescrita silenciosa. Necessário porque
`settings.json` usa `defaultMode: bypassPermissions` — sem o guard, nada pararia essa
escrita. O mesmo hook também bloqueia (`deny`) `sf org/data/project delete` mesmo
encadeado (`... && sf org delete x`), que os prefixos de `permissions.deny` sozinhos não
alcançam. Teste: `node --test .claude/skills/apex-callouts-developer/tests/*.test.mjs`.

### 3. Nada de segredo real
Nenhum `client_id`, `client_secret`, token, endpoint interno ou credencial de org real —
nem em referência, nem em script, nem em exemplo. Os scripts de setup usam placeholders
explícitos (`YOUR_CLIENT_SECRET`); mantenha assim.

### 4. Nada de nome real
Nenhum nome de empresa, org, cliente ou identificador vindo de uma org real — em conteúdo,
nomes de arquivo, mensagens de commit ou metadados de autoria do git. As referências usam
a empresa fictícia **ACME** e a org placeholder **YourOrg**; qualquer artefato novo segue a
mesma convenção.

### 5. As referências são o contrato validado
`references/apex/`, `references/metadata/` e `references/scripts/` não são exemplos
decorativos — são os artefatos que o `generate-tobe` copia como template. Mudança neles
muda o que a skill produz. Trate-os como código.

### 6. Idioma
Conteúdo e `README.md` em PT-BR. Falar com o usuário em PT-BR.

## Mapa do repositório

```
.claude/
├── agents/                        # 4 subagentes, um por fase
│   ├── analyze-asis.md            # Fase 1 — classifica padrão A–F, decide migrar ou não
│   ├── spec-callout.md            # Fase 2 — spec aprovável; PARA até aprovação explícita
│   ├── generate-tobe.md           # Fase 3 — gera connector, testes, EC/NC, PS, scripts
│   └── validate-tobe.md           # Fase 4 — checklists + comando de deploy pronto
├── rules/karpathy-guidelines.md   # disciplina comportamental (MIT)
├── skills/apex-callouts-developer/
│   ├── SKILL.md                   # arquitetura de referência e templates das 4 fases
│   ├── references/apex/           # ACMEConnector + base compartilhada (contrato validado)
│   ├── references/metadata/       # EC/NC XML, Lookup Table, Permission Set, inventário
│   └── references/scripts/        # setup de secrets/EC, smoke test
└── settings.json
```

## Definição de pronto

- [ ] Todo agente novo tem frontmatter com `name` e `description` na primeira linha
- [ ] A mudança rastreia a um pedido explícito (nada especulativo)
- [ ] Nenhum artefato compartilhado alterado como efeito colateral
- [ ] Nenhum segredo e nenhum nome real reintroduzido
- [ ] README reflete mudanças estruturais
