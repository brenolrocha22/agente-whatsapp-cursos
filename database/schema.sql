-- =====================================================================
-- Banco de dados do Agente de Vendas e Atendimento no WhatsApp
-- Escola fictícia: Trilha Tech
-- Compatível com SQLite (testado) e adaptável para PostgreSQL/MySQL.
-- Os dados de exemplo são fictícios.
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- 1. CLIENTES
-- Guarda só o necessário para o atendimento (princípio da minimização
-- da LGPD). Nada de CPF, cartão ou senha: o pagamento acontece no link
-- oficial de matrícula, fora do chat.
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nome                TEXT    NOT NULL,
    telefone_whatsapp   TEXT    NOT NULL UNIQUE,      -- formato E.164: +5581999990000
    email               TEXT,
    cidade              TEXT,
    perfil              TEXT    CHECK (perfil IN ('interessado', 'aluno')) DEFAULT 'interessado',
    objetivo            TEXT,                         -- ex.: primeiro emprego, mudar de área
    consentimento_lgpd  INTEGER NOT NULL DEFAULT 0 CHECK (consentimento_lgpd IN (0, 1)),
    data_consentimento  TEXT,
    opt_out             INTEGER NOT NULL DEFAULT 0 CHECK (opt_out IN (0, 1)),  -- pediu para não receber mensagens
    ultima_mensagem_em  TEXT,                         -- última mensagem da pessoa: abre a janela de 24h do WhatsApp
    criado_em           TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- 2. CURSOS (o [CATALOGO] que o agente recebe)
-- Preço, ementa, formas de pagamento e link só existem aqui: o agente
-- nunca inventa esses dados.
-- ---------------------------------------------------------------------
CREATE TABLE cursos (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    nome              TEXT    NOT NULL,
    area              TEXT    NOT NULL,                -- programação, dados, IA
    nivel             TEXT    NOT NULL CHECK (nivel IN ('iniciante', 'intermediario', 'avancado')),
    ementa            TEXT    NOT NULL,                -- o que a pessoa aprende, em uma frase
    carga_horaria_h   INTEGER NOT NULL,
    preco             REAL    NOT NULL,
    parcelas_max      INTEGER NOT NULL DEFAULT 1,
    formas_pagamento  TEXT    NOT NULL DEFAULT 'cartão de crédito, Pix ou boleto',
    certificado       INTEGER NOT NULL DEFAULT 1 CHECK (certificado IN (0, 1)),
    link_matricula    TEXT    NOT NULL,
    proximo_curso_id  INTEGER REFERENCES cursos(id), -- próximo passo da trilha, indicado a quem conclui
    ativo             INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0, 1))
);

-- ---------------------------------------------------------------------
-- 3. LEADS (funil de vendas)
-- Cada interesse de um cliente em um curso, com a etapa do funil.
-- ---------------------------------------------------------------------
CREATE TABLE leads (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id     INTEGER NOT NULL REFERENCES clientes(id),
    curso_id       INTEGER NOT NULL REFERENCES cursos(id),
    origem         TEXT    CHECK (origem IN ('anuncio', 'instagram', 'indicacao', 'site', 'outro')),
    status         TEXT    NOT NULL DEFAULT 'novo'
                   CHECK (status IN ('novo', 'em_conversa', 'link_enviado', 'matriculado', 'perdido')),
    criado_em      TEXT    NOT NULL DEFAULT (datetime('now')),
    atualizado_em  TEXT    NOT NULL DEFAULT (datetime('now')),
    UNIQUE (cliente_id, curso_id)
);

-- ---------------------------------------------------------------------
-- 4. MATRICULAS
-- ---------------------------------------------------------------------
CREATE TABLE matriculas (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id      INTEGER NOT NULL REFERENCES clientes(id),
    curso_id        INTEGER NOT NULL REFERENCES cursos(id),
    data_matricula  TEXT    NOT NULL DEFAULT (date('now')),
    status          TEXT    NOT NULL DEFAULT 'ativa'
                    CHECK (status IN ('ativa', 'concluida', 'cancelada', 'aguardando_pagamento')),
    progresso_pct   INTEGER NOT NULL DEFAULT 0 CHECK (progresso_pct BETWEEN 0 AND 100)
);

-- ---------------------------------------------------------------------
-- 5. ATENDIMENTOS
-- Histórico das conversas: permite ao agente não pedir de novo o que o
-- cliente já informou, e mede quanto vai para atendimento humano.
-- ---------------------------------------------------------------------
CREATE TABLE atendimentos (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id             INTEGER NOT NULL REFERENCES clientes(id),
    inicio                 TEXT    NOT NULL DEFAULT (datetime('now')),
    motivo                 TEXT    NOT NULL CHECK (motivo IN ('duvida_curso', 'indicacao', 'matricula', 'acesso', 'certificado', 'pagamento', 'reembolso', 'reclamacao', 'outro')),
    encaminhado_humano     INTEGER NOT NULL DEFAULT 0 CHECK (encaminhado_humano IN (0, 1)),
    motivo_encaminhamento  TEXT,
    resumo                 TEXT
);

