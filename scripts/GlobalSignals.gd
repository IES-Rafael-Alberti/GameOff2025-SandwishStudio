# En GameOff2025-SandwishStudio/scripts/GlobalSignals.gd
extends Node

signal item_deleted(item_data: Resource)
signal item_attached(item_data: Resource)
signal item_return_to_inventory_requested(item_data: Resource, on_complete_callback: Callable)

# --- AÑADE ESTA LÍNEA ---
# Señal para cuando la ruleta otorga una pieza e inicia un combate.
signal combat_requested(piece_resource: Resource)
