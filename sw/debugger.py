import drivingTimer

debug = drivingTimer.p.debugInfo()

def debugAddress(addr):
	# Find the corresponding label
	label = ""
	for k,v in debug["labels"].items():
		if v > debug["labels"].get(label,0) and v <= addr:
			label = k

	if addr not in debug:
		b.readByte(addr)
		return "%02X"%b.execute()[0][0]
	import json
	return label+" - "+json.dumps(debug[addr])

import bdm
import time
import sys

b = bdm.Bdm()
b.testConnection()

b.bootChip()
b.execute()

def reboot():
	global b
	b.shutdownChip()
	b.execute()
	time.sleep(0.5)
	b = bdm.Bdm()
	b.testConnection()
	b.bootChip()
	#b.background()
	b.execute()

def shutdown():
	b.shutdownChip()
	b.execute()

def peek(addr, nbytes=1):
	for i in range(nbytes):
		b.readByte(addr+i)
	#print ""%(b.execute()[0])
	bs = b.execute()[0]
	for x in bs:
		sys.stdout.write("0x%02X "%x)
	print()

def pc():
	b.readCcrPc()
	hilo = b.execute()[0]
	pc = ((hilo[0]&0x3F) << 8) | hilo[1]
	print("0x%04X - %s"%(pc, debugAddress(pc)))

def step():
	b.trace()
	b.execute()
	pc()

def brk(addr=None):
	if not addr:
		b.background()
		b.execute()
		return
	b.writeBreakpoint(addr)
	b.writeControl(0xA8)
	b.execute()

def disableBrk():
	b.writeControl(0x80)
	b.execute()

def go():
	b.go()
	b.execute()

def status():
	b.readStatus()
	status = b.execute()[0][0]
	print("BDM:", "enabled" if status&0x80 else "disabled")
	print("Background Active:", "true" if status&0x40 else "false")
	print("Breakpoints:", "enabled" if status&0x20 else "disabled")
	print("- Force/tag:", "force" if status&0x10 else "tag")
	print("Status:", "wait/stop" if status&0x04 else "running")
	if status&0x01:
		print("wait/stop failure status set")
	b.readA()
	print("A =",b.execute()[0][0])
