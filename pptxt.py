#! /usr/bin/env python
#

# DD/MM/YYYY HH:MN:SS  Hs  Hrms Hmax  Tz   Ts   Tc THmax  EPS  T02   Tp  Hrms  EPS 
width = [20,5,5,5,5,5,5,5,5,5,5,5,5]


def ppline(line):
    'Convert one line to CSV.'
    bits = []
    l = 0
    ll = len(line)
    for w in width:
        r = l+w
        if r > ll: break
        bits.append(line[l:r].strip())
        l = r

    return ','.join(bits)


def pptxt(filename):
    'Convert a data file with fixed-width columns to CSV.'
    F = open(filename)
    outfile = filename.replace('.txt','') + '.csv'
    O = open(outfile, 'w')

    # header
    hdr = F.readline()
    hdr = hdr.replace('DD/MM/YYYY HH:MN:SS','Time               ')
    hdr = hdr.replace(' Tp  Hrms  EPS','Tp Hrms2 EPS2')
    hdr = hdr.replace(' Tp  Hrms','Tp Hrms2')
    O.write(ppline(hdr) + '\n')
    F.readline()

    # data
    for line in F.readlines():
        O.write(ppline(line) + '\n')



if __name__=='__main__':
    import sys

    if len(sys.argv)<2: 
        print 'usage:'
        print '  '+sys.argv[0]+' file.txt'
        exit()

    pptxt(sys.argv[1])
