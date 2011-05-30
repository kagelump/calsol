import datetime
import time
import traceback

from collections import defaultdict
from Queue import PriorityQueue

import serial

import math
import random
import struct
import json

from xbee import XBee

from GraphData import GraphData

class FilterByIDStream:
    def __init__(self, port):
        self.port = port
        self.data_table = defaultdict(PriorityQueue)
        self.time_table = {}
        self.buffer = ""

    def get_data(self, identifier):
        return self.data_table[identifier]

    def sample(self):
        self.buffer += self.port.read()
        while "\n" in self.buffer:
            datum, self.buffer = self.buffer.split("\n", 1)
            if not datum.strip("\r\n "):
                break
            try:
                ident, t, value = datum.split(",")
                if ident in self.time_table:
                    arduino_start, real_start = self.time_table[ident]
                    delta = datetime.timedelta(milliseconds=(int(t)-arduino_start))
                    adjusted_time = real_start + delta
                    self.data_table[ident].put((adjusted_time, float(value)))
                else:
                    real_start = datetime.datetime.utcnow()
                    arduino_start = int(t)
                    self.time_table[ident] = (arduino_start, real_start)
                    self.data_table[ident].put((real_start, float(value)))
            except BaseException as err:
                print "Error on line: '%s'" % datum.strip("\r\n")
                traceback.print_exc()

            self.buffer += self.port.read()

class SineDataStream:
    def __init__(self, timeout=None):
        self.timeout = timeout
        self.data_table = defaultdict(PriorityQueue)

    def sample(self):
        if self.timeout is not None:
            time.sleep(self.timeout)

    def get_data(self, identifier):
        now = datetime.datetime.utcnow()
        if identifier == "LDR1":
            self.data_table[identifier].put((now, 2.5 + 2.5*math.sin(time.time())));
        else:
            self.data_table[identifier].put((now, 2.5 + 2.5*math.sin(time.time()+math.pi/2)));
        return self.data_table[identifier]
class RandomDataStream:
    def __init__(self):
        self.data_table = defaultdict(PriorityQueue)
        self.last_data = defaultdict(lambda: 5.0*random.random())
        self.sample_time = datetime.datetime.utcnow()
    def sample(self):
        self.sample_time = datetime.datetime.utcnow()
    def get_data(self, identifier):
        value = self.last_data[identifier] + random.gauss(0.0, 0.5)
        bounded = min(max(value, 0.0), 5.0)
        self.data_table[identifier].put((self.sample_time, bounded))
        self.last_data[identifier] = bounded
        return self.data_table[identifier]

class DataSource(object):
    """
    DataSource acts as an abstract representation of the data source,
    though in reality it also pulls its data from the XOMBIE stream.
    Handles pushing data to possibly multiple listeners in a thread-safe manner.

    class variables:
        sources - a mapping from signal-names to all live data sources

    class methods:
        find - Either finds the existing data source for some signal name,
               or creates a new one for that signal

    instance variables:
        name  - the signal name that this data source tracks, in the format
                id-in-hex:message-name. For example, the identifier for
                the Tritium Motor Drive Command Motor current is
                "0x501:Motor Current"
        queue - the internal data queue that the data source uses to pull
                data from the stream in a thread-safe manner
        data  - the GraphData object that handles filtering (not used right now)
                and storing the data for use with collections

    method summary:
        push  - notifies all listeners that new data is pending and copies
                any data from the internal queue to the GraphData storage
        pull  - pulls all data from a queue into the internal data queue.
                Intended for initializing with accumulated data
    """
    def __init__(self, identifier, desc=None):
        self.name = identifier
        self.queue = PriorityQueue()
        self.data = GraphData([])
        self.descriptor = desc

        self.last_received = datetime.datetime(1993, 6, 20)

    def __hash__(self):
        return hash(self.name)

    def __eq__(self, other):
        return self.name == other.name

    def put(self, point):
        "Add data from the stream to the internal data queue"
        time, datum = point
        self.queue.put(point)
        self.last_received = max(self.last_received, time)

    def pull(self):
        "Adds all of the data from the stream's queue to its internal queue"
        while not self.queue.empty():
            self.data.addPoint(self.queue.get_nowait())

    def __repr__(self):
        return "DataSource(%r)" % self.name

