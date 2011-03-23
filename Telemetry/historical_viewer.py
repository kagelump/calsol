import colorsys

import config
from matplotlib.pyplot import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg

import matplotlib.dates as mdates
import matplotlib.ticker as ticker

from Tkinter import *
import Tkinter as Tk
from GraphData import SQLIntervalView
from DatePlot import *
from datetime import datetime, timedelta
import sqlite3 as sql

def tk_color(color):
    return "#%02x%02x%02x" % (color[0]*255,
                              color[1]*255,
                              color[2]*255)
def lighten(color):
    H, L, S = colorsys.rgb_to_hls(color[0], color[1], color[2])
    L += 0.1
    if L >= 1.0:
        L = 1.0
    return colorsys.hls_to_rgb(H, L, S) + color[3:]

class HistoricalViewerApp:
    line_styles = ["solid"]
    colors = [
        (0.0, 0.0, 1.0, 1.0), #Blue
        (1.0, 0.0, 0.0, 1.0), #Red
        (0.0, 1.0, 0.0, 1.0), #Green
        (1.0, 1.0, 0.0, 1.0)
    ]

    def __init__(self, width, height):
        self.path = config.find_options("general.cfg")['database']
        self.descriptors = config.find_graphs("graphs.cfg")

        self.data = {}
        self.collections = {}
        self.nav_collections = {}

        self.color_map = {}

        self.connection = sql.connect(self.path, detect_types=(sql.PARSE_COLNAMES|sql.PARSE_DECLTYPES))

        self.root = Tk.Tk()
        self.root.wm_title("Historical Data Viewer")

        self.intervals = self.connection.execute("SELECT * FROM intervals ORDER BY start;").fetchall()
        self.intervals = list(reversed(self.intervals))
        

        #Grid layout:
        #        Col 0        Col 1
        #       +------------+------+   
        # Row 0 |            | ITVL |
        #       |    ZOOM    | SLCT |
        #       | - -GRAPH- -+------+
        # Row 1 |            | DATA |
        #       |            | SLCT |
        #       +------------+------+
        # Row 2 | NAV GRAPH  | ZOOM |
        #       |            | SLCT |
        #       +------------+------+


        #Setup for the Tk/Agg plotting backend
        self.figure = Figure(figsize = (width+1, height+2), dpi = 100)
        self.figure.subplots_adjust(bottom=0.15)
        self.axes = self.figure.add_subplot(111, autoscale_on=True)
        self.axes.xaxis.labelpad *= 3
        self.canvas = FigureCanvasTkAgg(self.figure, master=self.root)
        self.canvas.get_tk_widget().grid(row=0, column=0, rowspan=2)

        #Setup for the mini-navigation figure
        self.nav_figure = Figure(figsize = ((width+1)*1.05, 1.8), dpi = 100)
        self.nav_figure.subplots_adjust(bottom=0.3)
        self.nav_axes = self.nav_figure.add_subplot(111, autoscale_on=False)
        self.nav_axes.xaxis.labelpad *= 2
        self.nav_span = self.nav_axes.axvspan(0.0,1.0, facecolor='g', alpha=0.5)
        self.nav_handle1 = self.nav_axes.axvspan(0.00,0.025, facecolor='black', alpha=0.5)
        self.nav_handle2 = self.nav_axes.axvspan(0.975,1.00, facecolor='black', alpha=0.5)
        self.nav_canvas = FigureCanvasTkAgg(self.nav_figure, master=self.root)
        self.nav_canvas.get_tk_widget().grid(row=2, column=0)

        #Set the z-order to something high so that it works as an overlay
        self.nav_span.zorder = 1000
        self.nav_handle1.zorder = 1001
        self.nav_handle2.zorder = 1001

