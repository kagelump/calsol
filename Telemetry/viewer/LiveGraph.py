import datetime
import json
import matplotlib.dates as mdates
from matplotlib.axes import Subplot
from matplotlib.figure import Figure

from PySide import QtGui, QtCore

from backend_pysideagg import FigureCanvasQTAgg as FigureCanvas
from DatePlot import DatetimeCollection, KenLocator, KenFormatter
from SignalWidget import SignalTreeWidget, SignalListEditorDialog
from ViewWidget import BaseTabViewWidget
from util import link

__all__ = ["LiveGraphTabView"]

class LiveGraphTabView(BaseTabViewWidget, FigureCanvas):
    """
    LiveGraphTabView implements the live graphing functionality of the viewer,
    including supporting dropping signals into the graph, and pulling live
    data from multiple data sources and redrawing.

    class variables:
        view_name   - the user-visible title for LiveGraphTabViews
        view_id     - the type name stored when the tab is serialized to json
                      in this case, 'live.graph'
        view_icon   - the default icon filename for live graph widgets,
                      in this case, 'graph-icon.png'
        view_desc   - the user-visible description of the LiveGraphTabView
    instance variables:
        figure      - the matplotlib figure object associated with the widget
        plots       - the subplot objects being displayed
        tab_bar     - the TabWidget to which this tab belongs
        timescale   - the duration in seconds of previous data displayed

    method summary:
        json_friendly - returns a simple representation of the tab view suitable
                        for serialization to json. Specifically exports the
                        timescale and a list of plots.
        cleanup       - frees up the plots belonging to this figure and the
                        figure itself so that the tab can be cleanly deleted
                        
        update_view(now) - updates the current plots by copying any pending data
                           to their collections and updating the view limits to
                           reflect the current timescale relative to now.

        add_plot(names)  - adds a new subplot to this view with all of the signals
                           in names automatically added. Rescales existing plots
                           so that they all occupy the same amount of space.
        remove_plot(plot)- removes the subplot from this view and rescales the
                           remaining subplots.

        redraw           - redraws all plots and the figure.
    """
    view_name = "Live Graph View"
    view_id   = "live.graph"
    view_icon = "graph-icon.png"
    view_desc = "A live stream of data visualized on a plot vs time"

    def __init__(self, tab_bar, source_finder, parent=None):
        figure = Figure(figsize=(3,3), dpi=72)
        FigureCanvas.__init__(self, figure, parent)
        BaseTabViewWidget.__init__(self, parent, init=False)

        self.figure = figure
        self.plots = []
        self.tab_bar = tab_bar
        self.timescale = 30
        self.find_source = source_finder

        #General plan for actions:
        #Plot specific actions are dispatched through the contextMenuEvent
        #handler which finds the selected plot using get_axes_at_point
        #and then generates a context menu with actions bound to the specific
        #plot. Generic non-plot-specific actions like adjusting the timescale
        #and renaming the tab are bound to the tab view and the tab widget
        #respectively.
        self.timescale_action = QtGui.QAction("Adjust timescale", self)
        self.addAction(self.timescale_action)

        link(self.timescale_action.triggered, self.adjust_timescale)
        FigureCanvas.setSizePolicy(self, QtGui.QSizePolicy.Expanding,
                                         QtGui.QSizePolicy.Expanding)
        FigureCanvas.updateGeometry(self)
        self.setContextMenuPolicy(QtCore.Qt.DefaultContextMenu)
        self.setAcceptDrops(True)

    #Drag-and-Drop support
    def dragEnterEvent(self, event):
        if event.mimeData().hasFormat(SignalTreeWidget.mimeType):
            event.acceptProposedAction()
        else:
            event.ignore()

    def dropEvent(self, event):
        sources = SignalTreeWidget.getMimeDataSignals(event.mimeData())
        if sources is not None:
            event.acceptProposedAction()
            self.add_plot(sources)
        else:
            event.ignore()

    def add_plot(self, sources):
        "Add a subplot to this widget displaying all of the signals in names"
        
        rows = len(self.plots) + 1
        for i, plot in enumerate(self.plots):
            plot.change_geometry(rows, 1, i+1)
            plot.label_outer()
        
        new_plot = LiveSubplot(self.find_source, self, rows, 1, rows)
        td = datetime.timedelta(seconds=self.timescale)
        
        now = datetime.datetime.utcnow()
        new_plot.set_xbound(mdates.date2num(now - td),
                            mdates.date2num(now))
        if len(sources) == 1:
            new_plot.set_title(sources[0]["name"])

        for descr in sources:
            new_plot.add_signal(descr["identifier"],
                                color=descr["color"],
                                style=descr["style"])

        self.figure.add_subplot(new_plot)
        self.plots.append(new_plot)

        return new_plot
    
    def remove_plot(self, plot):
        "Remove the subplot from this view"
        self.figure.delaxes(plot)
        self.plots.remove(plot)

        plot.cleanup()

        rows = len(self.plots)
        for i, axes in enumerate(self.plots):
            axes.change_geometry(rows, 1, i+1)

    #TabView maintenance methods
    def cleanup(self):
        "Frees the plots and the figure"
        for plot in self.plots:
            plot.cleanup()
            self.figure.delaxes(plot)

    def json_friendly(self):
        "Serializes to a json-friendly data-structure. Adds timescale and plot info"
        json = BaseTabViewWidget.json_friendly(self)
        json["timescale"] = self.timescale
        json["plots"] = [plot.json_friendly() for plot in self.plots]
        return json

    @classmethod
    def from_json(cls, json, tab_bar, find_source, parent=None):
        tab = cls(tab_bar, find_source, parent)
        tab.timescale = json["timescale"]
        
        for plot_desc in json["plots"]:
            plot = tab.add_plot([])
            plot.init_from_json(plot_desc)

        return tab

    def update_view(self, now):
        "Copy any pending data to the plots and update the data limits"
        td = datetime.timedelta(seconds=self.timescale)
        for plot in self.plots:
            plot.update_data(now, td)

    def redraw(self):
        "Redraw with updated axes ticks"
        self.draw()
        self.figure.canvas.draw()

    #Context menu handlers
    def adjust_timescale(self):
        new_scale, accepted = QtGui.QInputDialog.getDouble(self,
                                  "Seconds of past data to display",
                                  "Seconds", self.timescale, 0.0)
        if accepted:
            self.timescale = new_scale
    
    def get_axes_at_point(self, x, y):
        trans = self.figure.transFigure.inverted()
        figure_point = trans.transform([x, self.figure.bbox.height - y])
        fx, fy = figure_point[0], figure_point[1]
        for plot in self.plots:
            if plot.get_position().contains(fx, fy):
                return plot
        else:
            return None


    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.RightButton:
            event.ignore()
            return
        axes = self.get_axes_at_point(event.x(), event.y())
        if axes is None:
            event.ignore()
            return
        else:
            axes.toggle_pause()
            event.accept()
            #To do: do stuff with the mouse-click.

    def contextMenuEvent(self, event):
        event.accept()
        axes = self.get_axes_at_point(event.x(), event.y())
        if axes is None:
            menu = QtGui.QMenu(self)
            menu.addActions([self.tab_bar.rename_action, self.timescale_action])
            menu.popup(event.globalPos())
            return

        menu = QtGui.QMenu(self)
        
        menu.addAction(axes.set_title_action)
        menu.addAction(axes.adjust_axes_action)
        menu.addAction(axes.adjust_signals_action)
        delete_action = menu.addAction("Delete Plot")

        menu.addSeparator()

        menu.addAction(self.tab_bar.rename_action)
        menu.addAction(self.timescale_action)

        link(delete_action.triggered, lambda: self.remove_plot(axes))
        
        menu.popup(event.globalPos())

