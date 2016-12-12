/// all below id for LED
int pinNumber=13;
const static int VERIFY_CRC = 0;
const int VERIFY_LRC = 1;
const int VERIFY_LRC_NONSTAND = 2;
int verifyType = 0;
int verifyFrom = 0;
int verifyBeforeEnd = -2;


void ledOn(){
  digitalWrite(pinNumber, HIGH);
}
void ledOff(){
  digitalWrite(pinNumber, LOW);
}
void twinkle(int onTime, int offTime){
  ledOn();
  delay(onTime);
  ledOff();
  delay(offTime);
}

void ledRecvSuccess(){
  twinkle(550,200);
}

void ledRecvDummyCmd(){
  ledReady();
}

void ledRecvCrcError(){
  ledError();
}

void ledError(){
  twinkle(100,50);
  twinkle(100,50);
  twinkle(100,50);
  twinkle(100,50);
  twinkle(100,50);
}
void ledReady(){
  twinkle(150,100);
  twinkle(150,100);
  twinkle(150,100);
}

void ledInit(){
  pinMode(pinNumber, OUTPUT);
  digitalWrite(pinNumber, LOW);
  ledReady();
}

/// All below is about send data
byte cmdBuffer[128];

byte hasCommand(){
  return Serial.readBytes(cmdBuffer, 128);
}

void sendResponse(byte data[], int len) {
  if (verifyType == VERIFY_CRC){
    unsigned short crc = CRC16(data, len);
    data[len+verifyBeforeEnd] = (byte)(crc);
    data[len+verifyBeforeEnd + 1] = (byte)(crc >> 8);
  }
  if (verifyType == VERIFY_LRC){
    byte lrc8 = LRC8(data, len);
    data[len+verifyBeforeEnd] = lrc8;
  }
  if (verifyType == VERIFY_LRC_NONSTAND){
    unsigned short lrc16 = LRCNonstand(data, len);
    data[len+verifyBeforeEnd] = (byte)(lrc16>>8);
    data[len+verifyBeforeEnd + 1] = (byte)(lrc16);
  }
  sendBack(data, len);
}

void sendBack(byte data[], int len){
  int i;
  for(i=0;i<len;i++){
    Serial.write(data[i]);
  }
  Serial.flush();
  digitalWrite(pinNumber, LOW);
}

byte* getCommand(){
  return cmdBuffer;
}

void sendCrcError() {
  // nothing to do now, just blink the led
  ledRecvCrcError();
}


/// all below is about verification

unsigned short LRCNonstand(byte buf[], int len)
{
  int fromByte = verifyFrom;
  int toByte = len+verifyBeforeEnd-1;
  unsigned short rst = 0;
  int b;
  for(b=fromByte;b<=toByte;b++){
    rst = rst + buf[b];
  }
  return rst;
}

unsigned short CRC16(unsigned char buf[], int len)
{
   int fromB = verifyFrom;
   int toB = len+verifyBeforeEnd-1;
   unsigned short crc = 0xffff ;
   int i=0;
   for(i = fromB; i <= toB; i++)
   {
        crc ^= buf[i] ;
        int b;
        for(b = 0; b < 8; b++)
        {
            bool f = crc & 1 ;
            crc >>= 1 ;
            if(f)
                crc ^= 0xa001 ;
        }
    }
    return(crc) ;
}



byte LRC8(byte buf[], int len)
{
  int fromByte = verifyFrom;
  int toByte = len+verifyBeforeEnd-1;
  byte rst = 0;
  int b;
  for(b=fromByte;b<=toByte;b++){
    rst = rst + buf[b];
  }
  return rst;
}



bool doVerify(byte data[], int len){
  if (verifyType == VERIFY_CRC){
    return verifyCrc16(data, len);
  }
  if (verifyType == VERIFY_LRC){
    return verifyLrc(data, len);
  }
  if (verifyType == VERIFY_LRC_NONSTAND){
    return verifyLrcNonstand(data, len);
  }
}
bool verifyCrc16(byte data[], int len){
  int endPos = len+verifyBeforeEnd;
  unsigned short crc = CRC16(data, len);
  return ((data[endPos] == (byte)(crc)) && (data[endPos+1] == (byte)(crc >> 8)));
}
bool verifyLrc(byte data[], int len){
  int endPos = len + verifyBeforeEnd;
  byte lrcVal = LRC8(data, len);
  return lrcVal == data[endPos];
}
bool verifyLrcNonstand(byte data[], int len){
  int endPos = len + verifyBeforeEnd;
  unsigned short lrcVal = LRCNonstand(data, len);
  return ((data[endPos] == (byte)(lrcVal >> 8)) && (data[endPos+1] == (byte)(lrcVal)));
}


void useCrcVerify(int fromByte, int toEndByte){
  verifyType = VERIFY_CRC;
  verifyFrom = fromByte;
  verifyBeforeEnd = toEndByte;
}
void useLrcVerify(int fromByte, int toEndByte){
  verifyType = VERIFY_LRC;
  verifyFrom = fromByte;
  verifyBeforeEnd = toEndByte;
}
void useLrcNonstandVerify(int fromByte, int toEndByte){
  verifyType = VERIFY_LRC_NONSTAND;
  verifyFrom = fromByte;
  verifyBeforeEnd = toEndByte;
}

