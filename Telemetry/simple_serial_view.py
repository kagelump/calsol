import serial
import struct
import json
import glob
import os

START_BYTE = 0xE7
ESCAPE_BYTE = 0x75

START_CHAR = chr(START_BYTE)
ESCAPE_CHAR = chr(ESCAPE_BYTE)

serial_data = ''

def load_can_descriptors():
    "Looks for all of the *.can.json files and compiles them into a list of descriptors"
    desc_sets = []
    fnames = glob.glob(os.path.join("config", "*.can.json"))
    if not fnames:
        print "Warning, no CAN message description files found!"
    for fname in fnames:
        f = open(fname, "r")
        head, tail = os.path.split(fname)
        x = json.load(f)
        d = {}
        for str_id in x:
            d[int(str_id, 16)] = x[str_id]
        desc_sets.append((tail[:-9], d))
        f.close()
    return desc_sets

desc_sets = load_can_descriptors()


def readMessage():
    findStartChar()
    can_id, msg_len = getPreamble()
    for msg_src, id_dict in desc_sets:
        if can_id in id_dict:
            break
    else:
        print "Unknown can ID!: %x" % can_id
        return
    msg_type_data = id_dict[can_id]
    name = msg_type_data['name'] if 'name' in msg_type_data else None
    fmt = msg_type_data['format'] if 'format' in msg_type_data else None
    data = readData(msg_len)
    interpreted_data = ()
    if fmt:
        interpreted_data = struct.unpack(str("<"+fmt), data)
    
    printIndent("Message from %s" % msg_src, 0)
    printIndent("Message name: %s" % name, 2)
    if 'message' in msg_type_data:
        for m, int_datum in zip(msg_type_data['messages'], interpreted_data):
            printIndent(("%s: %d" % (m[0], int_datum)), 2)
    else:
        printIndent("Data: %s" % (interpreted_data,), 2)

def debug():
    findStartChar()
    can_id, msg_len = getPreamble()
    data = readData(msg_len)
    print msg_len, data

def printIndent(string, indent):
    print (indent * ' ' + string)

def getPreamble():
    preamble = readPreamble()
    preamble, = struct.unpack("<H", preamble)
    can_id = preamble >> 4
    msg_len = preamble & 0xF
    return can_id, msg_len

def readPreamble():
    preamble = read(2)
    return preamble

def read(len):
    s = ''
    for x in range(len):
        s += getNextByteStr()
    return s

def getNextByteStr():
    byteString = ser.read(1);
    byte, = struct.unpack("<B", byteString)
    if byte != ESCAPE_BYTE:
        return chr(byte)
    else:
        b, = struct.unpack("<B", ser.read(1))
        return chr(b ^ ESCAPE_BYTE)

def readData(length):
    return read(length)

def findStartChar():
    while read(1) != START_CHAR:
        pass

def hasCompleteMessage():
    startMessagePos = serial_data.find(START_CHAR)
    nextStartMessagePos = serial_data.find(START_CHAR, startMessagePos+1)
    return startMessagePos != nextStartMessagePos

def pollSerialData():
    serial_data += ser.read(10000)

if __name__ == '__main__':
    ser = serial.Serial(timeout=0)
    ser.baudrate = 115200
    ser.port = 'COM4'
    ser.bytesize = 8
    ser.parity = 'N'
    ser.stopbits = 1
    ser.open()
##    print    ser.read(100)
    while True:
#        pollSerialData()
#        if hasCompleteMessage():
            readMessage()
##        debug()
