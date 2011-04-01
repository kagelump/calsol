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

def depthFirst(root, target):
	"""
	  Depth first traversal of the kml tree.
	  Returns an accumulation of the contents of all nodes
	  of type target 
	"""
	def helper(root, target, accumulation):
		for child in root:
			helper(child, target, accumulation)
			if child.tag == target:
				accumulation += [child.text]
	ret = []
	helper(root, target, ret)
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
			#print "returning:", coords
			return coords
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

def distance(coord1, coord2):
	# http://www.movable-type.co.uk/scripts/latlong.html
	R = 6371 # radius of the earth in km
	if coord1 == coord2:
		return 0
	else:
		d = acos(sin(coord1[1])*sin(coord2[1]) + 
				 cos(coord1[1])*cos(coord2[1]) *
				 cos(coord2[0]-coord1[0])) * R
		return d # distance along spherical globe in km

def formatCoord(coord):
	# be careful, google's kml lists longitude first
	lon, lat, _ = coord
	return "%f,%f" % (lat, lon)

def getEdgeElevations(edges, sample_rate, **elvtn_args):
	"""
	  Ask google very nicely to share their elevation data with us.
	  Returns a list of (longitude, latitude, altitude) tuples
	"""
	ret = []
	for i in range(0, len(edges)-1):
		start, dist = edges[i]
		end, _ = edges[i+1]
		
		"""
		I couldn't get this to format properly
		elvtn_args.update({
	        'path': "%s|%s" % (formatCoord(start), formatCoord(end)),
	        'samples': max(ceil(dist/sample_rate), 2),
	        'sensor': "false"
	      })
		url = ELEVATION_BASE_URL + urllib.urlencode(elvtn_args)
		"""
		# samples over 500 tend to get "DATA_NOT_AVAILABLE"
		sampleCount = min(max(ceil(dist/sample_rate), 2), 500)
		url = ELEVATION_BASE_URL + "path=%s|%s&samples=%d&sensor=false" % (formatCoord(start), formatCoord(end), sampleCount)
		
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
				return (x['location']['lng'], x['location']['lat'], -100000000000)
			return (x['location']['lng'], x['location']['lat'], x['elevation'])
		# convert json to tuples
		ret += map(makeTuple, response['results'])
	return (ret, i)

if __name__ == '__main__':
	print "started"
	
	ELEVATION_BASE_URL = 'http://maps.googleapis.com/maps/api/elevation/json?'
	coordTag = "{http://www.opengis.net/kml/2.2}coordinates"
	
	altitude_sample_rate = 1 # altitude sample ever tenth of a mile
	
	parser = argparse.ArgumentParser()
	parser.add_argument('--input', default="../misc/CalSol.kml")
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
	
	edges = [] # edges are ((longitude, latitude, altitude), distance)
	for i in range(0, len(parsed_coords)-1):
		edges += [ (parsed_coords[i], distance(parsed_coords[i], parsed_coords[i+1])) ]
	
	# don't go over 2500 requests per day or Google will block you
	altitudes, completed = getEdgeElevations(edges[args.start:args.end], altitude_sample_rate)
	
	#write the results to a csv
	fileName = args.input+"_"+str(args.start)+"_"+str(args.end)+".csv"
	print 'writing to:', fileName 
	file = open(fileName, "w")
	file.write("# latitude, longitude, elevation. completed %d\n" % completed)
	for alt in altitudes:
		file.write("%s,%s,%s\n" % (alt[1], alt[0], alt[2]))
	file.close() 
	
	print "done"

