#Import the main PySide modules: QtGui and QtCore
#As you might guess, anything involving the GUI directly like widget classes
#is in QtGui, and anything involving core Qt functionality like event callbacks,
#(some enumerations), and date-time objects are in QtCore.
from PySide import QtGui, QtCore

class StrategyApplication(QtGui.QApplication):
    """
    Your main application should subclass QtGui.QApplication, which is the
    base class for applications with user-visible windows.

    You should override setup as your main point of customization based on
    command-line arguments, configuration files, or the number of white
    chocolate macadamia nut cookies remaining. There's not much point
    in overriding __init__ since there's not much reason to create more
    than one application from the same process.

    The application itself should probably avoid touching any gui code
    directly, and just take care of initializing the data that the
    program will need, setting up startup/close handlers, and setting
    up any special configuration for the main window.

    The main way that you'll run your program will look something like:
    if __name__ == "__main__":
        magically_process(sys.argv)
        magically_process(config_file)

        app = StrategyApplication(sys.argv)
        app.setup(number_of_macadamia_nut_cookies, config_info)

        sys.exit(app.run())
    """

    def setup(self):
        """
        Do any setup necessary before we launch the main window - reading
        in config files or precomputing values. You'll also probably create
        the StrategyWindow object and configure it here. Feel free to add more
        arguments to this method as necessary. Don't just put all of the
        code in this one method, though. Write helper functions as needed
        to keep the setup process understandable.
        """

        #Do some setup here
        self.main_window = StrategyWindow()
        self.main_window.setup()

        self.lastWindowClosed.connect(self.quit)
    

    def run(self):
        """
        Any code that needs to happen immediately before the program runs
        should go here. Things like making the main application window
        visible, starting side-computation threads, etc. At the end of the
        method, be sure to call and return the value of self.exec_() to tell
        PySide to start the main event loop for the entire application.
        """

        #Do something here

        self.main_window.show()

        return self.exec_()

class StrategyWindow(QtGui.QMainWindow):
    """
    This class will serve as the top-level container for your interface. Every
    widget that you create will in some way be contained within an instance of
    this class.

    I suggest keeping a reference to the main application so that you can
    access the application's instance variables instead of using globals,
    because it's harder to keep track of where global variables are initialized,
    and it also complicates moving large classes into their own modules.
    """
    def setup(self):
        """
        Do any interface specific setup here. This includes configuring your
        widgets, creating the widgets that define the structure of your
        interface, pre-populating widgets with data from the application,
        and setting up custom event handlers.
        """

        #Setup your widgets here. Make sure to add them to a layout object
        #otherwise they'll appear in random places.

        #Set the window title to something informative
        self.setWindowTitle("Cookie Strategy Optimizer")

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

        #Create a layout that fits your needs - probably a QFormLayout
        self.central_layout = QtGui.QHBoxLayout(self.central_widget)

        self.label = QtGui.QLabel("Strategy: Make more cookies")

        #Adds the label to the layout so that it can figure out where to
        #place it. If you forget to do this, it will just end up in the
        #top left corner.
        self.central_layout.addWidget(self.label)
        self.central_layout.setAlignment(self.label,
                                         QtCore.Qt.AlignLeft | QtCore.Qt.AlignTop)

        #Also important, tell the main widget to use the central_layout
        #to arrange its widgets and to implicitly act as a parent for
        #the widgets in the layout for event-handling purposes
        self.central_widget.setLayout(self.central_layout)

if __name__ == "__main__":
    import sys
    number_of_macadamia_nut_cookies = 5

    app = StrategyApplication(sys.argv)
    app.setup()

    sys.exit(app.run())
