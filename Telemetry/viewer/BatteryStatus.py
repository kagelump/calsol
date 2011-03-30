from matplotlib.figure import Figure
from PySide import QtGui, QtCore

from backend_pysideagg import FigureCanvasQTAgg as FigureCanvas
from ViewWidget import BaseTabViewWidget

from util import link

class BatteryScatterPlotTabView(BaseTabViewWidget):
    view_name = "Live Battery Status View"
    view_id   = "live.battery.scatter"
    view_icon = "battery.png"
    view_desc = ("An overview of battery status information visualized"
                 " on a scatterplot of voltage vs temperature")
