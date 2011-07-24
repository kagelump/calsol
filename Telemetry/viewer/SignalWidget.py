import datetime
import json
import re

from PySide import QtGui, QtCore

from util import link, find_icon

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

        self._data = None
        self._mimeData = None
        self.widgets = {}

        self.descr_map = {}

    def add_descriptors(self, desc_sets):
        pattern = re.compile(r"Battery Information Module (\d+) (?:Cell (\d+)|(.+))")
        #Note: we want to flatten trees of the form:
        #Battery Module X Cell A
        #|-Cell Voltage
        #\-Cell Temperature
        #Battery Module X Cell B
        #|-Cell Voltage
        #\-Cell Temperature
        #
        #into
        #Battery Module X
        #|-Cell Voltage A
        #|-Cell Temperature A
        #|-Cell Voltage B
        #\-Cell Temperature B

        def make_msg_item(parent, id_, name, units, desc):
            ident = id_+":"+name
            name = "%s (%s)" % (name, units)
            msg_item = QtGui.QTreeWidgetItem(parent, [name, desc])
            msg_item.setData(0, QtCore.Qt.EditRole, ident)
            msg_item.setToolTip(0, name)
            msg_item.setToolTip(1, desc)
            return ident, msg_item
        
        module_items = {}
        
        for fname, desc_set in desc_sets:
            group_item = QtGui.QTreeWidgetItem(self, [fname])
            for id_, descr in sorted(desc_set.items()):
                id_ = "%#x" % int(id_, 16)
                if pattern.match(descr["name"]):
                    m = pattern.match(descr["name"])
                    mod_num, info = m.group(1), (m.group(2) or m.group(3))
                    if mod_num in module_items:
                        module = module_items[mod_num]
                    else:
                        module = QtGui.QTreeWidgetItem(group_item,
                                     ["Battery Module %s" % mod_num])
                        module_items[mod_num] = module
                    for [name, units, desc] in descr.get("messages", []):
                        ident, item = make_msg_item(module, id_,
                                                    name + " " + info,
                                                    units, desc)
                        self.widgets[ident] = (item, [module, group_item])
                        #Also set the normal identifier
                        self.widgets[id_+":"+name] = self.widgets[ident]
                        self.descr_map[id_+":"+name] = self.descr_map[ident] = [name, units, desc]
                else:
                    packet_item = QtGui.QTreeWidgetItem(group_item, [descr["name"]])
                    packet_item.setToolTip(0, id_ + ":" + descr["name"])
                    
                    for [name, units, desc] in descr.get("messages", []):
                        ident, item = make_msg_item(packet_item, id_, name, units, desc)
                        self.widgets[ident] = (item, [packet_item, group_item])
                        self.descr_map[ident] = [name, units, desc]
                    

    def mimeTypes(self):
        return QtGui.QTreeWidget.mimeTypes(self)+[SignalTreeWidget.mimeType]

    def mimeData(self, items):
        children = []
        #Flatten the list of selected entries and collect their
        #child signals into a single list
        pattern = re.compile("(.+?:Cell (?:Temperature|Voltage)) \d+")
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
                    if pattern.match(data):
                        data = pattern.match(data).group(1)
                    if not data in children:
                        children.append(data)
                else:
                    stack.extend(item.child(i) for i in xrange(item.childCount()-1, -1, -1))

        #Create a mimeData object to store the list of signals
        #the actual data is in text/plain; the application/x-data-signal-list
        #is just a dummy so that we can filter drop events
        
        mimeData = self._mimeData = QtCore.QMimeData()
        as_json = []
        for ident in children:
            name, units, desc = self.descr_map[ident]
            as_json.append({"identifier":ident, "color":None, "style":None,
                            "name":name, "desc":desc, "units":units})
        _data = QtCore.QByteArray(json.dumps(as_json))
        mimeData.setData(SignalTreeWidget.mimeType, _data)

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

    @staticmethod
    def getMimeDataSignals(mimedata):
        if mimedata.hasFormat(SignalTreeWidget.mimeType):
            data = str(mimedata.data(SignalTreeWidget.mimeType))
            sources = json.loads(data)
            return sources
        else:
            return None

class SignalListWidget(QtGui.QListWidget):
    """
    SignalListWidget operates in parallel with SignalTreeWidget. Whereas
    SignalTreeWidget provides a way to get access to all of the signals,
    SignalListWidget is intended to provide a mutable view of some subset
    of the signals. In particular, it is intended for use with plots to
    edit which signals are being plotted by dragging and dropping signals
    to and from the SignalListWidget
    """
    SignalStyleRole = QtCore.Qt.UserRole + 0xCA15 + 1
    def __init__(self, *args, **kwargs):
        QtGui.QListWidget.__init__(self, *args, **kwargs)
        
        self.setAlternatingRowColors(True)
        self.setDragDropMode(QtGui.QAbstractItemView.DragDrop)
        self.setDragEnabled(True)
        self.setSelectionMode(QtGui.QAbstractItemView.SingleSelection)

    def setup(self, signals):
        for descr in signals:
            #print descr
            item = QtGui.QListWidgetItem(descr["identifier"], self)
            item.setData(SignalListWidget.SignalStyleRole, (descr["color"],
                                                            descr["style"]))