##        self.nav_axes.xaxis.set_major_locator(ticker.NullLocator())
        self.nav_axes.yaxis.set_major_locator(ticker.NullLocator())

        #Setup for the choosing the interval we want to examine
        self.interval_frame = Tk.Frame(self.root)
        self.interval_frame.grid(row=0, column=1, sticky=N+E)
        picker_label = Tk.Label(self.interval_frame, text="Data Intervals")
        picker_label.grid(row=0, column=0, sticky=N)
        self.interval_picker = Tk.Listbox(self.interval_frame,
                                          selectmode=Tk.BROWSE,
                                          exportselection=0)
        self.interval_picker.grid(row=1, column=0, sticky=N+W+E)
        width = 20
        for (name, start, end) in self.intervals:
            string = format_span(start, end)
            width = max(width, len(string))
            self.interval_picker.insert(Tk.END, string)

        self.interval_picker.config(width=width)

        self.interval_picker.bind("<Double-Button-1>", self.select_interval)
        self.interval_scrollbar = Tk.Scrollbar(self.interval_frame, command=self.interval_picker.yview)
        self.interval_picker.config(yscrollcommand=self.interval_scrollbar.set)
        self.interval_scrollbar.grid(row=1, column=1, sticky=N+S+W)
        picker_button = Tk.Button(self.interval_frame,
                                  text="Select interval",
                                  command=self.select_interval)
        picker_button.grid(row=2, column=0, sticky=N+W)


        #----Variables for picking the table from the database--------------
        self.source_frame = Tk.Frame(self.root)
        self.source_frame.config(relief=Tk.GROOVE,
                                 borderwidth=2)
        self.source_frame.grid(row=1, column=1, sticky=N+W+E+S)

        source_label = Tk.Label(self.source_frame, text="Show/Hide plots")
        source_label.grid(column=0, columnspan=2, sticky=N)
        
        def set_var_callback(cb, data, checkbutton, var=None):
            if var is None:
                var = Tk.IntVar()
            def wrapper_callback():
                var.set(var.get())
                return cb(data, var.get())
            checkbutton.config(variable=var,
                               command=wrapper_callback)

        self.checkbuttons = []
        for i,desc in enumerate(self.descriptors):
            checkbutton = Tk.Checkbutton(self.source_frame,
                                         text=desc.title)
            toggle = Tk.Checkbutton(self.source_frame, text="   ")

            color = self.colors[i % len(self.colors)]
            checkbutton.config(relief=Tk.SUNKEN,
                               indicatoron=False)
            toggle.config(indicatoron=False,
                          background=tk_color(lighten(color)),
                          highlightbackground=tk_color(color),
                          activebackground=tk_color(color),
                          selectcolor=tk_color(color),
                          state=ACTIVE)
            var = Tk.IntVar()
            set_var_callback(self.toggle_source, desc, checkbutton, var)
            set_var_callback(self.toggle_source, desc, toggle, var)
            self.color_map[desc.table_name] = color

            toggle.grid(column=0, row=i+1, sticky=N+W)
            checkbutton.grid(column=1, row=i+1, sticky=N+W)
            self.checkbuttons.append(checkbutton)

        self.style_count = 0
        self.min_y = self.descriptors[0].min_y
        self.max_y = self.descriptors[0].max_y
        self.grabbing_navbar = False
        self.grabbing_handle = False
        self.grab_start = None
        self.handle_grabbed = None
        self.grab_reference = None
        

    def run(self):
        self.nav_figure.canvas.mpl_connect("button_press_event", self.mpl_on_press)
        self.nav_figure.canvas.mpl_connect("button_release_event", self.mpl_on_release)
        self.nav_figure.canvas.mpl_connect("motion_notify_event", self.mpl_on_motion)
        
        self.select_interval(index=0)
        self.interval_picker.selection_set(first=0)

        for desc, checkbutton in zip(self.descriptors, self.checkbuttons):
            checkbutton.select()
            self.toggle_source(desc, True)
        
        self.root.mainloop()

    def update_bounds(self):
        size = to_ordinal(self.absolute_end) - to_ordinal(self.absolute_start)
        x1 = to_ordinal(self.start_date)
        x2 = to_ordinal(self.end_date)
        self.axes.set_xbound(x1, x2)
        self.nav_span.set_xy([[x1, self.min_y],
                              [x1, self.max_y],
                              [x2, self.max_y],
                              [x2, self.min_y],
                              [x1, self.min_y]])
        if x1 > x2:
            x1, x2 = x2, x1
        self.nav_handle1.set_xy([[x1, self.min_y],
                                 [x1, self.max_y],
                                 [x1-size*0.025, self.max_y],
                                 [x1-size*0.025, self.min_y],
                                 [x1, self.min_y]])
        self.nav_handle2.set_xy([[x2, self.min_y],
                                 [x2, self.max_y],
                                 [x2+size*0.025, self.max_y],
                                 [x2+size*0.025, self.min_y],
                                 [x2, self.min_y]])
        locator = KenLocator(7.8)
        self.axes.xaxis.set_major_locator(locator)
        self.axes.xaxis.set_major_formatter(KenFormatter(locator))

        self.axes.set_xlabel(format_span(self.start_date, self.end_date))
        self.nav_axes.set_xlabel(format_timedelta(self.end_date-self.start_date))
        

    def update_data(self):
        for identifier in self.data:
            view = self.data[identifier]
            view.load(self.absolute_start, self.absolute_end)
            self.collections[identifier].set_segments([view.export()])
            self.nav_collections[identifier].set_segments([view.export()])

    def select_interval(self, index=None):
        #Support direct invocation, invocation by event, and as a command
        if not isinstance(index, int):
            if not self.interval_picker.curselection():
                return
            index = int(self.interval_picker.curselection()[0])

        name, start, end = self.intervals[index]
        self.absolute_start = self.start_date = start
        self.absolute_end = self.end_date = end

        size = to_ordinal(start) - to_ordinal(end)
        self.nav_axes.set_xlim(to_ordinal(start)+size*0.025, to_ordinal(end)-size*0.025)

        locator = KenLocator(7.8)
        self.nav_axes.xaxis.set_major_locator(locator)
        self.nav_axes.xaxis.set_major_formatter(KenFormatter(locator))
        
        self.update_data()
        self.update_bounds()

        self.redraw()

    def toggle_source(self, desc, enabled):
        if desc.table_name in self.data:
            if enabled:
                data = self.data[desc.table_name].export()
                self.axes.set_ylabel(desc.units)
            else:
                data = []
            self.collections[desc.table_name].set_segments([data])
            self.nav_collections[desc.table_name].set_segments([data])

            self.redraw()

        elif enabled:
            self.axes.set_ylabel(desc.units)
            self.add_source(desc.table_name, desc.title)
    
            self.min_y = min(self.min_y, desc.min_y)
            self.max_y = max(self.max_y, desc.max_y)
            self.axes.set_ybound(self.min_y,self.max_y)
            self.nav_axes.set_ybound(self.min_y, self.max_y)
