# Templates de follow-up no WhatsApp

Quem recebeu o link de matrícula e não comprou merece um lembrete, mas no WhatsApp isso tem regra.

## Por que template

No WhatsApp Business, a empresa só pode mandar mensagem livre até 24 horas depois da última mensagem da pessoa (a "janela de atendimento"). Fora dessa janela, só é permitido enviar **templates aprovados pela Meta**. Como o follow-up acontece justamente quando a pessoa sumiu, ele sempre sai como template.

Os dois templates abaixo são da categoria **Marketing**, que exige que a pessoa tenha aceitado receber mensagens. Por isso a fila de envio (consulta Q5 do `schema.sql`) só traz quem tem `consentimento_lgpd = 1` e `opt_out = 0`.

## Regras da fila (Q5)

- Só leads com status `link_enviado`, 24 horas ou mais sem mensagem da pessoa.
- No máximo 2 lembretes por lead: o segundo só 3 dias depois do primeiro, e só se a pessoa não respondeu.
- Um curso por pessoa (o link mais recente) e no máximo um lembrete por pessoa a cada 3 dias.
- Cada envio é registrado na tabela `followups`, e o `UNIQUE (lead_id, template)` impede mandar o mesmo lembrete duas vezes.

## lembrete_link_1

Enviado 24 horas depois do link, se a pessoa não respondeu.

| Campo | Conteúdo |
|---|---|
| Categoria | Marketing |
| Idioma | pt_BR |
| Variáveis | `{{1}}` primeiro nome · `{{2}}` nome do curso |
| Botões de resposta rápida | Quero me matricular · Tenho uma dúvida · Não quero receber |

```text
Oi, {{1}}! Você recebeu o link de matrícula do curso *{{2}}* da Trilha Tech. Ficou alguma dúvida que eu possa responder?
```

## lembrete_link_2

Enviado 3 dias depois do primeiro, se a pessoa continuou sem responder. É o último.

| Campo | Conteúdo |
|---|---|
| Categoria | Marketing |
| Idioma | pt_BR |
| Variáveis | `{{1}}` primeiro nome · `{{2}}` nome do curso · `{{3}}` parcelas · `{{4}}` valor da parcela |
| Botão de link | Ver o curso (URL: link de matrícula do curso) |
| Botão de resposta rápida | Não quero receber |

```text
{{1}}, o curso *{{2}}* continua com matrícula aberta, em até {{3}}x de {{4}}. Se quiser retomar, é só tocar no botão abaixo. Esta é a última mensagem sobre esse curso.
```

## O que acontece quando a pessoa responde

A resposta abre uma nova janela de 24 horas e cai no agente normalmente. O bloco `[DADOS_DO_CLIENTE]` traz o campo `ultimo_followup`, e o prompt orienta o agente a:

- **Quero me matricular:** mandar o link do curso citado no lembrete, sem recomeçar a conversa.
- **Tenho uma dúvida:** perguntar qual é a dúvida sobre aquele curso.
- **Não quero receber:** registrar o opt-out e encerrar, sem tentar convencer.

## Como o lembrete é montado (exemplo com a Ana)

A Q5 devolve, para cada linha da fila, o `proximo_template` e os valores das variáveis:

| Variável | Valor |
|---|---|
| `{{1}}` | Ana |
| `{{2}}` | Lógica de Programação do Zero |
| `{{3}}` | 6 |
| `{{4}}` | R$ 49,50 |

Mensagem que chega para a Ana no `lembrete_link_1`:

> Oi, Ana! Você recebeu o link de matrícula do curso *Lógica de Programação do Zero* da Trilha Tech. Ficou alguma dúvida que eu possa responder?
>
> [Quero me matricular] [Tenho uma dúvida] [Não quero receber]
