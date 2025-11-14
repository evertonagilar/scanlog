"""Dashboard Streamlit para visualização dos resultados do scanlog.

Execute com:
    streamlit run dashboard_streamlit.py
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Optional

import streamlit as st

BASE_DIR = Path(__file__).resolve().parent
RESULTADOS_DIR = BASE_DIR / "resultado"


@dataclass
class ReportEntry:
    modelo: str
    pasta: Path
    data_execucao: str
    report_path: Path


def descobre_reports() -> Dict[str, List[ReportEntry]]:
    """Percorre resultado/ e retorna os relatórios disponíveis por modelo."""
    encontrados: Dict[str, List[ReportEntry]] = {}
    if not RESULTADOS_DIR.exists():
        return encontrados

    for modelo_dir in sorted(RESULTADOS_DIR.iterdir()):
        if not modelo_dir.is_dir():
            continue
        modelo = modelo_dir.name
        for analise_dir in sorted(modelo_dir.glob("analise-*")):
            json_path = analise_dir / "report" / "data" / "report-data.json"
            if json_path.is_file():
                execucao = analise_dir.name.replace("analise-", "")
                encontrados.setdefault(modelo, []).append(
                    ReportEntry(modelo=modelo, pasta=analise_dir, data_execucao=execucao, report_path=json_path)
                )
    return encontrados


@lru_cache(maxsize=64)
def carrega_report(path: str) -> Optional[Dict]:
    """Carrega o JSON do relatório com cache simples."""
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except OSError as exc:
        st.error(f"Não foi possível ler {path}: {exc}")
    except json.JSONDecodeError as exc:
        st.error(f"JSON inválido em {path}: {exc}")
    return None


def altura_tabela(qtd_linhas: int) -> int:
    # aumenta o espaço para evitar scroll vertical sempre que possível
    base = 300
    row_height = 36
    return max(base, (qtd_linhas + 2) * row_height)


def mostra_tabela(dados: List[Dict], titulo: str) -> None:
    if not dados:
        st.info(f"Sem dados para {titulo.lower()}.")
        return
    st.subheader(titulo)
    st.dataframe(dados, use_container_width=True, height=altura_tabela(len(dados)))


def mostra_desempenho(info: Dict) -> None:
    if not info:
        st.info("Sem dados de desempenho.")
        return

    st.subheader("Desempenho (ms)")
    cols = st.columns(3)
    cols[0].metric("Média", f"{info.get('media_ms', 0):,.0f}".replace(",", "."), help="Tempo médio em ms")
    cols[1].metric("Mínimo", f"{info.get('min_ms', 0):,.0f}".replace(",", "."))
    cols[2].metric("Máximo", f"{info.get('max_ms', 0):,.0f}".replace(",", "."))

    cols = st.columns(3)
    cols[0].metric("P50", f"{info.get('p50_ms', 0):,.0f}".replace(",", "."))
    cols[1].metric("P95", f"{info.get('p95_ms', 0):,.0f}".replace(",", "."))
    cols[2].metric("P99", f"{info.get('p99_ms', 0):,.0f}".replace(",", "."))


def lista_extracoes(pasta: Path) -> List[Dict]:
    arquivos: List[Dict] = []
    if not pasta.exists():
        return arquivos
    for arquivo in sorted(pasta.glob("**/*")):
        if not arquivo.is_file():
            continue
        rel_path = arquivo.relative_to(pasta)
        try:
            stat = arquivo.stat()
            arquivos.append(
                {
                    "arquivo": str(rel_path),
                    "bytes": stat.st_size,
                    "tamanho_kb": round(stat.st_size / 1024, 2),
                    "atualizado_em": datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                    "path": arquivo,
                }
            )
        except OSError:
            continue
    return arquivos


def mostra_extracoes(pasta: Path, state_prefix: str) -> None:
    st.subheader("Arquivos de Extrações")
    arquivos = lista_extracoes(pasta)
    if not arquivos:
        st.info("Nenhum arquivo encontrado em result/extracoes.")
        return

    selecionado_key = f"{state_prefix}_selecionado"
    selecionado_info = st.session_state.get(selecionado_key)

    if selecionado_info:
        arquivo_path: Path = selecionado_info["path"]
        if st.button("⬅️ Voltar para a lista", key=f"{state_prefix}_voltar"):
            st.session_state.pop(selecionado_key, None)
            st.rerun()
        st.markdown(f"**Visualizando:** `{arquivo_path}`")
        tam_limite = 200_000
        try:
            with arquivo_path.open("r", encoding="utf-8", errors="ignore") as handle:
                conteudo = handle.read(tam_limite + 1)
        except OSError as exc:
            st.error(f"Não foi possível abrir o arquivo selecionado: {exc}")
            return

        truncado = len(conteudo) > tam_limite
        if truncado:
            conteudo = conteudo[:tam_limite]
        st.text_area("Conteúdo", conteudo, height=1600)
        if truncado:
            st.warning("Visualização limitada aos primeiros ~200 KB. Use o botão para baixar o arquivo completo.")

        try:
            dados_brutos = arquivo_path.read_bytes()
        except OSError as exc:
            st.error(f"Não foi possível ler o arquivo para download: {exc}")
            return

        st.download_button(
            "Baixar arquivo completo",
            data=dados_brutos,
            file_name=arquivo_path.name,
            mime="text/plain",
            key=f"{state_prefix}_download",
        )
        return

    tabela = []
    for a in arquivos:
        tabela.append(
            {
                "Selecionar": False,
                "Arquivo": a["arquivo"],
                "Tamanho (KB)": a["tamanho_kb"],
                "Atualizado em": a["atualizado_em"],
            }
        )

    tabela_editada = st.data_editor(
        tabela,
        use_container_width=True,
        hide_index=True,
        column_config={
            "Selecionar": st.column_config.CheckboxColumn(
                "Abrir",
                help="Marque uma linha para visualizar o arquivo",
                default=False,
            )
        },
        key=f"{state_prefix}_tabela",
        disabled=["Arquivo", "Tamanho (KB)", "Atualizado em"],
        height=altura_tabela(len(tabela)),
    )

    for idx, row in enumerate(tabela_editada):
        if row.get("Selecionar"):
            st.session_state[selecionado_key] = arquivos[idx]
            st.rerun()
            break


def main() -> None:
    st.set_page_config(page_title="Scanlog Dashboard", layout="wide")
    st.title("📊 Dashboard de Resultados do Scanlog")

    reports_por_modelo = descobre_reports()
    if not reports_por_modelo:
        st.warning("Nenhum relatório foi encontrado. Execute o scanlog antes de abrir o dashboard.")
        return

    modelos = sorted(reports_por_modelo)
    modelo_selecionado = st.sidebar.selectbox("Modelo", modelos)

    entradas = reports_por_modelo.get(modelo_selecionado, [])
    if not entradas:
        st.warning("Nenhuma análise disponível para o modelo selecionado.")
        return

    analises = sorted(entradas, key=lambda item: item.data_execucao, reverse=True)
    label_map = {entry.data_execucao: entry for entry in analises}
    execucoes = list(label_map)
    execucao_sel = st.sidebar.selectbox("Execução", execucoes)

    entrada = label_map[execucao_sel]
    report = carrega_report(str(entrada.report_path))
    if not report:
        return

    st.sidebar.markdown(f"**Arquivo fonte:** `{report.get('fonte', entrada.pasta)}`")
    st.sidebar.markdown(f"**Gerado em:** {report.get('geradoEm', 'N/D')}")
    st.sidebar.download_button(
        label="Baixar JSON",
        data=json.dumps(report, ensure_ascii=False, indent=2),
        file_name=f"scanlog-{modelo_selecionado}-{execucao_sel}.json",
        mime="application/json",
    )

    st.header(f"Resumo - {modelo_selecionado.upper()} ({execucao_sel})")
    contadores = report.get("contadores", [])
    if contadores:
        total_eventos = sum(item.get("quantidade", 0) for item in contadores)
    else:
        total_eventos = 0

    col1, col2 = st.columns(2)
    col1.metric("Indicadores monitorados", len(contadores))
    col2.metric("Total de eventos registrados", total_eventos)

    mostra_desempenho(report.get("desempenho", {}))
    mostra_tabela(contadores, "Contadores Gerais")
    mostra_tabela(report.get("mensagensNegocio", []), "Mensagens de Negócio")
    mostra_tabela(report.get("topMetodos", []), "Top Métodos Pesados")
    mostra_tabela(report.get("topUsoMetodos", []), "Top Uso de Métodos (Stacktrace)")
    mostra_tabela(report.get("topClasses", []), "Top Classes Utilizadas")
    mostra_tabela(report.get("topModulos", []), "Top Módulos Pesados")
    mostra_tabela(report.get("topModulosSubsistema", []), "Top Módulos por Subsistema")
    mostra_extracoes(entrada.pasta / "result" / "extracoes", state_prefix=f"extracoes_{modelo_selecionado}_{execucao_sel}")

    st.caption("Os dados são gerados a partir dos arquivos em resultado/<modelo>/analise-*/report/data/report-data.json")


if __name__ == "__main__":
    main()
