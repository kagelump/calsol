import datetime

from matplotlib import ticker
from matplotlib.collections import LineCollection
import matplotlib.dates as mdates

import numpy as np
import matplotlib.path as mpath

to_ordinal = mdates._to_ordinalf
class UTC(datetime.tzinfo):
    def utcoffset(self, dt):
        return datetime.timedelta(0)

    def tzname(self, dt):
        return "UTC"

    def dst(self, dt):
        return datetime.timedelta(0)

utc = UTC()

def from_ordinal(x):
    return mdates._from_ordinalf(x).astimezone(utc).replace(tzinfo=None)

def from_timestamp(s):
    return datetime.datetime.strptime(s, "%Y-%m-%d %H:%M:%S.%f")

possible_time_intervals = [21600,   #6 hours
                           14400,   #4 hours
                           10800,   #3 hours
                           7200,    #2 hours
                           3600,    #1 hour
                           1800,    #30 min
                           1200,    #20 min
                           900,     #15 min
                           600,     #10 min
                           300,     #5 min
                           120,     #2 min
                           60,      #1 min
                           30,
                           20,
                           15,
                           10,
                           5,
                           2,
                           1]



def find_aligned_datetime_before(dt, s):
    """Returns a datetime object immediately before dt aligned by s seconds"""
    
    total_seconds = dt.hour * 3600 + dt.minute * 60 + dt.second
    leftover_seconds = total_seconds % s
    td = datetime.timedelta(seconds = leftover_seconds, microseconds = dt.microsecond)
    new_dt = dt - td
    return new_dt
    
def find_aligned_datetime_after(dt, s):
    """Returns a datetime object immediately after dt aligned by s seconds"""

    return find_aligned_datetime_before(dt, s) + datetime.timedelta(seconds = s)

class KenLocator(ticker.Locator):
    def __init__(self, max_ticks):
        self.max_ticks = max_ticks

    def viewlim_to_dt(self):
        vmin, vmax = self.axis.get_view_interval()
        return from_ordinal(vmin), from_ordinal(vmax)

    def __call__(self):
        return [to_ordinal(tick) for tick in self.make_ticks()]

    def make_ticks(self, max_ticks=None):
        """Returns a list of aligned datetime objects between start and end."""
        if max_ticks is None:
            max_ticks = self.max_ticks
        start, end = self.viewlim_to_dt()
        time_interval = end - start
        #Get a list of number of tickmarks an interval would use
        tick_counts = [(time_interval.days*3600 + time_interval.seconds)/float(interval) for interval in possible_time_intervals]
        
        #Select the smallest interval that would result in less than max_ticks
        #or use largest interval
        interval_to_use = None
        for interval, num_ticks in zip(possible_time_intervals, tick_counts):
            if num_ticks > max_ticks:
                if interval_to_use is None:
                    interval_to_use = interval
                break
            interval_to_use = interval
        
        aligned_datetimes = []
        dt_tickmark = find_aligned_datetime_after(start, interval_to_use)
        while dt_tickmark < end:
            aligned_datetimes.append(dt_tickmark)
            dt_tickmark = dt_tickmark + datetime.timedelta(seconds = interval_to_use)
        return aligned_datetimes

