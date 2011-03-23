import glob
import Tkinter


import config
from config import PortDescriptor
import serial

def scan_ports():
    found = set()
    for name in (range(256) + glob.glob("/dev/ttyS*") + glob.glob("/dev/ttyUSB*")):
        try:
            s = serial.Serial(name)
            if not s.portstr in found:
                yield s.portstr
            found.add(s.portstr)
            s.close()
        except serial.SerialException:
            continue

class PortSelectorApp:
    def __init__(self, port_descs, root=None):
        self.portmap = dict((desc.name, desc) for desc in port_descs)
        self.portlist = list(scan_ports())

        self.root = root if root is not None else Tkinter.Tk()
        self.root.wm_title("Source selector")
        Tkinter.Label(self.root, text="Pick input source").pack()

        self.lb = Tkinter.Listbox(self.root, selectmode=Tkinter.BROWSE)
        self.lb.pack()
        self.lb.insert(Tkinter.END, "No Arduino")

        for portstr in self.portlist:
            self.lb.insert(Tkinter.END, portstr)

        Tkinter.Button(self.root, text="OK", command=self.update_source).pack()
        self.lb.bind("<Double-Button-1>", self.update_source)
        self.port = None

    def update_source(self, *args):
        index = int(self.lb.curselection()[0])
        if index == 0: #"No Arduino" selected
            self.port = None
        else:
            name = self.portlist[index-1]
            if name in self.portmap:
                desc = self.portmap[name]
            else:
                desc = PortDescriptor.default_descriptor(name, {})
                
            print "Using port %s, %dBd" % (desc.name, desc.baudrate)
            self.port = desc.instantiate(serial.Serial)
        self.close()

    def run(self):
        self.root.mainloop()

    def close(self):
        self.root.destroy()

def ask_for_port(config_file):
    port_descs = config.find_ports(config_file)
    app = PortSelectorApp(port_descs)
    app.run()
    return app.port

if __name__ == "__main__":
    port = ask_for_port("ports.cfg")
    if port:
        print "Picked %s" % port.portstr
    else:
        print "Picked 'No arduino'"
