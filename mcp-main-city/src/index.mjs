import { McpServer } from '@modelcontextprotocol/server';
import { serveStdio } from '@modelcontextprotocol/server/stdio';
import * as z from 'zod/v4';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(process.env.MAIN_CITY_ROOT || path.join(__dirname, '..', '..'));

const TEXT_EXTENSIONS = new Set([
  '.gd', '.tscn', '.tres', '.godot', '.cfg', '.json', '.md', '.txt',
  '.cs', '.shader', '.gdshader', '.ini', '.xml', '.csv', '.yml', '.yaml'
]);

const SKIP_DIRS = new Set(['.git', '.godot', 'node_modules', '.import', '.mcp-backups']);
const MAX_READ_BYTES = 2 * 1024 * 1024;
const MAX_SEARCH_FILES = 1200;

function insideRoot(candidate) {
  const rel = path.relative(PROJECT_ROOT, candidate);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

function resolveProjectPath(relativePath = '.') {
  const candidate = path.resolve(PROJECT_ROOT, relativePath);
  if (!insideRoot(candidate)) throw new Error('Caminho fora da pasta MAIN-CITY bloqueado.');
  return candidate;
}

function rel(candidate) {
  return path.relative(PROJECT_ROOT, candidate).replaceAll('\\', '/');
}

async function walkFiles(startDir, maxFiles = 500) {
  const out = [];
  const stack = [startDir];
  while (stack.length && out.length < maxFiles) {
    const current = stack.pop();
    let entries;
    try {
      entries = await fs.readdir(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (out.length >= maxFiles) break;
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (!SKIP_DIRS.has(entry.name)) stack.push(full);
      } else if (entry.isFile()) {
        out.push(full);
      }
    }
  }
  return out;
}

function textResult(text) {
  return { content: [{ type: 'text', text }] };
}

function createServer() {
  const server = new McpServer({ name: 'main-city-local', version: '0.1.0' });

  server.registerTool(
    'project_info',
    {
      description: 'Mostra informações básicas do projeto Main City e verifica se project.godot existe.',
      inputSchema: z.object({})
    },
    async () => {
      const projectFile = path.join(PROJECT_ROOT, 'project.godot');
      let exists = false;
      try { await fs.access(projectFile); exists = true; } catch {}
      return textResult(JSON.stringify({
        project_root: PROJECT_ROOT,
        project_godot_found: exists,
        mode: 'read-only',
        note: 'Este primeiro MCP não altera arquivos.'
      }, null, 2));
    }
  );

  server.registerTool(
    'list_project_files',
    {
      description: 'Lista arquivos do projeto a partir de uma pasta relativa, ignorando .git, .godot e node_modules.',
      inputSchema: z.object({
        directory: z.string().default('.'),
        limit: z.number().int().min(1).max(1000).default(300)
      })
    },
    async ({ directory, limit }) => {
      const start = resolveProjectPath(directory);
      const files = await walkFiles(start, limit);
      return textResult(files.map(rel).join('\n') || '(nenhum arquivo encontrado)');
    }
  );

  server.registerTool(
    'read_project_file',
    {
      description: 'Lê um arquivo de texto do projeto Main City. Arquivos binários e arquivos muito grandes são bloqueados.',
      inputSchema: z.object({
        file: z.string().min(1)
      })
    },
    async ({ file }) => {
      const full = resolveProjectPath(file);
      const ext = path.extname(full).toLowerCase();
      if (!TEXT_EXTENSIONS.has(ext)) {
        throw new Error(`Extensão não permitida para leitura textual: ${ext || '(sem extensão)'}`);
      }
      const stat = await fs.stat(full);
      if (!stat.isFile()) throw new Error('O caminho informado não é um arquivo.');
      if (stat.size > MAX_READ_BYTES) throw new Error('Arquivo maior que 2 MB; leitura bloqueada neste MCP inicial.');
      const content = await fs.readFile(full, 'utf8');
      return textResult(content);
    }
  );

  server.registerTool(
    'search_project_text',
    {
      description: 'Procura texto em scripts e arquivos de cena/configuração do Main City.',
      inputSchema: z.object({
        query: z.string().min(1),
        directory: z.string().default('.'),
        max_results: z.number().int().min(1).max(200).default(50)
      })
    },
    async ({ query, directory, max_results }) => {
      const start = resolveProjectPath(directory);
      const files = await walkFiles(start, MAX_SEARCH_FILES);
      const needle = query.toLowerCase();
      const results = [];
      for (const full of files) {
        if (results.length >= max_results) break;
        if (!TEXT_EXTENSIONS.has(path.extname(full).toLowerCase())) continue;
        let stat;
        try { stat = await fs.stat(full); } catch { continue; }
        if (stat.size > MAX_READ_BYTES) continue;
        let content;
        try { content = await fs.readFile(full, 'utf8'); } catch { continue; }
        const lines = content.split(/\r?\n/);
        for (let i = 0; i < lines.length && results.length < max_results; i++) {
          if (lines[i].toLowerCase().includes(needle)) {
            results.push(`${rel(full)}:${i + 1}: ${lines[i].trim()}`);
          }
        }
      }
      return textResult(results.join('\n') || '(nenhuma ocorrência encontrada)');
    }
  );

  server.registerTool(
    'git_status',
    {
      description: 'Mostra git status --short do repositório Main City. Não executa commit, pull, push nem altera arquivos.',
      inputSchema: z.object({})
    },
    async () => {
      try {
        const { stdout, stderr } = await execFileAsync('git', ['status', '--short'], {
          cwd: PROJECT_ROOT,
          windowsHide: true,
          maxBuffer: 2 * 1024 * 1024
        });
        return textResult((stdout || stderr || '(working tree limpo)').trim());
      } catch (error) {
        return textResult(`Não foi possível executar git status: ${error.message}`);
      }
    }
  );

  return server;
}

void serveStdio(createServer);
console.error(`Main City MCP iniciado em modo somente leitura. Projeto: ${PROJECT_ROOT}`);
