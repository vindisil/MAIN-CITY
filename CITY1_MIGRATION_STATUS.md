# MAIN CITY — City 1 ativa

Esta branch usa **somente a City 1 como mundo jogável**.

## Ativo no runtime

- `main.tscn` com `NovaCidade_City1`
- Player Third Person atual, sem troca de controlador
- Armas e HUD atuais
- Veículos dirigíveis preservando suas cenas/scripts originais
- Ciclo dia/noite
- Colisões seletivas da City 1
- Minimap gerado pela geometria da City 1
- Mapa de pausa gerado pela geometria da City 1
- Piso de segurança temporário sob a cidade

## Veículos colocados na área de rua inicial

1. BMW
2. Mercedes GLS
3. Urus
4. Ford Raptor
5. Ford Raptor Policial
6. Blindado Policial 1
7. Blindado Policial 2
8. Duster Policial
9. Ambulância Hospital
10. Caminhão Militar
11. Hammer Militar

## Sistemas preservados porém inativos

- Polícia
- Exército
- Hospital
- Bases e pontos de serviço antigos

Esses sistemas não são instanciados nas coordenadas antigas. Os arquivos das bases foram mantidos para reposicionamento futuro na City 1.

## Removido da branch City 1

- `assets/city_map.json` do mapa antigo
- `scenes/city_chunks/`
- `scenes/urban_plots/`
- streaming do mapa antigo (`scripts/world_streamer.gd`)
- cenas antigas de expansão/quadras/bairro importado
- wrappers antigos de veículos estacionados nas coordenadas do mapa antigo

## Regra para próximas edições

Não reintroduzir `city_chunks`, `city_map.json`, `WorldStreamer` ou coordenadas das bases antigas no runtime da City 1. Novos sistemas devem ser posicionados diretamente sobre `NovaCidade_City1`.
