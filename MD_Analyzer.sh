#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSAO="2.0"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-./downloads}"

# Campos que costumam revelar informações sensíveis (usados com -s e no resumo).
CAMPOS_SENSIVEIS=(Author Creator Producer LastModifiedBy Company Manager Software
                  CreatorTool HostComputer Make Model SerialNumber GPSPosition
                  CreateDate ModifyDate Title Subject Keywords Comment)

# Campos agrupados no resumo (-r): bons para descobrir usuários e softwares usados pelo alvo.
CAMPOS_RESUMO=(Author Creator LastModifiedBy Company Producer Software CreatorTool)

# Extensões baixadas no modo -w (crawler).
EXTENSOES="${EXTENSOES:-pdf,doc,docx,xls,xlsx,ppt,pptx,odt,ods,odp,rtf,jpg,jpeg,png,tiff}"

SOMENTE_SENSIVEIS=0
RESUMO=0
FORMATO=""
SAIDA=""
ACAO=""
ALVO=""
ANALISADOS=()   # Arquivos/diretórios analisados, usados no resumo final

function apresentacao() {
    echo -e "${BLUE}"
    if command -v figlet &> /dev/null; then
        figlet -f slant "MD Analyzer"
    else
        echo "=== MD Analyzer ==="
    fi
    echo -e "${NC}"
    echo -e "${YELLOW}Bem-vindo ao MD Analyzer!${NC}"
    echo -e "Este script usa a ferramenta exiftool para baixar e analisar MD (metadados) de arquivos como PDF, DOC, DOCX, Excel, entre outros."
    echo "----------------------------------------------------"
}

# Instruções (-h)
function instrucoes_uso() {
    echo -e "Uso: ${GREEN}$0 [opções] <ação> <arquivo, diretório, URL ou lista>${NC}"
    echo
    echo -e "Ações:"
    echo -e "  ${GREEN}-a, --analyze${NC} <alvo>     Baixa (se URL) e analisa metadados de um arquivo, diretório ou link"
    echo -e "  ${GREEN}-l, --list${NC} <arquivo>     Analisa cada URL/caminho de um arquivo de texto (um por linha)"
    echo -e "  ${GREEN}-w, --web${NC} <URL>          Procura documentos linkados em uma página, baixa e analisa todos"
    echo -e "  ${GREEN}-c, --clean${NC} <alvo>       Remove os metadados de um arquivo ou diretório (mantém backup *_original)"
    echo -e "  ${GREEN}-h, --help${NC}               Exibe este manual de uso"
    echo -e "  ${GREEN}-v, --version${NC}            Exibe a versão do script"
    echo
    echo -e "Opções (use antes da ação):"
    echo -e "  ${GREEN}-s, --sensitive${NC}          Mostra apenas campos sensíveis (autor, software, GPS, datas...)"
    echo -e "  ${GREEN}-r, --resume${NC}             Ao final, mostra um resumo de autores/softwares encontrados"
    echo -e "  ${GREEN}-f, --format${NC} <csv|json>  Saída em CSV ou JSON"
    echo -e "  ${GREEN}-o, --output${NC} <arquivo>   Salva o resultado também em um arquivo"
    echo -e "  ${GREEN}-e, --ext${NC} <lista>        Extensões baixadas com -w (padrão: $EXTENSOES)"
    echo
    echo -e "Exemplos:"
    echo -e "  $0 -a documento.pdf"
    echo -e "  $0 -s -a https://exemplo.com/relatorio.pdf"
    echo -e "  $0 -r -w https://exemplo.com/documentos/"
    echo -e "  $0 -f csv -o resultado.csv -a ./pasta"
    echo -e "  $0 -c foto.jpg"
    echo "===================================================="
}

function versao() {
    echo -e "${YELLOW}**MD Analyzer** - versão $VERSAO${NC}"
}

# Mensagens de status: vão para stderr no modo CSV/JSON para não sujar a saída.
function info() {
    if [ -n "$FORMATO" ]; then echo -e "$@" >&2; else echo -e "$@"; fi
}

function verificar_dependencias() {
    if ! command -v exiftool &> /dev/null; then
        echo -e "${RED}Erro: exiftool não está instalado. Instale com 'sudo apt install libimage-exiftool-perl'.${NC}"
        exit 1
    fi
}

