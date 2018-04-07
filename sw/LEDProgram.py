from bdm import Bdm, writeBytesToMemory
from rs08asm import rs08asm
import time

# Program a simple program: Turn on the LED (PTA0)
# This involves setting PTADD0 and PTAD0

from rs08asm import rs08asm
from mc9rs08kaX import *

device = mc9rs08kaX(2)
p = rs08asm(device)
p.at(0x20)         # Base of the big block of RAM (47 bytes!)
p.label("main")
p.movi(0x01, ".PTADD") # Set the data direction register
p.movi(0x01, ".PTAD")  # Turn on the LED
for i in range(3):     # Wait for 3 cycles
	p.nop()
p.movi(0x00, ".PTAD")  # Turn off the LED
for i in range(7):     # Wait for 7 cycles
	p.nop()
p.jmp("main")

memory,stats = p.assemble(enforceIsFlash=False)
print(memory)

#
# Program the chip and run the program
#

b = Bdm()
b.testConnection()

b.bootChip()
print(b.execute())

writeBytesToMemory(b, memory)

# Set the PC to 0x20, initialize A to 0
b.writeCcrPc(0, 0, 0x20)
b.writeA(0)

# Write SOPT to disable the COP
b.writeByte(0x201, 0x02)

# Now step (trace) the instruction, and read A
"""
for i in range(10):
	b.trace()
	b.readA()
	b.readCcrPc()
	print(b.execute())
"""

b.go()
print("Starting execution:",b.execute())

time.sleep(10)

b.shutdownChip()
print(b.execute())
