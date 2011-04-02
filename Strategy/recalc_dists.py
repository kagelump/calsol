def toRad(x):
	return x * 2 * pi / 360.

def distance(coord1, coord2):
	# http://www.movable-type.co.uk/scripts/latlong.html
	R = 6371000 # radius of the earth in km
	if coord1[:2] == coord2[:2]:
		return 0
	else:
		print 'c1:', coord1, 'c2:', coord2
		lat1, lon1 = map(toRad, map(float, coord1[0:2]))
		lat2, lon2 = map(toRad, map(float, coord2[0:2]))
		d = acos(sin(lat1)*sin(lat2) + 
			 cos(lat1)*cos(lat2) *
			 cos(lon1-lon2)) * R
		return d # distance along spherical globe in meters

if __name__ == '__main__':
	import sys
	from math import sin, cos, acos, ceil, pi
	
	input = open(sys.argv[1], 'r')
	output = open(sys.argv[2], 'w')
	
	if not (len(sys.argv) == 3):
		print 'usage input.csv output.csv'
		os.exit(1) 
	while True:
		l = input.readline().strip()
		if l[0] == '#':
			l = input.readline().strip()
		else:
			break
	
	lat, lon, alt, _  = input.readline().strip().split(",")
	output.write("%s,%s,%s,%s\n" % (lat, lon, alt, 0))
	
	previousCoord = (lat, lon)
	totalDist = 0
	for line in input:
		if line[0] == '#':
			continue
		lat, lon, alt, dist = line.strip().split(",")
		totalDist += distance( (lat, lon), previousCoord)
		output.write("%s,%s,%s,%s\n" % (lat, lon, alt, totalDist))
		previousCoord = (lat, lon)
	
	print 'done'
