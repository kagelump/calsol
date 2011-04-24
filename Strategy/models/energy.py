import collections
import math

route = None

GPSCoordinateBase = collections.namedtuple("GPSCoordinateBase",
                                           ["latitude", "longitude",
                                            "altitude", "distance"])

class GPSCoordinate(GPSCoordinateBase):
    "Represents a (latitude, longitude, altitude) GPS coordinate plus cumulative distance"
    __slots__ = ()

    def __new__(cls, latitude, longitude, altitude=0, distance=0):
        superclass = super(GPSCoordinateBase, cls)
        return superclass.__new__(cls, (latitude, longitude, altitude, distance))

    #Convenience attributes
    @property
    def lat(self):
        return self.latitude
    @property
    def lon(self):
        return self.longitude
    @property
    def long(self):
        return self.longitude
    @property
    def alt(self):
        return self.altitude

    def __sub__(self, other):
        "Computes the distance in meters between this coordinate and the other"
        lat1, lon1 = map(math.radians, [self.lat, self.lon])
        lat2, lon2 = map(math.radians, [other.lat, other.lon])
        R = 6371000
        dLat = lat2-lat1
        dLon = lon2-lon1
        a = (math.sin(dLat/2) * math.sin(dLat/2) +
             math.cos(lat1) * math.cos(lat2) * math.sin(dLon/2) * math.sin(dLon/2))
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

        return R * c

def distance(c1, c2, ignore_altitude=False):
    if ignore_altitude:
        c1 = c1._replace(altitude=0.0)
        c2 = c2._replace(altitude=0.0)
    return c2 - c1

MASS_CAR = 20 #kg
GRAVITY = 9.8 #m/s2
C1 = 0 #rolling constant
C2 = 0
C3 = 0
CD = 0
A = 0
RHO = 0
HV_CURRENT = 0
HV_RESISTANCE = 0
MOTOR_CURRENT = 0
MOTOR_VOLTAGE = 0

def pairwise(sequence, start=0):
    """
    Does a pairwise iteration over the sequence. Starting at the start
    index, it yields tuples of (seq[i], seq[i+1]) until the end of the
    sequence
    """
    if len(sequence) < 2:
        return
    
    prev = sequence[start]
    index = start + 1
    while index < len(sequence):
        curr = sequence[index + 1]
        yield (prev, curr)
        prev = curr
        index += 1
    

class CarModel(object):
    """
    CarModel represents our model of the car's parameters so that it's easier
    to keep them together and run simulations with alternative parameters.
    """
    def __init__(self, params={}, **kwargs):
        self.params = params.copy()
        self.params.update(kwargs)

    def __getattr__(self, name):
        return self.params[name]

    def step_energy_loss(self, start, end, speed):
        #Compute the power loss between two waypoints on the route, assuming
        #a constant speed
        dE = 0
        dh = start.altitude - end.altitude
        dx = end - start
        dt = dx / speed
        currentSpeed = speed
        
        # altitude
        dE += self.MASS_CAR * GRAVITY * dh
        
        # rolling
        dE += -1 * dx * (self.C1 + self.C2*currentSpeed + self.C3*speed**2)

        # drag
        dE += -.5 * self.CD * self.A * self.RHO * math.pow(currentSpeed, 3)

        # braking??? this formula from the wiki makes no sense
        #dE += -.5 * MASS_CAR * math.pow(currentSpeed, 2)
        
        # HV losses
        dE += -1 * math.pow(self.HV_CURRENT, 2) * self.HV_RESISTANCE * dt

        # Motor losses
        dE += -1 * self.MOTOR_CURRENT * self.MOTOR_VOLTAGE * dt

        # Battery losses
        # ???

        # Low Voltage losses
        # ???

        return dE

    def energy_loss_iterator(self, latitude, longitude, speed, time):
        """
        Assuming that we start at the point on the course nearest to the specified
        latitude and longitude, compute the energy consumed if we maintain the
        specified average velocity in (TODO: UNITS SHOULD GO HERE)

        Yields the computed dE on the final iteration.
        """
        if route is None:
            load_data()

        targetDist = speed * time
        done = False

        start = GPSCoordinate(latitude, longitude)
        pt_index = closestPointIndex(start)
        dE = 0.0

        #Compute the dE,distance from the initial start position to the closest
        #race checkpoint
        checkpoint = route[pt_index]
        distStep = distance(start, checkpoint, ignore_altitude=True)
        if distStep > targetDist:
            # if the distance to the next point on the route is greater
            # than the total distance to drive, then we're done
            checkpoint = interpolateCoordinates(start, checkpoint, targetDist/distStep)
            done = True

        dE += self.step_energy_loss(start, checkpoint, speed)
        yield (done, dE)
        
        distTravelled = distStep

        pt_index += 1
        for (waypt1, waypt2) in pairwise(route, pt_index):
            if distTravelled >= targetDist:
                done = True
                break

            distStep = waypt2.distance - waypt1.distance

            if distTravelled + distStep > targetDist:
                #If we reach the target distance inbetween checkpoints,
                #only compute the energy lost reaching the actual end
                fraction = (targetDist - distTravelled)/distStep
                intermediate = interpolateCoordinates(waypt1, waypt2, fraction)
                dE += self.step_energy_loss(waypt1, intermediate, speed)
                done = True
            else:
                dE += self.step_energy_loss(waypt1, waypt2, speed)
            yield (done, dE)
        
        yield (True, dE)

    def energy_loss(self, latitude, longitude, speed, time):
        it = self.energy_loss_iterator(latitude, longitude, speed, time)

        for (done, result) in it:
            if done:
                return result
        else:
            return None

    def step_energy_gain(self, start, end, speed):
        pass

    def energy_gain_iterator(self, latitude, longitude, speed, time):
        pass

    def energy_gain(self, latitude, longitude, speed, time):
        pass
    
