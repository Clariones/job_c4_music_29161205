// the setup function runs once when you press reset or power the board
#include <SoftwareSerial.h>
extern byte* bitOutput;
extern short* shortOutput;

const byte CMD_DELAY_AND_SEND = 0xE1;
const byte CMD_SET_RESPONSE = 0xE2;
const byte CMD_SET_NO_RESPONSE = 0xE3;

byte* dataBuffer;
byte responseLen;
byte responseMode;
unsigned long targetMills = 0;

SoftwareSerial  mySerial(0, 1);
byte deviceID = 0x00;
void setup() {
  // initialize digital pin 13 as an output.
  Serial.begin(9600);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }
  ledInit();
  responseMode = CMD_SET_NO_RESPONSE;
  dataBuffer = (byte*)malloc(256);
  initMemoryBlocks();  // MUST do before any memory operation
  Serial.setTimeout(10);
  ledReady();
  mySerial.begin(9600);
  useCrcVerify(0,-2);
}

// the loop function runs over and over again forever
void loop() {
  handleDelayResponse();
  byte len = hasCommand();
  if (len <= 0 ) {
    return;
  }
  byte* cmdBuffer = getCommand();
  // command format: [ID] [Code] [Length] [data..] FF DD
  byte cmdID = cmdBuffer[0];
  if ((cmdID == deviceID) && (cmdBuffer[len-2]==0xFF) && (cmdBuffer[len-1]==0xDD)){
    processSimulatorCmd(cmdBuffer);
    return;
  }
  simulateResponse();
}

void simulateResponse(){
  twinkle(50,50);
  if (responseMode != CMD_SET_RESPONSE) {
    return;
  }
  long delayMills = targetMills - 300;
  if (delayMills > 0){
    delay(delayMills);
  }
  twinkle(50,50);
  twinkle(50,50);
  sendSimResponse();
}

void sendSimResponse(){
  sendBack(dataBuffer, responseLen);
}

void handleDelayResponse(){
  if (responseMode != CMD_DELAY_AND_SEND) {
    return;
  }
  unsigned long curMills = millis();
  if (curMills < targetMills) {
    return;
  }
  responseMode = CMD_SET_NO_RESPONSE;
  sendSimResponse();
}

void saveData(byte* cmdBuffer, byte pos, byte len){
    if (len > 255) {
      return;
    }
    int i = 0;
    for(i=0;i<len;i++){
      dataBuffer[i] = cmdBuffer[pos+i];
    }
  responseLen = len;
}
void processSimulatorCmd(byte* cmdBuffer)
{
   byte cmdCode = cmdBuffer[1];
   unsigned long intvl = 0;
   switch (cmdCode){
    case CMD_DELAY_AND_SEND:
      intvl = cmdBuffer[3] * 100;
      targetMills = millis() + intvl;
      saveData(cmdBuffer, 4, cmdBuffer[2]-1);
      responseMode = CMD_DELAY_AND_SEND;
      twinkle(200,50);
      break;
    case CMD_SET_RESPONSE:
      intvl = cmdBuffer[3] * 100L;
      targetMills = intvl;
      saveData(cmdBuffer, 4, cmdBuffer[2]-1);
      responseMode = CMD_SET_RESPONSE;
      twinkle(200,50);
      break;
    case CMD_SET_NO_RESPONSE:
      responseMode = CMD_SET_NO_RESPONSE;
      twinkle(200,50);
      break;
    default:
      twinkle(50,50);
      break;
   }
}
  
  
