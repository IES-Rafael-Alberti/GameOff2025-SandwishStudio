# GlobalSignals.gd
extends Node

# Esta señal se emitirá cada vez que un item se suelte
# en CUALQUIER zona de borrado.
signal item_deleted(item_data: Resource)
signal item_attached(item_data: Resource)
signal item_return_to_inventory_requested(item_data: Resource, on_complete_callback: Callable)
