# Skills — Salesforce Apex Callouts Developer

Skills customizadas para refatorar callouts HTTP Apex do LegacyOrg (AS IS)
para a arquitetura de referência TargetOrg TO BE.

## Skills disponíveis

| Skill | Descrição |
|---|---|
| `apex-callouts-developer` | Refatora callouts legados em 4 fases: Analyze → Spec → Generate → Validate |

## Como usar

Mencione qualquer um destes termos para ativar a skill:
- "refatorar callout"
- "migrar webservice"
- "criar connector"
- "nova integração API"
- Nome de classe legada: `CachedTokenAPI`, `LegacyAPIConnector`, `SimpleNCConnector`
- Cole um curl de API

## Subagentes

Os agentes especializados ficam em `.claude/agents/`:
- `analyze-asis` — classifica o padrão legado e extrai o contrato
- `spec-callout` — gera spec aprovável antes de qualquer código
- `generate-tobe` — gera todos os artefatos: Apex, XML, scripts
- `validate-tobe` — valida checklists e entrega comando de deploy
