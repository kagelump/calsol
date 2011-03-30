import datetime
import matplotlib.dates as mdates
from matplotlib.axes import Subplot
from matplotlib.figure import Figure
from PySide import QtGui, QtCore

from backend_pysideagg import FigureCanvasQTAgg as FigureCanvas
from DatePlot import DatetimeCollection, KenLocator, KenFormatter
from GraphData import XOMBIESQLIntervalView
from SignalWidget import SignalTreeWidget
from ViewWidget import BaseTabViewWidget

from LiveGraph import CustomDateTimeEdit

from util import link

class HistoricalGraphTabView(BaseTabViewWidget):
    """
    HistoricalGraphTabView implements a static view of numeric data from
    the past. The actual graph itself is handled by the HistoricalPlot
    class, while HistoricalGraphTabView handles the controls. 
    
    """
    view_name = "Historical Graph View"
    view_id   = "static.graph"
    view_icon = "clock.png"
    view_desc = "A view of data from previous runs visualized on a plot vs time"

    
    def __init__(self, tab_bar, desc_sets, connection, parent=None):
        BaseTabViewWidget.__init__(self, parent)

        self.tab_bar = tab_bar
        self.connection = connection

        desc_map = {}
        for fname, desc_set in desc_sets:
            for id_, desc in desc_set.items():
                for [name, units, desc] in desc.get("messages", []):
                    desc_map[id_+":"+name] = desc
        
        self.plotWidget = HistoricalPlot(desc_map, connection, self)

        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                       QtGui.QSizePolicy.Expanding)
        sizePolicy.setHorizontalStretch(1)
        sizePolicy.setVerticalStretch(1)
        sizePolicy.setHeightForWidth(self.plotWidget.sizePolicy().hasHeightForWidth())
        self.plotWidget.setSizePolicy(sizePolicy)
        self.plotWidget.setMinimumSize(QtCore.QSize(400,150))
        self.plotWidget.resize(400, 150)

        
        self.controls = ControlWidget(self.plotWidget, self)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                       QtGui.QSizePolicy.Fixed)
        sizePolicy.setHeightForWidth(self.controls.sizePolicy().hasHeightForWidth())
        self.controls.setSizePolicy(sizePolicy)
        self.controls.setMinimumSize(QtCore.QSize(400,50))
        
        self.legend = LegendWidget(self.plotWidget, self)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                       QtGui.QSizePolicy.Expanding)
        sizePolicy.setHeightForWidth(self.legend.sizePolicy().hasHeightForWidth())
        self.legend.setSizePolicy(sizePolicy)
        self.legend.setMinimumSize(QtCore.QSize(100,200))

        

        self.layout = QtGui.QHBoxLayout(self)
        self.splitter = QtGui.QSplitter(self, QtCore.Qt.Horizontal)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Preferred, QtGui.QSizePolicy.Preferred)
        sizePolicy.setHorizontalStretch(1)
        sizePolicy.setVerticalStretch(1)
        sizePolicy.setHeightForWidth(self.splitter.sizePolicy().hasHeightForWidth())
        self.splitter.setSizePolicy(sizePolicy)
        self.layout.addWidget(self.splitter)

        self.splitter.addWidget(self.legend)

        container = QtGui.QWidget(self)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                       QtGui.QSizePolicy.Expanding)
        sizePolicy.setHorizontalStretch(1)
        sizePolicy.setVerticalStretch(1)
        container.setSizePolicy(sizePolicy)
        size = QtCore.QSize(self.plotWidget.minimumWidth() + self.controls.minimumWidth(),
                            self.plotWidget.minimumHeight() + self.controls.minimumHeight())
        container.setMinimumSize(size)
        
        subLayout = QtGui.QVBoxLayout(container)
        subLayout.addWidget(self.plotWidget)
        subLayout.addWidget(self.controls)

        container.setLayout(subLayout)
        self.splitter.addWidget(container)

        self.setLayout(self.layout)

        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                       QtGui.QSizePolicy.Expanding)
        self.setSizePolicy(sizePolicy)

    def json_friendly(self):
        json = BaseTabViewWidget.json_friendly(self)
        #do_stuff_here(json)
        return json

    @classmethod
    def from_json(cls, json, tab_bar, find_source, parent=None):
        tab = cls(tab_bar, find_source, parent)
        #do_stuff_with(tab, json)
        return tab

    def redraw(self):
        self.plotWidget.redraw()

    def cleanup(self):
        self.plotWidget.cleanup()

    def update_view(self, now):
        pass

class HistoricalPlot(FigureCanvas):
    def __init__(self, desc_map, connection, parent=None):
        figure = Figure(figsize=(3,3), dpi=72)
        FigureCanvas.__init__(self, figure, parent)

        self.figure = figure
        self.connection = connection
        self.desc_map = desc_map
        
        self.start = None
        self.end = None

        self.views = {}

        FigureCanvas.setSizePolicy(self, QtGui.QSizePolicy.Expanding,
                                         QtGui.QSizePolicy.Expanding)
        FigureCanvas.updateGeometry(self)
        

        from numpy import arange, sin, pi

        t = arange(0.0, 1.0, 0.01)

        self.plot = self.figure.add_subplot(111)
        self.plot.plot(t, sin(2*pi*t))
        self.plot.grid(True)
        self.plot.set_ylim( (-2,2) )
        self.plot.set_ylabel('1 Hz')
        self.plot.set_title('A sine wave or two')
        
        self.setAcceptDrops(True)

    def resizeEvent(self, evt):
        print "plot resize from %s to %s" % (evt.oldSize(), evt.size())
        FigureCanvas.resizeEvent(self, evt)

    def dragEnterEvent(self, event):
        if event.mimeData().hasFormat(SignalTreeWidget.mimeType):
            event.acceptProposedAction()
        else:
            event.ignore()

    def dropEvent(self, event):
        if event.mimeData().hasFormat(SignalTreeWidget.mimeType):
            event.acceptProposedAction()
            sources = event.mimeData().text().split("|")
            for name in sources:
                self.add_signal(sources)
        else:
            event.ignore()

    def add_signal(self, name):
        if name in self.views:
            return
        desc = self.desc_map[name]
        if desc.get("non_numeric") in frozenset(["true", "True", True]):
            return
        
        signal_id, signal_name = name.split(":", 1)
        
        self.views[name] = XOMBIESQLIntervalView(self.connection,
                                                 signal_id, signal_name,
                                                 self.start, self.end)

    def redraw(self):
        self.draw()
        self.figure.canvas.draw()

    def cleanup(self):
        pass

class ControlWidget(QtGui.QWidget):
    def __init__(self, plot, parent=None):
        QtGui.QWidget.__init__(self, parent)
        self.layout = QtGui.QHBoxLayout(self)

        self.left_dt_control = CustomDateTimeEdit()
        self.right_dt_control = CustomDateTimeEdit()
        self.layout.addWidget(self.left_dt_control)
        self.layout.addWidget(self.right_dt_control)
        self.setLayout(self.layout)

class LegendWidget(QtGui.QTreeWidget):
    def __init__(self, plot, parent=None):
        QtGui.QTreeWidget.__init__(self, parent)
##        self.layout = QtGui.QHBoxLayout(self)
##
##        self.test_label = QtGui.QLabel("Legend goes here")
##        self.layout.addWidget(self.test_label)
##        self.setLayout(self.layout)
