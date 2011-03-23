def link(signal, slot):
    "Connects the signal callback to the slot notifier"
    signal.connect(lambda *args, **kwargs: slot(*args, **kwargs))
