# Main City MCP

Servidor MCP local para trabalhar com o projeto Godot Main City de forma controlada.

## Estado atual

Versão inicial em modo **somente leitura**. Ferramentas disponíveis:

- `project_info`
- `list_project_files`
- `read_project_file`
- `search_project_text`
- `git_status`

Ele bloqueia acesso fora da pasta do projeto e não altera arquivos.

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

Execute:

```powershell
npm start
```

O servidor ficará aguardando um cliente MCP pelo transporte stdio. Para testar com o MCP Inspector:

```powershell
npx @modelcontextprotocol/inspector node src/index.mjs
```

No Inspector, teste primeiro `project_info` e depois `git_status`.

## Caminho do projeto

Por padrão o servidor considera como raiz a pasta `MAIN-CITY`, porque `mcp-main-city` fica dentro dela.

Se precisar apontar para outra cópia do projeto:

```powershell
$env:MAIN_CITY_ROOT='C:\\Projetos\\MAIN-CITY'
npm start
```

## Próxima etapa

Depois de validar a conexão, adicionar ferramentas de escrita controlada com backup automático e comandos específicos para Godot/Blender. Não adicionar execução arbitrária de shell.
