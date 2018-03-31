from bdm import Bdm, writeBytesToMemory
from rs08asm import rs08asm
import time

# Program a simple program: Turn on the LED (PTA0)
# This involves setting PTADD0 (0x11) and PTAD0 (0x10)

from rs08asm import rs08asm

p = rs08asm()
p.at(0x20)         # Base of the big block of RAM (47 bytes!)
p.label("main")
p.movi(0x01, 0x11) # Set the data direction register
p.movi(0x01, 0x10) # Turn on the LED
for i in range(3): # Wait for 3 cycles
	p.nop()
p.movi(0x00, 0x10) # Turn off the LED
for i in range(7): # Wait for 7 cycles
	p.nop()
p.jmp("main")

print(p.assemble())

#
# Program the chip and run the program
#

b = Bdm()
b.testConnection()

b.bootChip()
print(b.execute())

writeBytesToMemory(b, p.assemble())

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
