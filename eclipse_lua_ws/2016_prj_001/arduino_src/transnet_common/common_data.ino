#define length(x) ((sizeof(x))/(sizeof(x[0])))
byte* coilsData;
int coilsBlock[][2] =
{
    {10001, 10114}
};

byte* discreteInputsData;
int discreteInputsBlock [][2] =
{
    {20001, 20528}
};

unsigned short* inputRegistersData;
int inputRegistersBlock[][2]  =
{
    {30001, 30022}
};

unsigned short* holdingRegistersData;
int holdingRegistersBlock [][2] =
{
    {0, 100}
};

int regOffset, regBit;
byte* bitOutput;
short* shortOutput;

int calcByteMemorySize(int addressBlocks[][2], int blockNumbers)
{
    int i;
    int totalSize = 0;
//    printf("Calculate bit memory size of {");
    for(i=0; i<blockNumbers; i++)
    {
//        printf("[0x%04X,0x%04X] ", addressBlocks[i][0], addressBlocks[i][1]);
        totalSize += addressBlocks[i][1] - addressBlocks[i][0] + 1;
    }
//    printf("\b}\n");
    return totalSize * sizeof(unsigned short);
}

int calcBitMemorySize(int addressBlocks[][2], int blockNumbers)
{
    int i;
    int totalSize = 0;
//    printf("Calculate bit memory size of {");
    for(i=0; i<blockNumbers; i++)
    {
//        printf("[0x%04X,0x%04X] ", addressBlocks[i][0], addressBlocks[i][1]);
        totalSize += (addressBlocks[i][1] - addressBlocks[i][0])/8 + 1;
    }
//    printf("\b}\n");
    return totalSize;
}

void locateBitAddress(int address, int block[][2], int len)
{
    int i;
    regOffset = 0;
    regBit = 0;
    for(i = 0; i<len; i++)
    {
        int* segment = block[i];
        if (address >= segment[0] && address <= segment[1])
        {
            regOffset += (address - segment[0])/8;
            regBit = (address - segment[0]) % 8;
            return;
        }
        else
        {
            regOffset += (segment[1] - segment[0])/8 + 1;
        }
    }
    regOffset = -1;
    regBit = 0;
}
void locateShortAddress(int address, int block[][2], int len)
{
    int i;
    regOffset = 0;
    for(i = 0; i<len; i++)
    {
        int* segment = block[i];
        if (address >= segment[0] && address <= segment[1])
        {
            regOffset += address - segment[0];
            return;
        }
        else
        {
            regOffset += segment[1] - segment[0] + 1;
        }
    }
    regOffset = -1;
    regBit = 0;
}

/**
    Normally, return output bytes number.
    Output values stored in bitOutput.
    If returned value > 0x8000, this is an error code.
*/
int readBits(byte* dataMem, int memBoundary[][2], int len, int address, int number)
{
    if (number > 2000)
    {
        return 0x8000 + 2;
    }
    memset(bitOutput, 0, 256);
    int curAddr = address;
    int curOffset = 0, curBit=0;
    for(curAddr = address; curAddr < address+number; curAddr++)
    {
        locateBitAddress(curAddr, memBoundary, len);
        // if regOffset = -1, then error.
        if (regOffset < 0)
        {
            return 0x8000 + 3; // invalid address value, which in valid range, but still not valid
        }
        byte value = dataMem[regOffset] & (1 << regBit);
        //printf("%d: read from %d.%d, value is %02X, current bit value is %02X\n", curOffset, regOffset, regBit, dataMem[regOffset], (value));
        bitOutput[curOffset] |= value;
        curBit++;
        if (curBit >= 8)
        {
            curBit = 0;
            curOffset++;
        }
    }
    return curOffset + (curBit?1:0);
}

int writeBits(byte* dataMem, int memBoundary[][2], int len, int address, int number, byte* data)
{
    if (number > 2000)
    {
        return 0x8000 + 2;
    }
    int curAddr = address;
    int curOffset = 0, curBit=0;
    for(curAddr = address; curAddr < address+number; curAddr++)
    {
        locateBitAddress(curAddr, memBoundary, len);
        // if regOffset = -1, then error.
        if (regOffset < 0)
        {
            return 0x8000 + 3; // invalid address value, which in valid range, but still not valid
        }
        byte regValue = dataMem[regOffset];
        byte setValue = data[curOffset] & (1 << curBit);
        dataMem[regOffset] = regValue & ~(1<<curBit) | setValue;
        //printf("set %02X to 0x%04X.%d, it's original value is %02X, now is %02X\n",
        //        data[curOffset], regOffset, regBit, regValue, dataMem[regOffset]);
        curBit++;
        if (curBit >= 8)
        {
            curBit = 0;
            curOffset++;
        }
    }
    return curOffset + (curBit?1:0);
}

