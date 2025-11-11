# GlobalSignals.gd
extends Node

# Esta señal se emitirá cada vez que un item se suelte
# en CUALQUIER zona de borrado.
signal item_deleted(item_data: Resource)

signal item_attached(item_data: Resource)