class KenFormatter(ticker.FixedFormatter):
    def __init__(self, locator):
        self.locator = locator
        ticker.FixedFormatter.__init__(self, self.make_labels())

    def get_formats(self, twelve_hour=True, quote_format=True, truncation=True):
        start, end = self.locator.viewlim_to_dt()
        ticks = self.locator.make_ticks()

        labels = []
        skip_30_seconds = False
        show_seconds = True
        if len(ticks) > 1:
            interval = (ticks[1] - ticks[0]).seconds
            if interval % 30 == 0:
                show_seconds = False
            if interval == 30:
                skip_30_seconds = True
        prev = start
        hour_tag = "%I" if twelve_hour else "%H"
        hour_tag += "\'" if quote_format else ":"
        for tick in ticks:
            if skip_30_seconds and tick.second == 30:
                labels.append('')
                continue
            label = ''
            if tick.date() != prev.date():
                label += "%Y-%m-%d\n" + hour_tag
            elif not (truncation and show_seconds) or tick.hour != prev.hour:
                label += hour_tag
            if quote_format:
                label +=  "%M"
                if show_seconds:
                    label += "\"%S"
            else:
                label += "%M"
                if show_seconds:
                    label += ":%S"
            labels.append(label)
            prev = tick
        return labels

    def make_labels(self):
        ticks = self.locator.make_ticks()
        formats = self.get_formats()
        return [tick.strftime(fmt) for (tick, fmt) in zip(ticks, formats)]

class DatetimeCollection(LineCollection):
    """
    A LineCollection that expects samples with datetimes as x-coordinates
    and converts them to ordinal values internally."""
    def set_segments(self, segments):
        if not segments or segments == [[]]:
            self._paths = []
            return
        
        np_segments = []
        for seg in segments:
            if not np.ma.isMaskedArray(seg):
                seg = np.asarray([(to_ordinal(x), y) for (x, y) in seg], np.float_)
##                seg = np.array(((to_ordinal(x), y) for (x, y) in seg))

            np_segments.append(seg)
        if self._uniform_offsets is not None:
            np_segments = self._add_offsets(np_segments)
        self._paths = [mpath.Path(seg) for seg in np_segments]
##    def set_segments(self, segments):
##        if segments == [[]] or segments == []:
##            self._paths = []
##            LineCollection.set_segments(self, None)
##            return
##        
##        images = [[(to_ordinal(x), y) for (x, y) in line] for line in segments]
##        LineCollection.set_segments(self, images)

def common_period(start, end):
    categories = ['year', 'month', 'day', 'hour', 'minute', 'second']
    args = []
    
    while categories:
        cat = categories.pop(0)
        if getattr(start, cat) == getattr(end, cat):
            args.append(getattr(start, cat))
        else:
            categories.insert(0, cat)
            break
    return categories

def format_span(start, end):
    categories = common_period(start, end)
    if not categories:
        return "%s-%s" % (start.strftime("%b %d %Y %H:%M:%S"), end.strftime("%b %d %Y %H:%M:%S"))
    elif categories[0] == "second":
        return "%s %ds-%ds" % (start.strftime("%b %d %Y %I:%M%p"), start.second, end.second)
    elif categories[0] == "minute" or categories[0] == "hour":
        return "%s-%s" % (start.strftime("%b %d %Y %I:%M%p"), end.strftime("%I:%M:%p"))
    elif categories[0] == "day" or categories[0] == "month":
        return "%s-%s" % (start.strftime("%b %d %I:%M%p"), end.strftime("%b %d %I:%M%p %Y"))
    elif categories[0] == "year":
        return "%s-%s" % (start.strftime("%b %d %I:%M%p %Y"), end.strftime("%b %d %I:%M%p %Y"))
    else:
        return "%s-%s" % (start.strftime("%b %d %Y %H:%M:%S"), end.strftime("%b %d %Y %H:%M:%S"))

def format_timedelta(td):
    hours, remainder = divmod(td.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)

    parts = []
    if td.days:
        if td.days == 1:
            parts.append("1 day")
        else:
            parts.append("%d days" % td.days)
    if hours:
        if hours == 1:
            parts.append("1 hour")
        else:
            parts.append("%d hours" % hours)
    if minutes:
        if minutes == 1:
            parts.append("1 minute")
        else:
            parts.append("%d minutes" % minutes)
    if td.microseconds:
        parts.append("%.3f seconds" % (seconds + td.microseconds * 1e-6))
    elif seconds:
        if seconds == 1:
            parts.append("1 second")
        else:
            parts.append("%d seconds" % seconds)
    return ", ".join(parts)
