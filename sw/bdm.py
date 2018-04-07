import serial
import time

class Command:
	Nop = 0
	Read = 1
	Write = 2
	StartMcu = 3
	StopMcu = 4
	EchoTest = 5
	Delay = 6
	EnableVpp = 7
	DisableVpp = 8
	ReadSyncCount = 9
	Resync = 10

	@staticmethod
	def usesData(cmd):
		return cmd in [Command.Write, Command.EchoTest, Command.Delay]

	@staticmethod
	def dataReturned(cmd):
		return {
			Command.Read: 1,
			Command.EchoTest: 1,
			Command.ReadSyncCount: 2
		}.get(cmd, 0)

class BdmSerialConnection:
	def __init__(self, port='/dev/ttyACM0'):
		self.serial = serial.Serial(port, timeout=2)
		self.commandBuffer = []

	# Low-level I/O
	def __writeByte(self, byte):
		self.serial.write(bytes([byte]))

	def __readByte(self):
		retval = self.serial.read(1)
		if len(retval) == 0:
			raise Exception("Timed out reading bytes")
		return retval[0]

	# Public interface
	def startEngine(self):
		self.__writeByte(0x01)

	def stopEngine(self):
		self.__writeByte(0x00)

	def getCmdFifoHi(self):
		self.__writeByte(0x05)
		return self.__readByte()

	def getCmdFifoLo(self):
		self.__writeByte(0x04)
		return self.__readByte()

	def reset(self):
		self.__writeByte(0x03)
		time.sleep(0.25)

	def enqueueCommand(self, opcode, data=None):
		if not Command.usesData(opcode):
			if data != None:
				raise Exception("Command '%s' does not use data"%opcode)
			data = 0

		if data is None:
			raise Exception("Command '%s' requires that data be passed"%opcode)

		self.commandBuffer.append((opcode, data))

	def flushCommandQueue(self):
		hdrCommand = int('10000000', 2) + len(self.commandBuffer)
		self.__writeByte(hdrCommand)

		for opcode,data in self.commandBuffer:
			self.__writeByte(opcode)
			self.__writeByte(data)
		self.commandBuffer = []

	def read(self):
		return self.__readByte()

	def readN(self, N):
		return [self.__readByte() for _ in range(N)]