/**
    Normally, return output short number.
    Output values stored in shortOutput.
    If returned value > 0x8000, this is an error code.
*/
int readShorts(unsigned short* dataMem, int memBoundary[][2], int len, int address, int number)
{
    if (number > 2000)
    {
        return 0x8000 + 2;
    }
    memset(shortOutput, 0, 256*2);
    int curAddr = address;
    int curOffset = 0, curBit=0;
    for(curAddr = address; curAddr < address+number; curAddr++)
    {
        locateShortAddress(curAddr, memBoundary, len);
        // if regOffset = -1, then error.
        if (regOffset < 0)
        {
            return 0x8000 + 3; // invalid address value, which in valid range, but still not valid
        }
        //printf("read %d from [%d] to [%d]\n", dataMem[regOffset], regOffset, curOffset);
        shortOutput[curOffset++] = dataMem[regOffset];
    }
    return curOffset;
}
int writeShorts(unsigned short* dataMem, int memBoundary[][2], int len, int address, int number, short* data)
{
    if (number > 2000)
    {
        return 0x8000 + 2;
    }
    int curAddr = address;
    int curOffset = 0;
    for(curAddr = address; curAddr < address+number; curAddr++)
    {
        locateShortAddress(curAddr, memBoundary, len);
        // if regOffset = -1, then error.
        if (regOffset < 0)
        {
            return 0x8000 + 3; // invalid address value, which in valid range, but still not valid
        }
        //printf("write %d in [%d] to [%d]\n", data[curOffset], curOffset, regOffset);
        dataMem[regOffset] = data[curOffset];
        curOffset++;
    }
    return curOffset;
}
#define init(type, name, ptr) \
    {   int memSize = calc##type##MemorySize( name##Block, length( name##Block )); \
        name##Data = (ptr*)malloc(memSize + 2);   \
        memset( name##Data, 0, memSize); \
    }
void initMemoryBlocks()
{
    init(Bit, coils, byte)
    init(Bit, discreteInputs, byte)

    init(Byte, inputRegisters, unsigned short)
    init(Byte, holdingRegisters, unsigned short)

    bitOutput = (byte*)malloc(256);
    shortOutput = (short*)malloc(256*2);
}
#undef init

int writeCoils(int address, int number, byte* data)
{
    return writeBits(coilsData, coilsBlock, length(coilsBlock), address, number, data);
}
int readCoils(int address, int number)
{
    return readBits(coilsData, coilsBlock, length(coilsBlock), address, number);
}
int writeDiscreteInputs(int address, int number, byte* data)
{
    return writeBits(discreteInputsData, discreteInputsBlock, length(discreteInputsBlock), address, number, data);
}
int readDiscreteInputs(int address, int number)
{
    return readBits(discreteInputsData, discreteInputsBlock, length(discreteInputsBlock), address, number);
}
int writeInputRegisters(int address, int number, short* data)
{
    return writeShorts(inputRegistersData, inputRegistersBlock, length(inputRegistersBlock), address, number, data);
}
int readInputRegisters(int address, int number)
{
    return readShorts(inputRegistersData, inputRegistersBlock, length(inputRegistersBlock), address, number);
}
int writeHoldingRegisters(int address, int number, short* data)
{
    return writeShorts(holdingRegistersData, holdingRegistersBlock, length(holdingRegistersBlock), address, number, data);
}
int readHoldingRegisters(int address, int number)
{
    return readShorts(holdingRegistersData, holdingRegistersBlock, length(holdingRegistersBlock), address, number);
}
void dumpBitOutput(byte* ptr, int len)
{
    int i;
    for (i =0; i<len; i++)
    {
        printf(" %02X", ptr[i]);
        if ((i+1) % 8 == 0)
        {
            printf(" ");
        }
        if ((i+1) % 16 == 0)
        {
            printf("\n");
        }
    }
    if (len % 16)
    {
        printf("\n");
    }
}
