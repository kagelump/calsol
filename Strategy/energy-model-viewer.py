#Import the main PySide modules: QtGui and QtCore
#As you might guess, anything involving the GUI directly like widget classes
#is in QtGui, and anything involving core Qt functionality like event callbacks,
#(some enumerations), and date-time objects are in QtCore.
from PySide import QtGui, QtCore
from Queue import Queue
import traceback

from raceStrategy import iter_dE, iter_V, calc_dE, calc_V

class EnergyModelApplication(QtGui.QApplication):
    """
    Implements an interface on top of our energy model for determining
    a speed policy to reach a certain change in energy over a time interval
    and determining the change in energy for a given speed policy.

    Policy evaluations are done in a separate thread to keep the main interface
    responsive.
    """

    def setup(self):
        """
        Setup the worker thread and main window.
        """

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
    job_finished = QtCore.Signal([object, object])
    def __init__(self, application):
        QtCore.QThread.__init__(self, application)
        self.app = application

    def _setup(self):
        """
        Does internal thread-specific setup. Any Qt objects should be created
        here so that they're parented to this thread, since _setup is called
        from this thread instead of the application thread.
        """
        
        self.quitting = False
        self.cancelled = False

        #Timer for scheduling when we do the next iteration of the current job
        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(lambda: self.process())

        self.queue = Queue()

        self.job = self.state = None

    def run(self):
        """
        Internal setup method called immediately before the event loop begins
        processing. Note that this will be called from this thread, rather than
        the application thread.
        """
        self._setup()
        self.timer.start(100)
        print "Starting worker thread"
        return self.exec_()

    def process(self):
        """
        Handle a single iteration of enqueuing, cancelling, dequeuing,
        and/or calculating a job computation.
        """

        #Check if we should terminate our timer so the thread can cleanly exit
        if self.quitting:
            self.timer.stop()
            return

        if self.cancelled:
            if self.job:
                print "Cancelled job"
            self.cancelled = False
            self.state = None
            self.job = None

        #If there are enqueued jobs and we aren't working on one right now,
        #we should get one from the queue and work on it.
        if self.job is None and not self.queue.empty():
            print "Starting new job"
            self.job = self.queue.get_nowait()

        if self.job is None:
            return

        #Setup the generator that will do the actual computations for our
        #current job, if we haven't already done so.
        if self.state is None:
            self.state = self.setup_job_state(self.job)

        cleanup = False
        done = False

        #Do a single iteration and possibly emit the result if we're done
        try:
            done, result = self.state.next()
        except StopIteration:
            print "Job failed to complete properly"
            cleanup = True
        except BaseException as exc:
            print "Error in executing job:"
            traceback.print_exc()
            cleanup = True

        if done:
            #Emit the job finished signal so that our consumer can make
            #use of the result.
            print "Finished job"
            self.job_finished.emit(self.job, result)
            cleanup = True

        if cleanup:
            self.job = None
            self.state = None

    def on_new_job(self, params):
        """
        Slot for job request signals.
        Just puts the job into the queue. process() will pull new jobs from
        the queue as soon as it finishes/cancels a job.
        """
        print "Enqueued job"
        self.queue.put(params)

    def on_cancel_job(self):
        """
        Slot for job cancellation signals.
        Just mark the current job as cancelled. In process(), we'll check if
        the job is cancelled and clean it up accordingly.
        """
        self.cancelled = True

    def shutdownEvent(self, evt):
        """
        Handler for shutdown events. Mark the thread for shutdown by
        setting quitting = True so that we can terminate the timer from
        this thread in our next call to process(), then block on terminating
        this thread.
        """
        
        print "Got shutdown signal"
        self.quitting = True
        self.quit()

    def event(self, evt):
        """
        Handle Qt events sent to this thread. We only care about shutdown
        events in particular, so we only process those and pass the rest
        to the super method.
        """
        if evt.type() == self.shutdown_event_type:
            evt.accept()
            self.shutdownEvent(evt)
            return True
        else:
            return QtCore.QThread.event(self, evt)

    def setup_job_state(self, job):
        """
        Handle setting up the correct job computation generator for the
        input job parameters.
        """
        #TODO, need to make sure lat/long aren't swapped anywhere.
        if job["type"] == "Energy":
            state =  iter_V(job["energy"],
                            job["start_latitude"],
                            job["start_longitude"],
                            0, #Altitude, but it gets ignored anyways
                            job["start_time"],
                            job["end_time"],
                            job["cloudy"])
        elif job["type"] == "Velocity":
            state = iter_dE(job["velocity"],
                            job["start_latitude"],
                            job["start_longitude"],
                            job["start_time"],
                            job["end_time"],
                            job["cloudy"])
        return state

