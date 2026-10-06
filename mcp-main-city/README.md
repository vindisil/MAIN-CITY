# Main City MCP

Servidor MCP local para trabalhar com o projeto Godot Main City de forma controlada.

## Estado atual

Versão **0.2.0** com leitura e escrita controlada.

Ferramentas disponíveis:

- `project_info`
- `list_project_files`
- `read_project_file`
- `search_project_text`
- `write_project_file`
- `replace_project_text`
- `git_status`
- `git_diff`

## Proteções

- acesso fora da pasta `MAIN-CITY` é bloqueado;
- escrita só é permitida em arquivos textuais do projeto;
- antes de alterar um arquivo existente, é criado backup automático em `.mcp-backups`;
- escrita em `.git`, `.godot`, `.github`, `node_modules`, `.mcp-backups` e na própria pasta `mcp-main-city` é bloqueada;
- não existe ferramenta de shell genérico;
- o MCP não executa `commit`, `pull` ou `push` automaticamente.

## Requisitos

- Windows
- Node.js 20 ou mais recente
- Git instalado
- Projeto `MAIN-CITY` clonado localmente

## Instalar

Abra o PowerShell dentro da pasta `MAIN-CITY\\mcp-main-city` e execute:

```powershell
npm install
```

## Testar localmente

```powershell
npm run test:mcp
```

Resultado esperado:

```text
MCP_SMOKE_OK tools=8 controlled_write=ok
```

## Abrir no MCP Inspector

```powershell
npx @modelcontextprotocol/inspector node src/index.mjs
```

Depois conecte e abra `Tools`.

## Caminho do projeto

Por padrão o servidor considera como raiz a pasta `MAIN-CITY`, porque `mcp-main-city` fica dentro dela.

Para apontar para outra cópia:

```powershell
$env:MAIN_CITY_ROOT='C:\\Projetos\\MAIN-CITY'
npm start
```

## Próximas etapas

Adicionar validações específicas do Godot e Blender sem liberar execução arbitrária de comandos do sistema.
