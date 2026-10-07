# MAIN CITY MCP — Full Control Roadmap

Objetivo: dar a um agente MCP acesso amplo e estruturado ao projeto MAIN CITY, com foco em Godot 4, 3D, NPCs, mapa, veículos, animações e desempenho mobile.

## Estado da v1

A v1 foi separada em dois servidores MCP:

- `main-city-files`: leitura/escrita de arquivos, busca, backups e Git.
- `main-city-godot`: controle do editor Godot e criação 3D via plugin local.

O plugin `addons/main_city_mcp_bridge` escuta apenas em `127.0.0.1:6010`.

### Ferramentas Godot da v1

- localizar Godot e checar versão;
- validar projeto em modo headless;
- checar parser de scripts GDScript;
- iniciar/parar o projeto;
- ping do editor;
- ler cena aberta e árvore de nós;
- abrir/salvar cenas;
- criar nós;
- criar primitivas 3D com material e `Fisica`/`Colisao`;
- mover/rotacionar/escalar nós;
- alterar propriedades;
- duplicar/remover nós;
- executar lotes de até 200 operações para construir estruturas;
- executar/parar cena principal pelo editor;
- gerar um NPC-base com `CharacterBody3D` + `NavigationAgent3D`.

## Próximos módulos

### 1. 3D Builder avançado

- casas por parâmetros;
- muros, portões, garagens e interiores;
- portas interativas;
- materiais reutilizáveis;
- snap/alinhamento;
- lote de objetos;
- prefabs de polícia, hospital e exército.

### 2. NPC humano

- máquina de estados completa;
- percepção por visão/som;
- caminhada/corrida natural;
- AnimationTree;
- retarget de animação;
- reação a tiros e veículos;
- fuga/perseguição;
- polícia, médico, militar, civil e bandido;
- spawn por bairro;
- LOD de IA por distância para mobile.

### 3. Animação/personagem

- inspeção de Skeleton3D;
- edição controlada de poses;
- ajuste de mãos/arma;
- AnimationPlayer/AnimationTree;
- blending e transições;
- import/retarget;
- validação de ossos torcidos.

### 4. Terrain3D e mundo

- leitura de terreno;
- nivelamento;
- estradas;
- vegetação;
- áreas de construção;
- culling/streaming;
- colisões seletivas.

### 5. Veículos

- rodas/paralamas;
- suspensão;
- câmera/FOV;
- luzes;
- física;
- spawn;
- otimização por distância.

### 6. Materiais e visual

- PBR mobile;
- UV/tiling;
- normal/roughness;
- compressão;
- LOD;
- iluminação diurna/noturna;
- auditoria de texturas grandes/duplicadas.

### 7. Blender Bridge

- abrir arquivo Blender específico;
- operações paramétricas simples;
- export GLB;
- otimização de mesh;
- aplicar transform;
- LOD;
- retorno automático ao Godot.

### 8. Teste e diagnóstico

- F5 controlado;
- captura de logs;
- parser/import errors;
- referências `res://` quebradas;
- perfis simples de CPU/GPU;
- relatório de draw calls/nós/luzes/corpos físicos;
- comparação Git antes/depois.

## Limites reais

O objetivo é cobrir praticamente todo o fluxo de desenvolvimento que pode ser exposto com segurança e confiabilidade por APIs do Godot, arquivos, Git e ferramentas locais. Não existe uma ferramenta que garanta literalmente 99% de qualquer tarefa 3D: modelagem artística complexa, animação humana AAA e avaliação visual ainda exigem iteração e, às vezes, Blender ou revisão humana.

Também não será usado shell arbitrário escondido. Cada ação destrutiva deve ser uma ferramenta identificável, auditável e reversível por Git/backup. Isso evita repetir problemas de agentes que alteram arquivos fora do escopo.

## Antigravity

O workspace inclui `.agents/mcp_config.json` com os dois MCPs. No Antigravity CLI, abra `/mcp` e recarregue os servidores do workspace.

## Ativação no Godot

1. Abra o projeto MAIN CITY.
2. Vá em `Project > Project Settings > Plugins`.
3. Ative `Main City MCP Bridge`.
4. O Output deve mostrar `Main City MCP Bridge online em 127.0.0.1:6010`.
5. Teste a ferramenta `godot_bridge_ping` no cliente MCP.