function exif() {
    local args=()
    case "$FORMATO" in
        csv)  args+=(-csv) ;;
        json) args+=(-json) ;;
        *)    args+=(-G1 -s) ;;
    esac
    if [ "$SOMENTE_SENSIVEIS" = 1 ]; then
        for campo in "${CAMPOS_SENSIVEIS[@]}"; do args+=("-$campo"); done
    fi
    exiftool "${args[@]}" "$@"
}

# Baixa uma URL para um arquivo (ou para a saída padrão, se o destino for "-").
function baixar() {
    local url="$1" destino="$2"
    if command -v wget &> /dev/null; then
        wget -q --timeout=30 -U "Mozilla/5.0" "$url" -O "$destino"
    elif command -v curl &> /dev/null; then
        curl -fsSL --max-time 30 -A "Mozilla/5.0" "$url" -o "$destino"
    else
        echo -e "${RED}Erro: é necessário ter wget ou curl instalado.${NC}" >&2
        return 1
    fi
}

function baixar_e_analisar() {
    local url="$1"
    local nome_arquivo

    # Remove query string (?a=b) e fragmento (#x) do nome do arquivo.
    nome_arquivo=$(basename "${url%%[?#]*}")
    [ -z "$nome_arquivo" ] || [ "$nome_arquivo" = "/" ] && nome_arquivo="download_$(date +%s)"

    mkdir -p "$DOWNLOAD_DIR"
    local destino="$DOWNLOAD_DIR/$nome_arquivo"

    info "${GREEN}Baixando o arquivo: $url${NC}"
    # O wget cria o arquivo mesmo quando o download falha, por isso checamos também o tamanho.
    if baixar "$url" "$destino" && [ -s "$destino" ]; then
        info "${GREEN}Download concluído (${destino}). Analisando MD do arquivo baixado...${NC}"
        ANALISADOS+=("$destino")
        exif "$destino"
    else
        rm -f "$destino"
        echo -e "${RED}Erro: Falha no download do arquivo.${NC}"
        return 1
    fi
}

