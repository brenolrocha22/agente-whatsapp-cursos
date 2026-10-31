# Agente de Vendas e Atendimento no WhatsApp

Projeto do Desafio Criativo da DIO **"Projetando o Prompt de um Agente de Atendimento ao Cliente"**, da trilha *Bradesco: Agentes de IA do Zero à Prática*.

O agente atende pelo WhatsApp uma escola de cursos online de tecnologia (marca fictícia **Trilha Tech**). Ele tira dúvidas, indica o curso certo e leva a pessoa até o link de matrícula. Um banco de dados SQL guarda clientes, cursos, leads e atendimentos, e alimenta o agente com dados reais para que ele não invente nada.

## Estrutura

```
├── README.md
├── prompt-agente-whatsapp.md        # prompt final (entrega do desafio) + testes
├── passos/
│   ├── passo-1-papel-e-escopo.md     # quem é o agente e quem ele atende
│   └── passo-2-regras-e-formato.md   # tom, regras e encaminhamento
└── database/
    └── schema.sql                    # tabelas, dados de exemplo e consultas
```

## Como o agente usa o banco

```
Mensagem no WhatsApp
        │
        ▼
Sistema busca o número na tabela clientes
        │
        ├── Q1 → bloco [DADOS_DO_CLIENTE]  (nome, consentimento, interesses, matrículas, último atendimento)
        ├── Q2 → bloco [CATALOGO]          (cursos ativos, ementa, preço, parcela, pagamento, link, próximo curso)
        └── Q7 → bloco [AJUDA_ALUNO]       (passos de acesso, login e certificado)
        │
        ▼
Prompt + blocos → modelo de IA → resposta no WhatsApp
        │
        ▼
Registro na tabela atendimentos (e atualização do lead)
```

O prompt proíbe o agente de usar qualquer dado fora desses três blocos. Preço, conteúdo do curso, link e passos de suporte só existem no banco, então o agente não tem de onde inventar.

## Banco de dados

| Tabela | O que guarda |
|---|---|
| `clientes` | Nome, WhatsApp, objetivo, consentimento LGPD e opt-out. Não guarda CPF, cartão nem senha |
| `cursos` | Catálogo: nível, ementa, carga horária, preço, parcelas, formas de pagamento, link de matrícula e próximo curso da trilha |
| `leads` | Funil de vendas: novo → em conversa → link enviado → matriculado / perdido |
| `matriculas` | Cursos comprados e progresso do aluno |
| `atendimentos` | Histórico das conversas e se foram para um humano |
| `ajuda_aluno` | Passos oficiais de suporte: acessar o curso, recuperar login, emitir certificado |

Consultas incluídas no `schema.sql`:
1. Contexto do cliente para o agente
2. Catálogo ativo
3. Funil de vendas por etapa
4. Taxa de conversão por curso
5. Leads para follow-up (só com consentimento LGPD)
6. Percentual de atendimentos que foram para humano
7. Passos de suporte ao aluno

### Como rodar

```bash
sqlite3 trilha.db < database/schema.sql
```

Também dá para colar o script em um editor online de SQLite, como o sqliteonline.com.

## Testes do prompt

Os casos de teste (pedido comum, informação que o agente não tem, caso para humano, dado sensível e promessa indevida) estão no fim de `prompt-agente-whatsapp.md`, junto com o resultado da rodada no ChatGPT e os ajustes que ela gerou no prompt.

## Tecnologias

- Engenharia de prompt
- SQL (SQLite)
- Modelagem de dados com foco em LGPD

---

Feito por [Breno Lins Rocha](https://github.com/brenolrocha22).