class EnergyModelWindow(QtGui.QMainWindow):
    """
    EnergyModelWindow is the main window that is displayed to the user
    of the energy model viewer. It handles all of the main UI logic.
    """

    def __init__(self, application, *args, **kwargs):
        QtGui.QMainWindow.__init__(self, *args, **kwargs)
        self.app = application
    
    def setup(self):
        "General setup code that should be called before calling show"
        self.setup_ui()

        def on_submit(params):
            self.app.work_thread.on_new_job(params)
        
        self.vel_policy_widget.submitted.connect(on_submit)
        self.eng_policy_widget.submitted.connect(on_submit)

        def show_results(job, result):
            if job["type"] == "Velocity":
                print "Results for dE calculation w/params:"
                for k, v in sorted(job.items()):
                    if k != "type":
                        print "   ", k, "=", v
                print "Result: dE=%.1fJ" % result
            elif job["type"] == "Energy":
                print "Results for velocity calculation w/params:"
                for k, v in sorted(job.items()):
                    if k != "type":
                        print "   ", k, "=", v
                print "Result: average velocity=%.1fm/s" % result
        
        self.app.work_thread.job_finished.connect(show_results)

##        def on_cancel():
##            self.app.work_thread.on_cancel_job()
##
##        self.cancel_button.pressed.connect(on_cancel)

    def setup_ui(self):
        "Handles setting up all of the UI elements"

        #Set the window title to something informative
        self.setWindowTitle("Energy Model Policy Evaluator")

        #Create a central widget - just a widget to act as the main root
        #for everything else - this simplifies the layout.
        self.central_widget = QtGui.QWidget(self)

        #Setup the size policies so that it doesn't get super-squished.
        size_policy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                        QtGui.QSizePolicy.Expanding)
        size_policy.setHeightForWidth(self.central_widget.sizePolicy().hasHeightForWidth())
        size_policy.setHorizontalStretch(1)
        size_policy.setVerticalStretch(1)
        self.central_widget.setSizePolicy(size_policy)
        self.central_widget.setMinimumSize(QtCore.QSize(500, 400))
        self.setMinimumSize(QtCore.QSize(500, 400))
        

        #Setup the layout for the two side-by-side policy forms.
        self.central_layout = QtGui.QHBoxLayout(self.central_widget)

        self.vel_policy_widget = VelocityPolicyForm(self.central_widget)        
        self.central_layout.addWidget(self.vel_policy_widget)
        
        self.eng_policy_widget = EnergyPolicyForm(self.central_widget)        
        self.central_layout.addWidget(self.eng_policy_widget)

        self.central_layout.setAlignment(self.vel_policy_widget,
                                         QtCore.Qt.AlignLeft | QtCore.Qt.AlignTop)
        self.central_layout.setAlignment(self.eng_policy_widget,
                                         QtCore.Qt.AlignLeft | QtCore.Qt.AlignTop)

        size_policy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                        QtGui.QSizePolicy.Expanding)
        size_policy.setHeightForWidth(self.vel_policy_widget.sizePolicy().hasHeightForWidth())
        size_policy.setHorizontalStretch(1)
        size_policy.setVerticalStretch(1)
        self.vel_policy_widget.setSizePolicy(size_policy)

        size_policy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding,
                                        QtGui.QSizePolicy.Expanding)
        size_policy.setHeightForWidth(self.eng_policy_widget.sizePolicy().hasHeightForWidth())
        size_policy.setHorizontalStretch(1)
        size_policy.setVerticalStretch(1)
        self.eng_policy_widget.setSizePolicy(size_policy)
        
        self.central_widget.setLayout(self.central_layout)

