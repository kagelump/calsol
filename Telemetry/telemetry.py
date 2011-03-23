import os, sys

import datetime
import glob
import math
import json
from Queue import Queue, PriorityQueue
import sqlite3 as sql

from PySide import QtGui, QtCore

from viewer import config

from viewer.ports import ask_for_port
from viewer.sample import XOMBIEDecoder, XOMBIEStream, DataSource
from viewer.util import link

from viewer.ViewWidget import TabViewContainer
from viewer.LiveGraph import LiveGraphTabView
from viewer.SignalWidget import SignalTreeWidget

def find_source(name):
    if app.xombie_thread.isRunning():
        return app.xombie_thread.stream.get_data(name)
    else:
        return DataSource(name)

class ConsoleLogger:
    """
    Implements minimal logging.logger functionality and displays to the console
    instead of writing to a file by putting messages into a queue which is
    periodically copied to the console.
    """
    def __init__(self, queue):
        self.queue = queue

    def info(self, msg, *args, **kwargs):
        formatted = (msg % kwargs) if kwargs else (msg % args)
        self.queue.put(formatted)

    def warning(self, msg, *args, **kwargs):
        formatted = (msg % kwargs) if kwargs else (msg % args)
        self.queue.put('<font color="orange">%s</font>' % formatted)

    def error(self, msg, *args, **kwargs):
        formatted = (msg % kwargs) if kwargs else (msg % args)
        self.queue.put('<font color="red">%s</font>' % formatted)

    def critical(self, msg, *args, **kwargs):
        formatted = (msg % kwargs) if kwargs else (msg % args)
        self.queue.put('<font color="red">%s</font>' % formatted)

class XOMBIEThread(QtCore.QThread):
    """
    Handles connecting to the Telemetry Board and pushing data to the queue
    On startup, it launches the additional asynchronous XOMBIEStream thread
    and collects data from it using callbacks.

    Data from the XOMBIEStream is immediately logged and periodically committed
    to disk. Separately, data queues are maintained on the stream for each
    signal, from which the XOMBIE thread pushes data to DataSource objects.

    instance variables:
        connection - the DB-API connection object for the SQLite database, which
                     we use to commit data as it is received.
        stream     - the XOMBIEStream which we collect data from
        sources     - really just DataSource.sources

        checking_heartbeat - indicates if we're waiting on a heartbeat response
        got_heartbeat      - indicates if we got a heartbeat response while we were waiting
        heartbeat_timer    - timer for one-shot five-second waiting for a response

        timer         - the main timer for XOMBIEStream event polling handling
        commit_timer  - the timer for periodic commits
        
    method summary:
        setup           - takes care of all thread-specific setup
        update_sources  - notifies all active DataSources to copy over data from
                          the stream and to notify their listeners
        process         - implements the core XOMBIE handling loop for associating,
                          replying to hearbeats, and collecting data

        check_heartbeat - callback to check if we got a heartbeat response to
                          our heartbeat request
        mark_heartbeat  - callback to record any heartbeat responses

        insert_data     - Adds a single data point to the database
        commit_data     - Commits data to the database
        shutdown        - Handles closing down the XOMBIEStream
    """
    shutdown_event_type = QtCore.QEvent.Type(QtCore.QEvent.registerEventType())
    def __init__(self, conn, stream, parent=None):
        QtCore.QThread.__init__(self, parent)
        self.stream = stream
        self.connection = conn

        self.timer = self.commit_timer = None
        
        link(self.started, self.setup)

    def setup(self):
        self.got_heartbeat = False
        self.checking_heartbeat = False
        self.heartbeat_timer = QtCore.QTimer()
        self.heartbeat_timer.setSingleShot(True)

        link(self.heartbeat_timer.timeout, self.check_heartbeat)
        
        self.timer = QtCore.QTimer()
        self.commit_timer = QtCore.QTimer()
        
        link(self.commit_timer.timeout, self.commit_data)
        link(self.timer.timeout, self.process)

        self.stream.add_callback(0x85, self.mark_heartbeat)
        self.stream.start()

        self.commit_timer.start(5000)
        self.timer.start(500)

    def process(self):
        """
        Handles one iteration of the XOMBIEStream processing.
        Overall plan:
            If we're not associated, try to associate
            If we are, read in data from the stream
            If we haven't heard anything for five seconds,
                send a heartbeat request to make sure that
                they're still there.
        """
        five_seconds = datetime.timedelta(seconds=5)
        if self.stream.state is XOMBIEStream.UNASSOCIATED:
            self.stream.send_handshake1()
            self.timer.setInterval(500)
            
        if self.stream.state is XOMBIEStream.ASSOCIATED:
            self.timer.setInterval(50)
            gap = datetime.datetime.utcnow() - self.stream.last_received
            if gap > five_seconds:
                if not self.checking_heartbeat:
                    self.checking_heartbeat = True
                    self.stream.logger.warning("Haven't received data packet since %s",
                                               self.stream.last_received.strftime("%H:%M:%S"))
                    self.stream.logger.warning("Sending heartbeat check")
                    
                    self.stream.send_no_ack("\x84")
                    self.heartbeat_timer.start(5000)
            else:
                cursor = self.connection.cursor()
                while not self.stream.msg_queue.empty():
                    id_, name, t, datum = self.stream.msg_queue.get_nowait()
                    self.insert_data(cursor, id_, name, t, datum)
                cursor.close()
                for source in self.stream.data_table.values():
                    source.pull()

    def check_heartbeat(self):
        if not self.got_heartbeat:
            self.stream.logger.error("Didn't hear a heartbeat response - disassociating.")
            self.stream.state = XOMBIEStream.UNASSOCIATED
        else:
            self.stream.logger.info("Got heartbeat response")
        self.got_heartbeat = False
        self.checking_heartbeat = False

    def mark_heartbeat(self):
        if self.checking_heartbeat:
            self.got_heartbeat = True

    def insert_data(self, cursor, id_, name, t, data):
        cmd = "INSERT INTO data(id, name, time, data) VALUES (?,?,?,?)"
        cursor.execute(cmd, (id_, name, t, json.dumps(data, ensure_ascii=False)))

    def commit_data(self):
        self.connection.commit()
    
    def event(self, evt):
        if evt.type() == self.shutdown_event_type:
            evt.accept()
            self.shutdown()
            return True
        else:
            return QtCore.QThread.event(self, evt)

    def shutdown(self):
        self.heartbeat_timer.stop()
        self.commit_timer.stop()
        self.timer.stop()
        
        if self.stream is not None:
            self.stream.close()
        
        self.quit()

