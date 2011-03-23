from PySide import QtGui, QtCore
from util import link

class BaseTabViewWidget(QtGui.QWidget):
    view_type_name = "__default_view_widget__"
    view_type_icon = None
    def __init__(self, tab_bar, parent=None, init=True):
        if init:
            QtGui.QWidget.__init__(self, parent)

        self.tab_bar = tab_bar

    def json_friendly(self):
        return {
                  "type": self.view_type_name,
                  "icon": getattr(self, "icon_name", self.view_type_icon)
               }

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

    def close_tab(self, index):
        if self.count() == 1:
            dialog = QtGui.QDialog(self)
            dialog.setWindowTitle("Error")
            layout = QtGui.QVBoxLayout(dialog)
            label = QtGui.QLabel("You can't close the last tab")
            button = QtGui.QPushButton("Okay", dialog)
            layout.addWidget(label)
            layout.addWidget(button)
            dialog.setLayout(layout)

            link(button.pressed, dialog.close)

            dialog.show()
            
            #Closing the last tab makes the new tab button disappear...
            return
    
        tab = self.widget(index)
        self.removeTab(index)
        tab.cleanup()
        tab.close()


