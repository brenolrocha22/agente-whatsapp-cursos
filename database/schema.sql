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
    criado_em           TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- 2. CURSOS (o [CATALOGO] que o agente recebe)
-- Preço e link só existem aqui: o agente nunca inventa esses dados.
-- ---------------------------------------------------------------------
CREATE TABLE cursos (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    nome             TEXT    NOT NULL,
    area             TEXT    NOT NULL,                -- programação, dados, IA
    nivel            TEXT    NOT NULL CHECK (nivel IN ('iniciante', 'intermediario', 'avancado')),
    carga_horaria_h  INTEGER NOT NULL,
    preco            REAL    NOT NULL,
    parcelas_max     INTEGER NOT NULL DEFAULT 1,
    certificado      INTEGER NOT NULL DEFAULT 1 CHECK (certificado IN (0, 1)),
    link_matricula   TEXT    NOT NULL,
    ativo            INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0, 1))
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

-- Índices para as consultas mais frequentes do agente
CREATE INDEX idx_leads_status          ON leads(status);
CREATE INDEX idx_atendimentos_cliente  ON atendimentos(cliente_id);
CREATE INDEX idx_matriculas_cliente    ON matriculas(cliente_id);

-- =====================================================================
-- DADOS DE EXEMPLO (fictícios)
-- =====================================================================
INSERT INTO cursos (nome, area, nivel, carga_horaria_h, preco, parcelas_max, link_matricula) VALUES
('Lógica de Programação do Zero',  'programação', 'iniciante',     40,  297.00,  6, 'https://trilhatech.exemplo/matricula/logica'),
('Python para Análise de Dados',   'dados',       'iniciante',     60,  497.00, 10, 'https://trilhatech.exemplo/matricula/python-dados'),
('SQL na Prática',                 'dados',       'iniciante',     30,  247.00,  6, 'https://trilhatech.exemplo/matricula/sql'),
('Agentes de IA com Python',       'IA',          'intermediario', 50,  697.00, 12, 'https://trilhatech.exemplo/matricula/agentes-ia'),
('Desenvolvimento Web Full Stack', 'programação', 'intermediario', 120, 1197.00, 12, 'https://trilhatech.exemplo/matricula/fullstack');

INSERT INTO clientes (nome, telefone_whatsapp, email, cidade, perfil, objetivo, consentimento_lgpd, data_consentimento) VALUES
('Ana Souza',      '+5581990000001', 'ana@exemplo.com',     'Recife',    'interessado', 'primeiro emprego',  1, '2026-10-20 10:00:00'),
('Carlos Lima',    '+5581990000002', 'carlos@exemplo.com',  'Olinda',    'aluno',       'mudar de área',     1, '2026-09-02 14:30:00'),
('Juliana Alves',  '+5511990000003', NULL,                  'São Paulo', 'interessado', 'se atualizar',      1, '2026-10-28 19:15:00'),
('Marcos Ferreira','+5521990000004', 'marcos@exemplo.com',  'Rio de Janeiro', 'aluno',  'primeiro emprego',  1, '2026-08-15 09:00:00'),
('Patrícia Gomes', '+5581990000005', NULL,                  'Jaboatão',  'interessado', NULL,                0, NULL);

INSERT INTO leads (cliente_id, curso_id, origem, status) VALUES
(1, 1, 'instagram', 'link_enviado'),
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
      WHERE a.cliente_id = c.id ORDER BY a.inicio DESC LIMIT 1)    AS ultimo_atendimento
FROM clientes c
WHERE c.telefone_whatsapp = '+5581990000001';

-- Q2. Catálogo ativo para o agente ([CATALOGO])
SELECT nome, area, nivel, carga_horaria_h, preco, parcelas_max, certificado, link_matricula
FROM cursos
WHERE ativo = 1
ORDER BY area, nivel;

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

-- Q5. Leads que receberam o link e ainda não fecharam,
--     só de quem deu consentimento e não pediu para sair (follow-up).
SELECT c.nome, c.telefone_whatsapp, cu.nome AS curso, l.atualizado_em
FROM leads l
JOIN clientes c ON c.id = l.cliente_id
JOIN cursos  cu ON cu.id = l.curso_id
WHERE l.status = 'link_enviado'
  AND c.consentimento_lgpd = 1
  AND c.opt_out = 0;

-- Q6. Percentual de atendimentos encaminhados para humano, por motivo
SELECT
    motivo,
    COUNT(*)                                          AS atendimentos,
    SUM(encaminhado_humano)                           AS encaminhados,
    ROUND(100.0 * SUM(encaminhado_humano) / COUNT(*), 1) AS pct_humano
FROM atendimentos
GROUP BY motivo;