class XOMBIEDecoder:
    """
    Handles reading and decoding XBee Omnidirectional Message Based
    Information Exchange (XOMBIE) messages from a serial port.

    There are two types of XOMBIE messages, command messages and data messages.
      * Command messages are concerned with establishing a connection with the
        Telemetry board, determining the relative-time-to-absolute-time offset,
        and other maintenance functions.

        Every command message will have the most significant bit set to 1
        to indicate that it is a command message.

      * Data messages carry the information from actual CAN messages, plus
        a 32-bit timestamp. Every data message will have the most significant
        bit set to 0 to indicate that it is a data message
    
        Format of XOMBIE data messages sent from the Telemetry board:
        Field: [0|ID|LEN|TIME|DATA]
        Size:   1 11  4   32  LEN*8

        The msb is always 0 for data messages, so that the ID can
        be read by zero-extending the first 12 bits.
        ID   is the 11-bit CAN ID corresponding to the original message
        LEN  is a 4-bit number giving the number of bytes in the payload
        TIME is a 4-byte timestamp giving the relative time in milliseconds
             from when the board powered on to when it received the message
        DATA is the actual payload from the message, ranging from 0-8 bytes

    Note: The compiler we use, AVR-GCC, uses little-endian conventions

    Handshake procedure:
    Laptop     --0x81-->       Board
    Board  --0x82+Timestamp--> Laptop
    Laptop     --0x83-->       Board

    Hearbeat check:
    Listener   --0x84-->       Sender
    Sender     --0x85-->       Listener
    """
    
    ID_MASK =  0xfff0
    LEN_MASK = 0x000f

    def __init__(self, mappings=None):
        self.descriptors = {}
        mappings = mappings if mappings else []
        for mapping in mappings:
            self.add_descriptors(mapping)

    def decode(self, msg):
        (x,) = struct.unpack("<B", msg[0])
        if x & (2**7) == 0:
            return self.decode_data(msg)
        else:
            return self.decode_command(msg)

    @staticmethod
    def is_command(msg):
        (x,) = struct.unpack("<B", msg[0])
        return (x & (2**7) != 0)

    def decode_command(self, msg):
        """
        Decodes a XOMBIE command message and returns a tuple of the command
        id and any values associated with it
        Command messages are identified by a one-byte ID, of which the MSB
        is always 1

        HANDSHAKE1 - The byte 0x81 optionally followed by the vehicle name
        HANDSHAKE2 - The byte 0x82 followed by the 4-byte time in ms
        HANDSHAKE3 - The byte 0x83

        HEARTSHAKE - the byte 0x84
        HEARTBEAT - the byte 0x85
        """
        (x,) = struct.unpack("<B", msg[0])
        if x & (2**7) == 0:
            raise ValueError("Expected a command message, got a data message instead")
        if x == 0x81:
            return (x, msg[1:])
        elif x == 0x82:
            return (x, struct.unpack("<L", msg[1:5]))
        elif x == 0x83:
            return (x,)
        elif x == 0x84:
            return (x,)
        elif x == 0x85:
            return (x,)
        elif x == 0xC2:
            return (x, list(struct.unpack("<90B", msg[1:])))
        elif x == 0xE2:
            return (x, [msg[1:]])
        else:
            raise ValueError("Unknown command message with id=%#x" % x)
    
    def decode_data(self, msg):
        """
        Decodes a XOMBIE data message carrying a CAN message and returns
        a tuple of (TIME, ID, DESC, DATA)
        where TIME is the relative time in milliseconds
              ID is the CAN ID as an integer
              DESC is the CAN message descriptor dictionary
              DATA is a tuple of data values from the message
        """
        if len(msg) < 6:
            raise ValueError("Data message is too short - minimum length 6 bytes, got %d bytes" % len(msg))

        (x, TIME) = struct.unpack("<HL", msg[0:6])

        if x & (2**15) != 0:
            raise ValueError("Expected a data message, found a command message instead")

        ID = (x & self.ID_MASK) >> 4
        LEN = x & self.LEN_MASK

        if LEN < 0 or LEN > 8:
            raise ValueError("Invalid CAN payload length - %d bytes not in [0,8] bytes" % LEN)
        
        if ID in self.descriptors:
            desc = self.descriptors[ID]
            if "format" not in desc:
                raise ValueError("No format specified for %#x:%s" % (ID, desc["name"]))
            if LEN != struct.calcsize("<" + str(desc["format"])):
                raise ValueError("Error in decoding message id=%#x name=%s - length field %d mismatches descriptor %d"
                                 % (ID, desc["name"], LEN, struct.calcsize("<" + str(desc["format"]))))

            DATA = struct.unpack("<" + str(desc["format"]), msg[6:6+LEN])
            
            return (TIME, ID, desc, DATA)
        else:
            raise ValueError("Unknown message id=%#x, time=%d, len=%d, data=%r" % (ID, TIME, LEN, msg[6:]))

    def decode_multi(self, msg):
        while msg:
            if len(msg) < 6:
                raise ValueError("Data message is too short - minimum length 6 bytes, got %d bytes" % len(msg))

            (x, TIME) = struct.unpack("<HL", msg[0:6])

            if x & (2**15) != 0:
                raise ValueError("Expected a data message, found a command message instead")

            ID = (x & self.ID_MASK) >> 4
            LEN = x & self.LEN_MASK

            if LEN < 0 or LEN > 8:
                raise ValueError("Invalid CAN payload length - %d bytes not in [0,8] bytes" % LEN)
            
            if ID in self.descriptors:
                desc = self.descriptors[ID]
                if LEN != struct.calcsize("<" + str(desc["format"])):
                    raise ValueError("Error in decoding message id=%#x name=%s - length field %d mismatches descriptor %d"
                                     % (ID, desc["name"], LEN, struct.calcsize("<" + str(desc["format"]))))

                DATA = struct.unpack("<" + str(desc["format"]), msg[6:6+LEN])
                
                yield (TIME, ID, desc, DATA)
                msg = msg[6+LEN:]
            else:
                raise ValueError("Unknown message id=%#x, time=%d, len=%d, data=%r" % (ID, TIME, LEN, msg[6:]))
            
    def add_descriptors(self, mapping):
        """
        Takes a dictionary mapping from string ID constants to message field data
        and adds it to the decoder's internal descriptor table.
        """
        for key, desc in mapping.iteritems():
            self.descriptors[int(key, 16)] = desc