class Bdm:
	def __init__(self, port='/dev/ttyACM0', conn=None):
		if conn is None:
			self.conn = BdmSerialConnection(port)
			self.conn.reset()
		else:
			self.conn = conn

		self.queueOutstandingBytes = 0

	def testConnection(self):
		# The test involves sending three echo tests as part of two queues
		self.conn.enqueueCommand(Command.EchoTest, 123)
		self.conn.enqueueCommand(Command.EchoTest, 213)
		self.conn.flushCommandQueue()
		self.conn.startEngine()

		self.conn.enqueueCommand(Command.EchoTest, 86)
		self.conn.flushCommandQueue()

		responses = self.conn.readN(3)
		if responses != [123, 213, 86]:
			raise Exception("Echo test failed, got '%s'"%responses)
		self.conn.stopEngine()
		return responses

	def flushCommands(self):
		numberOfCommands = len(self.conn.commandBuffer)
		return self.conn.flushCommandQueue(), numberOfCommands

	def execute(self, simulate=False):
		# Add an echo test as a sentinal for when the commands are done
		self.conn.enqueueCommand(Command.EchoTest, 123)
		self.queueOutstandingBytes += 1

		# Figure out how many bytes we're expecting
		bytesToRead = self.queueOutstandingBytes
		self.queueOutstandingBytes = 0
		numberOfCommands = len(self.conn.commandBuffer)

		if simulate:
			self.conn.commandBuffer = []
			return [0]*bytesToRead, numberOfCommands

		self.conn.flushCommandQueue()
		commandsToRun = (self.conn.getCmdFifoHi() << 8) + self.conn.getCmdFifoLo()
		self.conn.startEngine()
		bytesRead = self.conn.readN(bytesToRead)
		#time.sleep(0.1)
		self.conn.stopEngine()

		if bytesRead[-1] != 123:
			raise Exception("Sentinal value was '%s', expected 123!"%bytesRead[-1])
		bytesRead = bytesRead[:-1]

		commandsLeft = (self.conn.getCmdFifoHi() << 8) + self.conn.getCmdFifoLo()
		if commandsLeft != 0:
			raise Exception("Did not execute all commands! There are '%s' left over"%commandsLeft)
		return bytesRead, numberOfCommands

	def _enqueueCommands(self, *commands):
		for opcode,data in commands:
			self.queueOutstandingBytes += Command.dataReturned(opcode)
			self.conn.enqueueCommand(opcode, data)
		pass

	def bootChip(self):
		self.conn.enqueueCommand(Command.StartMcu)

	def shutdownChip(self):
		self.conn.enqueueCommand(Command.StopMcu)

	def enableVpp(self):
		self.conn.enqueueCommand(Command.EnableVpp)

	def disableVpp(self):
		self.conn.enqueueCommand(Command.DisableVpp)

	def delay(self, ticks):
		self.conn.enqueueCommand(Command.Delay, ticks)

	def resync(self):
		self.conn.enqueueCommand(Command.Resync)

	def writeByte(self, addr, data):
		self._enqueueCommands(
			(Command.Write, 0xC0),
			(Command.Write, addr >> 8),
			(Command.Write, addr & 0xFF),
			(Command.Write, data),
			(Command.Delay, 30)
		)

	def readByte(self, addr):
		self._enqueueCommands(
			(Command.Write, 0xE0),
			(Command.Write, addr >> 8),
			(Command.Write, addr & 0xFF),
			(Command.Delay, 30),
			(Command.Read, None)
		)

	def writeCcrPc(self, z, c, pc):
		highbyte = (z<<7) | (c<<6) | (pc>>8)
		self._enqueueCommands(
			(Command.Write, 0x4B),
			(Command.Write, highbyte),
			(Command.Write, pc & 0xFF),
			(Command.Delay, 30)
		)

	def readCcrPc(self):
		self._enqueueCommands(
			(Command.Write, 0x6B),
			(Command.Delay, 30),
			(Command.Read, None),
			(Command.Read, None)
		)

	def writeA(self, data):
		self._enqueueCommands(
			(Command.Write, 0x48),
			(Command.Write, data),
			(Command.Delay, 30)
		)

	def readA(self):
		self._enqueueCommands(
			(Command.Write, 0x68),
			(Command.Delay, 30),
			(Command.Read, None)
		)

	def background(self):
		self._enqueueCommands(
			(Command.Write, 0x90),
			(Command.Delay, 30)
		)

	def readStatus(self):
		self._enqueueCommands(
			(Command.Write, 0xE4),
			(Command.Read, None)
		)

	def writeControl(self, data):
		self._enqueueCommands(
			(Command.Write, 0xC4),
			(Command.Write, data)
		)

	def targetReset(self):
		self.conn.enqueueCommand(Command.Write, 0x18)

	def trace(self):
		self._enqueueCommands(
			(Command.Write, 0x10),
			(Command.Delay, 30)
		)

	def go(self):
		self._enqueueCommands(
			(Command.Write, 0x08),
			(Command.Delay, 30)
		)

	def writeBreakpoint(self, addr):
		self._enqueueCommands(
			(Command.Write, 0xC2),
			(Command.Write, addr>>8),
			(Command.Write, addr&0xFF)
		)

	def readBreakpoint(self):
		self._enqueueCommands(
			(Command.Write, 0xE2),
			(Command.Read, None),
			(Command.Read, None)
		)

	def readSyncCount(self):
		self._enqueueCommands(
			(Command.ReadSyncCount, None)
		)

def writeBytesToMemory(b, memoryMap):
	numWritten = 0
	for address,value in memoryMap.items():
		b.writeByte(address, value)
		numWritten += 1
		if numWritten > 24:
			b.execute()
	b.execute()
	print(numWritten)

if __name__ == "__main__":
	b = Bdm()
	b.testConnection()

	b.bootChip()
	b.execute()
	time.sleep(0.05)

	b.writeByte(0x31, 0xDC)
	b.writeByte(0x32, 0xCD)
	b.execute()

	b.readByte(0x31)
	b.readByte(0x32)
	b.readByte(0x31)
	print(b.execute())

	b.readByte(0x31)
	b.readByte(0x31)
	b.shutdownChip()
	print(b.execute())