class VelocityPolicyForm(QtGui.QGroupBox):
    """
    Form that handles setting the parameters for evaluating a fixed velocity
    policy. That is, it handles the input boxes for finding the energy spent
    if the car travels at a constant velocity for some time.
    """
    submitted = QtCore.Signal(object)
    def __init__(self, parent=None):
        QtGui.QGroupBox.__init__(self, "Evaluate Velocity Policy", parent)

        self._setup(),

        self.start_latitude.setValue(  -12.45668)
        self.start_longitude.setValue(130.83705)
        self.goal_velocity.setValue(50)

        self.button.pressed.connect(lambda: self.handle_submit())

    def _setup(self):
        self.layout = QtGui.QFormLayout(self)

        self.goal_velocity = QtGui.QDoubleSpinBox(self)
        self.goal_velocity.setRange(0.0, 120.0)
        self.goal_velocity.setDecimals(1)
        #TODO: find out what the units are supposed to be
        self.goal_velocity.setSuffix("m/s")

        self.start_latitude = QtGui.QDoubleSpinBox(self)
        self.start_longitude = QtGui.QDoubleSpinBox(self)
        self.start_latitude.setRange(-90.0, 90.0)
        self.start_longitude.setRange(-180.0, 180.0)
        self.start_latitude.setDecimals(6)
        self.start_longitude.setDecimals(6)

        self.start_time = QtGui.QTimeEdit(self)
        self.end_time   = QtGui.QTimeEdit(self)
        
        self.cloudiness = QtGui.QDoubleSpinBox(self)
        self.cloudiness.setDecimals(2)
        self.cloudiness.setRange(0.0, 1.0)
        self.cloudiness.setSingleStep(0.01)

        self.button = QtGui.QPushButton("Evaluate", self)
        
        self.layout.addRow("Average Velocity", self.goal_velocity)
        self.layout.addRow("Start Latitude", self.start_latitude)
        self.layout.addRow("Start Longitude", self.start_longitude)
        self.layout.addRow("Start Time", self.start_time)
        self.layout.addRow("End Time", self.end_time)
        self.layout.addRow("Cloudiness", self.cloudiness)
        self.layout.addRow(self.button)
        
        self.setLayout(self.layout)

    def handle_submit(self):
        params = {}
        params["type"] = "Velocity"
        params["velocity"] = self.goal_velocity.value()
        params["start_latitude"] = self.start_latitude.value()
        params["start_longitude"] = self.start_longitude.value()
        params["start_time"] = self.start_time.time().toString("HH:mm")
        params["end_time"] = self.end_time.time().toString("HH:mm")
        params["cloudy"] = self.cloudiness.value()

        self.submitted.emit(params)

class EnergyPolicyForm(QtGui.QGroupBox):
    """
    Form that handles setting the parameters for evaluating a fixed velocity
    policy. That is, it handles the input boxes for finding the energy spent
    if the car travels at a constant velocity for some time.
    """
    
    submitted = QtCore.Signal(object)
    def __init__(self, parent=None):
        QtGui.QGroupBox.__init__(self, "Evaluate Energy Policy", parent)

        self._setup()

        self.start_latitude.setValue( -12.447305)
        self.start_longitude.setValue(130.781250)
        self.goal_energy.setValue(50)

        self.button.pressed.connect(lambda: self.handle_submit())

    def _setup(self):
        self.layout = QtGui.QFormLayout(self)

        self.goal_energy = QtGui.QDoubleSpinBox(self)
        self.goal_energy.setRange(0.0, 120.0)
        self.goal_energy.setDecimals(1)
        #TODO: find out what the units are supposed to be
        self.goal_energy.setSuffix("J")

        self.start_latitude = QtGui.QDoubleSpinBox(self)
        self.start_longitude = QtGui.QDoubleSpinBox(self)
        self.start_latitude.setRange(-90.0, 90.0)
        self.start_longitude.setRange(-180.0, 180.0)
        self.start_latitude.setDecimals(6)
        self.start_longitude.setDecimals(6)

        self.start_time = QtGui.QTimeEdit(self)
        self.end_time   = QtGui.QTimeEdit(self)
        
        self.cloudiness = QtGui.QDoubleSpinBox(self)
        self.cloudiness.setDecimals(2)
        self.cloudiness.setRange(0.0, 1.0)
        self.cloudiness.setSingleStep(0.01)

        self.button = QtGui.QPushButton("Evaluate", self)
        
        self.layout.addRow("Goal dEnergy", self.goal_energy)
        self.layout.addRow("Start Latitude", self.start_latitude)
        self.layout.addRow("Start Longitude", self.start_longitude)
        self.layout.addRow("Start Time", self.start_time)
        self.layout.addRow("End Time", self.end_time)
        self.layout.addRow("Cloudiness", self.cloudiness)
        self.layout.addRow(self.button)
        
        self.setLayout(self.layout)

    def handle_submit(self):
        params = {}
        params["type"] = "Energy"
        params["energy"] = self.goal_energy.value()
        params["start_latitude"] = self.start_latitude.value()
        params["start_longitude"] = self.start_longitude.value()
        params["start_time"] = self.start_time.time().toString("HH:mm")
        params["end_time"] = self.end_time.time().toString("HH:mm")
        params["cloudy"] = self.cloudiness.value()

        self.submitted.emit(params)

if __name__ == "__main__":
    import sys

    #Create the application and run it
    app = EnergyModelApplication(sys.argv)
    app.setup()

    sys.exit(app.run())