class XOMBIEStream:
    """Handles the """
    ASSOCIATED = "ASSOCIATED"
    ASSOCIATING = "ASSOCIATING"
    UNASSOCIATED = "UNASSOCIATED"
    def __init__(self, port, decoder, logger, target_address, name="Train"):
        self.rel_start = None
        self.abs_start = None

        self.logger = logger
        self.decoder = decoder
        self.target_address = target_address

        self.port = port

        self.state = XOMBIEStream.UNASSOCIATED

        self.data_table = {}
        self.msg_queue = PriorityQueue()
        self.name = name
        self.next_frame_id = 1

        self.frame_cache = {}
        self.command_callbacks = {}
        self.last_received = None

        self.xbee = None
        self.rssi_average = None

    def start(self):
        self.xbee = XBee(self.port, callback=self.process, escaped=True)

    def at_command(self, command, parameter=None, callback=None):
        self.xbee.send("at",
                       command=command,
                       parameter=parameter,
                       frame_id=struct.pack(">B", self.next_frame_id))
        self.frame_cache[self.next_frame_id] = command, callback
        self.next_frame_id = (1 + self.next_frame_id) % 256

    def send_handshake1(self):
        "Send the first handshake message, 0x81 to connect to the board"
        self.send_no_ack("\x81" + self.name)

    def send_handshake3(self):
        "Send the third handshake message, 0x83 to confirm that we've connected to the board"
        self.send("\x83", callback=self.do_associate)

    def send(self, data, dest_addr=None, callback=None):
        "Send a packet to the destination using 64-bit addressing"
        dest_addr = dest_addr if dest_addr else self.target_address
        self.frame_cache[self.next_frame_id] = data, callback
        self.xbee.send("tx_long_addr", dest_addr=struct.pack(">q", dest_addr),
                                       frame_id= struct.pack(">B", self.next_frame_id),
                                       options=  struct.pack(">B", 0x00),
                                       data=     data)
        self.next_frame_id = (1 + self.next_frame_id) % 256

    def send_no_ack(self, data, dest_addr=None):
        "Send a packet to the destination using 64-bit addressing without requesting receipt acknowledgement"
        dest_addr = dest_addr if dest_addr else self.target_address
        self.xbee.send("tx_long_addr", dest_addr=struct.pack(">q", dest_addr),
                                       frame_id= struct.pack(">B", 0x00),
                                       options=  struct.pack(">B", 0x01),
                                       data=     data)

    def do_associate(self, frame):
        if frame["status"] == '\x00':
            if self.state is XOMBIEStream.ASSOCIATING:
                self.state = XOMBIEStream.ASSOCIATED
                self.logger.info("Now associated with XBee")
        else:
            self.state = XOMBIEStream.UNASSOCIATED

    def process(self, frame):
        print frame
        #print "\a"
        if frame["id"] == "rx_long_addr":
            alpha = 0.5
            rssi = -ord(frame["rssi"])
            if self.rssi_average is None:
                self.rssi_average = rssi
            else:
                self.rssi_average = self.rssi_average * (1-alpha) + rssi
            print "RSSI:" + str(rssi)
            self.last_received = datetime.datetime.utcnow()
            msg = frame["rf_data"]
            (source, ) = struct.unpack(">q", frame["source_addr"])
            if self.decoder.is_command(msg):
                try:
                    command = self.decoder.decode_command(msg)
                except ValueError as e:
                    self.logger.error("Error while decoding command packet: %s", e)
                    print frame
                    return
                if command[0] == 0x84:
                    self.logger.info("Got heartbeat request. Replying with heartbeat.")
                    if 0x84 not in self.command_callbacks or not self.command_callbacks[0x84]():
                        self.send_no_ack("\x85")
                    return
                elif command[0] == 0x85:
                    if 0x85 not in self.command_callbacks or not self.command_callbacks[0x85]():
                        pass  
                elif command[0] == 0x82:
                    self.state = XOMBIEStream.ASSOCIATING
                    self.rel_start = command[1][0]
                    self.abs_start = datetime.datetime.utcnow()
                    self.logger.info("Received handshake reply from XBee address=%#x synchronized at BRAIN time=%s, Laptop time=%s",
                                     source,
                                     self.rel_start,
                                     self.abs_start.strftime("%Y-%m-%d %H:%M:%S"))
                    if 0x82 not in self.command_callbacks or not self.command_callbacks[0x82]():
                        self.send_handshake3()
                elif command[0] in self.command_callbacks:
                    self.command_callbacks[command[0]](*command[1:])
                else:
                    self.logger.warning("Got irrelevant command message %#x", command[0])
                    pass
            else:
                if self.state is XOMBIEStream.UNASSOCIATED:
                    self.send_handshake1()
                elif self.state in (XOMBIEStream.ASSOCIATING, XOMBIEStream.ASSOCIATED):
                    if self.state is XOMBIEStream.ASSOCIATING:
                        self.state = XOMBIEStream.ASSOCIATED
                        self.logger.info("Now associated with XBee address=%#x", source)
                    try:
                        messages = list(self.decoder.decode_multi(msg))
                    except ValueError as e:
                        self.logger.error("Error while decoding data packet: %s", e)
                        self.logger.error(" ".join([str(hex(ord(b))) for b in msg]))
                        return
                    for (offset, id_, desc, data) in messages:
                        dt = datetime.timedelta(seconds=(offset - self.rel_start)/1000.0)
                        for msg_desc, datum in zip(desc["messages"], data):
                            ident = "%#x:%s" % (id_, msg_desc[0])
                            self.put_data(ident, (self.abs_start+dt, datum), msg_desc)
                            self.msg_queue.put((id_, msg_desc[0], self.abs_start+dt, datum))
                            #self.logger.info("Got packet %s = %s", ident, datum)
        elif frame["id"] == "tx_status" or "frame_id" in frame:
            (frame_id,) = struct.unpack(">B", frame["frame_id"])
            if frame_id in self.frame_cache:
                data, callback = self.frame_cache.pop(frame_id)
                if callback:
                    callback(frame)

    def put_data(self, identifier, datum, desc=None):
        if identifier not in self.data_table:
            self.data_table[identifier] = DataSource(identifier, desc)
        self.data_table[identifier].put(datum)

    def get_data(self, identifier):
        if identifier not in self.data_table:
            self.data_table[identifier] = DataSource(identifier)
        return self.data_table[identifier]

    def add_callback(self, id_, cb):
        self.command_callbacks[id_] = cb

    def close(self):
        "Shuts down the XBee processing thread and closes the serial port"
        self.xbee.halt()
        self.port.close()
    
