import sys, math

route = None

def calcdE(startPos, speed, time):
    global route
    if not route:
        print 'route not loaded!!!'
        sys.exit(1)

    targetDist = speed(0) * time

    pti = closestPointIndex(route, startPos)
    dE = 0
    
    startDist = route[pti][3]
    currentDist = startDist
    
    distStep = distance(startPos, route[pti])
    dE += energyStep(startPos, route[pti], distStep, speed)
    currentDist += distStep

    lastCoord = route[pti]
    pti += 1
    while (currentDist - startDist < targetDist) and (not (pti == len(route))):
        currentDist += route[pti][3]
        
        distStep = route[pti][3] - lastCoord[3]
        dE += energyStep(route[pti], lastCoord, distStep, speed)
        print 'dE:', dE
        lastCoord = route[pti]
        pti += 1
    return dE

def energyStep(start, end, dist, speed):
    dE = 0
    currentSpeed = speed(0)
    time = dist / currentSpeed
    
    # altitude
    dE += MASS_CAR * GRAVITY * (start[3] - end[3])
    
    # rolling
    dE += -1 * dist * (C1 + C2*currentSpeed + C3*math.pow(currentSpeed, 2))

    # drag
    dE += -.5 * CD * A * RHO * math.pow(currentSpeed, 3)

    # breaking??? this formula from the wiki makes no sense
    #dE += -.5 * MASS_CAR * math.pow(currentSpeed, 2)
    
    # HV losses
    dE += -1 * math.pow(HV_CURRENT, 2) * HV_RESISTANCE * time

    # Motor losses
    dE += -1 * MOTOR_CURRENT * MOTOR_VOLTAGE * time

    # Battery losses
    # ???

    # Low Voltage losses
    # ???

    return dE

    

def distance(c1, c2):
    import math
    lon1, lat1 = map(lambda x: x*2*math.pi/360., c1[0:2])
    lon2, lat2 = map(lambda x: x*2*math.pi/360., c2[0:2])
    R = 6371000
    dLat = lat2-lat1
    dLon = lon2-lon1
    a = math.sin(dLat/2.) * math.sin(dLat/2.) + \
        math.cos(lat1) * math.cos(lat2) * \
        math.sin(dLon/2.) * math.sin(dLon/2.);
    c = 2. * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def closestPointIndex(route, coord):
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
    """
    """if data_loaded:
        print 'trying to load the data twice!'
        sys.exit(1)"""
    global route
    route = [] #format [ pos1, pos2, ... ]
    input = open("./misc/ddist.csv")
    
    line = input.readline()
    while line:
        if line[0] == '#':
            # lines w/ #'s are for comments in my csv's
            line = input.readline()
            continue
        
        coord = map(float, line.strip().split(","))
        #print 'coord1:', coord
        #coord[1], coord[0] = coord[0], coord[1]
        #print 'coord2:', coord
        coord = tuple(coord)
        #print 'coord:', coord

        route += [coord]
        line = input.readline()
    input.close()
    
    #test that the data is in the correct format
    if route[0][0] < 120 or route[0][0] > 140:
        print 'route[0][0]:', route[0][0]
        print 'make sure you did not switch longitude and lattitude in the csv!!!'
        sys.exit(1)
    if route[0][1] > -10 or route[0][1] < -40:
        print 'route[0][1]:', route[0][1]
        print 'make sure you did not switch longitude and lattitude in the csv!!!'
        sys.exit(1)
    #end load_data()

if __name__ == '__main__':
    print 'started'

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

    
    time = 1000 #seconds left in race
    start_pos = (138, -34, 41, 10) #longitude, latitude, meters above sea level
    speed = lambda x: 30 #km/h speed parametrized on something

    
    load_data()
    dE = calcdE(start_pos, speed, time)
    print 'dE:', dE
    
    print 'done'

























