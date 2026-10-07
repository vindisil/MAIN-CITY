import { McpServer } from '@modelcontextprotocol/server';
import { serveStdio } from '@modelcontextprotocol/server/stdio';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { registerGodotControlTools } from './godot-control-tools.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(process.env.MAIN_CITY_ROOT || path.join(__dirname, '..', '..'));

function createServer() {
  const server = new McpServer({ name: 'main-city-godot-control', version: '1.0.0' });
  registerGodotControlTools(server, { projectRoot: PROJECT_ROOT });
  return server;
}

void serveStdio(createServer);
console.error(`Main City Godot Control MCP v1.0 iniciado. Projeto: ${PROJECT_ROOT}`);
