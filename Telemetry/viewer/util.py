import os

from PySide import QtCore, QtGui
__all__ = ["link", "find_icon"]

def link(signal, slot):
    "Connects the signal callback to the slot notifier"
    signal.connect(lambda *args, **kwargs: slot(*args, **kwargs))

icon_cache = {}
def find_icon(name):
    if name in icon_cache:
        return icon_cache[name]
    else:
        try:
            icon = QtGui.QIcon(os.path.join("icons", name))
        except:
            return None
        icon_cache[name] = icon
        return icon
