import Tkinter as Tk

class SliderHandle:
    """A canvas element that represents a slider handle and tracks the state
       of the mouse, including grabbing.

       Instance variable semantics:
       parent: the slider canvas element that this handle belongs to
       id:     the id associated with the main handle canvas element that is
               bound to mouse events (the clickable one)
       group:  the tag associated with all of the canvas elements that make
               up this handle
       value:  the data value associated with the handle
       pos:    the x position of the center of the handle on the scale
    """
    def __init__(self, slider, id, group):
        self.parent = slider
        self.id = id
        self.group = group
        
        self.mouse_origin = self.handle_origin = None
        self.grabbed = False
        self.value = None

    @property
    def pos(self):
        x = self.parent.coords(self.id)[0]
        return x + 6

    def move(self, dx):
        self.parent.move(self.group, dx, 0)

    def move_to(self, dest):
        self.parent.move(self.group, dest - self.pos, 0)

    def on_grab(self, event):
        self.mouse_origin = event.x
        self.handle_origin = self.pos
        self.grabbed = True

        self.parent.tag_raise(self.group)

    def on_move(self, event):
        dest = self.parent.clamp(event.x - self.mouse_origin + self.handle_origin)
        
        if self.parent.set_on_drag:
            value = self.parent.value_at(dest)
            rounded = self.parent.round(value)
            if rounded != value:
                self.move_to(self.parent.position_for(rounded))
            else:
                self.move_to(dest)
            self.value = rounded
            self.parent.notify_change()
        else:
            self.move_to(dest)
            self.value = self.parent.value_at(dest)
            self.parent.notify_drag()

    def on_release(self, event):
        dest = self.parent.clamp(event.x - self.mouse_origin + self.handle_origin)

        value = self.parent.value_at(dest)
        rounded = self.parent.round(value)
        if rounded != value:
            self.move_to(self.parent.position_for(rounded))
        else:
            self.move_to(dest)
        self.value = rounded
        
        self.grabbed = False
        self.mouse_origin = self.handle_origin = None

        self.parent.notify_change()

    def bind(self, event_type, cb, add=None):
        self.parent.tag_bind(self.id, event_type, cb, add)

    def bind_mouse_events(self):
        self.bind("<ButtonPress-1>", self.on_grab)
        self.bind("<ButtonRelease-1>", self.on_release)
        self.bind("<B1-Motion>", self.on_move)

def linear_to_scale(left, right, x):
    return (x - left) / (right - left)

def linear_to_data(left, right, x):
    return left + x * (right - left)

def default_round(x):
    return x