##    def mimeData(self, items):
##        for item in items:
##            item.text()

    def dragEnterEvent(self, event):
        if event.mimeData().hasFormat(SignalTreeWidget.mimeType):
            print event.proposedAction(), event.source()
            #event.acceptProposedAction()
            event.ignore()
        else:
            event.ignore()

    def dragLeaveEvent(self, event):
        if event.mimeData().hasFormat(SignalTreeWidget.mimeType):
            event.ignore()
        else:
            event.ignore()

    def dropEvent(self, event):
        if event.mimeData().hasFormat(SignalTreeWidget.mimeType):
            print event.proposedAction(), event.source()
##            data = str(event.mimeData().data(SignalTreeWidget.mimeType))
##            sources = json.loads(data)
##            event.acceptProposedAction()
##            self.add_plot(sources)
            event.ignore()
        else:
            event.ignore()

class SignalListEditorDialog(QtGui.QDialog):
    """
    SignalListEditorDialog provides a dialog window to allow for viewing and
    editing the list of signals being plotted on a graph as well as changing
    the label, line-style, and color of the signal on plots.
    """
    signal_removed  = QtCore.Signal([str])
    signal_added    = QtCore.Signal([list])
    signal_modified = QtCore.Signal([dict])

    styles = [("solid", None),
              ("dashed", None),
              ("dashdot", None),
              ("dotted", None)]
    def __init__(self, *args, **kwargs):
        QtGui.QDialog.__init__(self, *args, **kwargs)

        self.setWindowTitle("Signals Editor")

        self.vert_layout = QtGui.QVBoxLayout(self)

        self.horz_layout = QtGui.QHBoxLayout()
        self.vert_layout.addLayout(self.horz_layout)
        self.list_widget = SignalListWidget(self)
        
        self.control_frame = QtGui.QFrame(self)
        self.control_frame.setFrameShape(QtGui.QFrame.Box)
        self.control_layout = QtGui.QFormLayout(self.control_frame)
        
        self.name_field = QtGui.QLineEdit(self.control_frame)
        self.style_field = QtGui.QComboBox(self.control_frame)
        self.color_field = CustomColorPicker(self.control_frame)

        for (style, icon) in self.styles:
            if icon:
                self.style_field.addItem(icon, style)
            else:
                self.style_field.addItem(style)

        self.control_layout.addRow("Name:", self.name_field)
        self.control_layout.addRow("Style:", self.style_field)
        self.control_layout.addRow("Color:", self.color_field)
##        self.edit_button = QtGui.QPushButton("&Edit", self)
##        self.remove_button = QtGui.QPushButton("&Remove", self)
##
##        self.control_layout.addWidget(self.edit_button)
##        self.control_layout.addWidget(self.remove_button)
##        self.control_layout.addStretch(1)

        self.control_frame.setLayout(self.control_layout)
        
        self.horz_layout.addWidget(self.list_widget)
        self.horz_layout.addWidget(self.control_frame)

        self.footer_buttons = QtGui.QDialogButtonBox(QtGui.QDialogButtonBox.Close)
        self.vert_layout.addWidget(self.footer_buttons)
        self.setLayout(self.vert_layout)

        link(self.footer_buttons.rejected, self.close)
##        link(self.edit_button.clicked, self.do_edit)
##        link(self.remove_button.clicked, self.do_remove)

        link(self.list_widget.currentItemChanged, self.update_controls)

    def update_controls(self, new, prev):
        self.name_field.setText(new.text())
##        self.style_field.something()

    def do_edit(self):
        self.signal_modified.emit({changed: "Test edit"})

    def do_remove(self):
        self.signal_removed.emit("Test remove")

    def setup(self, signals):
        self.list_widget.setup(signals)

class CustomColorPicker(QtGui.QWidget):
    def __init__(self, *args, **kwargs):
        QtGui.QWidget.__init__(self, *args, **kwargs)

        self.layout = QtGui.QHBoxLayout(self)
        self.patch = QtGui.QImage(QtCore.QSize(64, 32), QtGui.QImage.Format_Indexed8)
        self.patch.fill(0)

        self.picker_button = QtGui.QToolButton(self)
        self.picker_button.setIcon(find_icon("palette-icon.png"))
        self.picker_button.setAutoRaise(True)
##        wrapper = QtGui.QWidget(self)
##        wrapper_layout = QtGui.QHBoxLayout(wrapper)
##        wrapper_layout.addWidget(self.patch
##        wrapper.setLayout(wrapper_layout)
##        self.layout.addWidget(self.patch, 1, QtCore.Qt.AlignLeft)
        self.layout.addWidget(self.picker_button, 0, QtCore.Qt.AlignLeft)
        self.setLayout(self.layout)

        self.color_dialog = QtGui.QColorDialog(self)        

        link(self.picker_button.pressed, self.show_dialog)

    def recolor_patch(self, color):
        self.patch.setColor(0, color.getRgb())

    def show_dialog(self):
        self.color_dialog.open()