class LiveSubplot(Subplot):
    """
    LiveSubplot implements the plotting functionality for individual plots.

    instance variables:
        signals   - a mapping from signal names to source objects and
                    collections
        parent    - the LiveGraphTabView that holds this plot
        paused    - whether or not this plot is paused and should not update
                    its data limits
        autoscale - whether or not the plot should automatically calculate
                    the y-axis data-limits from the data seen so far or
                    use pre-determined limits
        static    - whether or not the plot should use static x-axis time
                    data limits instead of being pegged to the present.
    method summary:
        json_friendly       - returns a json-friendly data structure containing:
                              * a list of signal names and color/line-styles
                              * autoscaling status
                              * static status
                              * y-axis current data-limits (ignored if autoscaling)
                              * x-axis current data-limits (ignored if not static)
                              * current y-axis units label
                              * current plot title
        cleanup             - frees all of the collections in use
        add_signal(name)    - adds the signal to the plot, if it doesn't already exist
        remove_signal(name) - removes the signal from the plot
        toggle_pause        - toggles paused status on/off
        update_data         - updates plot data and data limits for any unpaused plots
    """
    def __init__(self, find_source, parent, *args, **kwargs):
        Subplot.__init__(self, parent.figure, *args, **kwargs)
        self.signals = {}
        self.parent = parent
        self.paused = False
        self.autoscale = True
        self.static = False

        self.find_source = find_source
        
        self.set_title_action = QtGui.QAction("Set plot title", parent)
        self.adjust_axes_action = QtGui.QAction("Adjust plot axes", parent)
        self.adjust_signals_action = QtGui.QAction("Change signals plotted", parent)

        link(self.set_title_action.triggered, self.adjust_title)
        link(self.adjust_axes_action.triggered, self.adjust_axes)
        link(self.adjust_signals_action.triggered, self.adjust_signals)

    def json_friendly(self):
        signal_list = []
        for name, (source, col) in self.signals.items():
            signal_list.append((name, tuple(col.get_color()[0]), col.get_linestyle()[0]))

        return { "signals"   : signal_list,
                 "autoscale" : self.autoscale,
                 "static"    : self.static,
                 "yview"     : tuple(self.yaxis.get_view_interval()),
                 "xview"     : tuple(self.xaxis.get_view_interval()),
                 "units"     : self.yaxis.get_label_text(),
                 "title"     : self.get_title()
               }

    def init_from_json(self, json):
        self.autoscale = json["autoscale"]
        self.static = json["static"]
        if json.get("title"):
            self.set_title(json["title"])
        if json.get("units"):
            self.yaxis.set_label_text(json["units"])
        y_min, y_max = json["yview"]
        self.yaxis.set_view_interval(y_min, y_max, ignore=True)
        self.yaxis.reset_ticks()
        
        for (name, color, style) in json["signals"]:
            self.add_signal(name)

    def cleanup(self):
        for name, (signal, collection) in self.signals.items():
            collection.remove()

    def add_signal(self, name, color=None, style=None):
        if name in self.signals:
            return

        collection = DatetimeCollection([])
        self.add_collection(collection)
        self.signals[name] = (self.find_source(name), collection)

    def remove_signal(self, name):
        self.signals[name].remove()
        del self.signals[name]

    def toggle_pause(self):
        self.paused = not self.paused

    def update_data(self, now, delta):
        if self.paused:
            return

        locator = KenLocator(5)
        self.xaxis.set_major_locator(locator)
        formatter = KenFormatter(locator)
        self.xaxis.set_major_formatter(formatter)

        for name, (signal, collection) in self.signals.items():
            ymin, ymax = signal.data.y_bounds
            collection.set_segments([signal.data.export()])
            if self.autoscale:
                cmin, cmax = self.get_ybound()
                self.yaxis.set_view_interval(ymin, ymax, ignore=False)
        self.set_xbound(now-delta, now)

    def adjust_title(self):
        title, accepted = QtGui.QInputDialog.getText(self.parent,
                          "Change plot title",
                          "New title",
                          text=self.get_title())
        if accepted:
            self.set_title(title)

    def adjust_axes(self):
        dialog = QtGui.QDialog(self.parent)
        dialog.setWindowTitle('Axis parameters for "%s"' % self.get_title())
        L1 = QtGui.QVBoxLayout(dialog)
        L2 = QtGui.QHBoxLayout()
        L1.addLayout(L2)

        xbox = QtGui.QGroupBox("Static X-Axis (Time)", dialog)
        xbox.setCheckable(True)
        xbox.setChecked(self.static)
        xlayout = QtGui.QFormLayout(xbox)
        x_min   = CustomDateTimeEdit(parent=xbox)
        x_max   = CustomDateTimeEdit(parent=xbox)

        xlayout.addRow("Start", x_min)
        xlayout.addRow("End", x_max)
        xbox.setLayout(xlayout)

        ybox = QtGui.QGroupBox("Y-Axis", dialog)
        ylayout = QtGui.QFormLayout(ybox)
        y_units = QtGui.QLineEdit(self.yaxis.get_label_text(), ybox)

        autoscale = QtGui.QCheckBox("&Autoscale axis", dialog)
        state = QtCore.Qt.Checked if self.autoscale else QtCore.Qt.Unchecked
        autoscale.setCheckState(state)
        
        y_min   = QtGui.QDoubleSpinBox(ybox)
        y_min.setDecimals(5)
        y_min.setRange(-2e308, 2e308)
        a, b = self.yaxis.get_view_interval()
        y_min.setValue(a)
        y_max   = QtGui.QDoubleSpinBox(ybox)
        y_max.setDecimals(5)
        y_max.setRange(-2e308, 2e308)
        y_max.setValue(b)

        if self.autoscale:
            y_min.setEnabled(False)
            y_max.setEnabled(False)

        ylayout.addRow("Units", y_units)
        ylayout.addWidget(autoscale)
        ylayout.addRow("Max", y_max)
        ylayout.addRow("Min", y_min)
        ybox.setLayout(ylayout)
        L2.addWidget(xbox)
        L2.addWidget(ybox)

        buttonbox = QtGui.QDialogButtonBox((QtGui.QDialogButtonBox.Ok
                                           |QtGui.QDialogButtonBox.Apply
                                           |QtGui.QDialogButtonBox.Cancel),
                                           parent=dialog)
        ok = buttonbox.button(QtGui.QDialogButtonBox.Ok)
        apply = buttonbox.button(QtGui.QDialogButtonBox.Apply)
        cancel = buttonbox.button(QtGui.QDialogButtonBox.Cancel)

        def apply_changes():
            self.yaxis.set_label_text(y_units.text())
            if autoscale.isChecked():
                self.autoscale = True
            else:
                self.yaxis.set_view_interval(y_min.value(), y_max.value(), ignore=True)
                self.yaxis.reset_ticks()

            if xbox.isChecked():
                print x_min.pyDateTime(), x_max.pyDateTime()
        
        L1.addWidget(buttonbox)
        dialog.setLayout(L1)

        link(autoscale.stateChanged, lambda state: (y_min.setEnabled(not state),
                                                    y_max.setEnabled(not state)))
        link(cancel.pressed, dialog.close)
        link(apply.pressed, apply_changes)
        link(ok.pressed, lambda: (apply_changes(), dialog.close()))
        dialog.show()
        

    def adjust_signals(self):
        print "Adjust sources selected"
        dialog = SignalListEditorDialog(self.parent)
        descrs = []
        for name in self.signals:
            descr = {"identifier":name,
                     "color": [0.0, 0.0, 1.0, 1.0],
                     "style": "solid"}
            descrs.append(descr)
        dialog.setup(descrs)

        def say_hi(*args):
            print "Hi", args

        link(dialog.signal_added, self.add_signal)
        link(dialog.signal_modified, say_hi)
        link(dialog.signal_removed, say_hi)
        
        dialog.show()


