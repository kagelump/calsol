import datetime
from PySide import QtGui, QtCore

class SignalTreeWidget(QtGui.QTreeWidget):
    """
    SignalTreeWidget implements the tree-view of all possible CAN packets
    grouped by:
    Category (taken from the filename)
     \---Packet Name
       \---Packet ID: Message Name (units) | Message Description
       |---Packet ID: Message Name (units) | Message Description
     \---Packet Name...

    SignalTreeWidget is responsible for handling the drag-and-drop mimetype
    data setup, which is transfered as a string of signal names separated
    by '|' characters.

    class variables:
        mimeType - the mimeType used to identifier our data in drag-and-drop
                   operations. However, the actual data is stored as text/plain

    method summary:
        add_descriptors - takes in a list of (filename, descriptor_set) objects
                          and builds the tree accordingly
    
    """
    mimeType = "application/x-data-signal-list"

    curve = QtCore.QEasingCurve(QtCore.QEasingCurve.InQuart)

    def __init__(self, *args, **kwargs):
        QtGui.QTreeWidget.__init__(self, *args, **kwargs)
        
        self.setAlternatingRowColors(True)
        self.setDragDropMode(QtGui.QAbstractItemView.DragOnly)
        self.setDragEnabled(True)
        self.setSelectionMode(QtGui.QAbstractItemView.ExtendedSelection)
        self.setColumnCount(2)
        self.setHeaderLabels(["Name", "Description"])

        self.dummy_data = QtCore.QByteArray("see text/plain")
        self._mimeData = None
        self.widgets = {}

    def add_descriptors(self, desc_sets):
        for fname, desc_set in desc_sets:
            group_item = QtGui.QTreeWidgetItem(self, [fname])
            for id_, desc in sorted(desc_set.items()):
                packet_item = QtGui.QTreeWidgetItem(group_item, [desc["name"]])
                packet_item.setToolTip(0, id_ + ":" + desc["name"])
                if not "messages" in desc:
                    continue
                for [name, units, desc] in desc["messages"]:
                    ident = id_+":"+name
                    name = "%s (%s)" % (name, units)
                    msg_item = QtGui.QTreeWidgetItem(packet_item, [name, desc])
                    msg_item.setData(0, QtCore.Qt.EditRole, ident)
                    msg_item.setToolTip(0, name)
                    msg_item.setToolTip(1, desc)
                    self.widgets[ident] = (msg_item, [packet_item, group_item])
                    

    def mimeTypes(self):
        return QtGui.QTreeWidget.mimeTypes(self)+[SignalTreeWidget.mimeType]

    def mimeData(self, items):
        children = []
        #Flatten the list of selected entries and collect their
        #child signals into a single list
        for item in items:
            stack = []
            if item.childCount() > 0:
                stack = list(item.child(i) for i in xrange(item.childCount()-1, -1, -1))
            else:
                stack = [item]
            while stack:
                item = stack.pop()
                if item.childCount() == 0:
                    data = item.data(0, QtCore.Qt.EditRole)
                    if not data in children:
                        children.append(data)
                else:
                    stack.extend(item.child(i) for i in xrange(item.childCount()-1, -1, -1))

        #Create a mimeData object to store the list of signals
        #the actual data is in text/plain; the application/x-data-signal-list
        #is just a dummy so that we can filter drop events
        
        mimeData = self._mimeData = QtCore.QMimeData()
        mimeData.setData(SignalTreeWidget.mimeType, self.dummy_data)
        text = "|".join(children)

        mimeData.setText(text)
        return mimeData

    def update_colors(self, items):
        now = datetime.datetime.utcnow()
        updated = {}
        for name, t in items:
            msg, parents = self.widgets[name]
            dt = (now - t)
            x = dt.seconds + 1e-6 * dt.microseconds
            if x <= 0.05:
                color = QtGui.QColor.fromHsl(225, 255, 127, 127)
            else:
                L = 0.5 + 0.5*self.curve.valueForProgress(min((x-0.05)/2.0, 1.0))
                color = QtGui.QColor.fromHslF(225/360.0, 1.0, L, 0.5)
            
            msg.setBackground(0, color)
            msg.setBackground(1, color)
            for parent in parents:
                if id(parent) not in updated or updated[id(parent)] > x:
                    parent.setBackground(0, color)
                    parent.setBackground(1, color)
                    updated[id(parent)] = x
