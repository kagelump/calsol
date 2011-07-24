import ConfigParser
from copy import deepcopy
import traceback

class OrderedDict(dict):
    def __init__(self):
        self._keys = []
    def items(self):
        return [self[key] for key in self._keys]
    def keys(self):
        return self._keys[:]
    def __setitem__(self, key, value):
        if key not in self._keys:
            self._keys.append(key)
        dict.__setitem__(self, key, value)

    def __delitem__(self, key):
        if key in self._keys:
            self._keys.remove(key)
        dict.__delitem__(self, key)

try:
    from collections import OrderedDict #Requires Python 2.7+
except ImportError:
    pass

class DescriptorParserError(RuntimeError):
    def __init__(self, tb):
        self.traceback = tb

class MissingFieldsError(ValueError):
    pass

class Descriptor:
    fields = {}
    defaults = {}
    optional = []
    def __init__(self, name, config):
        self.name = name
        self.config = config

    @classmethod
    def from_config(cls, parser, section, local_defaults, allow_missing=False):
        config = {}
        
        for option in parser.options(section):
            data = parser.get(section, option)
            if option in cls.fields:
                data_constructor = cls.fields[option]
                try:
                    config[option] = data_constructor(data)
                except:
                    message = "Error in parsing option %s = %s in section %s"
                    print message % (option, data, section)
                    if option in local_defaults or option in cls.defaults:
                        if option in local_defaults:
                            fallback = deepcopy(local_defaults[option])
                        else:
                            fallback = deepcopy(cls.defaults[option])
                        print "Using default of %s instead" % fallback
                        config[option] = fallback
                        traceback.print_exc()
                    else:
                        trace = traceback.extract_stack()
                        raise DescriptorParserError(trace)
            else:
                config[option] = data

        for option in local_defaults:
            if option not in config:
                config[option] = deepcopy(local_defaults[option])
        
        for option in cls.defaults:
            if option not in config:
                config[option] = deepcopy(cls.defaults[option])        

        missing = [option for option in cls.fields if not option in cls.optional and not option in config]
        if missing and not allow_missing:
            message = "Missing the following fields in section %s: %s" % (section, missing)
            raise MissingFieldsError(message)

        return cls(section, config)

    @classmethod
    def default_descriptor(cls, name, fields):
        config = deepcopy(cls.defaults)
        config.update(fields)
        return cls(name, config)

    def instantiate(self, cls, *args, **kwargs):
        raise NotImplementedError

    def __nonzero__(self):
        return True

    def __repr__(self):
        return "%s(%s, %r)" % (self.__class__.__name__, self.name, self.config)

    def __getattr__(self, name):
        return self.config[name]
    
class PortDescriptor(Descriptor):
    fields = {
        "baudrate": int,
        "timeout": float,
        "xonxoff": bool,
        "rtscts": bool}
    defaults = {
        #"baudrate": 115200,
        "baudrate": 57600,
        "timeout": 0
    }
    optional = ["xonxoff", "rtscts"]
    
    def instantiate(self, cls, **kwargs):
        config = self.config.copy()
        config.update(kwargs)

        obj = cls(self.name)
        for option, value in config.items():
            setattr(obj, option, value)

        return obj

class GraphDescriptor(Descriptor):
    fields = {
        "width": float,
        "height": float,
        "min_y": float,
        "max_y": float,
        "y_tick": float,
        "x_tick": float,
        "id": str,
        "title": str,
        "table_name": str,
        "units": str}
    optional = []
    
    def instantiate(self, cls, parent, **kwargs):
        config = self.config.copy()
        config.update(kwargs)

        graph = cls(config["width"], config["height"], parent,
                    config["id"], config["table_name"])

        graph.figure.suptitle(config["title"])

        y_ticks = list(self.make_ticks(config["min_y"],
                                       config["max_y"],
                                       config["y_tick"]))
        graph.axes.set_yticks(y_ticks)
        if "y_units" in config:
            graph.axes.set_ylabel(config["y_units"])
        if "x_units" in config:
            graph.axes.set_xlabel(config["x_units"])


        x_ticks = list(self.make_ticks(config["min_y"],
                                       config["max_y"],
                                       config["y_tick"]))
        graph.axes.set_xticks(y_ticks)

        return graph

    @staticmethod
    def make_ticks(start, stop, step):
        x = start
        while x <= stop:
            yield x
            x += step


def find_ports(filename):
    parser = ConfigParser.RawConfigParser(dict_type=OrderedDict)
    if not parser.read([filename]):
        raise IOError("Couldn't read config file %s" % filename)

    if parser.has_section("PORT-DEFAULTS"):
        defaults = PortDescriptor.from_config(parser, "PORT-DEFAULTS", {}, allow_missing=True).config

    descriptors = []
    for section in parser.sections():
        if section == "PORT-DEFAULTS":
            continue
        try:
            config = PortDescriptor.from_config(parser, section, defaults)
            descriptors.append(config)
        except DescriptorParserError as e:
            print "Skipping port %s" % section
            traceback.print_tb(e.traceback)
        except MissingFieldsError as e:
            print e
            print "Skipping port %s" % section
    return descriptors

def find_graphs(filename):
    parser = ConfigParser.RawConfigParser(dict_type=OrderedDict)
    if not parser.read([filename]):
        raise IOError("Couldn't read config file %s" % filename)

    if parser.has_section("GRAPH-DEFAULTS"):
        defaults = GraphDescriptor.from_config(parser, "GRAPH-DEFAULTS", {}, allow_missing=True).config
    
    descriptors = []
    for section in parser.sections():
        if section == "GRAPH-DEFAULTS":
            continue
        try:
            config = GraphDescriptor.from_config(parser, section, defaults)
            descriptors.append(config)
        except DescriptorParserError as e:
            print "Skipping graph %s" % section
            traceback.print_tb(e.traceback)
        except MissingFieldsError as e:
            print e
            print "Skipping port %s" % section
    return descriptors

def find_options(filename):
    parser = ConfigParser.RawConfigParser(dict_type=OrderedDict)
    if not parser.read([filename]):
        raise IOError("Couldn't read config file %s" % filename)
    
    options = {}
    for section in parser.sections():
        for key,value in parser.items(section):
            options[key] = value
    options["board_address"] = int(options["board_address"], 16)
    
    return options
