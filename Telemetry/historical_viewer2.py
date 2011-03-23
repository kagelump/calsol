import colorsys

import config
from matplotlib.pyplot import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg

import matplotlib.dates as mdates
import matplotlib.ticker as ticker
from matplotlib.transforms import BboxTransformTo

from Tkinter import *
import Tkinter as Tk
from GraphData import SQLIntervalView
from DatePlot import *
from datetime import datetime, timedelta
import sqlite3 as sql

from DoubleSlider import DoubleSlider

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
        #self.axes.xaxis.labelpad *= 3
        

        self.canvas = FigureCanvasTkAgg(self.figure, master=self.root)
        self.canvas.get_tk_widget().grid(row=0, column=0, rowspan=2)

        #Setup for the mini-navigation figure
        self.nav_figure = Figure(figsize = ((width+1)*1.05, 1.8), dpi = 100)
        #self.nav_figure.subplots_adjust(bottom=0.3)
        self.nav_axes = self.nav_figure.add_subplot(111, autoscale_on=False)
        #self.nav_axes.xaxis.labelpad *= 2
                
        self.nav_canvas = FigureCanvasTkAgg(self.nav_figure, master=self.root)
        self.nav_canvas.get_tk_widget().grid(row=2, column=0)
        
        self.nav_axes.yaxis.set_major_locator(ticker.NullLocator())

        #Setup for the slider
        def scale_to_data(left, right, x):
            return from_ordinal(to_ordinal(left) + x * (to_ordinal(right) - to_ordinal(left)))
        def data_to_scale(left, right, x):
            return (to_ordinal(x) - to_ordinal(left)) / (to_ordinal(right) - to_ordinal(left))
        
        self.slider = DoubleSlider(self.root,
                                   left_bound=datetime(1999,1,1),
                                   right_bound=datetime(1999,1,28),
                                   data_to_scale=data_to_scale,
                                   scale_to_data=scale_to_data,
                                   set_on_drag=False,
                                   on_change=self.update_bounds,
                                   on_drag=lambda left, right: self.update_bounds(left, right, True))
        self.slider.grid(row=3, column=0, sticky=W+E)        

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


    def run(self):
        left_pad = self.nav_figure.subplotpars.left * self.nav_figure.get_figwidth() * self.nav_figure.dpi
        right_pad = (1-self.nav_figure.subplotpars.right) * self.nav_figure.get_figwidth() * self.nav_figure.dpi
        self.slider.config(left_padding=left_pad,
                           right_padding=right_pad)

        self.figure.canvas.draw()
        self.nav_figure.canvas.draw()

        self.slider.init()
        
        self.select_interval(index=0)
        self.interval_picker.selection_set(first=0)

        for desc, checkbutton in zip(self.descriptors, self.checkbuttons):
            checkbutton.select()
            self.toggle_source(desc, True)

        locator = KenLocator(7.8)
        self.nav_axes.xaxis.set_major_locator(locator)
        self.nav_axes.xaxis.set_major_formatter(KenFormatter(locator))

        locator = KenLocator(7.8)
        self.axes.xaxis.set_major_locator(locator)
        self.axes.xaxis.set_major_formatter(KenFormatter(locator))
        
        self.root.mainloop()

    def update_bounds(self, left, right, dragging=False):
        if not dragging:
            self.axes.set_xbound(to_ordinal(left), to_ordinal(right))

            self.axes.set_xlabel(format_span(left, right)
                                 + " (" + format_timedelta(right - left) + ")")

        agg_canvas = self.nav_canvas.get_tk_widget()
        agg_canvas.delete("OVERLAY")


        #    c1            c3
        #    +---+---------+---+
        #    |...| _/\   _ |...|
        #    |...|/   \_/ \|...|
        #    +---+---------+---+
        #        c2            c4
        cx2, cy2 = self.nav_axes.transData.transform_point((to_ordinal(left), self.max_y)).tolist()
        cx3, cy3 = self.nav_axes.transData.transform_point((to_ordinal(right), self.min_y)).tolist()
        agg_canvas.create_rectangle([cx2, cy2, cx3, cy3], tags="OVERLAY",
                                    stipple = "gray50",
                                    fill = "green")
##        cx1, cy1 = self.nav_axes.transData.transform_point((to_ordinal(self.slider.left_bound), self.min_y)).tolist()
##        cx2, cy2 = self.nav_axes.transData.transform_point((to_ordinal(left), self.max_y)).tolist()
##        agg_canvas.create_rectangle([(cx1+1, cy1+2), (cx2, cy2)],
##                                    tags="OVERLAY",
##                                    stipple="gray50",
##                                    fill="red", outline="")
##
##        cx3, cy3 = self.nav_axes.transData.transform_point((to_ordinal(right), self.min_y)).tolist()
##        cx4, cy4 = self.nav_axes.transData.transform_point((to_ordinal(self.slider.right_bound), self.max_y)).tolist()
##        agg_canvas.create_rectangle([(cx3, cy3+2), (cx4, cy4)],
##                                    tags="OVERLAY",
##                                    stipple="gray50",
##                                    fill="red", outline="")

        if not dragging:
            self.figure.canvas.draw()
        self.nav_figure.canvas.draw()

    def select_interval(self, index=None):
        #Support direct invocation, invocation by event, and as a command
        if not isinstance(index, int):
            if not self.interval_picker.curselection():
                return
            index = int(self.interval_picker.curselection()[0])

        name, start, end = self.intervals[index]
        for identifier in self.data:
            view = self.data[identifier]
            view.load(start, end)
            self.collections[identifier].set_segments([view.export()])
            self.collections[identifier].set_antialiased(False)
            self.nav_collections[identifier].set_segments([view.export()])
        
        self.slider.config(left_bound=start,
                           right_bound=end)
        self.slider.reset()

        self.nav_axes.set_xbound(to_ordinal(start), to_ordinal(end))
        self.nav_axes.set_xlabel("%s (%s)" % (format_span(start, end),
                                              format_timedelta(end - start)))
        self.redraw()

    def toggle_source(self, desc, enabled):
        if desc.table_name in self.data:
            self.nav_collections[desc.table_name].set_visible(enabled)
            self.collections[desc.table_name].set_visible(enabled)
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
        left, right = sorted([self.slider.left_bound, self.slider.right_bound])
        view = SQLIntervalView(self.connection, identifier, left, right)
        self.data[identifier] = view

        colors = [self.color_map.get(identifier, self.colors[0])]
        col = DatetimeCollection([view.export()], colors=colors)
        col.set_label(title)
        self.collections[identifier] = col

        col2 = DatetimeCollection([view.export()], colors=colors)
        self.nav_collections[identifier] = col2
        
        self.axes.add_collection(col)
        self.nav_axes.add_collection(col2)


if __name__ == "__main__":
##    import cProfile
##    cProfile.run("HistoricalViewerApp(6, 3).run()", "hs-stats")
    hv = HistoricalViewerApp(6, 3)
    hv.run()