defaultModel = CarModel(
    MASS_CAR = 20,
    C1 = 0,
    C2 = 0,
    C3 = 0,
    CD = 0,
    A = 0,
    RHO = 0,
    HV_CURRENT = 0,
    HV_RESISTANCE = 0,
    MOTOR_CURRENT = 0,
    MOTOR_VOLTAGE = 0)

def powerConsumption(start, speed, time):
    return defaultModel.energy_loss(start.lat, start.lon, speed, time)

def interpolateCoordinates(c1, c2, p):
    """
    Do linear interpolation between two coordinates
    """
    c1 = map(lambda x: x*p, c1)
    c2 = map(lambda x: x*(1-p), c2)
    return GPSCoordinate(*map(lambda x: x[0] + x[1], zip(c1, c2)))

def nextPointIndex(coord):
    """
    Returns the index of the next checkpoint on the route after coord
    """
    closestPti = closestPointIndex(route, coord)
    closestPt= route[closestPti]
    nextPt = route[closestPti+1]
    if distance(coord, nextPt) < distance(closestPt, nextPt):
        return closestPti+1
    else:
        return closestPti

def closestPointIndex(coord):
    """
    Returns the index of the coordinate on the route closest to coord
    """
    closestDist = float('-Inf')
    for i in range(0, len(route)):
        d = distance(route[i], coord)
        if d > closestDist:
            closestDist = d
        else:
            return i

def load_data():
    """
    Load Route Data and put it in route as groups of coordinate points
    Expects csv data in the format (lat, lon, alt, cumulative distance)
    where latitude and longitude are measured in decimal degrees and
    altitude and cumulative distance are measured in meters.
    
    """
    global route
    if route is not None:
        return
    
    route = [] #format [ pos1, pos2, ... ]
    route_filename = "./data/course.csv"
    with open(route_filename, "r") as f:
        for i, line in enumerate(f):
            line = line.strip()
            # lines w/ #'s are for comments in my csv's
            if line.startswith("#"):
                continue
            try:
                values = map(float, line.split(","))
            except:
                raise ValueError("Error on line %d of %s: unparsable coordinate:\n%s" %
                                 (i+1, route_filename, line))

            coord = GPSCoordinate(*values)

            if coord.lat > 90 or coord.lat < -90:
                raise ValueError("Error on line %d of %s: invalid latitude:\n%s" %
                                 (i+1, route_filename, line))

            if coord.lat > 180 or coord.lat < -180:
                raise ValueError("Error on line %d of %s: invalid longitude:\n%s" %
                                 (i+1, route_filename, line))

            route.append(coord)
    
    if not route:
        raise ValueError("Race route is empty")
    

if __name__ == '__main__':
    print 'started'
    
    time = 60*60        #seconds left in race
    lat, lon = 130, -12 #latitude, latitude, meters above sea level
    start_pos = (-12, 130) 
    speed = 10          #m/s speed parametrized on something

    
    load_data()
    dE = defaultModel.energy_loss(lat, lon, speed, time)
    print 'dE:', dE
    print 'done'
