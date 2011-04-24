import numpy
import datetime
import math
import time
import scipy.integrate

def powerGeneration(latitude, velocity, start_time, end_time, cloudy):
	cloudy = cloudy/100
	deltaX = 60 #minutes, defaulted to sample every hour
	year = start_time.timetuple()[0]
	month = start_time.timetuple()[1]
	day = start_time.timetuple()[2]
	startHour = start_time.timetuple()[3]
	startMinute = start_time.timetuple()[4]
	endHour = end_time.timetuple()[3]
	endMinute = end_time.timetuple()[4]
	minutes = (endHour - startHour)*60 + (endMinute - startMinute)
	samples = minutes/deltaX
	fringe = minutes%deltaX
	yValues = []
	xValues = range(samples)
	for i in range(samples):
		yValues.append(totalPower(latitude, datetime.datetime(year, month, day, startHour+int((i*(deltaX/60.0))), (startMinute+i*deltaX) % 60).timetuple()))	
	#fringe
	yValues.append(totalPower(latitude, datetime.datetime(year, month, day, endHour, endMinute).timetuple()))	
	xValues.append(samples - (fringe/60.0))
	result = scipy.integrate.simps(yValues, xValues)
	result *= (1 - .65*cloudy**2) 	#I_effective = I_sol * (1-0.65* c^2)
	return result

def totalPower(latitude, timeTuple):
	global shell_normal
	global shell_faceO
	global shell_vertO
	matrixImport()
	month = timeTuple[1]
	day = timeTuple[2]
	hour = timeTuple[3]
	heading = 85 # Moving SSE
	shell_heading = heading
	shell_azimuths = 180/math.pi*numpy.arctan2(-shell_normal[:,1] ,shell_normal[:,0]) + heading
	shell_tilts = 90 - 180/math.pi*numpy.arcsin(shell_normal[:,2])
	a = shell_vertO[numpy.int_(shell_faceO[:,0]),:]
	b = shell_vertO[numpy.int_(shell_faceO[:,1]),:]
	c = shell_vertO[numpy.int_(shell_faceO[:,2]),:]
	v1 = b - a
	v2 = c - a
	temp = numpy.cross(v1,v2)**2
	temp = numpy.sum(temp, 1)
	shell_Area = 0.5*temp**0.5
	#shell_area = numpy.sum(shell_Area)
	shell_flux = incident_radiation(month, day, hour, shell_tilts, shell_azimuths, latitude)
	shell_power = numpy.dot(shell_flux,shell_Area)
	#shell_fluxavg = shell_power/shell_area
	#return shell_fluxavg
	return shell_power

def rotateZ(nodes, theta):
	"""
	theta in radians
	"""
	theta = math.radians(theta)
	c = math.cos(theta)
	s = math.sin(theta)
	T = numpy.array([(c, -s, 0, 0), (s, c, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)])
	data = numpy.array([nodes, numpy.ones((nodes.shape.append(1)))])
	data = numpy.dot(T, data).transpose()
	out = data[1:3,:].transpose()
	return out

def incident_radiation(month, day, hour, epsilon, zeta, latitude):
	#latitude = lambda_deg 
	year = time.localtime()[0] #current year
	t = datetime.datetime(year, month, day) #generate a timetuple so we can access day number
	d = t.timetuple()[8] # day number of the year
	A = 1310 # W/m^2  Max radiation flux
	B = 0.18
	delta_deg = 23.44*math.sin(math.radians(360/365.25*(d-80))) #declination or angle of earth axis
	alpha_deg = 15*(hour-12) # hour angle
	delta = math.radians(delta_deg)
	latitude = math.radians(latitude)
	alpha = math.radians(alpha_deg)
	chi = math.acos(math.sin(latitude)*math.sin(delta) + math.cos(latitude)*math.cos(delta)*math.cos(alpha));
	xi = math.atan2(math.sin(alpha),(math.sin(latitude)*math.cos(alpha) - math.cos(latitude)*math.tan(delta))) + math.pi
	I_DN = A*math.exp(-B/math.sin(math.pi/2-chi)) # intensity of direct normal radation
	if math.cos(chi) < 0:
		I_D = numpy.zeros(epsilon.shape[0])
	else:
		I_D = I_DN*(math.cos(chi)*numpy.cos(numpy.radians(epsilon)) + numpy.sin(numpy.radians(epsilon))*math.sin(chi)*numpy.cos(xi - numpy.radians(zeta)))
		I_D = numpy.maximum(I_D, 0)
	return I_D

def matrixImport():
	global shell_normal
	global shell_faceO
	global shell_vertO
	global shell_flux
	normFile = open('Impulse_Normals.csv')
	verticesFile = open('Impulse_Vertices.csv')
	norm = numpy.loadtxt(normFile, dtype=float, delimiter=',')
	v = numpy.loadtxt(verticesFile, dtype=float, delimiter=',')
	norm = norm.transpose()
	v = v.transpose()
	vnum = v.shape[1] 
	fnum = norm.shape[1]
	F = numpy.arange(vnum).reshape(3,-1)
	numkeep = 0
	keepnorm = numpy.zeros(norm.shape)
	keepF = numpy.zeros(F.shape)
	for p in range(0, fnum-1):
		if norm[2,p] > -1:
			numkeep += 1
			keepnorm[:,numkeep] = norm[:,p]
			keepF[:,numkeep] = F[:,p]
	shell_vertO = v[:,0:vnum].transpose()
	shell_normal = keepnorm[:,0:numkeep].transpose()
	shell_faceO = keepF[:,0:numkeep].transpose()

#-----------------------------------------------------
#correct, but not used (yet)
def heading(long1, lat1, long2, lat2):
	"""
	heading(long1, lat1, long2, lat2)
	input coordinates in degrees
	output heading in degrees
			0
	270	  		   90
		   180
	"""
	dlong = long2 - long1
	dlat = lat2 - lat1
	#convert everything to radians
	for coord in [dlong, dlat, long1, long2, lat2, lat2]:
		coord = math.radians(coord)
	heading = math.atan2(math.sin(dlong)*math.cos(lat2), math.cos(lat1)*math.sin(lat2) - math.sin(lat1)*math.cos(lat2)*math.cos(dlong))
	heading = math.degrees(heading)
	heading = (heading + 360) % 360
	return heading

if __name__ == '__main__':
	#dummy values
	powerGeneration(36, 20, datetime.datetime(2011, 6, 20, 0), datetime.datetime(2011, 6, 20, 23) , 20)