def tableExists(conn, name):
    cur = conn.cursor()
    cur.execute('SELECT name FROM sqlite_master where name = ?;', (name,))
    exists = cur.fetchone() != None
    cur.close()
    return exists

class TelemetryApp(QtGui.QApplication):
    def setup(self):
        port = ask_for_port(os.path.join("config", "ports.cfg"))
        if port is None:
            self.start_thread = False
            print "Running in debug mode - no serial port connected"
        else:
            self.start_thread = True

        self.read_config()

        print "Logging to %s" % self.general_options["database"]
        self.connection = sql.connect(self.general_options["database"],
                                      detect_types=(sql.PARSE_DECLTYPES
                                                    | sql.PARSE_COLNAMES))

        self.config_database(self.connection, True)
        
        desc_sets = self.load_can_descriptors()
        decoder = XOMBIEDecoder([desc_set for (source, desc_set) in desc_sets])

        self.window = TelemetryViewerWindow(self, "Telemetry Viewer", desc_sets)

        if self.start_thread:
            stream = XOMBIEStream(port, decoder, self.window.logger,
                                  self.general_options["board_address"])
        else:
            stream = None
        self.xombie_thread = XOMBIEThread(self.connection, stream)
                
        link(self.lastWindowClosed, self.closeEvent)

    def run(self):
        if self.start_thread:
            self.xombie_thread.start()
            print "XOMBIE thread started"

        self.window.setup_tabs(self.tab_descs)
        self.window.show()
        
        return self.exec_()

    def config_database(self, conn, drop_tables=False):
        "Sets up the database with the intervals and data tables"
        cursor = conn.cursor()
        if tableExists(conn, "intervals") and drop_tables:
            cursor.execute("DROP TABLE intervals;")
        if not tableExists(conn, "intervals"):
            cursor.execute("CREATE TABLE intervals (name text, start timestamp, end timestamp);")

        if tableExists(conn, "data") and drop_tables:
            cursor.execute("DROP TABLE data;")
        if not tableExists(conn, "data"):
            cursor.execute("CREATE TABLE data (id integer, name text, time timestamp, data text);")
        conn.commit()
        cursor.close()

    def load_can_descriptors(self):
        "Looks for all of the *.can.json files and compiles them into a list of descriptors"
        desc_sets = []
        fnames = glob.glob(os.path.join("config", "*.can.json"))
        if not fnames:
            print "Warning, no CAN message description files found!"
        for fname in fnames:
            f = open(fname, "r")
            head, tail = os.path.split(fname)
            desc_sets.append((tail[:-9], json.load(f)))
            f.close()
        self.can_descriptors = desc_sets
        return desc_sets

    def read_config(self):
        self.general_options = config.find_options(os.path.join("config", "general.cfg"))
        try:
            f = open(os.path.join("config", "tabs.config.json"), "r")
            self.tab_descs = json.load(f)
        except BaseException as e:
            print "Error while loading tab config file: %s" % e
            self.tab_descs = [["New Tab", {"plots": [], "timescale": 30.0}]]

    def closeEvent(self, event=None):
        try:
            if self.xombie_thread.isRunning():
                print        "Sending shutdown signal...             ",
                shutdown = QtCore.QEvent(XOMBIEThread.shutdown_event_type)
                self.sendEvent(self.xombie_thread, shutdown)
                print "\r" + "Waiting for XOMBIE to shutdown         ",
                self.xombie_thread.wait()
                print "\r" + "XOMBIE shutdown successfully           "

            if self.connection is not None:
                print        "Commiting remaining data to disk       ",
                self.connection.commit()
                print "\r" + "Closing database connection...         ",
                self.connection.close()
                print "\r" + "SQLite connection shutdown successfully."
            
        finally:
            print "Writing configuration information to '%s'" % "tabs.config.json"
            f = open(os.path.join("config", "tabs.config.json"), "w+")
            json.dump(self.window.json_friendly(), f, indent=4)
            f.close()
            print "Telemetry Viewer shutdown successfully"
            self.quit()

