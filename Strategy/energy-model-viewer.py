#Import the main PySide modules: QtGui and QtCore
#As you might guess, anything involving the GUI directly like widget classes
#is in QtGui, and anything involving core Qt functionality like event callbacks,
#(some enumerations), and date-time objects are in QtCore.
from PySide import QtGui, QtCore

class EnergyModelApplication(QtGui.QApplication):
    """
    Implements an interface on top of our energy model for determining
    a speed policy to reach a certain change in energy over a time interval
    and determining the change in energy for a given speed policy.
    """

    def setup(self):
        """
        Setup the worker thread and main window.
        """

        #Do some setup here

        self.work_thread = EnergyModelEvaluationThread(self)
        
        self.main_window = EnergyModelWindow(self)
        self.main_window.setup()

        self.lastWindowClosed.connect(self.handleClose)
    

    def run(self):
        """
        Start the worker thread that handles energy/velocity policy evaluation
        and the main window that controls it.
        """

        self.main_window.show()
        self.work_thread.start()
        
        return self.exec_()

    def handleClose(self):
        """
        When the main window is closed, ensure that we also terminate the
        worker thread.
        """

        #Send the shutdown notification, then wait until the thread shuts down
        print "Sending shutdown signal"
        if self.work_thread.isRunning():
            shutdown = QtCore.QEvent(EnergyModelEvaluationThread.shutdown_event_type)
            self.sendEvent(self.work_thread, shutdown)

        print "Waiting for worker thread"
        self.work_thread.wait()
        print "Closing complete"
        self.quit()

class EnergyModelEvaluationThread(QtCore.QThread):
    """
    Handles incrementally evaluating a policy for a particular setup. Emits
    job_finished with a dictionary of the results when it finishes a job.
    Emit a signal connected to the on_new_job slot to cancel the current job
    and start a new job.
    """

    shutdown_event_type = QtCore.QEvent.Type(QtCore.QEvent.registerEventType())
    job_finished = QtCore.Signal(object)
    def __init__(self, application):
        QtCore.QThread.__init__(self, application)
        self.app = application

    def _setup(self):
        self.quitting = False

        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(lambda: self.process())

        self.baked = 0
        self.goal = 0

    def run(self):
        self._setup()
        self.timer.start(100)
        print "Starting worker thread"
        return self.exec_()

    def process(self):
        if self.quitting:
            self.timer.stop()
            return
        
        if self.baked >= self.goal:
            return

        print "Baking cookie number %s" % (self.baked + 1)
        self.baked += 1

        if self.baked == self.goal:
            self.job_finished.emit(self.baked)
            self.baked = 0
            self.goal = 0

    def on_new_job(self, job_parameters):
        print "Got baking request!"
        self.goal = job_parameters["quantity"]

    def shutdownEvent(self, evt):
        print "Got shutdown signal"
        self.quitting = True
        self.quit()

    def event(self, evt):
        if evt.type() == self.shutdown_event_type:
            evt.accept()
            self.shutdownEvent(evt)
            return True
        else:
            return QtCore.QThread.event(self, evt)

class EnergyModelWindow(QtGui.QMainWindow):
    """
    This class will serve as the top-level container for your interface. Every
    widget that you create will in some way be contained within an instance of
    this class.

    I suggest keeping a reference to the main application so that you can
    access the application's instance variables instead of using globals,
    because it's harder to keep track of where global variables are initialized,
    and it also complicates moving large classes into their own modules.
    """

    got_baking_request = QtCore.Signal(object)
    def __init__(self, application, *args, **kwargs):
        QtGui.QMainWindow.__init__(self, *args, **kwargs)
        self.app = application
    
    def setup(self):
        """
        Do any interface specific setup here. This includes configuring your
        widgets, creating the widgets that define the structure of your
        interface, pre-populating widgets with data from the application,
        and setting up custom event handlers.
        """
        self.setup_ui()

        def bake_cookies():
            self.got_baking_request.emit({"quantity": 12})

        self.got_baking_request.connect(self.app.work_thread.on_new_job)
        self.button.pressed.connect(bake_cookies)

    def setup_ui(self):
        #Setup your widgets here. Make sure to add them to a layout object
        #otherwise they'll appear in random places.

        #Set the window title to something informative
        self.setWindowTitle("Energy Model Policy Evaluator")

        #Create a central widget - just a widget to act as the main root
        #for everything else - this simplifies the layout.
        self.central_widget = QtGui.QWidget(self)

        #Setup the size policy so that the window can expand
        #QtSizePolicy.Preferred tells Qt that we want the widget (the window,
        #in this case) to be around this size when possible, but that it's
        #okay to make it expand or shrink. It appears once for each dimension.
        size_policy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                        QtGui.QSizePolicy.Expanding)
        size_policy.setHorizontalStretch(1)
        size_policy.setVerticalStretch(1)
        self.central_widget.setSizePolicy(size_policy)
        self.central_widget.setMinimumSize(QtCore.QSize(300, 200))
        self.central_widget.setMaximumSize(QtCore.QSize(300, 200))

        #Create a layout that fits your needs - probably a QFormLayout
        self.central_layout = QtGui.QVBoxLayout(self.central_widget)

        self.label = QtGui.QLabel("Strategy: Make more cookies")
        self.button = QtGui.QPushButton("Make more!")

        #Adds the label to the layout so that it can figure out where to
        #place it. If you forget to do this, it will just end up in the
        #top left corner.
        self.central_layout.addWidget(self.label)
        self.central_layout.setAlignment(self.label,
                                         QtCore.Qt.AlignLeft | QtCore.Qt.AlignTop)
        self.central_layout.addWidget(self.button)
        self.central_layout.setAlignment(self.button,
                                         QtCore.Qt.AlignLeft | QtCore.Qt.AlignTop)

        #Also important, tell the main widget to use the central_layout
        #to arrange its widgets and to implicitly act as a parent for
        #the widgets in the layout for event-handling purposes
        self.central_widget.setLayout(self.central_layout)

if __name__ == "__main__":
    import sys
    number_of_macadamia_nut_cookies = 5

    app = EnergyModelApplication(sys.argv)
    app.setup()

    sys.exit(app.run())
