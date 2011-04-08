import collections
import datetime
import operator
import bisect
import json

getx = operator.itemgetter(0)
gety = operator.itemgetter(1)

class GraphData:
    def __init__(self, initial=None):
        self.data = []
        self.total = 0
        self.peak = -2e308
        self.min = 2e308
        self.aveCounter = 0
        if initial:
            self.addPoints(initial)

    @property
    def x(self):
        return map(getx, self.data)

    @property
    def y(self):
        return map(gety, self.data)

    @property
    def y_bounds(self):
        if not self.data:
            return 0.0, 1.0
        diff = abs(self.peak - self.min)
        return self.min - diff * 0.10, self.peak + diff * 0.10
    
    def addPoint(self, point):
        if not self.data or point[0] >= self.data[-1][0]:
            self.data.append(point)
        else:
            bisect.insort(self.data, point)
        try:
            self.total += point[1]
            self.aveCounter += 1
            if point[1] > self.peak:
                self.peak = point[1]
            if point[1] < self.min:
                self.min = point[1]
        except TypeError:
            pass

    def addPoints(self, points):
        for point in points:
            self.addPoint(point)

    @property
    def average(self):
        if self.aveCounter != 0:
            return float(self.total) / self.aveCounter
        return 0.0

    def export(self):
        return self.data

    def filter(self, earliest=None, latest=None):
        if earliest is None:
            earliest = datetime.datetime.min
        if latest is None:
            latest = datetime.datetime.max

        if self.data and self.data[0][0] > earliest:
            del self.data[:bisect.bisect_left(self.data, (earliest, 0.0))]
        if self.data and self.data[-1][0] > latest:
            del self.data[bisect.bisect_right(self.data, (latest, 2e308)):]

    def clear(self):
        self.data = []

class XOMBIESQLIntervalView:
    query_template = ("SELECT time, data FROM data"
                      " WHERE id = ? AND name = ? AND"
                      " ? <= time AND time <= ? ORDER BY time;")
    def __init__(self, connection, id_, name, start=datetime.datetime.min, end=datetime.datetime.max):
        self.connection = connection
        self.id = str(int(id_, 16))
        self.name = name
        self.query = self.query_template

        self.peak = -2e308
        self.min = 2e308

        self.start = self.end = self.data = None
        self.load(start, end)

    @property
    def y_bounds(self):
        if not self.data:
            return 0.0, 1.0
        diff = abs(self.peak - self.min)
        return self.min - diff * 0.10, self.peak + diff * 0.10

    def __repr__(self):
        return "%s[%#x:%s:%r, %r]" % (self.__class__.__name__, self.id, self.name, self.start, self.end)

    def __iter__(self):
        return iter(self.data)

    def __len__(self):
        return len(self.data)

    def __nonzero__(self):
        return bool(self.data)

    def fetch(self, start, end):
        data = self.connection.execute(self.query, (self.id, self.name, start, end))
        for time, data_str in data:
            yield time, json.loads(data_str)
        return 

    def load(self, start, end):
        if start > end:
            start, end = end, start
        if start == self.start and end == self.end:
            return
        else:
            self.start = start
            self.end = end
            self.data = list(self.fetch(start, end))

            count = 0
            total = 0.0
            self.peak = -2e308
            self.min = 2e308
            for t, value in self.data:
                count += 1
                total += value
                if value > self.peak:
                    self.peak = value
                if value < self.min:
                    self.min = value
            self.average = total/count if count != 0 else 0.0

    def filter(self, earliest=None, latest=None):
        pass

    def clear(self):
        self.data = None
        self.peak = -2e308
        self.min = 2e308

        self.start = self.end = None
        

    @property
    def x(self):
        return map(getx, self.data)

    @property
    def y(self):
        return map(gety, self.data)

    def export(self):
        return self.data

class MinimalSQLIntervalView:
    query_template = "SELECT time, value FROM %s WHERE ? <= time AND time <= ? ORDER BY time;"
    def __init__(self, connection, table, start=datetime.datetime.min, end=datetime.datetime.max):
        self.connection = connection
        self.table = table
        self.query = self.query_template % self.table

        self.start = self.end = self.data = None
        self.load(start, end)

    def __repr__(self):
        return "%s[%r:%r, %r]" % (self.__class__.__name__, self.table, self.start, self.end)

    def __iter__(self):
        return iter(self.data)

    def __len__(self):
        return len(self.data)

    def __nonzero__(self):
        return bool(self.data)

    def fetch(self, start, end):
        return self.connection.execute(self.query, (start, end))

    def load(self, start, end):
        if start > end:
            start, end = end, start
        if start == self.start and end == self.end:
            return
        else:
            self.start = start
            self.end = end
            self.data = list(self.fetch(start, end))

            count = 0
            total = 0.0
            self.peak = 0
            for t, value in self.data:
                count += 1
                total += value
                if value > self.peak:
                    self.peak = value
            self.average = total/count if count != 0 else 0.0

    @property
    def x(self):
        return map(getx, self.data)

    @property
    def y(self):
        return map(gety, self.data)

    def export(self):
        return self.data

class SQLIntervalView(MinimalSQLIntervalView):
    def load(self, start, end):
        if start > end:
            start,end = end,start
        if start == self.start and end == self.end:
            return

        if not self.data or (start > self.end) or (end < self.start): #No overlap
            self.data = collections.deque(self.fetch(start, end))
        else:
            if start < self.start:
                added = list(self.fetch(start, self.start))
                self.data.extendleft(reversed(added))
            elif start > self.start and self.data:
                first = self.data.popleft()
                while first[0] < start and self.data:
                    first = self.data.popleft()
                if first[0] >= start:
                    self.data.appendleft(first)

            if end > self.end:
                added = self.fetch(self.end, end)
                self.data.extend(added)
            elif end < self.end and self.data:
                last = self.data.pop()
                while last[0] > end and self.data:
                    last = self.data.pop()
                if last[0] <= end:
                    self.data.append(last)

        count = 0
        total = 0.0
        self.peak = 0
        for t, value in self.data:
            count += 1
            total += value
            if value > self.peak:
                self.peak = value
        self.average = total/count if count != 0 else 0.0

    def export(self):
        return self

SQLIntervalView = MinimalSQLIntervalView