-- ---------------------------------------------------------------------
-- 6. AJUDA_ALUNO (o [AJUDA_ALUNO] que o agente recebe)
-- Passos oficiais para os pedidos de suporte. Sem isso, o agente teria
-- de inventar como recuperar login ou emitir certificado.
-- ---------------------------------------------------------------------
CREATE TABLE ajuda_aluno (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    tema    TEXT NOT NULL UNIQUE,
    passos  TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 7. FOLLOWUPS
-- Lembretes enviados a quem recebeu o link e não comprou. Fora da janela
-- de 24h o WhatsApp só aceita templates aprovados, por isso cada envio
-- guarda o nome do template (ver templates/followup-whatsapp.md).
-- ---------------------------------------------------------------------
CREATE TABLE followups (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    lead_id    INTEGER NOT NULL REFERENCES leads(id),
    template   TEXT    NOT NULL CHECK (template IN ('lembrete_link_1', 'lembrete_link_2')),
    enviado_em TEXT    NOT NULL DEFAULT (datetime('now')),
    UNIQUE (lead_id, template)                   -- cada lembrete vai no máximo uma vez
);

-- Índices para as consultas mais frequentes do agente
CREATE INDEX idx_leads_status          ON leads(status);
CREATE INDEX idx_followups_lead        ON followups(lead_id);
CREATE INDEX idx_atendimentos_cliente  ON atendimentos(cliente_id);
CREATE INDEX idx_matriculas_cliente    ON matriculas(cliente_id);

-- =====================================================================
-- DADOS DE EXEMPLO (fictícios)
-- =====================================================================
INSERT INTO cursos (nome, area, nivel, ementa, carga_horaria_h, preco, parcelas_max, link_matricula) VALUES
('Lógica de Programação do Zero',  'programação', 'iniciante',     'Variáveis, condições, repetições e funções, com exercícios em Python', 40,  297.00,  6, 'https://trilhatech.exemplo/matricula/logica'),
('Python para Análise de Dados',   'dados',       'iniciante',     'Python, Pandas e gráficos para limpar e analisar planilhas e bases reais', 60,  497.00, 10, 'https://trilhatech.exemplo/matricula/python-dados'),
('SQL na Prática',                 'dados',       'iniciante',     'Consultas, filtros, junções e relatórios em bancos de dados relacionais', 30,  247.00,  6, 'https://trilhatech.exemplo/matricula/sql'),
('Agentes de IA com Python',       'IA',          'intermediario', 'Criação de agentes com modelos de linguagem, prompts, ferramentas e memória', 50,  697.00, 12, 'https://trilhatech.exemplo/matricula/agentes-ia'),
('Desenvolvimento Web Full Stack', 'programação', 'intermediario', 'HTML, CSS, JavaScript, React e Node.js para criar e publicar aplicações web', 120, 1197.00, 12, 'https://trilhatech.exemplo/matricula/fullstack');

-- Trilha: o curso indicado a quem conclui cada um
UPDATE cursos SET proximo_curso_id = 5 WHERE id = 1;  -- Lógica → Full Stack
UPDATE cursos SET proximo_curso_id = 4 WHERE id = 2;  -- Python Dados → Agentes de IA
UPDATE cursos SET proximo_curso_id = 2 WHERE id = 3;  -- SQL → Python Dados
UPDATE cursos SET proximo_curso_id = 4 WHERE id = 5;  -- Full Stack → Agentes de IA

INSERT INTO ajuda_aluno (tema, passos) VALUES
('recuperar login', '1. Acesse trilhatech.exemplo/entrar; 2. Toque em "Esqueci minha senha"; 3. Informe o e-mail da matrícula; 4. Abra o link enviado ao e-mail (veja também o spam) e crie uma nova senha.'),
('emitir certificado', '1. Conclua 100% das aulas do curso; 2. Na área do aluno, abra o curso; 3. Toque em "Certificado" e baixe o PDF.'),
('acessar o curso', '1. Entre em trilhatech.exemplo/entrar com o e-mail da matrícula; 2. Abra "Meus cursos"; 3. Escolha o curso e continue de onde parou.');

INSERT INTO clientes (nome, telefone_whatsapp, email, cidade, perfil, objetivo, consentimento_lgpd, data_consentimento, ultima_mensagem_em) VALUES
('Ana Souza',      '+5581990000001', 'ana@exemplo.com',     'Recife',    'interessado', 'primeiro emprego',  1, '2026-10-20 10:00:00', '2026-10-28 18:05:00'),
('Carlos Lima',    '+5581990000002', 'carlos@exemplo.com',  'Olinda',    'aluno',       'mudar de área',     1, '2026-09-02 14:30:00', '2026-09-05 10:00:00'),
('Juliana Alves',  '+5511990000003', NULL,                  'São Paulo', 'interessado', 'se atualizar',      1, '2026-10-28 19:15:00', '2026-10-28 19:20:00'),
('Marcos Ferreira','+5521990000004', 'marcos@exemplo.com',  'Rio de Janeiro', 'aluno',  'primeiro emprego',  1, '2026-08-15 09:00:00', '2026-08-20 16:00:00'),
('Patrícia Gomes', '+5581990000005', NULL,                  'Jaboatão',  'interessado', NULL,                0, NULL,                  '2026-10-29 08:30:00');

INSERT INTO leads (cliente_id, curso_id, origem, status, atualizado_em) VALUES
(1, 1, 'instagram', 'link_enviado', '2026-10-28 18:00:00');
INSERT INTO leads (cliente_id, curso_id, origem, status) VALUES
(1, 3, 'instagram', 'em_conversa'),
(2, 2, 'anuncio',   'matriculado'),
(3, 4, 'site',      'novo'),
(4, 5, 'indicacao', 'matriculado'),
(4, 3, 'indicacao', 'perdido'),
(5, 1, 'anuncio',   'novo');

INSERT INTO matriculas (cliente_id, curso_id, data_matricula, status, progresso_pct) VALUES
(2, 2, '2026-09-05', 'ativa',     45),
(4, 5, '2026-08-20', 'concluida', 100);

INSERT INTO atendimentos (cliente_id, motivo, encaminhado_humano, motivo_encaminhamento, resumo) VALUES
(1, 'indicacao',   0, NULL, 'Quer primeiro emprego; indicados Lógica e SQL; link de Lógica enviado.'),
(2, 'acesso',      0, NULL, 'Recuperou login pela opção "esqueci minha senha".'),
(4, 'certificado', 0, NULL, 'Orientado a emitir certificado na área do aluno.'),
(3, 'pagamento',   1, 'Pediu parcelamento fora do catálogo', 'Interessado em Agentes de IA; pediu 18x.');

-- =====================================================================
-- CONSULTAS ÚTEIS
-- =====================================================================

-- Q1. Contexto do cliente para o agente ([DADOS_DO_CLIENTE])
--     O sistema roda esta consulta com o número que chegou no WhatsApp.
SELECT
    c.nome,
    c.perfil,
    c.objetivo,
    c.consentimento_lgpd,
    c.opt_out,
    (SELECT GROUP_CONCAT(cu.nome || ' (' || l.status || ')', '; ')
       FROM leads l JOIN cursos cu ON cu.id = l.curso_id
      WHERE l.cliente_id = c.id)                                   AS interesses,
    (SELECT GROUP_CONCAT(cu.nome || ' - ' || m.status || ' ' || m.progresso_pct || '%', '; ')
       FROM matriculas m JOIN cursos cu ON cu.id = m.curso_id
      WHERE m.cliente_id = c.id)                                   AS matriculas,
    (SELECT a.resumo FROM atendimentos a
      WHERE a.cliente_id = c.id ORDER BY a.inicio DESC LIMIT 1)    AS ultimo_atendimento,
    (SELECT f.template || ' sobre ' || cu.nome || ' em ' || f.enviado_em
       FROM followups f JOIN leads l ON l.id = f.lead_id JOIN cursos cu ON cu.id = l.curso_id
      WHERE l.cliente_id = c.id ORDER BY f.enviado_em DESC LIMIT 1) AS ultimo_followup
FROM clientes c
WHERE c.telefone_whatsapp = '+5581990000001';

-- Q2. Catálogo ativo para o agente ([CATALOGO])
SELECT
    cu.nome, cu.area, cu.nivel, cu.ementa, cu.carga_horaria_h, cu.preco, cu.parcelas_max,
    ROUND(cu.preco / cu.parcelas_max, 2) AS valor_parcela,
    cu.formas_pagamento, cu.certificado, cu.link_matricula,
    prox.nome                            AS proximo_curso
FROM cursos cu
LEFT JOIN cursos prox ON prox.id = cu.proximo_curso_id AND prox.ativo = 1
WHERE cu.ativo = 1
ORDER BY cu.area, cu.nivel;

-- Q3. Funil de vendas: quantos leads em cada etapa
SELECT status, COUNT(*) AS total
FROM leads
GROUP BY status
ORDER BY CASE status
    WHEN 'novo' THEN 1 WHEN 'em_conversa' THEN 2 WHEN 'link_enviado' THEN 3
    WHEN 'matriculado' THEN 4 WHEN 'perdido' THEN 5 END;

-- Q4. Taxa de conversão por curso
SELECT
    cu.nome,
    COUNT(l.id)                                                  AS leads,
    SUM(l.status = 'matriculado')                                AS matriculados,
    ROUND(100.0 * SUM(l.status = 'matriculado') / COUNT(l.id), 1) AS conversao_pct
FROM cursos cu
LEFT JOIN leads l ON l.curso_id = cu.id
GROUP BY cu.id
ORDER BY conversao_pct DESC;

-- Q5. Fila de follow-up: quem recebeu o link, não comprou e está fora da
--     janela de 24h (então só pode receber template aprovado).
--     Regras: só com consentimento e sem opt-out; no máximo 2 lembretes;
--     o 2º só 3 dias depois do 1º e se a pessoa não respondeu ao 1º;
--     e nunca mais de um lembrete por pessoa a cada 3 dias.
SELECT
    l.id                                  AS lead_id,
    c.nome,
    c.telefone_whatsapp,
    cu.nome                               AS curso,
    cu.preco,
    cu.parcelas_max,
    ROUND(cu.preco / cu.parcelas_max, 2)  AS valor_parcela,
    cu.link_matricula,
    CASE WHEN f1.id IS NULL THEN 'lembrete_link_1' ELSE 'lembrete_link_2' END AS proximo_template
FROM leads l
JOIN clientes c ON c.id = l.cliente_id
JOIN cursos  cu ON cu.id = l.curso_id
LEFT JOIN followups f1 ON f1.lead_id = l.id AND f1.template = 'lembrete_link_1'
LEFT JOIN followups f2 ON f2.lead_id = l.id AND f2.template = 'lembrete_link_2'
WHERE l.status = 'link_enviado'
  AND c.consentimento_lgpd = 1
  AND c.opt_out = 0
  AND l.atualizado_em        <= datetime('now', '-24 hours')
  AND c.ultima_mensagem_em   <= datetime('now', '-24 hours')
  AND f2.id IS NULL
  AND (f1.id IS NULL
       OR (f1.enviado_em <= datetime('now', '-3 days') AND c.ultima_mensagem_em < f1.enviado_em))
  AND l.id = (SELECT lx.id FROM leads lx         -- um curso por pessoa: o link mais recente
               WHERE lx.cliente_id = c.id AND lx.status = 'link_enviado'
               ORDER BY lx.atualizado_em DESC, lx.id DESC LIMIT 1)
  AND NOT EXISTS (                               -- no máximo um lembrete por pessoa a cada 3 dias
        SELECT 1 FROM followups fx JOIN leads lx ON lx.id = fx.lead_id
         WHERE lx.cliente_id = c.id AND fx.enviado_em > datetime('now', '-3 days'));

-- Q6. Percentual de atendimentos encaminhados para humano, por motivo
SELECT
    motivo,
    COUNT(*)                                          AS atendimentos,
    SUM(encaminhado_humano)                           AS encaminhados,
    ROUND(100.0 * SUM(encaminhado_humano) / COUNT(*), 1) AS pct_humano
FROM atendimentos
GROUP BY motivo;

-- Q7. Passos de suporte para o agente ([AJUDA_ALUNO])
SELECT tema, passos
FROM ajuda_aluno
ORDER BY tema;

-- Q8. Aplicar o <registro> que o agente devolve no fim de cada resposta.
--     Exemplo com o registro de uma resposta à Ana:
--     {"nome": null, "motivo": "matricula", "lead": {"curso": "SQL na Prática", "status": "link_enviado"},
--      "encaminhar_humano": false, "motivo_encaminhamento": null, "opt_out": false,
--      "consentimento": null, "resumo": "Achou o SQL caro; viu a parcela e recebeu o link."}
INSERT INTO atendimentos (cliente_id, motivo, encaminhado_humano, motivo_encaminhamento, resumo)
VALUES (1, 'matricula', 0, NULL, 'Achou o SQL caro; viu a parcela e recebeu o link.');

INSERT INTO leads (cliente_id, curso_id, status)
SELECT 1, id, 'link_enviado' FROM cursos WHERE nome = 'SQL na Prática'
ON CONFLICT (cliente_id, curso_id) DO UPDATE
   SET status = excluded.status, atualizado_em = datetime('now')
 WHERE leads.status <> 'matriculado'           -- quem já comprou não volta no funil
   AND NOT (leads.status = 'link_enviado' AND excluded.status = 'em_conversa');  -- nem quem já recebeu o link

UPDATE clientes
   SET ultima_mensagem_em = datetime('now'),
       opt_out = MAX(opt_out, 0)               -- 1 quando o registro trouxer "opt_out": true
 WHERE id = 1;