##            self.axes.legend(loc=3)
            
            self.redraw()
        
    def redraw(self):
        self.figure.canvas.draw()
        self.nav_figure.canvas.draw()

    def add_source(self, identifier, title):
        view = SQLIntervalView(self.connection, identifier, self.absolute_start, self.absolute_end)
        self.data[identifier] = view

        colors = [self.color_map.get(identifier, self.colors[0])]

        col = DatetimeCollection([view.export()], colors=colors)
        col.set_label(title)
        self.collections[identifier] = col

        col2 = DatetimeCollection([view.export()], colors=colors)
        self.nav_collections[identifier] = col2
        
        self.axes.add_collection(col)
        self.nav_axes.add_collection(col2)

    def mpl_on_press(self, event):
        if event.button != 1 or self.grabbing_navbar or self.grabbing_handle:
            return
        trans = self.nav_axes.transData.inverted()
        xdata = trans.transform((event.x, event.y))[0]
        if self.nav_handle1.contains(event)[0]:
            self.grabbing_handle = True
            self.handle_grabbed = 1
            self.grab_start = xdata
            self.grab_reference = to_ordinal(min(self.start_date, self.end_date))
        elif self.nav_handle2.contains(event)[0]:
            self.grabbing_handle = True
            self.handle_grabbed = 2
            self.grab_start = xdata
            self.grab_reference = to_ordinal(max(self.start_date, self.end_date))
        elif self.nav_span.contains(event)[0]:
            self.grabbing_navbar = True
            self.grab_start = xdata
            self.grab_reference = (to_ordinal(self.start_date),
                                   to_ordinal(self.end_date))

    def move_navbar(self, pos):
        left_end = to_ordinal(self.absolute_start)
        right_end = to_ordinal(self.absolute_end)
        x1, x2 = self.grab_reference

        if x1 > x2:
            x1, x2 = x2, x1
        
        diff = pos - self.grab_start
        if diff < 0 and x1 + diff < left_end:
            self.start_date = self.absolute_start
            self.end_date = from_ordinal(left_end + (x2 - x1))
        elif diff > 0 and x2 + diff > right_end:
            self.end_date = self.absolute_end
            self.start_date = from_ordinal(right_end - (x2 - x1))
        else:
            self.start_date = from_ordinal(x1 + diff)
            self.end_date = from_ordinal(x2 + diff)

        self.update_bounds()
        self.redraw()

    def move_handle(self, pos):
        left_end = to_ordinal(self.absolute_start)
        right_end = to_ordinal(self.absolute_end)
        
        diff = pos - self.grab_start
        new_pos = max(min(self.grab_reference + diff, right_end), left_end)
        new_date = from_ordinal(new_pos)

        if self.handle_grabbed == 1:
            if new_date > self.end_date:
                self.handle_grabbed = 2
                self.start_date = self.end_date
                self.end_date = new_date
            else:
                self.start_date = new_date
        else:
            if new_date < self.start_date:
                self.handle_grabbed = 1
                self.end_date = self.start_date
                self.start_date = new_date
            else:
                self.end_date = new_date
            

        self.update_bounds()
        self.redraw()

    def mpl_on_release(self, event):
        if event.button != 1:
            return

        trans = self.nav_axes.transData.inverted()
        xdata = trans.transform((event.x, event.y))[0]

        if self.grabbing_navbar:
            self.grabbing_navbar = False
            self.move_navbar(xdata)
        elif self.grabbing_handle:
            self.grabbing_handle = False
            self.move_handle(xdata)

    def mpl_on_motion(self, event):
        trans = self.nav_axes.transData.inverted()
        xdata = trans.transform((event.x, event.y))[0]
        if self.grabbing_navbar:
            self.move_navbar(xdata)
        elif self.grabbing_handle:
            self.move_handle(xdata)


if __name__ == "__main__":
    hv = HistoricalViewerApp(6, 3)
    hv.run()