class DoubleSlider(Tk.Canvas):
    def __init__(self, master=None, cnf={},
                 left_bound=0.0, right_bound=1.0,
                 round=default_round,
                 data_to_scale=linear_to_scale,
                 scale_to_data=linear_to_data,
                 on_change=None, on_drag=None,
                 **kw):
        """A slider widget with two slider handles.
           Additional configuration options:
               left_padding: padding in pixels to be added to the left (defaults to 10)
               right_padding: padding in pixels to be added to the right (defaults to 10)
               top_padding: padding in pixels to be added to the top (defaults to 5)
               bottom_padding: padding in pixels to be added to the bottom (defaults to 15)
               set_on_drag: update values while dragging handles (defaults to True)

               left_bound: the value to be used as the left bound
               right_bound: the value to be used as the right bound
               round: a function to round the value to the nearest nice value (for snapping)
               data_to_scale: a function that maps from data coordinates onto [0.0, 1.0], given the left and right bounds (defaults to lambda left, right, x: (x - left)/(right - left))
               scale_to_data: a function that maps from [0.0, 1.0] onto data coordinates (defaults to lambda left, right, x: left + (right - left)*x)
               on_change: a callback that is triggered whenever the values change.
               on_drag: a callback that is triggered whenever the slider is dragged, but the values are not yet set. If set_on_drag is True, then on_change is called instead"""

        self.left_pad = self.right_pad = 10
        self.top_pad = 5
        self.bottom_pad = 15
        self.set_on_drag = True

        self.left_bound = left_bound
        self.right_bound = right_bound
        self.round = round
        self.data_to_scale = data_to_scale
        self.scale_to_data = scale_to_data
        self.on_change = on_change
        self.on_drag = on_drag

        self.width = self.height = None
        self.bar = self.left_handle = self.right_handle = None

        Tk.Canvas.__init__(self, master, cnf)
        options = Tk._cnfmerge([cnf, kw])
        self.config(**options)
            
        if "height" not in cnf and "height" not in kw:
            self.config(height=16 + self.top_pad + self.bottom_pad)
        self.bind("<Configure>", self.resize)

    def config(self, **kw):
        if not kw:
            conf = Tk.Canvas.config(self)
            conf["left_padding"] = self.left_pad
            conf["right_padding"] = self.right_pad
            conf["top_padding"] = self.top_pad
            conf["bottom_padding"] = self.bottom_pad
            conf["left_bound"] = self.left_bound
            conf["right_bound"] = self.right_bound
            conf["round"] = self.round
            conf["data_to_scale"] = self.data_to_scale
            conf["scale_to_data"] = self.scale_to_data
            conf["set_on_drag"] = self.set_on_drag
            conf["on_change"] = self.on_change
            conf["on_drag"] = self.on_drag

            return conf

        if "left_padding" in kw:
            self.left_pad = kw.pop("left_padding")
        if "right_padding" in kw:
            self.right_pad = kw.pop("right_padding")
        
        if "top_padding" in kw:
            self.top_pad = kw.pop("top_padding")
        if "bottom_padding" in kw:
            self.bottom_pad = kw.pop("bottom_padding")
        
        
        if "set_on_drag" in kw:
            self.set_on_drag = kw.pop("set_on_drag")

        if "left_bound" in kw and "right_bound" in kw:
            left_bound, right_bound = kw.pop("left_bound"), kw.pop("right_bound")
            if left_bound > right_bound:
                left_bound, right_bound = right_bound, left_bound
            old_left = self.left_handle.value
            old_right = self.right_handle.value
            self.set(left=old_left, right=old_right)
            self.left_bound = left_bound
            self.right_bound = right_bound
        
        if "left_bound" in kw:
            raise NotImplementedError
        if "right_bound" in kw:
            raise NotImplementedError
        
        if "round" in kw:
            self.round = kw.pop("round")

        if "data_to_scale" in kw:
            self.data_to_scale = kw.pop("data_to_scale")
            self.left_handle.move_to(self.position_for(self.left_handle.value))
            self.right_handle.move_to(self.position_for(self.right_handle.value))

        if "scale_to_data" in kw:
            self.scale_to_data = kw.pop("scale_to_data")
            self.left_handle.move_to(self.position_for(self.left_handle.value))
            self.right_handle.move_to(self.position_for(self.right_handle.value))

        if "on_change" in kw:
            self.on_change = kw.pop("on_change")
        if "on_drag" in kw:
            self.on_drag = kw.pop("on_drag")

        Tk.Canvas.config(self, **kw)

    def make_handle(self, pos, tag=None):
        x, y = pos
        handle_coords = [(x-6, y), (x-6, y-10), (x, y-16), (x+6, y-10), (x+6,y)]
        main_handle = self.create_polygon(handle_coords, fill="SystemButtonFace", tags=tag)

        highlight_coords = [(x-5, y-1), (x-5, y-10), (x, y-15)]
        highlight = self.create_line(highlight_coords, fill="SystemButtonHighlight", tags=tag)

        shadow_coords = [(x-4, y), (x+6, y), (x+6, y-10), (x, y-16)]
        shadow = self.create_line(shadow_coords, fill="SystemButtonShadow", tags=tag)
        return SliderHandle(self, main_handle, tag)

    def init(self, width=None, height=None):
        "Initialize the slider's canvas with the given width and height"
        conf = self.config()
        width = width if width is not None else int(conf["width"][-1])
        height = height if height is not None else int(conf["height"][-1])

        self.resize((width, height))

    def resize(self, event, update_config=True):
        if isinstance(event, tuple):
            width, height = event
        else:
            width, height = event.width, event.height
            update_config = False
        if self.width is None or self.height is None:
            bar_options = dict(stipple="gray50", fill="White", outline="")
            self.bar = self.create_rectangle([(self.left_pad,height-16-self.bottom_pad),(width-self.right_pad, height-self.bottom_pad)],
                                             **bar_options)
            self.width, self.height = width, height
            if update_config:
                self.config(width=width, height=height)
            self.left_handle = self.make_handle((self.left_pad, height-self.bottom_pad), "LEFT_HANDLE")
            self.left_handle.value = self.left_bound
            self.left_handle.bind_mouse_events()
            self.right_handle = self.make_handle((width-self.right_pad, height-self.bottom_pad), "RIGHT_HANDLE")
            self.right_handle.value = self.right_bound
            self.right_handle.bind_mouse_events()
        else:
            if update_config:
                self.config(width=width, height=height)
            self.move(Tk.ALL, 0, height - self.height)
            corners = [self.left_pad, height-16-self.bottom_pad,
                       width-self.right_pad, height-self.bottom_pad]

            self.coords(self.bar, *corners)
            self.width, self.height = width, height
            self.set(left=self.left_handle.value, right=self.right_handle.value)
            

    def clamp(self, x):
        return max(self.left_pad, min(x, self.width-self.right_pad))

    def normalized(self, x):
        return (x - self.left_pad)/float(self.width - self.right_pad - self.left_pad)

    def get(self):
        "Returns the values of the left and right handles"
        return sorted((self.left_handle.value, self.right_handle.value))

    def bounds(self):
        "Returns the left and right bounds"
        return self.left_bound, self.right_bound

    def value_at(self, x):
        "Returns the value at the position x in canvas coordinates"
        return self.scale_to_data(self.left_bound, self.right_bound, self.normalized(self.clamp(x)))

    def position_for(self, value):
        "Returns the position x in canvas coordinates for the given value"
        norm = self.data_to_scale(self.left_bound, self.right_bound, value)
        return self.clamp(self.left_pad + norm * (self.width - self.left_pad - self.right_pad))

    def set(self, left=None, right=None):
        "Sets the position of the left and/or right handle"
        if self.left_handle.pos < self.right_handle.pos:
            self.left_handle, self.right_handle = self.right_handle, self.left_handle
        if left is not None:
            self.left_handle.move_to(self.position_for(left))
            self.left_handle.value = self.value_at(self.left_handle.pos)
        if right is not None:
            self.right_handle.move_to(self.position_for(right))
            self.right_handle.value = self.value_at(self.right_handle.pos)
        if left or right:
            self.notify_change()

    def reset(self):
        "Sets the left handle to the left bound and the right handle to the right bound"
        self.set(left=self.left_bound, right=self.right_bound)
            
    def notify_change(self):
        if self.on_change:
            self.on_change(*self.get())

    def notify_drag(self):
        if self.on_drag:
            self.on_drag(*self.get())