function analisar_metadados() {
    if [ -z "$1" ]; then
        echo -e "${RED}Erro: Nenhum arquivo, diretório ou link fornecido.${NC}"
        return 1
    fi

    if [[ "$1" =~ ^https?:// ]]; then
        baixar_e_analisar "$1"
    elif [ -d "$1" ]; then
        info "${GREEN}Analisando todos os arquivos no diretório: $1${NC}"
        ANALISADOS+=("$1")
        exif -r "$1"
    elif [ -f "$1" ]; then
        info "${GREEN}Analisando arquivo: $1${NC}"
        ANALISADOS+=("$1")
        exif "$1"
    else
        echo -e "${RED}Erro: O arquivo ou diretório especificado não existe: $1${NC}"
        return 1
    fi
}

function analisar_lista() {
    if [ ! -f "$1" ]; then
        echo -e "${RED}Erro: Lista não encontrada: $1${NC}"
        return 1
    fi

    local erros=0
    while IFS= read -r alvo || [ -n "$alvo" ]; do
        alvo="${alvo%$'\r'}"
        # Ignora linhas vazias e comentários.
        [[ -z "$alvo" || "$alvo" == \#* ]] && continue
        echo "----------------------------------------------------"
        analisar_metadados "$alvo" || erros=$((erros + 1))
    done < "$1"

    [ "$erros" -eq 0 ]
}

# Converte um link relativo de uma página em URL absoluta.
function url_absoluta() {
    local link="$1" pagina="$2"
    local origem="${pagina%%://*}://$(echo "${pagina#*://}" | cut -d/ -f1)"
    local base="${pagina%%[?#]*}"
    base="${base%/*}"
    [[ "$pagina" =~ ^https?://[^/]+$ ]] && base="$pagina"

    case "$link" in
        http://*|https://*) echo "$link" ;;
        //*) echo "${pagina%%://*}:$link" ;;
        /*)  echo "$origem$link" ;;
        *)   echo "$base/$link" ;;
    esac
}

# Procura links para documentos em uma página web, baixa e analisa cada um.
function analisar_pagina() {
    local pagina="$1"
    if [[ ! "$pagina" =~ ^https?:// ]]; then
        echo -e "${RED}Erro: informe uma URL começando com http:// ou https://${NC}"
        return 1
    fi

    info "${GREEN}Procurando documentos em: $pagina${NC}"
    local html
    html=$(baixar "$pagina" -) || { echo -e "${RED}Erro: não foi possível acessar a página.${NC}"; return 1; }

    local regex_ext="\\.(${EXTENSOES//,/|})([?#][^\"']*)?$"
    local links=()
    mapfile -t links < <(echo "$html" \
        | grep -oiE "(href|src)=[\"'][^\"']+[\"']" \
        | sed -E "s/^(href|src)=[\"']//I; s/[\"']$//" \
        | grep -iE "$regex_ext" \
        | while IFS= read -r l; do url_absoluta "$l" "$pagina"; done \
        | sort -u)

    if [ ${#links[@]} -eq 0 ]; then
        info "${YELLOW}Nenhum documento ($EXTENSOES) encontrado na página.${NC}"
        return 0
    fi

    info "${GREEN}${#links[@]} documento(s) encontrado(s).${NC}"
    for link in "${links[@]}"; do
        echo "----------------------------------------------------"
        baixar_e_analisar "$link"
    done
}

function limpar_metadados() {
    local alvo="$1"
    if [ -d "$alvo" ]; then
        echo -e "${YELLOW}Removendo metadados de todos os arquivos em: $alvo${NC}"
        exiftool -r -all= "$alvo"
    elif [ -f "$alvo" ]; then
        echo -e "${YELLOW}Removendo metadados de: $alvo${NC}"
        exiftool -all= "$alvo"
    else
        echo -e "${RED}Erro: O arquivo ou diretório especificado não existe: $alvo${NC}"
        return 1
    fi
    echo -e "${GREEN}Concluído. O arquivo original foi mantido com o sufixo _original.${NC}"
}

# Agrupa os valores dos campos mais interessantes de todos os arquivos analisados.
function mostrar_resumo() {
    [ ${#ANALISADOS[@]} -eq 0 ] && return
    echo
    echo -e "${BLUE}==================== RESUMO ====================${NC}"
    for campo in "${CAMPOS_RESUMO[@]}"; do
        local valores
        valores=$(exiftool -q -r -s3 "-$campo" "${ANALISADOS[@]}" 2> /dev/null \
                  | grep -v '^$' | sort | uniq -c | sort -nr)
        [ -z "$valores" ] && continue
        echo -e "${YELLOW}$campo:${NC}"
        echo "$valores"
    done
    echo -e "${BLUE}================================================${NC}"
}

# Lê as opções (curtas e longas) até encontrar a ação.
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)      ACAO="ajuda"; shift ;;
        -v|--version)   ACAO="versao"; shift ;;
        -s|--sensitive) SOMENTE_SENSIVEIS=1; shift ;;
        -r|--resume)    RESUMO=1; shift ;;
        -f|--format)    FORMATO="$2"; shift; shift ;;
        -o|--output)    SAIDA="$2"; shift; shift ;;
        -e|--ext)       EXTENSOES="$2"; shift; shift ;;
        -a|--analyze)   ACAO="analisar"; ALVO="$2"; shift; shift ;;
        -l|--list)      ACAO="lista"; ALVO="$2"; shift; shift ;;
        -w|--web)       ACAO="web"; ALVO="$2"; shift; shift ;;
        -c|--clean)     ACAO="limpar"; ALVO="$2"; shift; shift ;;
        *)              ACAO="invalida"; shift ;;
    esac
done

# No formato CSV/JSON a saída precisa ser "limpa" para poder ser importada.
if [ -z "$FORMATO" ]; then
    apresentacao
elif [[ "$FORMATO" != "csv" && "$FORMATO" != "json" ]]; then
    echo -e "${RED}Erro: formato inválido '$FORMATO' (use csv ou json).${NC}"
    exit 1
fi

if [ -n "$SAIDA" ]; then
    exec > >(tee -a "$SAIDA")
fi

if [[ "$ACAO" =~ ^(analisar|lista|web|limpar)$ ]]; then
    if [ -z "$ALVO" ]; then
        echo -e "${RED}Erro: Nenhum arquivo, diretório ou link fornecido.${NC}"
        exit 1
    fi
    verificar_dependencias
fi

status=0
case "$ACAO" in
    ajuda)    instrucoes_uso ;;
    versao)   versao ;;
    analisar) analisar_metadados "$ALVO" || status=1 ;;
    lista)    analisar_lista "$ALVO" || status=1 ;;
    web)      analisar_pagina "$ALVO" || status=1 ;;
    limpar)   limpar_metadados "$ALVO" || status=1 ;;
    *)
        echo -e "${RED}Opção inválida. Use -h para exibir o manual de uso.${NC}"
        exit 1
        ;;
esac

[ "$RESUMO" -eq 1 ] && mostrar_resumo
exit "$status"