if __name__ == "__main__":
    from ports import ask_for_port
    from time import sleep
    import sys
    import glob
    import logging
    
    desc_sets = []
    for fname in glob.glob("*.can.json"):
        f = open(fname, "r")
        desc_sets.append(json.load(f))
        f.close()

    port = ask_for_port("ports.cfg")
    if not port:
        sys.exit(0)
        
    decoder = XOMBIEDecoder(desc_sets)
    stream = XOMBIEStream(port, decoder, logging, 0x0013A20040621D3B)
    x = 0
    did_not_reply = False
    def mark_heartbeat():
        global did_not_reply
        did_not_reply = False

    stream.add_callback(0x85, mark_heartbeat)
    
    try:
        while True:
            try:
                while stream.state is XOMBIEStream.UNASSOCIATED:
                    stream.send_handshake1()
                    sleep(0.5)
                while stream.state is XOMBIEStream.ASSOCIATED:
                    if datetime.datetime.utcnow() - stream.last_received > datetime.timedelta(seconds=5):
                        logging.warning("Haven't received data packet since %s",
                                              stream.last_received.strftime("%H:%M:%S"))
                        logging.warning("Sending heartbeat check")
                        
                        stream.send_no_ack("\x84")
                        did_not_reply = True
                        for i in xrange(60):
                            sleep(0.1)
                            if not did_not_reply:
                                break
                        if did_not_reply:
                            logging.error("Didn't hear a heartbeat response - disassociating.")
                            stream.state = XOMBIEStream.UNASSOCIATED

            except KeyboardInterrupt:
                break
    finally:
        stream.close()
