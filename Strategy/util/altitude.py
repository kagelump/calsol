'''
Created on Feb 22, 2011

@author: kevin
'''
from math import sin, cos, acos, ceil
from lxml import etree, objectify
import urllib
import argparse
import sys
import simplejson as json

"""
EVERYTHING SHOULD BE LATTITUDE, LONGITUDE
"""

def depthFirst(root, target, ret = []):
	"""
	  Depth first traversal of the kml tree.
	  Returns an accumulation of the contents of all nodes
	  of type target 
	"""
	for child in root:
		depthFirst(child, target, ret)
		if child.tag == target:
			ret += [child.text]
	return ret

def parseCoords(coordList):
	"""
	  Pass in a list of values from <coordinate> elements
	  Return a list of (longitude, latitude, altitude) tuples
	  forming the road geometry
	"""
	def parseCoordGroup(coordGroupStr):
		"""
		  This looks for <coordinates> that form the road geometry, and
	  	  then parses them into (longitude, latitude, altitude). Altitude
	  	  is always 0.
	  	  If the coordinate string is just the coordinates of a place, then
	  	  return the empty list 
		"""
		#print "coordGroupStr:", coordGroupStr
		coords = coordGroupStr.strip().split(" ")
		if len(coords) > 3:
			coords = map(lambda x: x.split(","), coords)
			coords = map(lambda x: tuple(map(float, x)), coords)
			coords = map(lambda x: (x[1], x[0]), coords)
			
			#print 'returning:', coords
			return coords
		else:
			return []
	
	ret = []
	#print "coordList:", coordList
	for coordGroup in coordList:
		ret += parseCoordGroup(coordGroup)
	return ret

def filterDups(coordList):
	"""
	  gets rid of adjacent duplicates in a list
	"""
	ret = []
	for i in range(0, len(coordList)-1):
		if coordList[i] == coordList[i+1]:
			continue
		ret += [coordList[i]]
	ret += [coordList[-1]]
	return ret

def toRad(x):
	return x * 2 * math.pi / 360.

def distance(coord1, coord2):
	import math
	# http://www.movable-type.co.uk/scripts/latlong.html
	R = 6371000 # radius of the earth in km
	if coord1[:2] == coord2[:2]:
		return 0
	else:
		lat1, lon1 = map(toRad, coord1[0:2])
		lat2, lon2 = map(toRad, coord2[0:2])
		d = acos(sin(lat1)*sin(lat2) + 
			 cos(lat1)*cos(lat2) *
			 cos(lon1-lon2)) * R
		return d # distance along spherical globe in km

def calcDistances(route):
	'''
	  route is a list [((lat, lon), alt) ... ]
	'''
	ret = []
	ret.append(route[0] + (0,))
	for i in range(1, len(route)):
		dist = distance(route[i][0], route[i-1][0])
		print 'route[', i, ']:', route[i]
		print 'd ', i-1, ':', ret[i-1][-1]
		print 'd ', i, ':', dist
		print 'tot dist:', ret[i-1][-1] + dist
		print '='*10, '\n'
		ret.append(route[i] + (ret[i-1][-1]+dist,))
	return ret


def getEdgeElevations(edges, groupSize = 50):
	"""
	  Ask google very nicely to share their elevation data with us.
	  Returns a list of (longitude, latitude, altitude) tuples
	  
	  groupSizes have the potential to be too large for
	  Google to give a response. It's best not to go over 50 
	"""
	ret = []
	i = 0
	while i < len(edges):
		points = ""
		j = i
		while j < len(edges) and j < i + groupSize:
			#print "loc:", edges[j]
			points += "%f,%f|" % edges[j]
			j += 1
		points = points[:-1] #chop off the last |
		
		url = ELEVATION_BASE_URL + "locations=%s&sensor=false" % (points)
		print 'url:', url
		response = json.load(urllib.urlopen(url))
		
		if response['status'] != 'OK':
			if response['status'] == 'DATA_NOT_AVAILABLE':
				print "no data for:"
				print "url:", url
			elif response['status'] == 'OVER_QUERY_LIMIT':
				print "OVER QUERY LIMIT!!!"
				print "url:", url
				print 'response:', response
				return (ret, i)
			else:
				print "STOPPED GETTING ALTITUDE DATA!!!!"
				print "url:", url
				print 'response:', response
				print 'finished indices', 0, 'through', i-1, 'of edges'
				return (ret, i)
		else:
			print "query", i, "ok:", url
		def makeTuple(x):
			if 'elevation' not in x.keys():
				return ((x['location']['lat'], x['location']['lng']), -100000000000)
			return ((x['location']['lat'], x['location']['lng']), x['elevation'])
		# convert json to tuples
		ret += map(makeTuple, response['results'])
		i += groupSize
	return (ret, i)

if __name__ == '__main__':
	import math
	print "started"
	
	ELEVATION_BASE_URL = 'http://maps.googleapis.com/maps/api/elevation/json?'
	coordTag = "{http://www.opengis.net/kml/2.2}coordinates"
	
	altitude_sample_rate = 1 # altitude sample ever tenth of a mile
	
	parser = argparse.ArgumentParser()
	parser.add_argument('--input', default="../data/CalSol.kml")
	parser.add_argument('--start', default="0")
	parser.add_argument('--end', default="-1")
	args = parser.parse_args(sys.argv[1:])
	
	kml_root = etree.parse(open(args.input, "r")).getroot()
	unparsed_coords = depthFirst(kml_root, coordTag)
	parsed_coords = filterDups(parseCoords(unparsed_coords))
	
	args.start = int(args.start)
	args.end = int(args.end)
	
	print "start index:", args.start
	print "end index:", args.end
	print "len(parsed_coords):", len(parsed_coords)
	if args.end == -1:
		args.end = len(parsed_coords)
	
	# don't go over 2500 requests per day or Google will block you
	parsed_coords, completed = getEdgeElevations(parsed_coords[args.start:args.end])
	
	parsed_coords = calcDistances(parsed_coords)
	print 'after calc D:', parsed_coords
	#write the results to a csv
	fileName = args.input+"_"+str(args.start)+"_"+str(args.end)+".csv"
	print 'writing to:', fileName 
	file = open(fileName, "w")
	file.write("# latitude, longitude, elevation in m above sea level, cumulative distance traveled in m. completed %d\n" % completed)
	for p in parsed_coords:
		file.write("%s,%s,%s,%s\n" % (p[0][0], p[0][1], p[1], p[2]))
	file.close() 
	
	print "done"

