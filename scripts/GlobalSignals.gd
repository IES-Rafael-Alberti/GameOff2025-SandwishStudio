# En GameOff2025-SandwishStudio/scripts/GlobalSignals.gd
extends Node

signal item_deleted(item_data: Resource)
signal item_attached(item_data: Resource)
signal item_return_to_inventory_requested(item_data: Resource, on_complete_callback: Callable)

# --- AÑADE ESTA LÍNEA ---
# Señal para cuando la ruleta otorga una pieza e inicia un combate.
signal combat_requested(piece_resource: Resource)

# --- ¡NUEVAS SEÑALES PARA EL SISTEMA DE USOS! ---

# Se emite desde slot.gd cuando se suelta una pieza en la ruleta.
# inventory.gd la escucha para restar 1 uso.
signal piece_placed_on_roulette(piece_data: PieceData)

# Se emite desde slot.gd cuando se hace clic en una pieza de la ruleta.
# inventory.gd la escucha para sumar 1 uso.
signal piece_returned_from_roulette(piece_data: PieceData)

# Se emite desde inventory.gd cuando se vende una pila de piezas.
# RuletaScene.gd la escucha para limpiar todas las copias de esa pieza.
signal piece_type_deleted(piece_data: PieceData)