class TelemetryViewerWindow(QtGui.QMainWindow):
    def __init__(self, application, title, desc_sets):
        QtGui.QMainWindow.__init__(self)

        self.title = title
        self.app = application
        self.setWindowTitle(title)


        self.icon_cache = {}

        self._ui_setup()
        self.tabWidget.setMovable(True)

        self.tabs = []
        
        #Take the CAN descriptions from the *.can.json files
        #and place them in the TreeWidget so that we can drag'n'drop them
        #to the main graph view
        self.canTreeWidget.add_descriptors(desc_sets)

        

        self.message_queue = Queue()
        self.logger = ConsoleLogger(self.message_queue)
        self.console_timer = QtCore.QTimer(self)
        self.redraw_timer = QtCore.QTimer(self)
        self.color_timer = QtCore.QTimer(self)

        link(self.console_timer.timeout, self.update_console)
        #link(self.color_timer.timeout, self.update_colors)
        link(self.redraw_timer.timeout, self.redraw)

        self.console_timer.start(50)
        self.redraw_timer.start(100)
        #self.color_timer.start(1000)


    def find_icon(self, name):
        if name in self.icon_cache:
            return self.icon_cache[name]
        else:
            try:
                icon = QtGui.QIcon(os.path.join("icons", name))
            except:
                return None
            self.icon_cache[name] = icon
            return icon

    def json_friendly(self):
        return [(self.tabWidget.tabText(i), self.tabWidget.widget(i).json_friendly())
                    for i in xrange(self.tabWidget.count())]

    def redraw(self):
        "Updates and redraws the active plot"
        now = datetime.datetime.utcnow()
        plot = self.tabWidget.currentWidget()
        if plot is not None:
            plot.update_view(now)
            plot.redraw()

    def _ui_setup(self):
        "Largely autogenerated layout code to setup interface"
        self.centralwidget = QtGui.QWidget(self)
        self.verticalLayout = QtGui.QVBoxLayout(self.centralwidget)
        
        self.vsplitter = QtGui.QSplitter(self.centralwidget)
        self.vsplitter.setOrientation(QtCore.Qt.Vertical)

        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Preferred, QtGui.QSizePolicy.Preferred)
        sizePolicy.setHorizontalStretch(1)
        sizePolicy.setVerticalStretch(1)
        sizePolicy.setHeightForWidth(self.vsplitter.sizePolicy().hasHeightForWidth())
        self.vsplitter.setSizePolicy(sizePolicy)

        self.hsplitter = QtGui.QSplitter(self.vsplitter)
        self.hsplitter.setOrientation(QtCore.Qt.Horizontal)
        
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Preferred, QtGui.QSizePolicy.Preferred)
        sizePolicy.setHorizontalStretch(1)
        sizePolicy.setVerticalStretch(1)
        sizePolicy.setHeightForWidth(self.hsplitter.sizePolicy().hasHeightForWidth())
        self.hsplitter.setSizePolicy(sizePolicy)

        self.canTreeWidget = SignalTreeWidget(self.hsplitter)
        self.canTreeWidget.setMinimumSize(QtCore.QSize(300, 300))
        self.canTreeWidget.setObjectName("canTreeWidget")
        self.tabWidget = TabViewContainer(self.hsplitter)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding, QtGui.QSizePolicy.Expanding)
        sizePolicy.setHorizontalStretch(1)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(self.tabWidget.sizePolicy().hasHeightForWidth())
        self.tabWidget.setSizePolicy(sizePolicy)
        self.tabWidget.setMinimumSize(QtCore.QSize(500, 300))
        self.tabWidget.setObjectName("tabWidget")

        self.hsplitter.addWidget(self.canTreeWidget)
        self.hsplitter.addWidget(self.tabWidget)

        #Debugging Console
        self.console = QtGui.QTextEdit(self.vsplitter)
        self.console.setReadOnly(True)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding, QtGui.QSizePolicy.Expanding)
        sizePolicy.setHorizontalStretch(0)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(self.console.sizePolicy().hasHeightForWidth())
        self.console.setSizePolicy(sizePolicy)
        self.console.setMinimumSize(QtCore.QSize(0, 100))
        self.console.setMaximumSize(QtCore.QSize(2000, 2000))
        self.console.setObjectName("console")

        self.vsplitter.addWidget(self.hsplitter)
        self.vsplitter.addWidget(self.console)

        self.setCentralWidget(self.centralwidget)
        self.centralwidget.setLayout(self.verticalLayout)
        self.verticalLayout.addWidget(self.vsplitter)
        
        self.menubar = QtGui.QMenuBar(self)
        self.menubar.setGeometry(QtCore.QRect(0, 0, 878, 19))
        self.menubar.setObjectName("menubar")
        self.menuFile = QtGui.QMenu(self.menubar)
        self.menuFile.setObjectName("menuFile")
        self.setMenuBar(self.menubar)
        self.toolBar = QtGui.QToolBar(self)
        self.toolBar.setObjectName("toolBar")

        self.toolBar.setToolButtonStyle(QtCore.Qt.ToolButtonIconOnly)

        self.makeTabIcon = self.find_icon("list-add.png")
        self.makeTabAction = QtGui.QAction(self.makeTabIcon, " ", self)
        link(self.makeTabAction.triggered, self.make_new_tab)

        self.makeTabButton = QtGui.QToolButton()
        self.makeTabButton.setDefaultAction(self.makeTabAction)
        self.toolBar.addWidget(self.makeTabButton)
        
        self.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar)
        #self.insertToolBarBreak(self.toolBar)

        self.cornerMakeTabButton = QtGui.QToolButton()
        self.cornerMakeTabButton.setDefaultAction(self.makeTabAction)
        self.cornerMakeTabButton.setToolButtonStyle(QtCore.Qt.ToolButtonIconOnly)

        self.tabWidget.setCornerWidget(self.cornerMakeTabButton,
                                       QtCore.Qt.TopLeftCorner)
        
        self.statusBar = QtGui.QStatusBar(self)
        self.statusBar.setObjectName("statusBar")
        self.setStatusBar(self.statusBar)

    def setup_tabs(self, descs):
        if not descs:
            return
        try:
            for [tab_name, desc] in descs:
                if desc["type"] == "live.graph":
                    new_tab = LiveGraphTabView(self.tabWidget, find_source)
                    new_tab.timescale = desc["timescale"]
                    for plot_desc in desc["plots"]:
                        plot = new_tab.add_plot([])
                        for (name, color, style) in plot_desc["signals"]:
                            plot.add_signal(name)
                        plot.autoscale = plot_desc["autoscale"]
                        plot.static = plot_desc["static"]
                        if plot_desc.get("title"):
                            plot.set_title(plot_desc["title"])
                        if plot_desc.get("units"):
                            plot.yaxis.set_label_text(plot_desc["units"])
                        y_min, y_max = plot_desc["yview"]
                        plot.yaxis.set_view_interval(y_min, y_max, ignore=True)
                        plot.yaxis.reset_ticks()

                icon = None
                if desc.get("icon") is not None:
                    icon = self.find_icon(desc.get("icon"))
                    if icon is None:
                        print "Warning: couldn't load icon '%s'" % icon
                
                if icon is not None:
                    self.tabWidget.addTab(new_tab, icon, tab_name)
                    new_tab.icon = desc.get("icon")
                else:
                    self.tabWidget.addTab(new_tab, tab_name)
                self.tabs.append(new_tab)
        except BaseException as e:
            print "Error occurred while setting up tabs from config file: %s" % e

    def update_console(self):
        "Pull any messages from the message queue and display them on the console"
        while not self.message_queue.empty():
            self.console.append(self.message_queue.get_nowait())
        self.update_colors()
        
    def make_new_tab(self):
        new_plot = LiveGraphTabView(self.tabWidget, find_source)
        self.tabWidget.addTab(new_plot, "A New Tab")
        self.tabWidget.setCurrentWidget(new_plot)
        self.tabs.append(new_plot)

    def update_colors(self):
        if not app.xombie_thread.isRunning():
            #self.color_timer.stop()
            return
        received_times = []
        for name, source in app.xombie_thread.stream.data_table.items():
            received_times.append((name, source.last_received))
        self.canTreeWidget.update_colors(received_times)

if __name__ == "__main__":
    app = TelemetryApp(sys.argv)
    app.setup()
    
    sys.exit(app.run())
    
