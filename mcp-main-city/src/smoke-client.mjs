import { Client } from '@modelcontextprotocol/client';
import { StdioClientTransport } from '@modelcontextprotocol/client/stdio';

const requiredTools = [
  'project_info',
  'list_project_files',
  'read_project_file',
  'search_project_text',
  'git_status'
];

const client = new Client({ name: 'main-city-smoke-client', version: '0.1.0' });
const transport = new StdioClientTransport({
  command: process.execPath,
  args: ['src/index.mjs']
});

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
  const text = info.content?.find(block => block.type === 'text')?.text ?? '';
  if (!text.includes('project_godot_found')) {
    throw new Error('project_info não retornou o formato esperado');
  }

  const gitStatus = await client.callTool({ name: 'git_status', arguments: {} });
  if (gitStatus.isError) throw new Error('git_status retornou erro');

  console.log(`MCP_SMOKE_OK tools=${tools.length}`);
} finally {
  await client.close();
}
