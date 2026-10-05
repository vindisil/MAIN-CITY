extends RefCounted
## Bairro exibido na HUD e no mapa de pausa. O mapa tem 4x4 regioes,
## com cada centro a -960, -320, 320 ou 960 nos eixos X e Z.
const FIRST_CENTER: float = -960.0
const BLOCK_WIDTH: float = 640.0
const NAMES = [
    "Vila das Acacias", "Alto do Cedro", "Jardim do Norte", "Morro Azul",
    "Parque Norte", "Bairro Industrial", "Vila Horizonte", "Nova Esperanca",
    "Jardim Central", "Centro", "Bairro da Estacao", "Vila das Palmeiras",
    "Parque do Sul", "Vila das Flores", "Jardim da Serra", "Bairro do Lago"
]

# Identificacoes compactas para o minimapa e o mapa GPS; os nomes oficiais permanecem intactos.
const MAP_NAMES = [
    "Acácias", "Cedro", "Jd. Norte", "Morro Azul",
    "Pq. Norte", "Industrial", "Horizonte", "Esperança",
    "Jd. Central", "Centro", "Estação", "Palmeiras",
    "Pq. Sul", "Flores", "Serra", "Lago"
]

static func map_name_at_world(world_position: Vector2) -> String:
    var col: int = clampi(floori((world_position.x + 1280.0) / BLOCK_WIDTH), 0, 3)
    var row: int = clampi(floori((world_position.y + 1280.0) / BLOCK_WIDTH), 0, 3)
    return MAP_NAMES[row * 4 + col]

static func name_at_world(world_position: Vector2) -> String:
    # Map boundaries: -1280, -640, 0, 640 and 1280 on both axes.
    var col: int = clampi(floori((world_position.x + 1280.0) / BLOCK_WIDTH), 0, 3)
    var row: int = clampi(floori((world_position.y + 1280.0) / BLOCK_WIDTH), 0, 3)
    return NAMES[row * 4 + col]
