import { Client } from '@modelcontextprotocol/client';
import { StdioClientTransport } from '@modelcontextprotocol/client/stdio';
import fs from 'node:fs/promises';
import path from 'node:path';

const requiredTools = [
  'project_info',
  'list_project_files',
  'read_project_file',
  'search_project_text',
  'write_project_file',
  'replace_project_text',
  'git_status',
  'git_diff'
];

const client = new Client({ name: 'main-city-smoke-client', version: '0.2.0' });
const transport = new StdioClientTransport({
  command: process.execPath,
  args: ['src/index.mjs']
});

const smokeFile = 'MCP_SMOKE_TEST.md';
const smokeFull = path.resolve('..', '..', smokeFile);

try {
  await client.connect(transport);

  const { tools } = await client.listTools();
  const names = new Set(tools.map(tool => tool.name));
  const missing = requiredTools.filter(name => !names.has(name));
  if (missing.length) {
    throw new Error(`Ferramentas ausentes: ${missing.join(', ')}`);
  }

  const info = await client.callTool({ name: 'project_info', arguments: {} });
  if (info.isError) throw new Error('project_info retornou erro');
  const infoText = info.content?.find(block => block.type === 'text')?.text ?? '';
  if (!infoText.includes('controlled-write')) {
    throw new Error('project_info não confirmou modo de escrita controlada');
  }

  const writeResult = await client.callTool({
    name: 'write_project_file',
    arguments: { file: smokeFile, content: 'alpha\n' }
  });
  if (writeResult.isError) throw new Error('write_project_file retornou erro');

  const replaceResult = await client.callTool({
    name: 'replace_project_text',
    arguments: { file: smokeFile, find: 'alpha', replace: 'beta', replace_all: false }
  });
  if (replaceResult.isError) throw new Error('replace_project_text retornou erro');

  const readResult = await client.callTool({
    name: 'read_project_file',
    arguments: { file: smokeFile }
  });
  if (readResult.isError) throw new Error('read_project_file retornou erro');
  const readText = readResult.content?.find(block => block.type === 'text')?.text ?? '';
  if (!readText.includes('beta')) throw new Error('Arquivo de teste não foi alterado corretamente');

  const gitStatus = await client.callTool({ name: 'git_status', arguments: {} });
  if (gitStatus.isError) throw new Error('git_status retornou erro');

  const gitDiff = await client.callTool({ name: 'git_diff', arguments: { file: smokeFile } });
  if (gitDiff.isError) throw new Error('git_diff retornou erro');

  console.log(`MCP_SMOKE_OK tools=${tools.length} controlled_write=ok`);
} finally {
  await client.close();
  await fs.rm(smokeFull, { force: true });
}
