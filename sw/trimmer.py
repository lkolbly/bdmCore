import time
from bdm import Bdm

def getSyncCount(b):
	syncCounts = []
	for i in range(10):
		b.resync()
		#b.execute()
		#time.sleep(0.05)

		b.readSyncCount()
		bs = b.execute()[0]
		syncCounts.append((bs[0]<<8) | bs[1])
	syncCount = sum(syncCounts) / len(syncCounts)
	MHz = 50.0/(syncCount/128.0)
	return syncCount, MHz

def checkTrimValue(b, trim):
	b.writeByte(0x16, int(trim)>>1)
	b.writeByte(0x17, int(trim)&0x01) # The fine bit
	b.execute()
	#time.sleep(0.5)

	syncCount, MHz = getSyncCount(b)
	return syncCount, MHz

def autotrim(tgtMHz):
	b = Bdm()
	b.testConnection()
	b.bootChip()
	b.execute()

	getSyncCount(b)

	trim = 256
	while True:
		# Write the trim
		# WARNING: If you go above ~7MHz (below ~30ish), the clock will be unstable!
		if trim < 30:
			trim = 30
		if trim > 511:
			trim = 511
		syncCount, MHz = checkTrimValue(b, trim)
		print(int(trim), "trim gives", syncCount, "ticks is", MHz, "MHz")

		trim += (MHz - tgtMHz) * 15.0

	b.shutdownChip()
	b.execute()

def buildtrimgraph():
	b = Bdm()
	b.testConnection()
	b.bootChip()
	b.execute()

	for trim in range(512):
		print("%s,%s"%(trim, checkTrimValue(b, trim)[1]))

	b.shutdownChip()
	b.execute()

if __name__ == "__main__":
	autotrim(5) # 5MHz target
	#buildtrimgraph()
	pass