class CustomDateTimeEdit(QtGui.QDateTimeEdit):

    pyDateTimeChanged = QtCore.Signal([object])
    def __init__(self, date=None, time=None, parent=None):
        QtGui.QDateTimeEdit.__init__(self, parent)
        date = date if date is not None else QtCore.QDate.currentDate()
        self.setDate(date)
        self.setMinimumDate(QtCore.QDate(1993, 6, 20))
        self.setDisplayFormat("ddd MM/dd/yyyy h:mm:ss AP")

        self.setCalendarPopup(True)
        link(self.dateTimeChanged, self.emit_datetime)


    def pyDateTime(self):
        qdt = self.dateTime().toUTC()
        qdate, qtime = qdt.date(), qdt.time()

        dt = datetime.datetime(qdate.year(), qdate.month(), qdate.day(),
                               qtime.hour(), qtime.minute(), qtime.second())
        return dt

    def emit_datetime(self, qdt):
        qdate, qtime = qdt.date(), qdt.time()

        dt = datetime.datetime(qdate.year(), qdate.month(), qdate.day(),
                               qtime.hour(), qtime.minute(), qtime.second())
        self.pyDateTimeChanged.emit(dt)

    def setPyDateTime(self, dt):
        qdate = QtCore.QDate(dt.year, dt.month, dt.day)
        qtime = QtCore.QTime(dt.hour, dt.minute, dt.second)
        qdt = QtCore.QDateTime(qdate, qtime)
