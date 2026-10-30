# MD Analyzer

Script em Bash que usa o **exiftool** para analisar metadados de arquivos como PDF, DOC, DOCX, XLSX, PPTX e imagens. Analisa arquivos locais, diretórios inteiros, URLs e até páginas web inteiras, baixando todos os documentos linkados. Útil em OSINT para descobrir nomes de usuários, softwares e versões usados por uma organização.

## Funcionalidades

- Análise de **arquivo**, **diretório** (recursivo) ou **URL**
- **Lista** de alvos em um arquivo de texto (URLs e caminhos misturados)
- **Crawler** (`-w`): encontra documentos linkados em uma página, baixa e analisa todos
- **Modo sensível** (`-s`): mostra apenas os campos que costumam vazar informação (autor, empresa, software, GPS, datas, número de série da câmera...)
- **Resumo** (`-r`): agrupa os autores, empresas e softwares encontrados em todos os arquivos
- Saída em **CSV** ou **JSON** (`-f`)
- **Remoção de metadados** (`-c`), mantendo um backup do original
- Salva o resultado em arquivo (`-o`)
- Funciona com `wget` ou `curl`

## Instalação

```bash
sudo apt install libimage-exiftool-perl wget figlet   # figlet é opcional
git clone https://github.com/knxbrenno/Metadata-Analyzer.git
cd Metadata-Analyzer
chmod +x MD_Analyzer.sh
```

## Uso

```bash
./MD_Analyzer.sh [opções] <ação> <alvo>
```

**Ações**

| Ação | Descrição |
|---|---|
| `-a, --analyze <alvo>` | Analisa um arquivo, diretório ou URL |
| `-l, --list <arquivo>` | Analisa cada linha de um arquivo de texto |
| `-w, --web <URL>` | Baixa e analisa todos os documentos linkados na página |
| `-c, --clean <alvo>` | Remove os metadados (cria backup `*_original`) |
| `-h, --help` | Ajuda |
| `-v, --version` | Versão |

**Opções** (use antes da ação)

| Opção | Descrição |
|---|---|
| `-s, --sensitive` | Mostra apenas campos sensíveis |
| `-r, --resume` | Resumo de autores/softwares ao final |
| `-f, --format <csv\|json>` | Formato da saída |
| `-o, --output <arquivo>` | Salva o resultado em um arquivo |
| `-e, --ext <lista>` | Extensões baixadas com `-w` (padrão: documentos do Office, PDF e imagens) |

Os downloads ficam em `./downloads` (altere com a variável `DOWNLOAD_DIR`).

### Exemplos

```bash
# Arquivo local
./MD_Analyzer.sh -a relatorio.pdf

# Apenas campos sensíveis de um arquivo online
./MD_Analyzer.sh -s -a https://exemplo.com/arquivo.docx

# Todos os PDFs de uma página, com resumo de autores e softwares
./MD_Analyzer.sh -r -e pdf -w https://exemplo.com/documentos/

# Pasta inteira exportada para CSV
./MD_Analyzer.sh -f csv -o metadados.csv -a ./arquivos

# Remover metadados de uma foto antes de publicar
./MD_Analyzer.sh -c foto.jpg
```

## Aviso

Ferramenta para fins educacionais e testes autorizados.