from matplotlib.pyplot import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.collections import LineCollection
from matplotlib.transforms import blended_transform_factory

class DoubleSliderTestApp:
    def __init__(self, width, height):
        self.root = Tk.Tk()
        self.root.wm_title("Double Slider Test")
        
        self.plot = Figure(figsize = (width+1, height+2), dpi=72)
        self.axes = self.plot.add_subplot(111)
        self.canvas = FigureCanvasTkAgg(self.plot, master=self.root)
        self.canvas.get_tk_widget().grid(row=0)

        self.nav_plot = Figure(figsize = (width+1, 2), dpi=72)
        self.nav_axes = self.nav_plot.add_subplot(111)
        self.nav_canvas = FigureCanvasTkAgg(self.nav_plot, master=self.root)
        self.nav_canvas.get_tk_widget().grid(row=1)
        self.nav_plot.subplots_adjust(bottom=0.2)

        self.agg_canvas = self.nav_canvas.get_tk_widget()

        self.slider = DoubleSlider(self.root, round=lambda x: round(x, 2),
                                   left_bound=2.0, right_bound=3.0)

        self.slider.grid(row=2, sticky=Tk.W+Tk.E+Tk.N+Tk.S)

        data = [(2.0, 0.6), (2.1, 0.9), (2.2, 0.7), (2.3, 0.8), (2.4, 0.5),
                (2.6, 0.2), (2.7, 0.3), (2.8, 0.6), (2.9, 0.4), (3.0, 0.1)]
        
        self.axes.set_xbound(2.0, 3.0)
        self.axes.add_collection(LineCollection([data]))

        self.nav_axes.set_xbound(2.0, 3.0)
        self.nav_axes.add_collection(LineCollection([data]))
        
    def run(self):
        self.plot.canvas.draw()
        self.nav_plot.canvas.draw()
        left_pad = self.nav_plot.subplotpars.left * self.nav_plot.get_figwidth() * self.nav_plot.dpi
        right_pad = (1-self.nav_plot.subplotpars.right) * self.nav_plot.get_figwidth() * self.nav_plot.dpi

        self.slider.config(left_padding=left_pad,
                           right_padding=right_pad)
        

        def update_limits(left, right):
            self.agg_canvas.delete("OVERLAY")
            trans = blended_transform_factory(self.nav_axes.transData,
                                              self.nav_axes.transAxes)

            corner1 = trans.transform_point([left, 1]).tolist()
            corner2 = trans.transform_point([self.slider.left_bound, 0]).tolist()
            self.agg_canvas.create_rectangle([corner1, corner2], stipple="gray25", fill="gray",tags="OVERLAY")

            corner3 = trans.transform_point((right, 1)).tolist()
            corner4 = trans.transform_point((self.slider.right_bound, 0)).tolist()
            self.agg_canvas.create_rectangle([corner3, corner4], stipple="gray25", fill="gray",tags="OVERLAY")
            
            self.axes.set_xbound(left, right)
            self.plot.canvas.draw()

        self.slider.config(on_change=update_limits)
        self.slider.init()
        
        self.root.mainloop()

if __name__ == "__main__":
    app = DoubleSliderTestApp(5, 5)
    app.run()
