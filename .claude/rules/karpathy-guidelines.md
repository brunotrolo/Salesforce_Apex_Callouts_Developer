# Karpathy Guidelines — aplicadas à refatoração de callouts em produção

Diretrizes comportamentais para reduzir erros comuns de LLM em código, derivadas das
[observações de Andrej Karpathy](https://x.com/karpathy/status/2015883857489522876) sobre
armadilhas de LLM em programação.

Origem: [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)
(MIT). As quatro seções abaixo estão **na íntegra**, em tradução fiel; cada uma traz depois
um bloco `Neste projeto` que contextualiza a diretriz para refatorar integrações HTTP que
já rodam em produção. A contextualização acrescenta, nunca substitui nem relaxa a
orientação original.

Estas diretrizes são comportamentais e transversais: valem para como cada um dos quatro
subagentes decide. A `SKILL.md` continua sendo a autoridade sobre a arquitetura de
referência e os templates.

**Tradeoff:** estas diretrizes privilegiam cautela sobre velocidade. Para tarefas triviais, use bom senso.

---

## 1. Pense Antes de Codar

**Não presuma. Não esconda confusão. Exponha tradeoffs.**

Antes de implementar:
- Declare suas premissas explicitamente. Se estiver incerto, pergunte.
- Se existem múltiplas interpretações, apresente-as — não escolha silenciosamente.
- Se existe uma abordagem mais simples, diga. Discorde quando for o caso.
- Se algo está obscuro, pare. Nomeie o que está confuso. Pergunte.

> **Neste projeto.** É a Fase 2 inteira, e o `spec-callout` já a aplica como regra
> absoluta: *nunca passar para a Fase 3 sem aprovação explícita do usuário.* As
> "perguntas fechadas para completar dados faltantes" existem exatamente porque o dado
> que falta não pode ser inventado — um `client_secret` de HML, a estrutura real do JSON
> de resposta 200, um header obrigatório, o CPF de teste do smoke.
>
> O risco específico aqui é que **a API remota não perdoa palpite**. Um campo de payload
> assumido, um código de erro que você achou que significava uma coisa, um `grant_type`
> que você deduziu — nada disso falha no compilador. Falha no primeiro callout real,
> contra um sistema de terceiro, possivelmente em produção. Se o curl não provou, é
> pergunta, não premissa.

---

## 2. Simplicidade Primeiro

**O mínimo de código que resolve o problema. Nada especulativo.**

- Nenhuma funcionalidade além do que foi pedido.
- Nenhuma abstração para código de uso único.
- Nenhuma "flexibilidade" ou "configurabilidade" que não foi solicitada.
- Nenhum tratamento de erro para cenários impossíveis.
- Se você escreveu 200 linhas e dava para fazer em 50, reescreva.

Pergunte a si mesmo: "Um engenheiro sênior diria que isto está complicado demais?" Se sim, simplifique.

> **Neste projeto.** A arquitetura de referência (Template Method + Lookup Table + Named
> Credential + External Credential + cache de token) já é a abstração — e ela vale porque
> é compartilhada por todas as integrações. O que **não** vale é inventar uma camada em
> cima dela para uma API só: um `Config` intermediário quando a Lookup Table já resolve,
> um wrapper de retry quando a plataforma já renova o token, um DTO por endpoint quando
> o connector devolve o contrato inteiro.
>
> Vale também para o inverso, que o `analyze-asis` já codifica: os padrões classificados
> como ❌ **Manter** (cache de plataforma, autenticação delegada, dois tokens simultâneos)
> não são convites a "melhorar". A decisão mais simples e mais frequente é **não migrar**.

---

## 3. Mudanças Cirúrgicas

**Toque apenas no que precisa. Limpe apenas a sua própria bagunça.**

Ao editar código existente:
- Não "melhore" código adjacente, comentários ou formatação.
- Não refatore coisas que não estão quebradas.
- Siga o estilo existente, mesmo que você fizesse diferente.
- Se notar código morto não relacionado, mencione — não apague.

Quando suas mudanças criam órfãos:
- Remova imports/variáveis/funções que **as suas** mudanças tornaram inúteis.
- Não remova código morto pré-existente a menos que peçam.

O teste: toda linha alterada deve ser rastreável diretamente ao pedido do usuário.

> **Neste projeto.** Esta é a diretriz de maior consequência aqui, porque o alvo é código
> que **já está em produção movendo dados reais entre sistemas**. Três aplicações
> concretas:
> **(a) O escopo é UMA integração.** Refatorar o connector X não autoriza tocar no
> connector Y que você viu ao lado, mesmo que ele viole os mesmos padrões. Reporte;
> não corrija.
> **(b) Artefatos compartilhados são compartilhados.** `APIConnector`, `APIConfigDAO`,
> `APIException` e o Permission Set servem todas as integrações. Mudança neles é mudança
> em todas — nunca um efeito colateral da sua API. Se a sua integração exige alterar a
> base, isso é uma decisão a levar ao usuário, não um commit a mais na Fase 3.
> **(c) O Permission Set é delta.** Apenas os novos principals. Reescrever o arquivo
> inteiro remove acessos que outra integração depende, e o deploy não reclama.

---

## 4. Execução Orientada a Objetivo

**Defina critérios de sucesso. Itere até verificar.**

Transforme tarefas em objetivos verificáveis:
- "Adicione validação" → "Escreva testes para entradas inválidas, depois faça-os passar"
- "Corrija o bug" → "Escreva um teste que o reproduz, depois faça-o passar"
- "Refatore X" → "Garanta que os testes passam antes e depois"

Para tarefas multi-etapa, declare um plano breve:
```
1. [Passo] → verificar: [checagem]
2. [Passo] → verificar: [checagem]
3. [Passo] → verificar: [checagem]
```

Critérios de sucesso fortes permitem iterar de forma independente. Critérios fracos
("faça funcionar") exigem esclarecimento constante.

> **Neste projeto.** As quatro fases são esse plano, e o `validate-tobe` é o critério
> tornado explícito: *"parece correto" não é evidência*, e nada é aprovado sem checklist
> completo mais o comando de deploy pronto.
>
> O ponto que merece nome próprio: **num callout, teste passando não é integração
> funcionando.** Um `HttpCalloutMock` prova que o seu código compila e trata a resposta
> que **você** escreveu — não que a API remota responde assim. Por isso o smoke test
> contra HML existe e não é opcional: ele é o único critério que toca o sistema real. Os
> testes unitários com mock cobrem os 75%; o smoke é o que prova a integração. Confundir
> os dois é o caso clássico de critério fraco vestido de forte.

---

*Diretrizes derivadas de observações de Andrej Karpathy, via
[multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills),
licença MIT. Os blocos `Neste projeto` são contextualização própria desta skill.*
