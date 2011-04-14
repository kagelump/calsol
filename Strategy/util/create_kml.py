def mapPath(ptBuff):
    ret =\
    '        <Placemark>\n'\
    '            <MultiGeometry>\n'\
    '                <LineString>\n'\
    '                    <coordinates>\n'
    for pt in ptBuff:
        ret += '%s,%s,%s \n' % pt
    ret +=\
    '                     </coordinates>\n'\
    '                 </LineString>\n'\
    '             </MultiGeometry>\n'\
    '        </Placemark>\n'
    return ret

def makeKML(file, points):
    file.write(
    '<?xml version="1.0" encoding="UTF-8"?>\n'\
    '<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">\n'\
    '<Folder>\n'\
    '    <name>CalSol</name>\n'\
    '    <open>1</open>\n'\
    '    <Document>\n'\
    '        <name>Darwin NT, Australia to Katherine NT, Australia</name>\n'
    )
    
    count = 0
    ptBuff = []
    for pt in points:
        ptBuff += [pt]
        count += 1
        if count == 1000:
            file.write(\
    '        <Placemark>\n'\
    '            <name>%s points</name>\n' % count\
    +'            <Point>\n' \
    '                <coordinates>%s,%s</coordinates>\n' % (ptBuff[-1][0:2])\
    +'            </Point>\n'\
    '        </Placemark>\n')
            file.write(mapPath(ptBuff))
            count = 0
            ptBuff = []
    
    file.write(
    '    </Document>\n'\
    '</Folder>\n'\
    '</kml>'
    )

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) != 2:
        print 'usage output.kml'
        sys.exit(1)

    #input = open('../misc/master_2.csv', 'r')
    output = open('../data/kml_out.kml', 'w')

    points = []

    for line in sys.stdin:
        #print 'line:', line
        lon, lat, alt = line.strip().split(',')
        points += [ (lon, lat, alt) ]

    makeKML(output, points)

    #input.close()
    output.close()

