import datetime
import matplotlib.dates as mdates
from matplotlib.axes import Subplot
from matplotlib.figure import Figure
from PySide import QtGui, QtCore

from backend_pysideagg import FigureCanvasQTAgg as FigureCanvas
from DatePlot import DatetimeCollection, KenLocator, KenFormatter
from GraphData import XOMBIESQLIntervalView
from SignalWidget import SignalTreeWidget, SignalListEditorDialog
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
            for id_, descr in desc_set.items():
                for [name, units, desc] in descr.get("messages", []):
                    desc_map[id_+":"+name] = descr
        
        self.plotWidget = HistoricalPlot(desc_map, connection, self)
        self.controlWidget = ControlWidget(self.plotWidget, parent=self)
        self.layout = QtGui.QVBoxLayout(self)
        self.layout.addWidget(self.plotWidget)
        self.layout.addWidget(self.controlWidget)
        self.setLayout(self.layout)

    def json_friendly(self):
        json = BaseTabViewWidget.json_friendly(self)
        self.plotWidget.add_json(json)
        return json

    @classmethod
    def from_json(cls, json, tab_bar, desc_sets, connection, parent=None):
        tab = cls(tab_bar, desc_sets, connection, parent)
        start, end = map(mdates.num2date, json["xview"])
        tab.plotWidget.update_bounds(start, end)
        tab.controlWidget.left_dt_control.setPyDateTime(start)
        tab.controlWidget.right_dt_control.setPyDateTime(end)

        for ident, descr in json["signals"].items():
            self.add_signal(descr)

    def redraw(self):
        self.plotWidget.redraw()

    def cleanup(self):
        self.plotWidget.cleanup()

    def update_view(self, now):
        pass

    def contextMenuEvent(self, event):
        event.accept()

        menu = QtGui.QMenu(self)
        menu.addActions(self.tab_bar.actions())
        menu.addSeparator()
        menu.addActions(self.plotWidget.actions())
        
        menu.popup(event.globalPos())

class HistoricalPlot(FigureCanvas):
    def __init__(self, desc_map, connection, parent=None):
        figure = Figure(figsize=(3,3), dpi=72)
        FigureCanvas.__init__(self, figure, parent)

        self.figure = figure
        self.connection = connection
        self.desc_map = desc_map
        
        self.start = datetime.datetime.utcnow()
        self.end = datetime.datetime.utcnow()

        self.adjust_signals_action = QtGui.QAction("Adjust signals plotted", self)
        self.addAction(self.adjust_signals_action)
        

        self.views = {}
        self.autoscale = True
        self.showing_dialog = False

        FigureCanvas.setSizePolicy(self, QtGui.QSizePolicy.Expanding,
                                         QtGui.QSizePolicy.Expanding)
        FigureCanvas.updateGeometry(self)
        
        self.plot = self.figure.add_subplot(111)
        self.setAcceptDrops(True)

        link(self.adjust_signals_action.triggered, self.adjust_signals)

    def adjust_signals(self):
##        if self.showing_dialog:
##            return
        
        dialog = SignalListEditorDialog(self)
        descrs = []
        for name in self.views:
            descr = {"identifier":name,
                     "color": [0.0, 0.0, 1.0, 1.0],
                     "style": "solid"}
            descrs.append(descr)
        dialog.setup(descrs)

##        def set_hidden():
##            self.showing_dialog = False
##
##        link(dialog.closed, set_hidden)

        dialog.show()
        self.showing_dialog = True

    def update_bounds(self, left, right):
        if left is None:
            left = self.start
        if right is None:
            right = self.end

        if left > right:
            left, right = right, left

        self.start = left
        self.end = right

        self.plot.set_xbound(self.start,
                             self.end)

        locator = KenLocator(5)
        self.plot.xaxis.set_major_locator(locator)
        formatter = KenFormatter(locator)
        self.plot.xaxis.set_major_formatter(formatter)
        
        for ident, (view, collection) in self.views.items():
            view.load(self.start, self.end)
            ymin, ymax = view.y_bounds
            collection.set_segments([view.export()])
            if self.autoscale:
                cmin, cmax = self.plot.get_ybound()
                self.plot.yaxis.set_view_interval(ymin, ymax, ignore=False)

    def add_json(self, json):
        json["xview"] = tuple(self.plot.get_xbound())
        json["yview"] = tuple(self.plot.yaxis.get_view_interval())

    def dragEnterEvent(self, event):
        if event.mimeData().hasFormat(SignalTreeWidget.mimeType):
            event.acceptProposedAction()
        else:
            event.ignore()
    
    def dropEvent(self, event):
        sources = SignalTreeWidget.getMimeDataSignals(event.mimeData())
        if sources is not None:
            event.acceptProposedAction()
            for name in sources:
                self.add_signal(name)
        else:
            event.ignore()

    def add_signal(self, descr):
        ident = descr["identifier"]
        if ident in self.views:
            return
        desc = self.desc_map[ident]
        if desc.get("non_numeric") in frozenset(["true", "True", True]):
            return
        
        signal_id, signal_name = ident.split(":", 1)
        collection = DatetimeCollection([])
        self.plot.add_collection(collection)
        view = XOMBIESQLIntervalView(self.connection, signal_id,
                                     signal_name, self.start, self.end)
        self.views[ident] = (view, collection)
        collection.set_segments(view.export())

    def redraw(self):
        self.draw()
        self.figure.canvas.draw()

    def cleanup(self):
        for ident, (view, collection) in self.views.items():
            collection.remove()
    

class ControlWidget(QtGui.QWidget):
    def __init__(self, plot, start_date=None, end_date=None, parent=None):
        QtGui.QWidget.__init__(self, parent)
        self.plot = plot
        self.layout = QtGui.QHBoxLayout(self)

        self.left_dt_control = CustomDateTimeEdit(date=start_date, parent=self)
        self.right_dt_control = CustomDateTimeEdit(date=end_date, parent=self)
        self.layout.addWidget(self.left_dt_control)
        self.layout.addWidget(self.right_dt_control)
        self.setLayout(self.layout)

        def update_left(dt):
            self.plot.update_bounds(dt, None)

        def update_right(dt):
            self.plot.update_bounds(None, dt)

        link(self.left_dt_control.pyDateTimeChanged, update_left)
        link(self.right_dt_control.pyDateTimeChanged, update_right)

