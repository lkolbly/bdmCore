from bdm import Bdm
import time

class Programmer:
	def __init__(self, device):
		self.device = device
		pass

	def _openBdm(self):
		b = Bdm()
		b.testConnection()

		b.bootChip()
		b.execute()

		# Make 100% sure we can write an address and read it back
		for i in range(0x10):
			b.writeByte(0x30 + i, i)
			b.readByte(0x30 + i)
			readData,_ = b.execute()
			if readData[0] != i:
				raise Exception("Got '%s' Expected '%s'"%(readData,i))
		return b

	def _massErase(self, b):
		page = (0x3C00 >> 6) & 0xFF

		b.enableVpp()
		b.delay(50*4) # This is how long it takes for Vpp to rise
		b.writeByte(0x0211, 0x04) # Set MASS bit in FLCR

		b.writeByte(0x1F, page) # Set PAGESEL
		b.writeByte(0xC0, 0x01) # Write arbitrary memory to an arbitrary place in the paging window
		b.delay(5*4) # Delay Tnvs 5us
		b.writeByte(0x0211, 0x0C) # Set HVEN (and MASS)

		b.execute() # The next delay is much too long, we just have to software time it

		# Delay Tme 500ms (500,000us)
		time.sleep(0.5)

		b.writeByte(0x0211, 0x08) # Clear MASS
		b.delay(200)
		b.delay(200) # Delay Tnvhl 100us (200*2)
		b.writeByte(0x0211, 0x00) # Clear HVEN
		b.delay(1*4) # Delay Trcp 1us

		b.disableVpp()
		b.execute()
		pass

	def _slice(self, p):
		memoryMap, stats = p.assemble()

		# Set the low bit of NVOPT to disable flash security
		memoryMap[self.device.labels[".NVOPT"]] = 0x01

		# Turn the memory into an array
		flashBase = self.device.labels[".FLASHBASE"]
		memory = [0]*self.device.getFlashQuantity()
		for addr,data in memoryMap.items():
			memory[addr - flashBase] = data

		rows = []
		for i in range(0, len(memory), 64):
			# Check if this row is even written
			shouldProgram = False
			for j in range(64):
				if flashBase+i+j in memoryMap:
					shouldProgram = True
					break

			if not shouldProgram:
				continue

			rows.append((i + flashBase, memory[i:i+64]))
		return rows

	def program(self, p):
		b = self._openBdm()

		rows = self._slice(p)

		# Erase the chip
		self._massErase(b)
		time.sleep(0.1)

		# Now program each row
		for addr, row in rows:
			print("Programming row at address", addr)
			self._programRow(b, addr, row)
		"""for i in range(0, len(memory), 64):
			# Check if this row is even written
			shouldProgram = False
			for j in range(64):
				if flashBase+i+j in memoryMap:
					shouldProgram = True
					break

			if not shouldProgram:
				continue

			print("Programming row", i, "at address", flashBase + i)
			rowData = memory[i:i+64]
			self._programRow(b, i + flashBase, rowData)"""

		b.shutdownChip()
		b.execute()
		pass

	def _programRow(self, b, rowOffset, rowData):
		if rowOffset & 0x3F != 0:
			raise Exception("rowOffset must be 64-byte aligned! Got %s"%rowOffset)
		page = (rowOffset >> 6) & 0xFF

		b.writeByte(0x1F, page) # Set PAGESEL

		b.enableVpp()
		b.delay(50*4) # This is how long it takes for Vpp to rise
		b.writeByte(0x0211, 0x01) # Set PGM bit in FLCR

		b.writeByte(0xC0, 0x01) # Write arbitrary memory to an arbitrary place in the paging window
		b.delay(5*4) # Delay Tnvs 5us
		b.writeByte(0x0211, 0x09) # Set HVEN (and PGM)
		b.delay(10*4) # Delay Tpgs 10us
		b.flushCommands()

		# Now write all of the data
		addr = rowOffset
		for datum in rowData:
			b.writeByte(addr, datum)
			b.delay(40*4) # Delay Tprog 20-40us
			b.flushCommands()
			addr += 1

		b.writeByte(0x0211, 0x08) # Clear PGM
		b.delay(5*4) # Delay Tnvh 5us
		b.writeByte(0x0211, 0x00) # Clear HVEN
		b.delay(1*4) # Delay Trcp 1us

		b.disableVpp()
		b.flushCommands()
		b.execute()
		time.sleep(0.01)

		# Now read back the memory
		addr = rowOffset
		for i in range(64):
			b.readByte(addr)
			programmedData, _ = b.execute()
			if programmedData[0] != rowData[i]:
				raise Exception("Data programmed at address 0x%04X was 0x%02X, expected 0x%02X"%(addr, programmedData[0], rowData[i]))
			addr += 1
		pass
	pass

if __name__ == "__main__":
	from rs08asm import rs08asm
	from mc9rs08kaX import *
	device = mc9rs08kaX(1)
	p = rs08asm(device)

	p.at(".FLASHBASE")
	p.label("main")
	p.movi(0x01, 0x10)
	p.movi(0x01, 0x11)
	p.bra("main")

	p.at(".RESET")
	p.jmp("main")

	programmer = Programmer(device)
	programmer.program(p)
	pass
