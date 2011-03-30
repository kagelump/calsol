import math

from PySide import QtGui, QtCore
from util import link

class BaseTabViewWidget(QtGui.QWidget):
    view_name = "Base Tab View"
    view_id   = "view.base"
    view_icon = None
    view_desc = None
    def __init__(self, tab_bar, parent=None, init=True):
        if init:
            QtGui.QWidget.__init__(self, parent)

        self.tab_bar = tab_bar

    def json_friendly(self):
        return {
                  "type": self.view_id,
                  "icon": getattr(self, "icon_name", self.view_icon)
               }

    def redraw(self):
        raise NotImplementedError

    def cleanup(self):
        raise NotImplementedError

    def update_view(self, now):
        raise NotImplementedError

class TabViewContainer(QtGui.QTabWidget):
    def __init__(self, parent=None):
        QtGui.QTabWidget.__init__(self, parent)

        self.rename_action = QtGui.QAction("Rename tab", self)
        self.addAction(self.rename_action)

        link(self.rename_action.triggered, self.rename)
        self.setContextMenuPolicy(QtCore.Qt.ActionsContextMenu)
        self.setTabsClosable(True)

        link(self.tabCloseRequested, self.close_tab)

    def rename(self):
        index = self.currentIndex()
        old_name = self.tabText(index)
        new_name, accepted = QtGui.QInputDialog.getText(self,
                                 'Rename tab "%s"' % old_name,
                                 "New name", text=old_name)
        if accepted:
            self.setTabText(index, new_name)

    def replace_tab(self, new_tab, icon):
        "Destroy the current active tab and put this tab in its place"
        index = self.currentIndex()
        tab = self.widget(index)
        label = self.tabText(index)
        
        self.removeTab(index)
        tab.cleanup()
        tab.close()

        self.insertTab(index, new_tab, icon, label)
        self.setCurrentIndex(index)

    def close_tab(self, index):
        tab = self.widget(index)
        self.removeTab(index)
        tab.cleanup()
        tab.close()

class NewTabViewSelector(BaseTabViewWidget):
    view_name = "New Tab View Selector"
    view_id   = "view.select"
    view_icon = "window-new.png"

    choice_selected = QtCore.Signal(object)
    def __init__(self, tab_bar, choices, parent=None):
        BaseTabViewWidget.__init__(self, tab_bar, parent)
        
        self.layout = QtGui.QGridLayout(self)
        self.setup(choices)
        self.setLayout(self.layout)

    def setup(self, choices):
        #General layout heuristic - if there are N choices, try to make
        #a ceil(sqrt(N)) x ceil(sqrt(N)) grid.

        M = N = int(math.ceil(math.sqrt(len(choices))))
        for k, (name, icon, desc, ident) in enumerate(choices):
            button = QtGui.QPushButton(icon, name)
            label = QtGui.QLabel(desc)
            layout = QtGui.QVBoxLayout()
            i, j = divmod(k, N)
            self.layout.addLayout(layout, i, j)
            layout.addWidget(button)
            layout.addWidget(label)

            link(button.pressed, lambda ident=ident: self.choice_selected.emit(ident))


    def redraw(self):
        pass

    def cleanup(self):
        pass

    def update_view(self, now):
        pass

    @classmethod
    def from_json(cls, json, tab_bar, choices, do_transform, parent=None):
        selector = cls(tab_bar, choices, parent)
        link(selector.choice_selected, do_transform)
        return selector
