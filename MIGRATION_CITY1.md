# MAIN CITY — Migração para City 1

Branch: `nova-city1`

## Mantido sem alteração
- `scenes/third_person_player.tscn` e toda a lógica atual do personagem.
- Scripts/modelos das armas e o fluxo atual de mira/tiro.
- Cenas e scripts originais dos veículos.
- `VehicleEditStore`.
- `BrasiliaDayNight`, `WorldEnvironment` e `Sun`.
- Fluxo Tela Inicial → Lobby → Carregamento → Gênero → `main.tscn`.

## Novo mapa
- `assets/City1/City 1_MAIN_CITY_TEXTURED_MOBILE_GLB_FIX.glb` é a cidade principal.
- Escala da raiz mantida em `1.0` para preservar o tamanho original do GLB.
- O mapa antigo (`scenes/city_chunks/global.tscn`) não é mais instanciado em `main.tscn`.
- `WorldStreamer`, `StreetLamps`, `GPSNavigation`, `WorldEditStore` e `editor_map_preview` do mapa antigo não são carregados na nova cena principal.

## Colisão e segurança
- `scripts/city1_post_import.gd` tenta criar colisões trimesh somente em superfícies de circulação com nomes como road/street/tarmac/sidewalk/bridge, limitadas a 180 colisões para proteger o mobile.
- Há um `FallbackGround` invisível de 4000 x 4000 no `main.tscn` para impedir que personagem e veículos caiam enquanto refinamos as colisões da City 1.

## Veículos
Uma garagem temporária de migração (`scenes/city1_vehicle_yard.tscn`) mantém os veículos civis imediatamente testáveis:
- BMW
- Mercedes GLS
- Urus
- Ford Raptor

As cenas de Duster policial, blindado, ambulância, Hammer e caminhão militar permanecem intactas no projeto e serão reposicionadas junto das novas bases.

## Polícia / Exército / Hospital
- O código original continua preservado em `scripts/city_services.gd`.
- A nova cena usa `scripts/city1_services_disabled.gd`, portanto checkpoints, painéis e spawns nas coordenadas antigas ficam inativos.
- Nada das funções originais foi apagado; a reativação será feita depois de escolher os pontos das novas bases.

## Spawn inicial
- Player: `(0, 1.4, 8)`.
- Veículos civis: fila temporária em `z = 22`.

Esses pontos são deliberadamente temporários para o primeiro teste de escala/FPS no novo mapa.
