"""Lê o <registro> que o agente devolve no fim de cada resposta e atualiza o banco.

Uso direto (valida e aplica os registros de uma rodada de testes):
    python sistema/aplicar_registro.py testes/rodada-3.md
"""
import json
import re
import sqlite3
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MOTIVOS = {"duvida_curso", "indicacao", "matricula", "acesso", "certificado",
           "pagamento", "reembolso", "reclamacao", "outro"}
STATUS_LEAD = {"em_conversa", "link_enviado", "perdido"}
CAMPOS = {"nome", "motivo", "lead", "encaminhar_humano", "motivo_encaminhamento",
          "opt_out", "consentimento", "resumo"}
REGISTRO = re.compile(r"<registro>(.*?)</registro>", re.S)
DADO_SENSIVEL = re.compile(r"\d{11,}|\d{4}[ .-]?\d{4}[ .-]?\d{4}[ .-]?\d{4}")  # CPF ou cartão


def separar(resposta):
    """Devolve (texto que vai para o WhatsApp, registro como dict ou None)."""
    achado = REGISTRO.search(resposta)
    texto = REGISTRO.sub("", resposta).strip()
    return texto, (json.loads(achado.group(1)) if achado else None)


def validar(registro, cursos):
    erros = []
    if registro is None:
        return ["resposta sem <registro>"]
    if set(registro) != CAMPOS:
        erros.append(f"campos diferentes do esperado: {sorted(set(registro) ^ CAMPOS)}")
    if registro.get("motivo") not in MOTIVOS:
        erros.append(f"motivo inválido: {registro.get('motivo')}")
    lead = registro.get("lead")
    if lead is not None:
        if lead.get("curso") not in cursos:
            erros.append(f"curso fora do catálogo: {lead.get('curso')}")
        if lead.get("status") not in STATUS_LEAD:
            erros.append(f"status de lead inválido: {lead.get('status')}")
    if registro.get("encaminhar_humano") and not registro.get("motivo_encaminhamento"):
        erros.append("encaminhou sem motivo_encaminhamento")
    if len(str(registro.get("resumo", "")).split()) > 20:
        erros.append("resumo com mais de 20 palavras")
    if DADO_SENSIVEL.search(json.dumps(registro)):
        erros.append("registro com possível CPF ou cartão")
    return erros


def aplicar(con, telefone, registro):
    """Grava o atendimento, avança o lead e atualiza o cliente. Devolve o id do cliente."""
    linha = con.execute("SELECT id FROM clientes WHERE telefone_whatsapp = ?", (telefone,)).fetchone()
    if linha is None:
        if not registro["nome"]:
            return None  # contato novo ainda sem nome: nada a gravar
        cur = con.execute("INSERT INTO clientes (nome, telefone_whatsapp) VALUES (?, ?)",
                          (registro["nome"], telefone))
        cliente_id = cur.lastrowid
    else:
        cliente_id = linha[0]

    con.execute(
        "INSERT INTO atendimentos (cliente_id, motivo, encaminhado_humano, motivo_encaminhamento, resumo)"
        " VALUES (?, ?, ?, ?, ?)",
        (cliente_id, registro["motivo"], int(registro["encaminhar_humano"]),
         registro["motivo_encaminhamento"], registro["resumo"]))

    if registro["lead"]:
        # Mesma regra da Q8: o funil não volta para trás
        con.execute(
            "INSERT INTO leads (cliente_id, curso_id, status)"
            " SELECT ?, id, ? FROM cursos WHERE nome = ?"
            " ON CONFLICT (cliente_id, curso_id) DO UPDATE"
            "   SET status = excluded.status, atualizado_em = datetime('now')"
            " WHERE leads.status <> 'matriculado'"
            "   AND NOT (leads.status = 'link_enviado' AND excluded.status = 'em_conversa')",
            (cliente_id, registro["lead"]["status"], registro["lead"]["curso"]))

    con.execute("UPDATE clientes SET ultima_mensagem_em = datetime('now') WHERE id = ?", (cliente_id,))
    if registro["opt_out"]:
        con.execute("UPDATE clientes SET opt_out = 1 WHERE id = ?", (cliente_id,))
    if registro["consentimento"] is not None:
        con.execute(
            "UPDATE clientes SET consentimento_lgpd = ?,"
            " data_consentimento = CASE WHEN ? THEN datetime('now') END WHERE id = ?",
            (int(registro["consentimento"]), int(registro["consentimento"]), cliente_id))
    return cliente_id


def banco_de_exemplo():
    """Cria o banco em memória só com tabelas e dados de exemplo (sem rodar as consultas)."""
    sql = (RAIZ / "database" / "schema.sql").read_text(encoding="utf-8")
    con = sqlite3.connect(":memory:")
    con.executescript(sql[:sql.index("-- Q1.")])
    return con


def main(caminho):
    """Lê as conversas de um arquivo de rodada, valida e aplica cada registro em ordem."""
    con = banco_de_exemplo()
    cursos = {nome for (nome,) in con.execute("SELECT nome FROM cursos")}
    texto = Path(caminho).read_text(encoding="utf-8")
    total, com_erro = 0, 0
    for conversa in re.split(r"<!-- telefone: ", texto)[1:]:
        telefone, corpo = conversa.split(" -->", 1)
        for resposta in re.findall(r"```text\n(.*?)```", corpo, re.S):
            if "<registro>" not in resposta:
                continue  # blocos de configuração, não são respostas
            total += 1
            mensagem, registro = separar(resposta)
            erros = validar(registro, cursos)
            if "<registro>" in mensagem:
                erros.append("registro vazou para o texto do WhatsApp")
            if erros:
                com_erro += 1
                print(f"[ERRO] {telefone}: {mensagem[:50]}... -> {erros}")
            else:
                aplicar(con, telefone, registro)
    print(f"\n{total} respostas, {total - com_erro} registros válidos aplicados, {com_erro} com erro.\n")
    for nome, opt_out, consent, ult in con.execute(
            "SELECT nome, opt_out, consentimento_lgpd, ultima_mensagem_em IS NOT NULL FROM clientes"):
        leads = con.execute(
            "SELECT cu.nome || ': ' || l.status FROM leads l JOIN cursos cu ON cu.id = l.curso_id"
            " JOIN clientes c ON c.id = l.cliente_id WHERE c.nome = ?", (nome,)).fetchall()
        print(f"{nome:16} opt_out={opt_out} consentimento={consent} leads={[l[0] for l in leads]}")
    encaminhados = con.execute(
        "SELECT c.nome, a.motivo_encaminhamento FROM atendimentos a JOIN clientes c ON c.id = a.cliente_id"
        " WHERE a.encaminhado_humano = 1 AND a.id > 4").fetchall()
    print("\nEncaminhados nesta rodada:", encaminhados)
    return com_erro


if __name__ == "__main__":
    sys.exit(1 if main(sys.argv[1]) else 0)
